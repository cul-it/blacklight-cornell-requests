require 'dotenv'
require 'borrow_direct'
require 'net/http'
require 'uri'
require 'json'

module BlacklightCornellRequests

  class CULBorrowDirect

    attr_reader :mode, :patron, :work, :available

    ######## Constants for updated API calls ########
    TEST = {
      :base_url => 'https://bdtest.relais-host.com',
      :api_key => ENV['BORROW_DIRECT_TEST_API_KEY']
    }
    PROD = {
      :base_url => 'https://borrow-direct.relais-host.com',
      :api_key => ENV['BORROW_DIRECT_PROD_API_KEY']
    }
    # Values shared by both test and production environments
    COMMON = {
      :symbol => 'CORNELL',
      :group => 'PATRON',
      :partnership => 'BD'
    }
    #################################################

    # patron should be a Patron instance
    # work = { :isbn, :title }
    # ISBN is best, but title will work if ISBN isn't available.
    def initialize(patron, work, add_request=false)
      @patron = patron
      @work = work
      @credentials = nil

      # Set parameters for the Borrow Direct API
      BorrowDirect::Defaults.library_symbol = 'CORNELL'
      BorrowDirect::Defaults.find_item_patron_barcode = @patron.barcode
      BorrowDirect::Defaults.timeout = ENV['BORROW_DIRECT_TIMEOUT'].to_i || 30 # (seconds)

      # Set api_base to the value specified in the .env file. possible values:
      # TEST - use default test URL
      # PRODUCTION - use default production URL
      # any other URL beginning with http - use that
      set_mode ENV['BORROW_DIRECT_URL']

      # AID is the AuthenticationId needed to use the Borrow Direct APIs
      @aid = authenticate

      @available = available_in_bd? if !add_request
      
    end

    # Switch between test and production configuration
    def set_mode mode
      BorrowDirect::Defaults.api_key = ENV['BORROW_DIRECT_TEST_API_KEY']
      @mode = 'TEST'
      api_base = ''

      case mode
      when 'TEST'
        api_base = BorrowDirect::Defaults::TEST_API_BASE
        @credentials = TEST
      when 'PRODUCTION'
        api_base = BorrowDirect::Defaults::PRODUCTION_API_BASE
        BorrowDirect::Defaults.api_key = ENV['BORROW_DIRECT_PROD_API_KEY']
        @mode = 'PRODUCTION'
        @credentials = PROD
      when /^http/
        # It's possible for the mode to be something other than 'test' or
        # 'production' (since it usually comes from the ENV settings). When
        # that's the case, a URL implies that things are set up to point to
        # a temporary or tertiary Relais server. Of course, an API key is still
        # required. FOR NOW, assume that it's the test API key (as set in
        # default above).
        api_base = ENV['BORROW_DIRECT_URL']
      else
        # Assume we're using test
        api_base = BorrowDirect::Defaults::TEST_API_BASE
        @credentials = TEST
      end

      BorrowDirect::Defaults.api_base = api_base
    end

    # (new APIs)
    # Use the authentication API to get an 'AID' token needed for other API calls
    # returns the AID, or nil if there is an error
    def authenticate
      uri = URI.parse("#{@credentials[:base_url]}/portal-service/user/authentication")
      body = {
        "LibrarySymbol" => COMMON[:symbol],
        'UserGroup' => COMMON[:group],
        'PartnershipId'=> COMMON[:partnership],
        'ApiKey' => @credentials[:api_key],
        'PatronId' => @patron.barcode
      }
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.path, {'Content-Type' => 'application/json' })
      request.body = body.to_json
      response = http.request(request)
      Rails.logger.debug("mjc12test: authn response: #{response.code} #{response.body}")

      if (response.code.to_i == 200)
        return JSON.parse(response.body)['AuthorizationId']
      else
        Rails.logger.warn("Warning: Requests unable to obtain AuthorizationId from Borrow Direct (response: #{response.code} #{response.body}")
        return nil
      end
    end

    # Determine Borrow Direct availability for an ISBN or title
    def available_in_bd?
      # Don't bother if BD has been disabled in .env
      return false if ENV['DISABLE_BORROW_DIRECT'].present?
      # Or if the user isn't eligible
      return false unless BD.available?(@patron)

      ######## Code for updated API calls ########
      #
      # (re-enable caching in the next line once we're done testing the lookup)
  #    Rails.cache.fetch("bd-availability-#{@work.bibid}", :expires_in => 5.minutes) do
        response = nil
        Rails.logger.debug "mjc12test: DOING A FRESH BD CALL #{@work.title}, #{@work.isbn}"

        # Get the ISBNs or work title to use as search parameters
        # TODO: The new APIs use a more flexible CQL query structure that might let us
        # incorporate multiple metadata components into a single search. Something to consider.
        query_param = ''
        if @work.isbn.present?
          # Note: [*<variable>] gives us an array if we don't already have one,
          # which we need for the map.
          isbns = ([*@work.isbn].map!{|i| i = i.clean_isbn})
          query_param = 'isbn=' + isbns.join(' or isbn=')
        elsif @work.title.present?
          query_param = 'ti=' + URI.encode("\"#{@work.title}\"")
        end

        records = search_bd(query_param)
        return records ? requestable?(records) : false
     # end
      ############################################

      # old code follows

      # set_mode(ENV['BORROW_DIRECT_URL']) unless @mode.present?

      # Rails.cache.fetch("bd-availability-#{@work.bibid}", :expires_in => 5.minutes) do
      #   response = nil
      #   Rails.logger.debug "mjc12test: DOING A FRESH BD CALL #{@work.title}, #{@work.isbn}"
      #   # This block can throw timeout errors if BD takes to long to respond
      #   begin
      #     if @work.isbn.present?
      #       # Note: [*<variable>] gives us an array if we don't already have one,
      #       # which we need for the map.
      #       response = BorrowDirect::FindItem.new.find(:isbn => ([*@work.isbn].map!{|i| i = i.clean_isbn}))
      #     elsif @work.title.present?
      #       response = BorrowDirect::FindItem.new.find(:phrase => @work.title)
      #     end

      #     return response.requestable?

      #   rescue Errno::ECONNREFUSED => e
      #     #  ExceptionNotifier.notify_exception(e)
      #     Rails.logger.warn 'Requests: Borrow Direct connection was refused'
      #     Rails.logger.warn e.message
      #     Rails.logger.warn e.backtrace.inspect
      #     return false
      #   rescue BorrowDirect::HttpTimeoutError => e
      #     Rails.logger.warn 'Requests: Borrow Direct check timed out'
      #     Rails.logger.warn e.message
      #     Rails.logger.warn e.backtrace.inspect
      #     return false
      #   rescue BorrowDirect::Error => e
      #     Rails.logger.warn 'Requests: Borrow Direct gave error.'
      #     Rails.logger.warn e.message
      #     Rails.logger.warn e.backtrace.inspect
      #     Rails.logger.warn response.inspect
      #     return false
      #   end

      # end
    end

    # Use the Find Item BD API to execute a search. Returns the array of records provided in the response.
    def search_bd(query)
        # Use the Find Item API to determine availability. This API returns results asynchronously,
        # with additional results being updated each time we query the same URL. Unfortunately, we
        # have to keep querying the API until the entire result set is complete, then parse it ourselves
        # to determine whether an item is available locally.
        uri = URI.parse("#{@credentials[:base_url]}/di/search?query=#{query}&aid=#{@aid}")
        query_pending = true
        json_response = {}

        while query_pending
          response = Net::HTTP.get_response(uri)
          if (response.code.to_i == 200)
            # The ActiveCatalog parameter in the response indicates how many BD catalogs are being
            # actively searched. When the search is complete, this number should be 0.
            json_response = JSON.parse(response.body)
            query_pending = json_response['ActiveCatalog'] > 0
          elsif (response.code.to_i == 404)
            # This indicates "no result"
            query_pending = false
            return nil
          else
            Rails.logger.warn("Warning: Requests unable to complete an item search in Borrow Direct (response: #{response.code} #{response.body}")
            query_pending = false
            return nil
          end
        end
        # At this point, we should have all the records from the search
        return json_response['Record'][0]['Item']
    end

    # Given an array of record items returned from the BD search API, determine whether
    # the item can be requested from BD as a whole (from Cornell's perspective). For now,
    # that means that there are no Cornell items that are currently available.
    def requestable?(records)
      #Rails.logger.debug("mjc12test2: records array main #{records}")

      cornell_records = records.select { |rec| rec['CatalogName'] == 'CORNELL' }
      # If there are no records from the Cornell catalog, we can say it's requestable via BD
      # tlw72: this looks like it's not the case. I found an instance where the Cornell item was on order,
      # and the only other record, was a item that was checked out. That suggests it's possible to have
      # no Cornell records and no other records that are available. So commenting out the next line.
      # return true if cornell_records.empty?

      cornell_records.each do |rec|
        holdings = rec['Holding']

        # If any of the Cornell record holdings is marked Available, then it's not requestable via BD
        if holdings.present?
          return false if holdings.any? { |h| h['Availability'] == 'Available' }
        end
      end

      # If we've made it this far, it's requestable! tlw72: may not be true. See comment above.
      # Check the other records to see if any are available, and only return true if there is.
      non_cornell_records = records.select { |rec| rec['CatalogName'] != 'CORNELL' }
      non_cornell_records.each do |rec|
        holdings = rec['Holding']

        # If any of the record holdings is marked Available, then it's requestable via BD
        if holdings.present?
          return true if holdings.any? { |h| h['Availability'] == 'Available' }
        end
      end
      # If we get this far, nothing is available.
      return false
    end

    # Place an item request through the Borrow Direct API
    # :pickup_location is the BD location code (not CUL location code)
    # :notes are any notes on the request
    def request_from_bd(params)
      response = nil
      hash = {}
      hash["BibliographicInfo"] = {}
      hash["RequestFor"] = {}
      hash["ElectronicDelivery"] = {}
      hash["ElectronicDelivery"]["DeliveryMethod"] = "P"
      hash["ElectronicDelivery"]["DeliveryAddress"] = params[:library_id]
      hash["PartnershipId"] = "BD"
      hash["RequestFor"]["PatronId"] = @patron.barcode
      hash["RequestInfo"] = {"Notes" => params[:reqcomments]} if params[:reqcomments].present?

      if @work[:isbn].present?
        isbns = [*@work[:isbn]].map!{|i| i = i.clean_isbn}
        hash["BibliographicInfo"]["ISBN"] = isbns
      end

      if @work[:title].present?
        hash["BibliographicInfo"]["Title"] = @work[:title]
      end

      uri = URI.parse("#{@credentials[:base_url]}/portal-service/request/add?aid=#{@aid}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri, {'Content-Type' => 'application/json' })
      request.body = JSON.generate(hash)
      response = http.request(request)
       
      return response  # response should include the BD request tracking number

    end

  end # class

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
