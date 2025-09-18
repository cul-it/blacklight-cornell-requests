require 'rails_helper'

module BlacklightCornellRequests
  RSpec.describe RequestController, type: :controller do
    routes { BlacklightCornellRequests::Engine.routes }

    describe '#magic_request' do
      let(:bibid) { 'testid' }
      let(:document) do
        {
          'title_display' => 'Test Title',
          'holdings_json' => { 'h1' => { 'location' => { 'code' => 'main' }, 'call' => 'QA123' } }.to_json,
          'items_json' => { 'h1' => [{ 'active' => true, 'location' => { 'name' => 'Stacks', 'code' => 'main' }, 'enum' => 'v.1', 'chron' => '', 'year' => '' }] }.to_json
        }
      end

      it 'returns no_content for HEAD requests' do
        # Stub search_state to avoid NameError
        allow(controller).to receive(:search_state).and_return(double(to_h: {}, params: {}))
        allow_any_instance_of(RequestController)
          .to receive_message_chain(:search_service, :fetch)
          .and_return([nil, { 'title_display' => 'Test Title' }]) # or a more complete document hash if needed
        # Stub Patron.new to avoid network/ENV errors
        patron_record = { 'personal' => { 'firstName' => 'Test', 'lastName' => 'User' } }
        patron_double = double(display_name: 'Test User', record: patron_record)
        allow(BlacklightCornellRequests::Patron).to receive(:new).and_return(patron_double)

        head :magic_request, params: { bibid: bibid }
        expect(response).to have_http_status(:no_content)
      end

      it 'redirects to /catalog if solr doc not found' do
        # Stub the document fetch service to raise an error
        allow_any_instance_of(RequestController)
          .to receive_message_chain(:search_service, :fetch)
          .and_raise(Blacklight::Exceptions::RecordNotFound)

        get :magic_request, params: { bibid: bibid }
        expect(response).to redirect_to('/catalog')
        expect(flash[:notice]).to eq(I18n.t('blacklight.search.errors.invalid_solr_id'))
      end
    end

    describe '#make_folio_request' do
      it 'renders flash error if holding_id is blank' do
        post :make_folio_request, params: { bibid: 'someid', holding_id: '', library_id: 'lib' }
        expect(flash[:error]).to include(I18n.t('requests.errors.holding_id.blank'))
        expect(response).to render_template('shared/_flash_msg')
      end

      it 'renders flash error if library_id is blank' do
        post :make_folio_request, params: { bibid: 'someid', holding_id: 'hid', library_id: '' }
        expect(flash[:error]).to include(I18n.t('requests.errors.library_id.blank'))
        expect(response).to render_template('shared/_flash_msg')
      end
    end

    # Add more tests for other actions as needed, e.g.:
    # describe '#make_purchase_request' do
    #   ...
    # end
    # describe '#make_bd_request' do
    #   ...
    # end
  end
end