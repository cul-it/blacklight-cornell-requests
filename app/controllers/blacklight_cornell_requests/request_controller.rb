require_dependency "blacklight_cornell_requests/application_controller"

module BlacklightCornellRequests

  class RequestDatabaseException < StandardError
    attr_reader :data

    def initialize(data)
     super
     @data = data
    end
  end

  class RequestController < ApplicationController

    include Blacklight::Catalog # needed for "fetch", replaces "include SolrHelper"
    include Cornell::LDAP

    # This may seem redundant, but it makes it easier to fetch the document from
    # various model classes
    def get_solr_doc doc_id
      resp, document = fetch doc_id
      document
    end

    def auth_magic_request target=''
      session[:cuwebauth_return_path] =  magic_request_path(params[:bibid])
      Rails.logger.debug "es287_log #{__FILE__} #{__LINE__}: #{magic_request_path(params[:bibid]).inspect}"
      redirect_to "#{request.protocol}#{request.host_with_port}/users/auth/saml"
      #magic_request target
    end

    def magic_request target=''

      @id = params[:bibid]
      resp, @document = fetch @id
      @document = @document

      work_metadata = Work.new(@id, @document)
      # Create an array of all the item records associated with the bibid
      items = []
      holdings = JSON.parse(@document['items_json'] || '{}')
      # Items are keyed by the associated holding record
      holdings.each do |h, item_array|
        item_array.each do |i|
          items << Item.new(h, i)
        end
      end
      @ti = work_metadata.title

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
          else
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

      available_request_methods = DeliveryMethod.enabled_methods
      requester = Patron.new(user)
      borrow_direct = CULBorrowDirect.new(requester, work_metadata)

      # We have the following delivery methods to evaluate (at most) for each item:
      # L2L, BD, ILL, Hold, Recall, Patron-driven acquisition, Purchase request
      # ScanIt, Ask a librarian, ask at circ desk
      #
      # For the voyager methods (L2L, Hold, Recall), we do the following for each item:
      # 1. Get the circ group, patron group, and item type
      # 2. Use those values to look up the request policy
      # 3. Combine (2) with item availability to determine which methods are available
      #
      # For BD, do a single call to the BD API for the bib-level ISBN (NOT for each item)
      #
      # For PDA?

      # The options hash has the following structure:
      # options = { DeliveryMethod => [items] }
      # i.e., each key in the hash is the class, e.g. L2L, and that points to
      # an array of items available via that method
      options = {}
      available_request_methods.each do |rm|
        options[rm] = []
      end
      # First get the Voyager methods. Policy hash is used to cache policies for
      # particular parameter combinations so that we minimize DB queries
      policy_hash = {}
      items.each do |i|
        rp = {}
        # TODO: use a symbol instead of a string for the keys?
        policy_key = "#{i.circ_group}-#{requester.group}-#{i.type['id']}"
        if policy_hash[policy_key]
          rp = policy_hash[policy_key]
        else
          rp = RequestPolicy.policy(i.circ_group, requester.group, i.type['id'])
          policy_hash[policy_key] = rp
        end
        options = update_options(i, rp, options, requester)
      end
      options[BD] = [1] if borrow_direct.available

      Rails.logger.debug "mjc12test: options hash - #{options}"
      # At this point, options is a hash with keys being available delivery methods
      # and values being arrays of items deliverable using the keyed method

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
        available_request_methods.each do |rm|
          if rm::TemplateName == target
            @alternate_methods.unshift(fastest_method)
            alt_array_index = @alternate_methods.index{ |am| am[:method] == rm }
            fastest_method = {:method => rm, :items => @alternate_methods[alt_array_index]}
            @alternate_methods.delete_if{ |am| am[:method] == fastest_method[:method] }
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
      @scanit_link = work_metadata.scanit_link
      @netid = user
      @name = get_patron_name user
      @volume = params[:volume]
      @fod_data = get_fod_data user
      @items = fastest_method[:items]
