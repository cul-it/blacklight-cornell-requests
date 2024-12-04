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
          expect(DeliveryMethod.available_folio_methods(item, patron)).to eq([:holdy, :recall])
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
  end

end
