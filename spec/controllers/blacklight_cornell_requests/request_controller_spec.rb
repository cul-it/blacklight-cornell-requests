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
          'items_json' => { 'h1' => [
            {
              'active' => true,
              'location' => { 'name' => 'Stacks', 'code' => 'main' },
              'enum' => 'v.1',
              'chron' => '',
              'year' => '',
              'type' => { 'id' => 'book' },
              'status' => { 'status' => 'Available' }
            }
          ] }.to_json
        }
      end

      before do
        # Stub Patron.new to avoid network/ENV errors
        patron_record = { 'personal' => { 'firstName' => 'Test', 'lastName' => 'User', 'id' => 'patronid', 'group' => 'test_group' } }
        patron_double = double(display_name: 'Test User', record: patron_record, group: 'test_group')
        allow(BlacklightCornellRequests::Patron).to receive(:new).and_return(patron_double)
        # Stub DeliveryMethod.available_folio_methods to avoid FOLIO network/auth errors
        allow(DeliveryMethod).to receive(:available_folio_methods).and_return([])
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

      it 'returns no_content for HEAD requests' do
        # Stub search_state to avoid NameError
        allow(controller).to receive(:search_state).and_return(double(to_h: {}, params: {}))
        allow_any_instance_of(RequestController)
          .to receive_message_chain(:search_service, :fetch)
          .and_return([nil, { 'title_display' => 'Test Title' }]) # or a more complete document hash if needed

        head :magic_request, params: { bibid: bibid }
        expect(response).to have_http_status(:no_content)
      end

      it 'renders microfiche form if annex_microfiche is true' do
        doc = document.merge(
          'holdings_json' => { 'h1' => { 'location' => { 'code' => 'acc,anx' }, 'call' => 'QA123' } }.to_json
        )

        allow_any_instance_of(RequestController)
          .to receive_message_chain(:search_service, :fetch)
          .and_return([nil, doc])
        get :magic_request, params: { bibid: bibid }
        expect(response).to render_template('microfiche')
      end

      ### Tests for multivolume

      it 'renders the _volume_select partial if multivol_b is true and there is no volume param' do
        doc = document.merge('multivol_b' => true)
        allow_any_instance_of(RequestController)
          .to receive_message_chain(:search_service, :fetch)
          .and_return([nil, doc])
        allow(Volume).to receive(:volumes).and_return([
          double(enum: 'v.1', chron: '', year: '', select_option: nil, items: []),
          double(enum: 'v.2', chron: '', year: '', select_option: nil, items: [])
        ])
        get :magic_request, params: { bibid: bibid }
        expect(response).to render_template('shared/_volume_select')
      end

      it 'redirects to the volume request URL if only one volume is present and no volume param' do
        doc = document.merge('multivol_b' => true)
        allow_any_instance_of(RequestController)
          .to receive_message_chain(:search_service, :fetch)
          .and_return([nil, doc])
        # Stub Volume.volumes to return only one volume
        volumes = [
          double(enum: 'v.1', chron: '', year: '', select_option: nil, items: [])
        ]
        allow(Volume).to receive(:volumes).and_return(volumes)
        get :magic_request, params: { bibid: bibid }
        expect(response).to redirect_to("/request/#{bibid}?enum=v.1&chron=&year=")
      end
    end

    describe '#magic_request delivery options' do
      let(:bibid) { 'testid' }
      let(:document) do
        {
          'title_display' => 'Test Title',
          'holdings_json' => { 'h1' => { 'location' => { 'code' => 'main' }, 'call' => 'QA123' } }.to_json,
          'items_json' => { 'h1' => [
            {
              'active' => true,
              'location' => { 'name' => 'Stacks', 'code' => 'main' },
              'enum' => 'v.1',
              'chron' => '',
              'year' => '',
              'type' => { 'id' => 'book' },
              'status' => { 'status' => 'Available' }
            }
          ] }.to_json,
          :url_pda_display => [
            'http://example.com/pda|Sample note'
          ],
        }
      end

      let(:patron_record) { { 'personal' => { 'firstName' => 'Test', 'lastName' => 'User' }, 'id' => 'patronid', 'group' => 'test_group' } }
      let(:patron_double) { double(display_name: 'Test User', record: patron_record, group: 'test_group', get_folio_record: patron_record) }

      before do
        allow_any_instance_of(RequestController)
          .to receive_message_chain(:search_service, :fetch)
          .and_return([nil, document])
        allow(BlacklightCornellRequests::Patron).to receive(:new).and_return(patron_double)
        allow(DeliveryMethod).to receive(:enabled_methods).and_return([L2L, BD, MannSpecial, PDA, AskLibrarian])
        allow(DeliveryMethod).to receive(:sorted_methods).and_return({ fastest: { method: L2L, items: ['item1'] }, alternate: [{ method: BD, items: ['item2'] }] })
        allow(DeliveryMethod).to receive(:available_folio_methods).and_return([])
        allow(PDA).to receive(:available?).and_return(false)
        allow(BD).to receive(:available?).and_return(false)
        allow(MannSpecial).to receive(:available?).and_return(false)
        allow(AskLibrarian).to receive(:available?).and_return(true)
        allow_any_instance_of(RequestController).to receive(:user).and_return('testuser')
        allow(Work).to receive(:new).and_return(double(title: 'Test Title', author: 'Test Author', isbn: ['1234567890'], pub_info: 'Test Pub', ill_link: nil, call_number: nil, scanit_link: nil))
        allow(Item).to receive(:new).and_return(
          double(
            circ_group: 'circ',
            type: { 'id' => 'book' },
            location: { 'name' => 'Stacks', 'code' => 'main' },
            status: { 'status' => 'Available' },
            noncirculating?: false,
            minute_loan?: false
          )
        )
      end

      it 'sets fastest_method and alternate_methods' do
        get :magic_request, params: { bibid: bibid }
        expect(assigns(:alternate_methods)).to eq([{ method: BD, items: ['item2'] }])
        expect(assigns(:items)).to eq(['item1'])
      end

      it 'adds BD if BD.available? returns true' do
        allow(BD).to receive(:available?).and_return(true)
        allow_any_instance_of(RequestController).to receive(:bd_requestable_id).and_return('bdid')
        get :magic_request, params: { bibid: bibid }
        expect(assigns(:bd_id)).to eq('bdid')
      end

      it 'removes AskCirculation if MannSpecial is present in options' do
        allow(DeliveryMethod).to receive(:sorted_methods).and_return({ fastest: { method: MannSpecial, items: ['item1'] }, alternate: [] })
        allow_any_instance_of(RequestController).to receive(:user).and_return('testuser')
        get :magic_request, params: { bibid: bibid }
        # You may want to check that AskCirculation is not present in alternate_methods
        expect(assigns(:alternate_methods)).not_to include(hash_including(method: AskCirculation))
      end

      it 'sets fastest_method to PDA if PDA.available?' do
        allow(PDA).to receive(:available?).and_return(true)
        get :magic_request, params: { bibid: bibid }
        expect(assigns(:alternate_methods)).to eq([])
        expect(assigns(:items)).to eq(nil) # PDA may not have items
        expect(assigns(:estimate)).to eq(PDA.time) if defined?(PDA.time)
      end

      it 'renders the fastest_method template' do
        get :magic_request, params: { bibid: bibid }
        expect(response).to render_template(L2L::TemplateName)
      end

      it 'sets the PDA url and note if present in document' do
        allow(PDA).to receive(:available?).and_return(true)
        get :magic_request, params: { bibid: bibid }
        expect(assigns(:iis)).to eq({ pda: { itemid: 'pda', url: 'http://example.com/pda', note: 'Sample note' } })
      end
    end

    describe '#make_purchase_request' do
      before do
        allow(I18n).to receive(:t).with('requests.errors.name.blank').and_return('Name required')
        allow(I18n).to receive(:t).with('requests.errors.email.blank').and_return('Email required')
        allow(I18n).to receive(:t).with('requests.errors.status.blank').and_return('Status required')
        allow(I18n).to receive(:t).with('requests.errors.title.blank').and_return('Title required')
        allow(I18n).to receive(:t).with('requests.errors.email.invalid').and_return('Invalid email')
        allow(I18n).to receive(:t).with('requests.success').and_return('Success!')
      end

      it 'sets flash[:error] for missing required fields' do
        post :make_purchase_request, params: { bibid: '', name: '', email: '', reqstatus: '', reqtitle: '' }
        expect(flash[:error]).to include('Name required')
        expect(flash[:error]).to include('Email required')
        expect(flash[:error]).to include('Status required')
        expect(flash[:error]).to include('Title required')
        expect(response).to render_template('shared/_flash_msg')
      end

      it 'sets flash[:error] for invalid email format' do
        post :make_purchase_request, params: { bibid: '123', name: 'Test', email: 'bademail', reqstatus: 'Faculty', reqtitle: 'Book Title' }
        expect(flash[:error]).to include('Invalid email')
        expect(response).to render_template('shared/_flash_msg')
      end

      it 'sets flash[:success] for valid submission and calls mailer' do
        mailer = double('RequestMailer')
        allow(RequestMailer).to receive(:email_request).and_return(mailer)
        allow(mailer).to receive(:deliver_now)
        post :make_purchase_request, params: { bibid: '123', name: 'Test', email: 'test@cornell.edu', reqstatus: 'Faculty', reqtitle: 'Book Title' }
        expect(flash[:success]).to eq('Success!')
        expect(response).to render_template('shared/_flash_msg')
      end
    end

    describe '#make_bd_request' do
      before do
        allow(I18n).to receive(:t).with('requests.success').and_return('Success!')
      end

      it 'sets flash[:error] and renders flash_msg partial if library_id is blank' do
        post :make_bd_request, params: { bibid: '123', library_id: '', bd_id: '123' }
        expect(flash[:error]).to eq('Please select a library pickup location.')
        expect(response).to render_template('shared/_flash_msg')
      end
    end

    describe '#make_pda_request' do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('TEMPORAL_API_URL').and_return('http://temporal.example.com')
        allow(ENV).to receive(:[]).with('TEMPORAL_BEARER_TOKEN').and_return('Bearer token')
        allow(ENV).to receive(:[]).with('TEMPORAL_STATE').and_return('prod')
        allow(ENV).to receive(:[]).with(anything).and_return(nil)
        allow(I18n).to receive(:t).with('requests.success').and_return('Success!')
        allow(I18n).to receive(:t).with('requests.failure').and_return('Failure!')
      end

      let(:valid_params) { { netid: 'abc123', bibid: 'bib456' } }

      it 'sets flash[:success] and renders flash_msg partial on success' do
        expect(RestClient).to receive(:post).and_return(double)
        post :make_pda_request, params: valid_params
        expect(flash[:success]).to eq('Success!')
        expect(response).to render_template(/flash_msg/)
      end

      it 'sets flash[:error] and renders flash_msg partial on RestClient error' do
        allow(RestClient).to receive(:post).and_raise(StandardError.new('fail'))
        post :make_pda_request, params: valid_params
        expect(flash[:error]).to include('Failure!')
        expect(response).to render_template(/flash_msg/)
      end

      it 'sets flash[:error] if netid or bibid is missing' do
        post :make_pda_request, params: { netid: '', bibid: '' }
        expect(flash[:error]).to include('Failure!')
        expect(response).to render_template(/flash_msg/)
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

    describe '#set_volume' do
      it 'sets session[:volume] and session[:setvol] and renders JS with no body' do
        post :set_volume, params: { volume: '|v.1|Spring|2020|' }, format: :js
        expect(session[:volume]).to eq('|v.1|Spring|2020|')
        expect(session[:setvol]).to eq(1)
        expect(response).to have_http_status(:ok)
        expect(response.body).to be_blank
        expect(response.content_type).to eq('text/javascript; charset=utf-8')
      end
    end

    describe '#holdings_id_from_item_id' do
      let(:items_json) {
        {
          "hold1" => [
            { "id" => "itemA" },
            { "id" => "itemB" }
          ],
          "hold2" => [
            { "id" => "itemC" }
          ]
        }.to_json
      }

      it 'returns the correct holdings id for a matching item' do
        controller = described_class.new
        expect(controller.holdings_id_from_item_id("itemB", items_json)).to eq("hold1")
        expect(controller.holdings_id_from_item_id("itemC", items_json)).to eq("hold2")
      end

      it 'returns nil if item id is not found' do
        controller = described_class.new
        expect(controller.holdings_id_from_item_id("itemX", items_json)).to be_nil
      end

      it 'returns nil for empty items_json' do
        controller = described_class.new
        expect(controller.holdings_id_from_item_id("itemA", "{}")).to be_nil
      end
    end

  end
end
