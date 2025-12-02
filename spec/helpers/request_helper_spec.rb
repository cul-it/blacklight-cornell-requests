require 'rails_helper'

module BlacklightCornellRequests

  RSpec.describe RequestHelper, type: :helper do
    describe '#delivery_estimate_display' do
      it 'returns a single value when both values are the same' do
        expect(helper.delivery_estimate_display([1, 1])).to eq('1 working day')
        expect(helper.delivery_estimate_display([2, 2])).to eq('2 working days')
      end

      it 'returns a range when values differ' do
        expect(helper.delivery_estimate_display([1, 3])).to eq('1 to 3 working days')
        expect(helper.delivery_estimate_display([2, 5])).to eq('2 to 5 working days')
      end
    end

    describe '#author_display' do
      it 'displays the first author only' do
        @document = { 'title_responsibility_display' => ['Test Author 1', 'Test Author 2'] }
        expect(helper.author_display()).to eq('Test Author 1')
      end

      it 'returns nil if no author info' do
        @document = { 'title_display' => 'Test Title' }
        expect(helper.author_display()).to be_nil
      end
    end

    describe '#parsed_special_delivery' do
      it 'returns an empty array if no programs key is provided' do
        params = {}
        expect(helper.parsed_special_delivery(params)).to eq([])
      end

      it 'returns an empty array if the programs key is empty' do
        params = { 'programs' => [] }
        expect(helper.parsed_special_delivery(params)).to eq([])
      end

      it 'filters out faculty office delivery and formats the rest' do
        params = {
          'programs' => [
            { 'location_id' => 224, 'name' => 'Faculty Office', 'bd_loc_code' => 'X' },
            { 'location_id' => 250, 'name' => 'NYC-CFEM', 'bd_loc_code' => 'A' },
            { 'location_id' => 300, 'name' => 'Other Program' }
          ]
        }
        result = helper.parsed_special_delivery(params)
        expect(result).to eq([
          { label: 'Special Program Delivery: NYC-CFEM', value: 250, bd_value: 'A' },
          { label: 'Special Program Delivery: Other Program', value: 300, bd_value: '' }
        ])
      end

      it 'sorts programs by name' do
        params = {
          'programs' => [
            { 'location_id' => 250, 'name' => 'Zebra', 'bd_loc_code' => 'A' },
            { 'location_id' => 300, 'name' => 'Apple', 'bd_loc_code' => 'B' }
          ]
        }
        result = helper.parsed_special_delivery(params)
        expect(result.map { |r| r[:label] }).to eq([
          'Special Program Delivery: Apple',
          'Special Program Delivery: Zebra'
        ])
      end

      it 'sets bd_value to empty string if bd_loc_code is missing' do
        params = {
          'programs' => [
            { 'location_id' => 400, 'name' => 'NoCode' }
          ]
        }
        result = helper.parsed_special_delivery(params)
        expect(result.first[:bd_value]).to eq('')
      end
    end

    describe '#pickup_locations' do
      let(:servicepoints) do
        [
          { 'discoveryDisplayName' => 'Africana', 'id' => '7c5abc9f-f3d7-4856-b8d7-6712462ca007', 'pickupLocation' => true },
          { 'discoveryDisplayName' => 'Staff Use Only', 'id' => 'x', 'pickupLocation' => true },
          { 'discoveryDisplayName' => 'Special Program Delivery: Something', 'id' => 'y', 'pickupLocation' => true },
          { 'discoveryDisplayName' => 'Catherwood ILR', 'id' => 'ab1fce49-e832-41a4-8afc-7179a62332e2', 'pickupLocation' => true },
          { 'discoveryDisplayName' => 'No Pickup', 'id' => 'z', 'pickupLocation' => false }
        ]
      end

      let(:response_body) { { 'servicepoints' => servicepoints }.to_json }
      let(:response_double) { double('response', code: 200, body: response_body) }
      let(:token) { 'fake-token' }

      before do
        ENV['OKAPI_URL'] = 'http://folio.example.com'
        ENV['OKAPI_TENANT'] = 'tenant'
        ENV['OKAPI_USER'] = 'user'
        ENV['OKAPI_PW'] = 'pw'
        allow(CUL::FOLIO::Edge).to receive(:authenticate).and_return({ token: token })
        allow(RestClient).to receive(:get).and_return(response_double)
      end

      it 'returns filtered and formatted pickup locations' do
        result = helper.pickup_locations
        expect(result).to include(
          { name: 'Africana', id: '7c5abc9f-f3d7-4856-b8d7-6712462ca007', bd_code: 'F' },
          { name: 'Catherwood ILR', id: 'ab1fce49-e832-41a4-8afc-7179a62332e2', bd_code: 'I' }
        )
        # Should not include Staff Use Only, Special Program Delivery, or pickupLocation == false
        expect(result.any? { |r| r[:name] == 'Staff Use Only' }).to be_falsey
        expect(result.any? { |r| r[:name].start_with?('Special Program Delivery') }).to be_falsey
        expect(result.any? { |r| r[:name] == 'No Pickup' }).to be_falsey
      end

      it 'returns an empty array if RestClient raises an exception' do
        allow(RestClient).to receive(:get).and_raise(RestClient::ExceptionWithResponse)
        expect(helper.pickup_locations).to eq([])
      end

      it 'returns an empty array if response code is not 200' do
        bad_response = double('response', code: 500, body: '{}')
        allow(RestClient).to receive(:get).and_return(bad_response)
        expect(helper.pickup_locations).to eq([])
      end
    end
  end
end
