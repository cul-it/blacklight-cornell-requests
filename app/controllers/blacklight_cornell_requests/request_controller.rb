require_dependency 'blacklight_cornell_requests/application_controller'

require 'date'
require 'json'
require 'repost'
require 'rest-client'
require 'string' # ISBN extension to String class
require 'securerandom'

module BlacklightCornellRequests
  class RequestDatabaseException < StandardError
    attr_reader :data

    def initialize(data)
      super
      @data = data
    end
  end

  class RequestController < ApplicationController
    # Blacklight::Catalog is needed for "fetch", replaces "include SolrHelper".
    # As of B7, it now supplies search_service, and fetch is called as search_service.fetch
    include Blacklight::Catalog
    # Interface to Project ReShare
    include Reshare
    # include Cornell::LDAP

    # This may seem redundant, but it makes it easier to fetch the document from
    # various model classes
    def get_solr_doc(doc_id)
      _, document = search_service.fetch doc_id
      document
    end

    def auth_magic_request target=''
      id_format = params[:format].present? ? params[:bibid] + '.' + params[:format] : params[:bibid]
      session[:cuwebauth_return_path] = magic_request_path(id_format)
      Rails.logger.debug "es287_log #{__FILE__} #{__LINE__}: #{magic_request_path(id_format).inspect}"
      if ENV['DEBUG_USER'] && Rails.env.development?
        magic_request target
      else
        # Replace redirect_to with redirect_post (from repost gem) to deal with new
        # Omniauth gem requirements
        uri = URI(request.original_url)
        scheme_host = "#{uri.scheme}://#{uri.host}"
        if uri.port.present? && uri.port !=  uri.default_port()
          scheme_host = scheme_host + ':' + uri.port.to_s
        end
        redirect_post("#{scheme_host}/users/auth/saml", options: {authenticity_token: :auto})
      end
    end

    def magic_request(target = '')
      if request.headers['REQUEST_METHOD'] == 'HEAD'
        head :no_content
        return
      end

      @id = params[:bibid]

      # added rescue for DISCOVERYACCESS-5863
      begin
        _, @document = search_service.fetch @id
        # Rails.logger.debug "mjc12test: doc: #{@document.inspect}"
      rescue Blacklight::Exceptions::RecordNotFound => e
        Rails.logger.debug("******* " + e.inspect)
        flash[:notice] = I18n.t('blacklight.search.errors.invalid_solr_id')
        redirect_to '/catalog'
        return
      end
      # @document = @document
      # Rails.logger.debug "mjc12test: document = #{@document.inspect}"
      @scan = params[:format].present? && params[:format] == "scan" ? "yes" : ""
      work_metadata = Work.new(@id, @document)
      # Create an array of all the item records associated with the bibid
      items = []

      holdings = JSON.parse(@document['holdings_json'] || '{}')

      # Items are keyed by the associated holding record
      JSON.parse(@document['items_json'] || '{}').each do |h, item_array|
        item_array.each do |i|
          if (i['active'].nil? || i['active']) && i['location']['name'].present?
            items << Item.new(h, i, holdings)
          end
        end
      end

      # This isn't likely to happen, because the Request item button should be suppressed, but if there's
      # a work with only one item and that item is inactive, we need to redirect because the items array
      # will be empty.
      # Rails.logger.debug "mjc12test: items: #{items}"
      # if @document['items_json'].present? && eval(@document['items_json']).size == 1 && items.empty?
      #   flash[:alert] = 'There are no items available to request for this title.'
      #   redirect_to "/catalog/#{params['bibid']}"
      #   return
      # end

      @ti = work_metadata.title
      @ill_link = work_metadata.ill_link
      # When we're entering the request system from a /catalog path, then we're starting
      # fresh — no volume should be pre-selected (or kept in the session). However,
      # if the referer is a different path — i.e., /request/*, then we *do* want to
      # preserve the volume selection; this would be the case if the page is reloaded
      # or the user selects an alternate delivery method for the same item.
      session[:volume] = nil if session[:setvol].nil? && request&.referer&.exclude?('/request/')
      session[:setvol] = nil

      params[:volume] = session[:volume]
      # Reset session var after use so that we don't get weird results if
      # user goes to another catalog item
      session[:volume] = nil

      # If there's a URL-based volume present, that overrides the session data (this
      # should only happen now if someone is linking into requests from outside the main
      # catalog).
      if params[:enum] || params[:chron] || params[:year]
        params[:volume] = "|#{params[:enum]}|#{params[:chron]}|#{params[:year]}|"
      end

      # If this is a multivol item but no volume has been selected, show the appropriate screen
      if @document['multivol_b']
        @volumes = Volume.volumes(items)
        if params[:volume].blank?
          if @volumes.count > 1
            render 'shared/_volume_select'
            return
          elsif @volumes.count == 1
            vol = @volumes[0]
            redirect_to "/request#{request.env['PATH_INFO']}?enum=#{vol.enum}&chron=#{vol.chron}&year=#{vol.year}"
            return
          end
        end
      end

      # If a volume is selected, drop the items that don't match that volume -- no need
      # to waste time calculating delivery methods for them
      # TODO: This is a horribly inefficient approach. Make it better.
      @volumes&.each do |v|
        if v.select_option == params[:volume]
          items = v.items
          break
        end
      end

      enabled_request_methods = DeliveryMethod.enabled_methods
      requester = Patron.new(user)
      # borrow_direct = CULBorrowDirect.new(requester, work_metadata)
      # We have the following delivery methods to evaluate (at most) for each item:
      # L2L, BD, ILL, Hold, Recall, Patron-driven acquisition, Purchase request
      # ScanIt, Ask a librarian, ask at circ desk
      #
      # For the FOLIO methods (L2L, Hold, Recall), we can use the cul-folio-edge
      # gem to determine if they can be used (based on patron group, material type,
      # loan type, and location)
      #
      # For BD, do a single call to the BD API for the bib-level ISBN (NOT for each item)
      #
      # For PDA?

      # The options hash has the following structure:
      # options = { DeliveryMethod => [items] }
      # i.e., each key in the hash is the class, e.g. L2L, and that points to
      # an array of items available via that method
      options = {}
      enabled_request_methods.each do |rm|
        options[rm] = []
      end

      ############ TEMPORARY HANDLING CODE FOR MICROFICHE AT ANNEX #############
      # This should eventually be removed (along with microfiche view)
      # Look for Annex microfiche
      hid = holdings.keys[0]
      holdings_data = holdings[hid]
      # Get item metadata
      matched_item = nil
      if @document['items_json'].present?
        JSON.parse(@document['items_json']).each do |h, i|
          i.each do |item|
            volume_string = "|#{item['enum']}|#{item['chron']}|#{item['year']}|"
            if volume_string == params[:volume]
              matched_item = item
            end
          end
        end
      end
      annex_microfiche =
        holdings_data&.dig('location', 'code') == 'acc,anx' ||
        matched_item&.dig('location', 'code') == 'acc,anx'

      patron = BlacklightCornellRequests::Patron.new(user)

      @microfiche_link = 'https://cornell.libwizard.com/f/annex?'
      @microfiche_link += "4661140=#{patron.display_name}" # name
      @microfiche_link += "&4661145=#{user}" # netid or 'visitor'
      @microfiche_link += "&4661162=#{@document['title_display']}" # title
      @microfiche_link += "&4661160=#{holdings_data['call']}" if holdings_data.present? # call number
      @microfiche_link += "&4661164=#{matched_item['enum']}" if matched_item.present? # volume

      if annex_microfiche
        render('microfiche')
        return
      end
      ############ END TEMPORARY HANDLING CODE FOR MICROFICHE AT ANNEX #########

      # Rails.logger.debug "mjc12test: items: #{items}"
      items.each do |i|
        # rp = {}
        # policy_key = "#{i.circ_group}-#{requester.group}-#{i.type['id']}"
        # if policy_hash[policy_key]
        #   rp = policy_hash[policy_key]
        # else
        #   rp = RequestPolicy.policy(i.circ_group, requester.group, i.type['id'])
        #   policy_hash[policy_key] = rp
        # end
        options = update_options(i, options, requester)
      end

      # items_json = JSON.parse(@document['items_json']).values[0]
      # NOTE: [*<variable>] gives us an array if we don't already have one,
      # which we need for the map.
      isbns = ([*work_metadata.isbn].map! { |i| i.clean_isbn })
      # However, ReShare doesn't appear to support searching by multiple ISBNs,
      # so we'll take the first one for now.
      # TODO: is this a safe approach? Will we get false negatives by not checking
      # all the ISBNs?

      # BD.available? checks to see whether an item is available locally -- if it is, we can't use BD
      if BD.available?(requester, holdings)
        @bd_id = bd_requestable_id(isbns[0])
        Rails.logger.debug "mjc12a: got bd_id #{@bd_id}"
        options[BD] << @bd_id
      end

      # Rails.logger.debug "mjc12test: options hash - #{options}"
      # At this point, options is a hash with keys being available delivery methods
      # and values being arrays of items deliverable using the keyed method

      # Make some adjustments if this is a special collections item (kind of hacky)
      # TODO: If this item is ONLY available through Mann Special Collections request,
      # then methods like L2L and Ask at Circ should not appear. But how to handle
      # the case of an item that is both in special collections and regular collections
      # somewhere else?
      if options[MannSpecial]
        # Rails.logger.debug "mjc12test: MANN SPECIAL OPTIONS CHECK #{}"
        options[AskCirculation] = []
        # What about L2L?
      end
      sorted_methods = DeliveryMethod.sorted_methods(options)
      fastest_method = sorted_methods[:fastest]
      @alternate_methods = sorted_methods[:alternate]
      # Add PDA if appropriate
      # pda_data = PDA.pda_data(@document)
      # if pda_data.present?
      if PDA.available?(@document)
        @alternate_methods = []
        fastest_method = { method: PDA }
      end

      Rails.logger.debug "mjc12test8: fastest #{fastest_method}"
      Rails.logger.debug "mjc12test8: alternate #{@alternate_methods}"
      # If no other methods are found (i.e., there are no item records to process, such as for
      # an on-order record), ask a librarian
      fastest_method[:method] ||= AskLibrarian

      # If target (i.e., a particular delivery method) is specified in the URL, then we
      # have to prefer that method above others (even if others are faster in theory).
      # This code is a bit ugly, but it swaps the fastest method with the appropriate entry
      # in the alternate_methods array.
      if target.present?
        enabled_request_methods.each do |rm|
          next unless rm::TemplateName == target

          @alternate_methods.unshift(fastest_method)
          alt_array_index = @alternate_methods&.index{ |am| am[:method] == rm }
          fastest_method = { method: rm, items: @alternate_methods[alt_array_index][:items] } if alt_array_index.present?
          @alternate_methods.delete_if { |am| am[:method] == fastest_method[:method] }
          flash.now.alert = I18n.t('requests.invalidtarget', target: rm.description) if alt_array_index.nil?
          break
        end
      end

      @estimate = fastest_method[:method].time
      @ti = work_metadata.title
      @au = work_metadata.author
      @isbn = work_metadata.isbn
      @pub_info = work_metadata.pub_info
      @ill_link = work_metadata.ill_link
      @mann_special_delivery_link = work_metadata.mann_special_delivery_link
      @scanit_link = work_metadata.scanit_link
      @netid = user
      @patron = BlacklightCornellRequests::Patron.new(@netid).record

      @name = "#{@patron['personal']['firstName']} #{@patron['personal']['lastName']}"

      @volume = params[:volume]
      @fod_data = get_fod_data user
      @items = fastest_method[:items]

      @iis = ActiveSupport::HashWithIndifferentAccess.new
      if !@document[:url_pda_display].blank? && !@document[:url_pda_display][0].blank?
        pda_url = @document[:url_pda_display][0]
        pda_url, note = pda_url.split('|')
        @iis = { pda: { itemid: 'pda', url: pda_url, note: note } }
      end

      @counter = params[:counter]
      @counter = session[:search][:counter] if @counter.blank? && session[:search].present?
      Rails.logger.debug "mjc12test8: #{fastest_method}"
      render fastest_method[:method]::TemplateName
    end

    # Update the options hash with methods for a particular item
    # TODO: there's probably a better way to do this!
    def update_options(item, options, patron)
      available_folio_methods = DeliveryMethod.available_folio_methods(item, patron)
      Rails.logger.debug "mjc12test5: AFM: #{available_folio_methods}"
      # Rails.logger.debug "mjc12test: item is #{item.inspect}"

      options[ILL] << item if ILL.available?(item, patron)
      options[L2L] << item if L2L.enabled? && available_folio_methods.include?(:l2l)
      options[Hold].push(item) if Hold.enabled? && available_folio_methods.include?(:hold)
      options[Recall] << item if Recall.enabled? && available_folio_methods.include?(:recall)
      options[PurchaseRequest] << item if PurchaseRequest.available?(item, patron)
      options[DocumentDelivery] << item if DocumentDelivery.available?(item, patron)
      options[AskLibrarian] << item if AskLibrarian.available?(item, patron)
      options[AskCirculation] << item if AskCirculation.available?(item, patron)
      options[MannSpecial] << item if MannSpecial.available?(item, patron)

      options
    end

    # Get information about FOD/remote prgram delivery eligibility
    def get_fod_data(netid)
      return {} unless ENV['FOD_DB_URL'].present?

      begin
        uri = URI.parse(ENV['FOD_DB_URL'] + "?netid=#{netid}").to_s
        response = RestClient.get(uri)
        # response = Net::HTTP.get_response(uri)
        JSON.parse(response)
      rescue OpenURI::HTTPError, RestClient::Exception
        Rails.logger.warn("Warning: Unable to retrieve FOD/remote program eligibility data (from #{uri})")
        {}
      end
    end

    # These one-line service functions simply return the name of the view
    # that should be rendered for each one.
    def l2l
      magic_request 'l2l'
    end

    def hold
      magic_request 'hold'
    end

    def recall
      magic_request 'recall'
    end

    def bd
      magic_request 'bd'
    end

    def ill
      magic_request 'ill'
    end

    def purchase
      magic_request 'purchase'
    end

    def pda
      magic_request 'pda'
    end

    def ask
      magic_request 'ask'
    end

    def circ
      magic_request 'circ'
    end

    def document_delivery
      magic_request 'document_delivery'
    end

    def mann_special
      magic_request 'mann_special'
    end

    def blacklight_solr
      @solr ||= RSolr.connect(blacklight_solr_config)
    end

    def blacklight_solr_config
      Blacklight.solr_config
    end

    # Use the FOLIO APIs to place a hold, recall, or page/L2L request
    def make_folio_request
      # Validate the form data
      errors = []
      errors << I18n.t('requests.errors.holding_id.blank') if params[:holding_id].blank?
      errors << I18n.t('requests.errors.library_id.blank') if params[:library_id].blank?

      flash[:error] = errors.join('<br/>').html_safe if errors

      if errors.blank?
      #   req = BlacklightCornellRequests::Request.new(params[:bibid])
      #   # req.netid = request.env['REMOTE_USER']
      #   # req.netid.sub! '@CORNELL.EDU', ''
      #   req.netid = user
      #   # If the holding_id = 'any', then set to blank. Voyager expects an empty value for 'any copy',
      #   # but validation above expects a non-blank value!
      #   if params[:holding_id] == 'any'
      #     params[:holding_id] = ''
      #   end

        # To submit a FOLIO request, we need:
        # 1. Okapi URL
        # 2. Okapi tenant
        # 3. Okapi auth token
        # 4. item ID
        # 4a. instance ID
        # 4b. holdings ID
        # 5. requester ID
        # 6. request type (Hold, Recall, or Page)
        # 7. request date
        # 8. fulfillment preference (default to Hold Shelf)
        # 9. service point ID for pickup
        # 10. comments, if any
        url = ENV['OKAPI_URL']
        tenant = ENV['OKAPI_TENANT']
        token = CUL::FOLIO::Edge.authenticate(url, tenant, ENV['OKAPI_USER'], ENV['OKAPI_PW'])[:token]
        instance_id = params[:instance_id]
        item_id = params[:holding_id] # Ugh, why is the item ID named holding_id in the views??
        holdings_id = holdings_id_from_item_id(item_id, params[:items_json])
        requester_id = Patron.new(user).record['id']
        request_type = params[:request_action]
        request_date = DateTime.now.iso8601
        pickup_location = params[:library_id]
        comments = params[:reqcomments]

        response = CUL::FOLIO::Edge.request_item(
          url,
          tenant,
          token,
          instance_id,
          holdings_id,
          item_id,
          requester_id,
          request_type,
          request_date,
          'Hold Shelf',
          pickup_location,
          comments
        )

      #   response = req.make_voyager_request params
      #   if !response[:error].blank?
      #     flash[:error] = response[:error]
      #     render :partial => '/shared/flash_msg', :layout => false
      #     return
      #   end
        if response[:error].nil?
          # NOTE: the :flash=>'success' in this case is not setting the actual flash message,
          # but instead specifying a URL parameter that acts as a flag in Blacklight's show.html.erb view.
          flash[:error] = nil # Without this, a blank 'error' flash appears beneath the success message in B7 ... for some reason
          render js: "$('#main-flashes').hide(); window.location = '#{Rails.application.routes.url_helpers.solr_document_path(params[:bibid], :flash=>'success')}'"
          return
        else
          error = JSON.parse(response[:error])
          Rails.logger.info "Request: response failed: #{error}"
          flash[:error] = "Error: the request could not be completed (#{error['errors'][0]['message']})"
        end
      end

      render partial: '/shared/flash_msg', layout: false
    end

    def make_purchase_request
      errors = []
      errors << I18n.t('requests.errors.name.blank') if params[:name].blank?
      errors << I18n.t('requests.errors.email.blank') if params[:email].blank?
      errors << I18n.t('requests.errors.status.blank') if params[:reqstatus].blank?
      errors << I18n.t('requests.errors.title.blank') if params[:reqtitle].blank?

      if params[:email].present? && errors.empty?
        if params[:email].match(/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/)
          # Email the form contents to the purchase request staff
          RequestMailer.email_request(user, params)
          # TODO: check for mail errors, don't assume that things are working!
          flash[:success] = I18n.t('requests.success')
        else
          errors << I18n.t('requests.errors.email.invalid')
        end
      end

      flash[:error] = errors.join('<br/>').html_safe if errors
      render partial: '/shared/flash_msg', layout: false
    end

    def make_bd_request
      if params[:library_id].blank?
        flash[:error] = 'Please select a library pickup location.'
        render :partial => '/shared/flash_msg', :layout => false
      else
        status = nil
        result = request_from_reshare(patron: user, item: params[:bd_id], pickup_location: params[:library_id], note: params[:reqcomments])
        if result == :error
          status = 'failure'
          status_msg = 'There was an error when submitting this request to BorrowDirect. Your request could not be completed.'
        else
          status = 'success'
          status_msg = I18n.t('requests.success') + " The BorrowDirect request number is #{result}."
        end
        render :partial => 'bd_notification', :layout => false, locals: { :message => status_msg, :status => status }
      end
    end

    # Submit a PDA (Patron-Driven Acquisition) request to the Prefect workflow that does the
    # actual ordering and updating of catalog records. Requires the requester
    # netid and the instance HRID/bibid.
    #
    # This is based on code supplied by Brandon Kowalski
    def make_pda_request
      if params[:netid].present? && params[:bibid].present?
        url = "https://api.prefect.cloud/api/accounts/#{ENV['PREFECT_ACCOUNT']}/workspaces/#{ENV['PREFECT_WORKSPACE']}/deployments/#{ENV['PREFECT_DEPLOYMENT']}/create_flow_run"
        headers = {
          'authorization' => ENV['PREFECT_AUTH_TOKEN'],
          :content_type => 'application/json; charset=utf-8'
        }
        props = {
          'state' => {
            'type' => 'SCHEDULED'
          },
          'idempotency_key' => SecureRandom.uuid,
          'parameters' => {
            'requestor_netid' => user,
            'hrid' => params[:bibid],
            # If is_test = true, request is sent to the Prefect test environment, and Brandon Kowalski receives an email.
            # (In practice, an env value of anything other than 'prod' should be regarded as true.)
            'is_test' => ENV['PREFECT_STATE'] != 'prod'
          }
        }
        body = JSON.dump(props)

        begin
          response = RestClient.post(url, body, headers)
          flash[:success] = I18n.t('requests.success')
        rescue StandardError => e
          Rails.logger.error "Requests: PDA request failed (#{e})"
          error_msg = I18n.t('requests.failure')
          error_msg += ' (The requestor could not be identified.)' if params[:netid].nil?
          flash[:error] = error_msg
        end
      else
        error_msg = I18n.t('requests.failure')
        error_msg += ' (The requestor could not be identified.)' if params[:netid].nil?
        flash[:error] = error_msg
      end

      render :partial => '/shared/flash_msg', :layout => false
    end

    # AJAX responder used with requests.js.coffee to set the volume
    # when the user selects one in the volume drop-down list
    def set_volume
      session[:volume] = params[:volume]
      session[:setvol] = 1
      respond_to do |format|
        format.js { render body: nil }
      end
    end

    # Given an item UUID and a JSON object from the Solr document containing item info, return a holdings UUID
    # associated with the item. This is slightly tricky because the format of the document
    # items_json segment is
    # {
    #   <holdings ID>: [item 1, item 2, ...],
    #   <holdings ID 2>: [item 3],
    #   ...
    # }
    # So to do this, we need to iterate over the holdings IDs until we find an item record with the correct
    # item_id.
    def holdings_id_from_item_id(item_id, items_json)
      item_blob = JSON.parse(items_json)
      result = item_blob.keys.each do |h|
        items = item_blob[h]
        items.each do |i|
          return h if i['id'] == item_id
        end
      end
      return nil
    end

    def user
      netid = nil
      if ENV['DEBUG_USER'] && Rails.env.development?
        netid = ENV['DEBUG_USER']
      else
        netid = request.env['REMOTE_USER'] || session[:cu_authenticated_user]
      end

      netid = netid.sub('@CORNELL.EDU', '') unless netid.nil?
      netid = netid.sub('@cornell.edu', '') unless netid.nil?

      netid
    end
  end
end
