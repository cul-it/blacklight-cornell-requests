require_dependency "blacklight_cornell_requests/application_controller"
require 'date'
require 'json'

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
    #include Cornell::LDAP

    # This may seem redundant, but it makes it easier to fetch the document from
    # various model classes
    def get_solr_doc doc_id
      resp, document = search_service.fetch doc_id
      document
    end

    def auth_magic_request target=''
      id_format = params[:format].present? ? params[:bibid] + '.' + params[:format] : params[:bibid]
      session[:cuwebauth_return_path] = magic_request_path(id_format)
      Rails.logger.debug "es287_log #{__FILE__} #{__LINE__}: #{magic_request_path(id_format).inspect}"
      if ENV['DEBUG_USER'] && Rails.env.development?
        magic_request target
      else
        redirect_to "#{request.protocol}#{request.host_with_port}/users/auth/saml"
      end
    end

    def magic_request target=''
      if request.headers["REQUEST_METHOD"] == "HEAD"
        head :no_content
        return
      end

      @id = params[:bibid]
      # added rescue for DISCOVERYACCESS-5863
      begin
        resp, @document = search_service.fetch @id
       # Rails.logger.debug "mjc12test: doc: #{@document.inspect}"
      rescue Blacklight::Exceptions::RecordNotFound => e
        Rails.logger.debug("******* " + e.inspect)
        flash[:notice] = I18n.t('blacklight.search.errors.invalid_solr_id')
        redirect_to '/catalog'
        return
      end
     # @document = @document
     #Rails.logger.debug "mjc12test: document = #{@document.inspect}"
      @scan = params[:format].present? && params[:format] == "scan" ? "yes" : ""
      work_metadata = Work.new(@id, @document)
      # Temporary Covid-19 work around: patrons can only make delivery requests from 5 libraries, use
      # this string to prevent other locations from appearing in the items array.
      requestable_libraries = "Library Annex, Mann Library, Olin Library, Kroch Library Asia, Uris Library, ILR Library, Music Library, Music Library, Africana Library, Fine Arts Library, Veterinary Library, Law Library, Mathematics Library"
      # Create an array of all the item records associated with the bibid
      items = []

      # Somehow a user was able to request an ETAS work though no request button appears in the UI
      # for that work -- hacked the URL perhaps. So adding a check to see if the document includes
      # the etas_facet. If it does, bypass everything. This is a temporary Covid-19 change. Note:
      # customized the alert for this situation in the items.empty? block below.
      # if @document['etas_facet'].nil? || @document['etas_facet'].empty?
        holdings = JSON.parse(@document['items_json'] || '{}')
        #Rails.logger.debug "mjc12test: holdings: #{holdings}"

        # Items are keyed by the associated holding record
        holdings.each do |h, item_array|

          item_array.each do |i|
            #Rails.logger.debug "mjc12test: document: #{}"

            items << Item.new(h, i, JSON.parse(@document['holdings_json'])) if (i["active"].nil? || i["active"]) && (i['location']['name'].present? && requestable_libraries.include?(i['location']['library']))
            #Rails.logger.debug "mjc12test: added #{items}"
          end
        end
      # else
      #   flash[:alert] = "This title may not be requested because it is available online." if @document['etas_facet'].present?
      #   redirect_to '/catalog/' + params["bibid"]
      #   return
      # end



      # This isn't likely to happen, because the Request item button should be suppressed, but if there's
      # a work with only one item and that item is inactive, we need to redirect because the items array
      # will be empty.
      #Rails.logger.debug "mjc12test: items: #{items}"
      if @document['items_json'].present? && eval(@document['items_json']).size == 1 && items.empty?
        flash[:alert] = "There are no items available to request for this title."
        redirect_to '/catalog/' + params["bibid"]
        return
      end


      @ti = work_metadata.title
      @ill_link = work_metadata.ill_link
      # When we're entering the request system from a /catalog path, then we're starting
      # fresh — no volume should be pre-selected (or kept in the session). However,
      # if the referer is a different path — i.e., /request/*, then we *do* want to
      # preserve the volume selection; this would be the case if the page is reloaded
      # or the user selects an alternate delivery method for the same item.
      if session[:setvol].nil? && (request.referer && request.referer.exclude?('/request/'))
        session[:volume] = nil
      end
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
            redirect_to '/request' + request.env['PATH_INFO'] + "?enum=#{vol.enum}&chron=#{vol.chron}&year=#{vol.year}"
            return
          end
        end
      end

      # If a volume is selected, drop the items that don't match that volume -- no need
      # to waste time calculating delivery methods for them
      # TODO: This is a horribly inefficient approach. Make it better
      if @volumes
        @volumes.each do |v|
          if v.select_option == params[:volume]
            items = v.items
            break
          end
        end
      end

      enabled_request_methods = DeliveryMethod.enabled_methods
      requester = Patron.new(user)
      borrow_direct = CULBorrowDirect.new(requester, work_metadata)
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

      #Rails.logger.debug "mjc12test: items: #{items}"
      items.each do |i|
        rp = {}
        # policy_key = "#{i.circ_group}-#{requester.group}-#{i.type['id']}"
        # if policy_hash[policy_key]
        #   rp = policy_hash[policy_key]
        # else
        #   rp = RequestPolicy.policy(i.circ_group, requester.group, i.type['id'])
        #   policy_hash[policy_key] = rp
        # end
        options = update_options(i, options, requester)
      end
      options[BD] = [1] if borrow_direct.available

      #Rails.logger.debug "mjc12test: options hash - #{options}"
      # At this point, options is a hash with keys being available delivery methods
      # and values being arrays of items deliverable using the keyed method

      # Make some adjustments if this is a special collections item (kind of hacky)
      # TODO: If this item is ONLY available through Mann Special Collections request,
      # then methods like L2L and Ask at Circ should not appear. But how to handle
      # the case of an item that is both in special collections and regular collections
      # somewhere else?
      if options[MannSpecial]
        #Rails.logger.debug "mjc12test: MANN SPECIAL OPTIONS CHECK #{}"
        options[AskCirculation] = []
        # What about L2L?
      end
      sorted_methods = DeliveryMethod.sorted_methods(options)
      fastest_method = sorted_methods[:fastest]
      @alternate_methods = sorted_methods[:alternate]
      # Add PDA if appropriate
      pda_data = PDA.pda_data(@document)
      if pda_data.present?
        @alternate_methods.unshift fastest_method
        fastest_method = {:method => PDA}.merge(pda_data)
      end

      Rails.logger.debug "mjc12test: fastest #{fastest_method}"
      Rails.logger.debug "mjc12test: alternate #{@alternate_methods}"
      # If no other methods are found (i.e., there are no item records to process, such as for
      # an on-order record), ask a librarian
      fastest_method[:method] ||= AskLibrarian

      # If target (i.e., a particular delivery method) is specified in the URL, then we
      # have to prefer that method above others (even if others are faster in theory).
      # This code is a bit ugly, but it swaps the fastest method with the appropriate entry
      # in the alternate_methods array.
      if target.present?
        enabled_request_methods.each do |rm|
          if rm::TemplateName == target
            @alternate_methods.unshift(fastest_method)
            alt_array_index = @alternate_methods&.index{ |am| am[:method] == rm }
            fastest_method = {:method => rm, :items => @alternate_methods[alt_array_index][:items]} if alt_array_index.present?
            @alternate_methods.delete_if{ |am| am[:method] == fastest_method[:method] }
            flash.now.alert = I18n.t('requests.invalidtarget', target: rm.description) if alt_array_index.nil?
            break
          end
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
      @patron = BlacklightCornellRequests::Patron.new(@netid).get_folio_record()

      @name = "#{@patron['personal']['firstName']} #{@patron['personal']['lastName']}"

      @volume = params[:volume]
      @fod_data = get_fod_data user
      @items = fastest_method[:items]

      @iis = ActiveSupport::HashWithIndifferentAccess.new
      if !@document[:url_pda_display].blank? && !@document[:url_pda_display][0].blank?
        pda_url = @document[:url_pda_display][0]
        Rails.logger.debug "es287_log #{__FILE__} #{__LINE__}:" + pda_url.inspect
        pda_url, note = pda_url.split('|')
        @iis = {:pda => { :itemid => 'pda', :url => pda_url, :note => note }}
      end

      @counter = params[:counter]
      if @counter.blank? and session[:search].present?
        @counter = session[:search][:counter]
      end
      render fastest_method[:method]::TemplateName

    end

    def l2l_available?(item)
      L2L.enabled? && policy && policy[:l2l] && item.available? && !item.noncirculating?
    end

    def hold_available?(item, policy)
      Hold.enabled? && policy && policy[:hold] && !item.available?
    end

    def recall_available?(item, policy)
      Recall.enabled? && policy && policy[:recall] && !item.available?
    end

    # Update the options hash with methods for a particular item
    # TODO: there's probably a better way to do this!
    def update_options(item, options, patron)

      available_folio_methods = DeliveryMethod.available_folio_methods(item, patron)
      Rails.logger.debug "mjc12test: AFM: #{available_folio_methods}"
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

      return options
    end

    # Get information about FOD/remote prgram delivery eligibility
    def get_fod_data(netid)

      return {} unless ENV['FOD_DB_URL'].present?

      begin
        uri = URI.parse(ENV['FOD_DB_URL'] + "?netid=#{netid}")
        # response = Net::HTTP.get_response(uri)
        JSON.parse(open(uri, :read_timeout => 5).read)
      rescue OpenURI::HTTPError, Net::ReadTimeout
        Rails.logger.warn("Warning: Unable to retrieve FOD/remote program eligibility data (from #{uri})")
        return {}
      end
    end

    # These one-line service functions simply return the name of the view
    # that should be rendered for each one.
    def l2l
      return magic_request 'l2l'
    end

    def hold
      return magic_request 'hold'
    end

    def recall
      return magic_request 'recall'
    end

    def bd
      return magic_request 'bd'
    end

    def ill
      return magic_request 'ill'
    end

    def purchase
      return magic_request 'purchase'
    end

    def pda
      return magic_request 'pda'
    end

    def ask
      return magic_request 'ask'
    end

    def circ
      return magic_request 'circ'
    end

    def document_delivery
      return magic_request 'document_delivery'
    end

    def mann_special
      return magic_request 'mann_special'
    end

    def blacklight_solr
      @solr ||=  RSolr.connect(blacklight_solr_config)
    end

    def blacklight_solr_config
      Blacklight.solr_config
    end

    # Use the FOLIO APIs to place a hold, recall, or page/L2L request
    def make_folio_request
      # Validate the form data
      errors = []
      if params[:holding_id].blank?
        errors << I18n.t('requests.errors.holding_id.blank')
      end
      if params[:library_id].blank?
        errors << I18n.t('requests.errors.library_id.blank')
      end

      if errors
        flash[:error] = errors.join('<br/>').html_safe
      end

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
        # 5. requester ID
        # 6. request type (Hold, Recall, or Page)
        # 7. request date
        # 8. fulfillment preference (default to Hold Shelf)
        # 9. service point ID for pickup
        # 10. comments, if any
        url = ENV['OKAPI_URL']
        tenant = ENV['OKAPI_TENANT']
        token = CUL::FOLIO::Edge.authenticate(url, tenant, ENV['OKAPI_USER'], ENV['OKAPI_PW'])[:token]
        item_id = params[:holding_id]
        requester_id = Patron.new(user).record['id']
        request_type = params[:request_action]
        request_date = DateTime.now.iso8601
        pickup_location = params[:library_id]
        comments = params[:reqcomments]

        response = CUL::FOLIO::Edge.request_item(url, tenant, token, item_id, requester_id, request_type, request_date, 'Hold Shelf', pickup_location, comments)
        Rails.logger.debug "mjc12test: got response #{response}"

      #   response = req.make_voyager_request params
      #   if !response[:error].blank?
      #     flash[:error] = response[:error]
      #     render :partial => '/shared/flash_msg', :layout => false
      #     return
      #   end
        if response[:error].nil?
          # Note: the :flash=>'success' in this case is not setting the actual flash message,
          # but instead specifying a URL parameter that acts as a flag in Blacklight's show.html.erb view.
          flash[:error] = nil # Without this, a blank 'error' flash appears beneath the success message in B7 ... for some reason
          render js: "$('#main-flashes').hide(); window.location = '#{Rails.application.routes.url_helpers.solr_document_path(params[:bibid], :flash=>'success')}'"
          return
        else
          error = JSON.parse(response[:error])
          Rails.logger.info "Request: response failed: " + error.to_s
          flash[:error] = "Error: the request could not be completed (#{error['errors'][0]['message']})"
        end
      end

      render :partial => '/shared/flash_msg', :layout => false
    end

    def make_purchase_request

      errors = []
      if params[:name].blank?
        errors << I18n.t('requests.errors.name.blank')
      end
      if params[:email].blank?
        errors << I18n.t('requests.errors.email.blank')
      end
      if params[:reqstatus].blank?
        errors << I18n.t('requests.errors.status.blank')
      end
      if params[:reqtitle].blank?
        errors << I18n.t('requests.errors.title.blank')
      end
      if params[:email].present? and errors.empty?
        if params[:email].match(/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/)
          # Email the form contents to the purchase request staff
          RequestMailer.email_request(user, params)
          # TODO: check for mail errors, don't assume that things are working!
          flash[:success] = I18n.t('requests.success')
        else
          errors << I18n.t('requests.errors.email.invalid')
        end
      end

      if errors
        flash[:error] = errors.join('<br/>').html_safe
      end

      render :partial => '/shared/flash_msg', :layout => false

    end

    def make_bd_request
      if params[:library_id].blank?
        flash[:error] = "Please select a library pickup location"
      else
        resp, document = search_service.fetch params[:bibid]
        isbn = document[:isbn_display]
        title = document[:title_display]
        requester = Patron.new(user)
        work = { :isbn => isbn, :title => title }
        # Following FOLIO updates, using CULBorrowDirect for now as it has both the request_from_bd method
        #and an authenticate method, which is called on initialization. Passing the boolean provides a way
        # of distinguishing between the availability check and the call that actually makes the request.
        make_request = true
        req = BlacklightCornellRequests::CULBorrowDirect.new(requester, work, make_request)
        resp = req.request_from_bd({ :isbn => isbn, :netid => user, :pickup_location => params[:library_id], :notes => params[:reqcomments] })
        if resp
          status = 'success'
          status_msg = I18n.t('requests.success') + " The Borrow Direct request number is #{resp}."
        else
          status = 'failure'
          status_msg = "There was an error when submitting this request to Borrow Direct. Your request could not be completed."
        end
      end

      if status
        render :partial => 'bd_notification', :layout => false, locals: {:message => status_msg, :status => status}
      else
        render :partial => '/shared/flash_msg', :layout => false
      end
    end

    # AJAX responder used with requests.js.coffee to set the volume
    # when the user selects one in the volume drop-down list
    def set_volume
      Rails.logger.warn "mjc12test: setvol params: #{params}"
      session[:volume] = params[:volume]
      session[:setvol] = 1
      respond_to do |format|
        format.js {render body: nil}
      end
    end


    def user
      netid = nil
      if ENV['DEBUG_USER'] && Rails.env.development?
        netid = ENV['DEBUG_USER']
      else
        netid = request.env['REMOTE_USER'] ? request.env['REMOTE_USER']  : session[:cu_authenticated_user]
      end

      netid = netid.sub('@CORNELL.EDU', '') unless netid.nil?
      netid = netid.sub('@cornell.edu', '') unless netid.nil?

      netid
    end

  end

end
