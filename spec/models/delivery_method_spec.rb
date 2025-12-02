require 'rails_helper'

module BlacklightCornellRequests

  RSpec.describe DeliveryMethod, type: :model do
    describe '.available_folio_methods' do
      let(:item) {
        double('Item',
        status: status,
        type: { 'id' => 'type_id' },
        loan_type: { 'id' => 'loan_type_id' },
        location: { 'id' => 'location_id' })
      }
      let(:patron) {
        double('Patron',
        record: { 'patronGroup' => 'patron_group_id' })
      }
      let(:token) { { token: 'fake_token' } }
      let(:url) { 'http://example.com' }
      let(:tenant) { 'tenant' }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('OKAPI_URL').and_return(url)
        allow(ENV).to receive(:[]).with('OKAPI_TENANT').and_return(tenant)
        allow(ENV).to receive(:[]).with('OKAPI_USER').and_return('user')
        allow(ENV).to receive(:[]).with('OKAPI_PW').and_return('password')
        allow(CUL::FOLIO::Edge).to receive(:authenticate).and_return(token)
        allow(CUL::FOLIO::Edge).to receive(:request_options).and_return(result)
      end

      context 'when item status is Checked out' do
        let(:status) { 'Checked out' }
        let(:result) { { code: 200, request_methods: [:hold, :recall] } }

        it 'returns hold and recall' do
          expect(DeliveryMethod.available_folio_methods(item, patron)).to eq([:hold, :recall])
        end
      end

      context 'when item status is On order' do
        let(:status) { 'On order' }
        let(:result) { { code: 200, request_methods: [:hold, :recall] } }

        it 'returns an empty array' do
          expect(DeliveryMethod.available_folio_methods(item, patron)).to eq([])
        end
      end

      context 'when item status is In process' do
        let(:status) { 'In process' }
        let(:result) { { code: 200, request_methods: [:hold, :recall] } }

        it 'returns an empty array' do
          expect(DeliveryMethod.available_folio_methods(item, patron)).to eq([])
        end
      end
    end

    describe '.enabled_methods' do
      before do
        stub_const('BlacklightCornellRequests::DELIVERY_METHODS', %w[L2L BD ILL])
        allow(BlacklightCornellRequests::L2L).to receive(:enabled?).and_return(true)
        allow(BlacklightCornellRequests::BD).to receive(:enabled?).and_return(false)
        allow(BlacklightCornellRequests::ILL).to receive(:enabled?).and_return(true)
      end

      it 'returns only enabled methods' do
        expect(DeliveryMethod.enabled_methods).to contain_exactly(BlacklightCornellRequests::L2L, BlacklightCornellRequests::ILL)
      end
    end

    describe '.sorted_methods' do
      let(:hold) { BlacklightCornellRequests::Hold }
      let(:recall) { BlacklightCornellRequests::Recall }
      let(:docdel) { BlacklightCornellRequests::DocumentDelivery }

      before do
        allow(hold).to receive(:time).and_return([2, 2])
        allow(recall).to receive(:time).and_return([15, 15])
        allow(docdel).to receive(:time).and_return([1, 4])
      end

      it 'returns fastest and alternate methods sorted by time' do
        options = { hold => [1], recall => [2], docdel => [3] }
        result = DeliveryMethod.sorted_methods(options)
        expect(result[:fastest][:method]).to eq(hold)
        expect(result[:alternate].map { |a| a[:method] }).to include(docdel, recall)
      end

      it 'never returns DocumentDelivery as fastest if alternates exist' do
        options = { docdel => [1], hold => [2] }
        result = DeliveryMethod.sorted_methods(options)
        expect(result[:fastest][:method]).to eq(hold)
        expect(result[:alternate].first[:method]).to eq(docdel)
      end

      it 'removes methods with no items' do
        options = { hold => [], recall => [1] }
        result = DeliveryMethod.sorted_methods(options)
        expect(result[:fastest][:method]).to eq(recall)
        expect(result[:alternate].map { |a| a[:method] }).not_to include(hold)
      end
    end

    describe '.description' do
      it 'returns a description string' do
        expect(DeliveryMethod.description).to eq('An item delivery method')
      end
    end

    describe '.enabled?' do
      it 'returns true by default' do
        expect(DeliveryMethod.enabled?).to be true
      end
    end
  end

end
