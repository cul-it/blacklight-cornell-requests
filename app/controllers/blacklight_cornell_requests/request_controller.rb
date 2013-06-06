require_dependency "blacklight_cornell_requests/application_controller"

module BlacklightCornellRequests
  
  class RequestController < ApplicationController

    include Blacklight::SolrHelper
    
    def magic_request target=''
      
      @id = params[:bibid]
      resp, @document = get_solr_response_for_doc_id(@id)
      
      req = BlacklightCornellRequests::Request.new(@id)
      req.netid = request.env['REMOTE_USER']
      req.magic_request @document, request.env['HTTP_HOST'], target
      
      if ! req.service.nil?
        @service = req.service
      else
        @service = { :service => BlacklightCornellRequests::Request::ASK_LIBRARIAN }
      end
      
      @estimate = req.estimate
      @ti = req.ti
      @au = req.au
      @isbn = req.isbn
      @ill_link = req.ill_link
      @pub_info = req.pub_info
      
      @iis = {}
      req.request_options.each do |item|
        iid = item[:iid]
        @iis[iid['itemid']] = {
            :location => iid['location'],
            :location_id => iid['location_id'],
            :call_number => iid['callNumber'],
            :copy => iid['copy'],
            :enumeration => iid['enumeration'],
            :url => iid['url'],
            :chron => iid['chron'],
            :exclude_location_id => iid['exclude_location_id']
        }
      end
      
      @alternate_request_options = []
      req.alternate_options.each do |option|
        @alternate_request_options.push({:option => option[:service], :estimate => option[:estimate]})
      end
      
      # Rails.logger.info "sk274_debug: " + @alternate_request_options.inspect
      
      render @service
      
    end

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
    
    def blacklight_solr
      @solr ||=  RSolr.connect(blacklight_solr_config)
    end

    def blacklight_solr_config
      Blacklight.solr_config
    end
    
  end
end
