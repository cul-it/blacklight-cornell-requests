require_dependency "blacklight_cornell_requests/application_controller"

module BlacklightCornellRequests

  class RequestController < ApplicationController

    include Blacklight::SolrHelper
    include Cornell::LDAP
    
    def get_solr_doc(bibid)
      resp, document = get_solr_response_for_doc_id(bibid)
      document
    end
    
    def test 

      
      @id = params[:bibid]
      resp, document = get_solr_response_for_doc_id(@id)
     
      @netid = request.env['REMOTE_USER'] 
      # !!!!!!!!!!!!!!!!!!!!
      @netid = 'mjc12'
      # !!!!!!!!!!!!!!!!!!!!
      @netid.sub!('@CORNELL.EDU', '') unless @netid.nil?
     
      volume = volume_hash_from_params(params)
      request = BlacklightCornellRequests::Request2.new(@id, @netid, document,nil,nil,volume)
      
      best_method = nil
      alternate_methods = []
      if request.delivery_methods.present?
        best_method = request.delivery_methods[0]
        if request.delivery_methods.count > 1
          alternate_methods = request.delivery_methods[1..-1]
        end
      end
          
      
      # ############################
      # Variables for views
      # Delivery methods are returned already sorted by delivery time
      @estimate = best_method.time
      @primary_option = best_method
      @alternate_request_options = alternate_methods
      
      # #############################
      
      
      @volume = volume
      @volumes = request.work.volumes
      @document = request.document
      
      render_by_template best_method if params['goforit']
      
    end
    
    def render_by_template delivery_method
      render delivery_method::TemplateName
    end
    # 
    # 
    # def magic_request target=''
    #   
    #   @id = params[:bibid]
    #   resp, document = get_solr_response_for_doc_id(@id)
    #   
    #   @netid = request.env['REMOTE_USER'] 
    #   @netid.sub!('@CORNELL.EDU', '') unless @netid.nil?
    #   
    #   volume = volume_hash_from_params(params)
    #   request = BlacklightCornellRequests::Request2.new(@id, @netid, document,nil,nil,volume)
    #   # Delivery methods are returned already sorted by delivery time
    #   delivery_methods = request.delivery_methods
    # 
    #   @estimate = delivery_methods[0].time
    #   
    #   ######### ??????????? ############
    #   @ti       = request.work.title
    #   @au       = request.work.author
    #   @isbn     = request.work.isbn
    #   @ill_link = request.work.ill_link
    #   @pub_info = request.work.pub_info      
    #   @volume   = params[:volume]
    #   @name     = get_patron_name @netid
    #   ########## ??????????? #############
    # 
    #   # Note: the if statement here only shows the volume select screen
    #   # if a doc del request has *not* been specified. This is because 
    #   # (a) without that statement, the user just loops endlessly through
    #   # volume selection and doc del requesting; and (b) since we can't
    #   # pre-populate the doc del request form with bibliographic data, there's
    #   # no point in forcing the user to select a volume before showing the form.
    #   if request.multivolume == true && request.volume.nil?
    #     if request.work.volumes.count > 1
    #       render 'shared/_volume_select'
    #       return
    #     else
    #       # a bit hacky solution here to get to request path
    #       # will need more rails compliant solution down the road...
    #       redirect_to '/request' + request.env['PATH_INFO'] + "/?#{volume_url_params}"
    #       return
    #     end
    #   elsif delivery_methods.present?
    #     delivery_methods.each do |item|
    #       iid = item[:iid]
    #       @iis[iid[:item_id]] = iid unless iid.blank?
    #     end
    #     @volumes = request.work.volumes
    #   end
    # 
    #   @alternate_request_options = []
    #   if !req.alternate_options.nil?
    #     req.alternate_options.each do |option|
    #       @alternate_request_options.push({:option => option[:service], :estimate => option[:estimate]})
    #     end
    #   end
    #   
    #   @counter = params[:counter]
    #   if @counter.blank? and session[:search].present?
    #     @counter = session[:search][:counter]
    #   end
    # 
    #   render @service
    # 
    # end
    # 
    # Convert GET params into a volume enumeration hash
    def volume_hash_from_params(params)
      {
        :enum  => params[:enum],
        :chron => params[:chron],
        :year  => params[:year]
      }
    end
    # 
    # # These one-line service functions simply return the name of the view
    # # that should be rendered for each one.
    # def l2l
    #   return magic_request Request::L2L
    # end
    # 
    # def hold
    #   return magic_request Request::HOLD
    # end
    # 
    # def recall
    #   return magic_request Request::RECALL
    # end
    # 
    # def bd
    #   return magic_request Request::BD
    # end
    # 
    # def ill
    #   return magic_request Request::ILL
    # end
    # 
    # def purchase
    #   return magic_request Request::PURCHASE
    # end
    # 
    # def pda
    #   return magic_request Request::PDA
    # end
    # 
    # def ask
    #   return magic_request Request::ASK_LIBRARIAN
    # end
    # 
    # def circ
    #   return magic_request Request::ASK_CIRCULATION
    # end
    # 
    # def document_delivery
    #   return magic_request Request::DOCUMENT_DELIVERY
    # end
    # 
    # def blacklight_solr
    #   @solr ||=  RSolr.connect(blacklight_solr_config)
    # end
    # 
    # def blacklight_solr_config
    #   Blacklight.solr_config
    # end
    # 
    # # Take a volume hash of the form { :chron => ..., :enum => ..., :year => ...}
    # # and turn it into a string of URL params that can be appended to a path
    # def volume_url_params volume_hash
    #   URI::encode("enum=#{volume_hash[:enum]}&chron=#{volume_hash[:chron]}&year=#{volume_hash[:year]}")
    # end
    # 
    def make_voyager_request
    end
    # 
    #   # Validate the form data
    #   errors = []
    #   if params[:holding_id].blank?
    #     errors << I18n.t('requests.errors.holding_id.blank')
    #   end
    #   if params[:library_id].blank?
    #     errors << I18n.t('requests.errors.library_id.blank')
    #   end
    #   
    #   if errors
    #     flash[:error] = errors.join('<br/>').html_safe
    #   end
    # 
    #   if errors.blank?
    #     # Hand off the data to the request model for sending
    #     req = BlacklightCornellRequests::Request.new(params[:bibid])
    #     req.netid = request.env['REMOTE_USER']
    #     req.netid.sub! '@CORNELL.EDU', ''
    #     # If the holding_id = 'any', then set to blank. Voyager expects an empty value for 'any copy',
    #     # but validation above expects a non-blank value!
    #     if params[:holding_id] == 'any'
    #       params[:holding_id] = ''
    #     end
    # 
    #     response = req.make_voyager_request params
    #     Rails.logger.info "Response:" + response.inspect
    #     if !response[:error].blank?
    #       flash[:error] = response[:error]
    #       render :partial => '/flash_msg', :layout => false
    #       return
    #     end
    #     if response[:failure].blank?
    #       # Note: the :flash=>'success' in this case is not setting the actual flash message,
    #       # but instead specifying a URL parameter that acts as a flag in Blacklight's show.html.erb view.
    #       render js: "window.location = '#{Rails.application.routes.url_helpers.catalog_path(params[:bibid], :flash=>'success')}'"
    #       return
    #     else
    #       Rails.logger.info "Response: was failure" + response[:failure].inspect
    #       flash[:error] = response[:failure]
    #     end
    #   end
    # 
    #   render :partial => '/flash_msg', :layout => false
    # 
    # end
    # 
    # def make_purchase_request
    # 
    #   errors = []
    #   if params[:name].blank?
    #     errors << I18n.t('requests.errors.name.blank')
    #   end
    #   if params[:email].blank?
    #     errors << I18n.t('requests.errors.email.blank')
    #   end
    #   if params[:reqstatus].blank?
    #     errors << I18n.t('requests.errors.status.blank')
    #   end
    #   if params[:reqtitle].blank?
    #     errors << I18n.t('requests.errors.title.blank')
    #   end
    #   if params[:email].present? and errors.empty?
    #     if params[:email].match(/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/)
    #       # Email the form contents to the purchase request staff
    #       RequestMailer.email_request(request.env['REMOTE_USER'], params)
    #       # TODO: check for mail errors, don't assume that things are working!
    #       flash[:success] = I18n.t('requests.success')
    #     else
    #       errors << I18n.t('requests.errors.email.invalid')
    #     end
    #   end
    # 
    #   if errors
    #     flash[:error] = errors.join('<br/>').html_safe
    #   end
    # 
    #   render :partial => '/flash_msg', :layout => false
    # 
    # end
    # 
    # # AJAX responder used with requests.js.coffee to set the volume
    # # when the user selects one in the volume drop-down list
    # def set_volume
    #   session[:volume] = params[:volume]
    #   respond_to do |format|
    #     format.js {render nothing: true}
    #   end
    # end

  end

end
