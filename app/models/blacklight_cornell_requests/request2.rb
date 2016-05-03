require 'borrow_direct'

module BlacklightCornellRequests
  # @author Matt Connolly

  class Request2
    
    
    # @todo It's very annoying to have to bring document in as an initialization param.
    # It should be set here, but I'm not having much luck calling get_solr_response_for_doc_id
    # except in the controller.
    attr_reader :bibid, 
                :netid, 
                :document,
                # holdings_data is the unprocesssed data returned by a call to the holdings service 
                # @todo Do we really need to keep this around?
                :holdings_data,
                # holdings contains an array of Holding class instances for each library holding of
                # this bibid. 
                :holdings,
                :bd_available
    
    # Basic initializer
    # 
    # @param bibid [Fixnum] The bibID being requested
    # @param netid [String] The Cornell NetID of the requester
    # @param document [Hash] The Solr documenta associated with the bibID
    def initialize(bibid, netid, document)
      @bibid = bibid
      @netid = netid
      @document = document
      @bd_available = available_in_bd?
      @holdings_data = get_holdings
      @holdings = parse_holdings
    end
    
    def inspect
      puts "BibID #{@bibid} requested for '#{@netid}'"
      bd_avail = (@bd_available ? 'IS' : 'is NOT')
      puts "Item #{bd_avail} available in Borrow Direct"
    #  puts "There are #{@holdings.count} holdings records (#{@holdings.each |h| { print h}})"
    end
    
    def get_holdings
      
      response = HTTPClient.get_content(Rails.configuration.voyager_holdings + "/holdings/status_short/#{@bibid}")
      response = JSON.parse(response).with_indifferent_access
      puts "response: #{response.inspect}"
      response[@bibid.to_s][@bibid.to_s][:records][0][:holdings]
      
    end
    
    def parse_holdings
      
      holdings = []
      mfhds = Hash.new {|h, k| h[k] = [] }
      # Each chunk of holdings_data looks like this: 
      #{"BIB_ID"=>1419, "MFHD_ID"=>5248430, "ITEM_ID"=>6782463, "ITEM_STATUS"=>1, "DISPLAY_CALL_NO"=>"Oversize HD205 1962 .S52 +", "LOCATION_ID"=>99, "LOCATION_CODE"=>"olin", "LOCATION_DISPLAY_NAME"=>"Olin Library", "OQUANTITY"=>nil, "ODATE"=>nil, "LINE_ITEM_STATUS"=>nil, "LINE_ITEM_ID"=>nil, "TEMP_LOCATION_DISPLAY_NAME"=>nil, "TEMP_LOCATION_CODE"=>nil, "TEMP_LOCATION_ID"=>0, "ITEM_STATUS_DATE"=>"2013-07-11T05:39:16-04:00", "PERM_LOCATION"=>99, "PERM_LOCATION_DISPLAY_NAME"=>"Olin Library", "PERM_LOCATION_CODE"=>"olin", "CURRENT_DUE_DATE"=>nil, "HOLDS_PLACED"=>0, "RECALLS_PLACED"=>0, "PO_TYPE"=>nil, "ITEM_ENUM"=>"v.2", "CHRON"=>nil}
      @holdings_data.each do |h|
        mfhds[h['MFHD_ID']] << h
      end
      
      mfhds.each do |k, v|
        holdings << BlacklightCornellRequests::Holding.new(v)
      end
    
      holdings
      
    end
    
    # Determine Borrow Direct availability for an ISBN or title
    # params = { :isbn, :title }
    # ISBN is best, but title will work if ISBN isn't available.
    def available_in_bd?
      
      return false if @document.nil?
      
      isbn  = document[:isbn_display]
      title = document[:title_display]
    
      # Set up params for BorrowDirect gem
      BorrowDirect::Defaults.api_key = ENV['BORROW_DIRECT_TEST_API_KEY']
      BorrowDirect::Defaults.api_base = 'https://bdtest.relais-host.com/'
      BorrowDirect::Defaults.library_symbol = 'CORNELL'
      BorrowDirect::Defaults.find_item_patron_barcode = patron_barcode(@netid)
      BorrowDirect::Defaults.timeout = 30 # (seconds)
      # if api_base isn't specified, it defaults to BD test database
      if Rails.env.production?
        BorrowDirect::Defaults.api_base = BorrowDirect::Defaults::PRODUCTION_API_BASE
        BorrowDirect::Defaults.api_key = ENV['BORROW_DIRECT_PROD_API_KEY']
      end

      response = nil
      
      # This block can throw timeout errors if BD takes to long to respond
      begin
        if isbn.present?
          # Note: [*<variable>] gives us an array if we don't already have one,
          # which we need for the map.
          response = BorrowDirect::FindItem.new.find(:isbn => ([*isbn].map!{|i| i = i.clean_isbn}))
        elsif title.present?
          response = BorrowDirect::FindItem.new.find(:phrase => title)
        end

        return response.requestable?

      rescue Errno::ECONNREFUSED => e
        if ENV['ROUTE_EXCEPTIONS_TO_HIPCHAT'] == 'true'
          ExceptionNotifier.notify_exception(e)
        end
        Rails.logger.warn 'Requests: Borrow Direct connection was refused'
        Rails.logger.warn e.message
        Rails.logger.warn e.backtrace.inspect
        return false
      rescue BorrowDirect::HttpTimeoutError => e
        if ENV['ROUTE_EXCEPTIONS_TO_HIPCHAT'] == 'true'
          ExceptionNotifier.notify_exception(e)
        end
        Rails.logger.warn 'Requests: Borrow Direct check timed out'
        Rails.logger.warn e.message
        Rails.logger.warn e.backtrace.inspect
        return false
      rescue BorrowDirect::Error => e
        if ENV['ROUTE_EXCEPTIONS_TO_HIPCHAT'] == 'true'
          ExceptionNotifier.notify_exception(e)
        end
        Rails.logger.warn 'Requests: Borrow Direct gave error.'
        Rails.logger.warn e.message
        Rails.logger.warn e.backtrace.inspect
        Rails.logger.warn response.inspect 
        return false
      end
      
    end
    
    # Use the external netid lookup script to figure out the patron's barcode
    # (this might duplicate what's being done in the voyager_request patron method)
    def patron_barcode(netid)

      uri = URI.parse(ENV['NETID_URL'] + "?netid=#{netid}")
      response = Net::HTTP.get_response(uri)

      # Make sure that we got a real result. Unfortunately, the CGI doesn't
      # return a nice error code
      return nil if response.body.include? 'Software error'

      # Return the barcode
      JSON.parse(response.body)['bc']

    end
  
    
  end
end

class String
  def clean_isbn
    temp = self
    if self.index(' ')
      temp   = self[0,self.index(' ')]
    end
    temp =  temp.size == 10 ? temp : temp.gsub!(/[^0-9X]*/, '')
    temp =  temp.size == 13 ? temp : temp.gsub!(/[^0-9X]*/, '')
    temp
  end
end