require 'rails_helper'

module BlacklightCornellRequests
  RSpec.describe RequestController, type: :controller do
    routes { BlacklightCornellRequests::Engine.routes }

    describe '#magic_request' do
      before do
        allow_any_instance_of(RequestController)
          .to receive_message_chain(:search_service, :fetch)
          .and_raise(Blacklight::Exceptions::RecordNotFound)
      end

      it 'redirects to /catalog if solr doc not found' do
        get :magic_request, params: { bibid: 'badid' }
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