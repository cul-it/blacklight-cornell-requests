require_dependency "blacklight_cornell_requests/application_controller"

module BlacklightCornellRequests
  
  class RequestController < ApplicationController

    include Blacklight::SolrHelper
    
    def magic_request target=''
      
      @id = params[:bibid]
      resp, @document = get_solr_response_for_doc_id(@id)
      
      req = BlacklightCornellRequests::Request.new(@id)
      req.netid = request.env['REMOTE_USER']
      req.magic_request @document
      
      @alternate_request_options = req.request_options
      if ! req.service.nil?
        @service = req.service[:services][0]
      else
        @service = { :service => BlacklightCornellRequests::Request::ASK_LIBRARIAN }
      end
      
      @estimate = @service[:estimate]
      @ti = req.ti
      @au = req.au
      @isbn = req.isbn
      @ill_link = req.ill_link
      @pub_info = req.pub_info
      
      render @service[:service]
      
    end
    
    def _display request_options, service, doc
      
    end

    def l2l
      return magic_request L2L
    end

    def hold
      return magic_request HOLD
    end

    def recall
      return magic_request RECALL
    end

    def bd
      return magic_request BD
    end

    def ill
      return magic_request ILL
    end

    def purchase
      return magic_request PURCHASE
    end

    def pda
      return magic_request PDA
    end

    def ask
      return magic_request ASK_LIBRARIAN
    end
    
    def blacklight_solr
      @solr ||=  RSolr.connect(blacklight_solr_config)
    end

    def blacklight_solr_config
      Blacklight.solr_config
    end
    
  end
end
