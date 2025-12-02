require 'rails_helper'

RSpec.describe BlacklightCornellRequests::Patron do
  let(:netid) { 'abc123' }
  let(:folio_record) do
    {
      'id' => 'user-uuid',
      'barcode' => '1234567890',
      'patronGroup' => 'staff',
      'personal' => { 'firstName' => 'Jane', 'lastName' => 'Doe' }
    }
  end

  let(:token) { { token: 'fake-token' } }
  let(:service_point_response) do
    {
      'servicePointsUsers' => [
        { 'defaultServicePointId' => 'sp-uuid' }
      ]
    }.to_json
  end

  before do
    ENV['OKAPI_URL'] = 'http://folio.example.com'
    ENV['OKAPI_TENANT'] = 'tenant'
    ENV['OKAPI_USER'] = 'user'
    ENV['OKAPI_PW'] = 'pw'

    allow(CUL::FOLIO::Edge).to receive(:authenticate).and_return(token)
    allow(CUL::FOLIO::Edge).to receive(:patron_record).and_return({ user: folio_record })
    allow(RestClient).to receive(:get).and_return(double(body: service_point_response))
  end

  describe '#initialize' do
    it 'sets netid, record, and preferred_service_point' do
      patron = described_class.new(netid)
      expect(patron.netid).to eq(netid)
      expect(patron.record['id']).to eq('user-uuid')
      expect(patron.preferred_service_point).to eq('sp-uuid')
      expect(patron.record['preferred_service_point']).to eq('sp-uuid')
    end
  end

  describe '#barcode' do
    it 'returns the barcode from the record' do
      patron = described_class.new(netid)
      expect(patron.barcode).to eq('1234567890')
    end
  end

  describe '#group' do
    it 'returns the patron group from the record' do
      patron = described_class.new(netid)
      expect(patron.group).to eq('staff')
    end
  end

  describe '#display_name' do
    it 'returns the full name if present' do
      patron = described_class.new(netid)
      expect(patron.display_name).to eq('Jane Doe')
    end

    it 'returns empty string if personal name is missing' do
      allow(CUL::FOLIO::Edge).to receive(:patron_record).and_return({ user: folio_record.except('personal') })
      patron = described_class.new(netid)
      expect(patron.display_name).to eq('')
    end
  end

  describe '#get_service_point' do
    it 'returns nil if RestClient raises an exception' do
      allow(RestClient).to receive(:get).and_raise(RestClient::ExceptionWithResponse.new(double(code: 500, body: 'error')))
      patron = described_class.new(netid)
      expect(patron.get_service_point).to be_nil
    end
  end
end