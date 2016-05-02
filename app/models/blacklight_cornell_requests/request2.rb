module BlacklightCornellRequests
  # @author Matt Connolly

  class Request2
    
    
    # @todo It's very annoying to have to bring document in as an initialization param.
    # It should be set here, but I'm not having much luck calling get_solr_response_for_doc_id
    # except in the controller.
    attr_reader :bibid, :netid, :document, :holdings_data, :holdings
    
    # Basic initializer
    # 
    # @param bibid [Fixnum] The bibID being requested
    # @param netid [String] The Cornell NetID of the requester
    # @param document [Hash] The Solr documenta associated with the bibID
    def initialize(bibid, netid, document)
      @bibid = bibid
      @netid = netid
      @document = document
      get_holdings
      parse_holdings
    end
    
    def get_holdings
      
      response = HTTPClient.get_content(Rails.configuration.voyager_holdings + "/holdings/status_short/#{@bibid}")
      response = JSON.parse(response).with_indifferent_access
      puts "response: #{response.inspect}"
      @holdings_data = response[@bibid.to_s][@bibid.to_s][:records][0][:holdings]
      
      #@holdings_data = BlacklightCornellRequests::HoldingsData.new(@bibid, @document)
    end
    
    def parse_holdings
      
      holdings = []
      mfhds = Hash.new {|h, k| h[k] = [] }
      @holdings_data.each do |h|
        #if mfhds.keys.include? h['MFHD_ID']
          mfhds[h['MFHD_ID']] << h
        #end
      end
      
      mfhds.each do |k, v|
        holdings << BlacklightCornellRequests::Holding.new(v)
      end
    
      @holdings = holdings
      
    end
    
    
  end
end