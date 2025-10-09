require 'rails_helper'
require 'reshare'

RSpec.describe Reshare do
  # Need a dummy class to test module methods
  let(:dummy_class) { Class.new { extend Reshare } }

  describe '#bd_requestable_id' do
    it 'returns the id of the first LOANABLE record' do
      records = [
        { 'id' => '123', 'lendingStatus' => ['LOANABLE'] },
        { 'id' => '456', 'lendingStatus' => ['NOT_LOANABLE'] }
      ]
      allow(dummy_class).to receive(:_search_by_isn).with('isbn').and_return(records)
      expect(dummy_class.bd_requestable_id('isbn')).to eq('123')
    end

    it 'returns nil if no LOANABLE record is found' do
      records = [
        { 'id' => '456', 'lendingStatus' => ['NOT_LOANABLE'] }
      ]
      allow(dummy_class).to receive(:_search_by_isn).with('isbn').and_return(records)
      expect(dummy_class.bd_requestable_id('isbn')).to be_nil
    end
  end

  describe '#_search_by_isn' do
    before { ENV['RESHARE_SEARCH_URL'] = 'http://reshare.example.com/search' }

    it 'returns parsed records from the API' do
      allow(RestClient).to receive(:get).and_return('{"records":[{"id":"123","lendingStatus":["LOANABLE"]}]}')      
      result = dummy_class._search_by_isn('isbn')
      expect(result).to eq([{ 'id' => '123', 'lendingStatus' => ['LOANABLE'] }])
    end

    it 'returns empty hash on RestClient exception' do
      allow(RestClient).to receive(:get).and_raise(RestClient::Exception)
      expect(dummy_class._search_by_isn('isbn')).to eq({})
    end
  end

  describe '#request_from_reshare' do
    before { ENV['RESHARE_REQUEST_URL'] = 'http://reshare.example.com/request' }

    let(:patron) { 'patronid' }
    let(:item) { 'itemid' }
    let(:pickup_location) { 'loc' }
    let(:note) { 'Test note' }

    it 'returns the id if status is 201' do
      response_body = {
        'message' => '{"id":"req123"}',
        'status' => 201
      }.to_json
      response = double('response', body: response_body)
      allow(RestClient).to receive(:get).and_return(response)
      expect(dummy_class.request_from_reshare(patron: patron, item: item, pickup_location: pickup_location, note: note)).to eq('req123')
    end

    it 'returns :error if status is not 201' do
      response_body = {
        'message' => '{"id":"req123"}',
        'status' => 400
      }.to_json
      response = double('response', body: response_body)
      allow(RestClient).to receive(:get).and_return(response)
      expect(dummy_class.request_from_reshare(patron: patron, item: item, pickup_location: pickup_location, note: note)).to eq(:error)
    end

    it 'returns :error on RestClient exception' do
      allow(RestClient).to receive(:get).and_raise(RestClient::Exception)
      expect(dummy_class.request_from_reshare(patron: patron, item: item, pickup_location: pickup_location, note: note)).to eq(:error)
    end

    it 'returns :error on TypeError' do
      response = double('response', body: 'not json')
      allow(RestClient).to receive(:get).and_return(response)
      allow(JSON).to receive(:parse).and_raise(TypeError)
      expect(dummy_class.request_from_reshare(patron: patron, item: item, pickup_location: pickup_location, note: note)).to eq(:error)
    end
  end
end