###### END NEW #######

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

    def l2l_available?(item, policy)
      L2L.enabled? && policy[:l2l] && item.available?
    end

    def hold_available?(item, policy)
      Hold.enabled? && policy[:hold] && !item.available?
    end

    def recall_available?(item, policy)
      Recall.enabled? && policy[:recall] && !item.available?
    end

    # Update the options hash with methods for a particular item
    # TODO: there's probably a better way to do this!
    def update_options(item, policy, options, patron)

      options[ILL] << item if ILL.available?(item, patron)
      options[L2L] << item if l2l_available?(item, policy)
      options[Hold].push(item) if hold_available?(item, policy)
      options[Recall] << item if recall_available?(item, policy)
      options[PurchaseRequest] << item if PurchaseRequest.available?(item, patron)
      options[DocumentDelivery] << item if DocumentDelivery.available?(item, patron)
      options[AskLibrarian] << item if AskLibrarian.available?(item, patron)
      options[AskCirculation] if AskCirculation.available?(item, patron)

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
      return magic_request Request::L2L
    end

    def hold
      return magic_request Request::HOLD
    end

    def recall
      return magic_request Request::RECALL
    end

    def bd
      return magic_request Request::BD
    end

    def ill
      return magic_request Request::ILL
    end

    def purchase
      return magic_request Request::PURCHASE
    end

    def pda
      return magic_request Request::PDA
    end

    def ask
      return magic_request Request::ASK_LIBRARIAN
    end

    def circ
      return magic_request Request::ASK_CIRCULATION
    end

    def document_delivery
      return magic_request Request::DOCUMENT_DELIVERY
    end

    def blacklight_solr
      @solr ||=  RSolr.connect(blacklight_solr_config)
    end

    def blacklight_solr_config
      Blacklight.solr_config
    end

    def make_voyager_request

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
        # Hand off the data to the request model for sending
        req = BlacklightCornellRequests::Request.new(params[:bibid])
        # req.netid = request.env['REMOTE_USER']
        # req.netid.sub! '@CORNELL.EDU', ''
        req.netid = user
        # If the holding_id = 'any', then set to blank. Voyager expects an empty value for 'any copy',
        # but validation above expects a non-blank value!
        if params[:holding_id] == 'any'
          params[:holding_id] = ''
        end

        response = req.make_voyager_request params
        Rails.logger.info "Response:" + response.inspect
        if !response[:error].blank?
          flash[:error] = response[:error]
          render :partial => '/flash_msg', :layout => false
          return
        end
        if response[:failure].blank?
          # Note: the :flash=>'success' in this case is not setting the actual flash message,
          # but instead specifying a URL parameter that acts as a flag in Blacklight's show.html.erb view.
          render js: "window.location = '#{Rails.application.routes.url_helpers.solr_document_path(params[:bibid], :flash=>'success')}'"
          return
        else
          Rails.logger.info "Response: was failure" + response[:failure].inspect
          flash[:error] = response[:failure]
        end
      end

      render :partial => '/flash_msg', :layout => false

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

      render :partial => '/flash_msg', :layout => false

    end

    def make_bd_request

      if params[:library_id].blank?
        flash[:error] = "Please select a library pickup location"
      else
        resp, document = fetch params[:bibid]
        isbn = document[:isbn_display]
        req = BlacklightCornellRequests::Request.new(params[:bibid])

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
        render :partial => '/flash_msg', :layout => false
      end

    end

    # AJAX responder used with requests.js.coffee to set the volume
    # when the user selects one in the volume drop-down list
    def set_volume
      Rails.logger.warn "mjc12test: setvol params: #{params}"
      session[:volume] = params[:volume]
      session[:setvol] = 1
      respond_to do |format|
        format.js {render nothing: true}
      end
    end


    def user
      netid = request.env['REMOTE_USER'] ? request.env['REMOTE_USER']  : session[:cu_authenticated_user]
      netid.sub!('@CORNELL.EDU', '') unless netid.nil?
      netid.sub!('@cornell.edu', '') unless netid.nil?

      netid
    end

  end

end
