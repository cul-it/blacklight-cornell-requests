require 'dotenv'
require 'borrow_direct'
require 'rest-client'
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
    # make_request: this boolean is "true" when calling request_from_bd from the request controller
    # ISBN is best, but title will work if ISBN isn't available.
    def initialize(patron, work, make_request=false)
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

      @available = available_in_bd? if !make_request
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
    # returns the AID, or nil if there is an error.
    # NOTE: the AuthenticationID that is returned is based in part on User-Agent,
    # so mixing different request libraries (e.g., Net::HTTPD and RestClient) will
    # lead to non-obvious authentication failures unless the User-Agent is set to
    # be consistent!
    def authenticate
      url = "#{@credentials[:base_url]}/portal-service/user/authentication"
      body = {
        "LibrarySymbol" => COMMON[:symbol],
        'UserGroup' => COMMON[:group],
        'PartnershipId'=> COMMON[:partnership],
        'ApiKey' => @credentials[:api_key],
        'PatronId' => @patron.barcode
      }.to_json
      response = RestClient.post url, body, { content_type: :json }
      Rails.logger.debug("mjc12test2: authn response: #{response.code} #{response.body}")

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
    end

    # Use the Find Item BD API to execute a search. Returns the array of records provided in the response.
    def search_bd(query)
        # Use the Find Item API to determine availability. This API returns results asynchronously,
        # with additional results being updated each time we query the same URL. Unfortunately, we
        # have to keep querying the API until the entire result set is complete, then parse it ourselves
        # to determine whether an item is available locally.
        url = "#{@credentials[:base_url]}/di/search?query=#{query}&aid=#{@aid}"
        query_pending = true
        json_response = {}

        while query_pending
          begin
            response = RestClient.get url
            if (response.code.to_i == 200)
              # The ActiveCatalog parameter in the response indicates how many BD catalogs are being
              # actively searched. When the search is complete, this number should be 0.
              json_response = JSON.parse(response.body)
              query_pending = json_response['ActiveCatalog'] > 0
            else
              Rails.logger.warn("Warning: Requests unable to complete an item search in Borrow Direct (response: #{response.code} #{response.body}")
              query_pending = false
              return nil
            end
          # BD inexplicably returns a 404 if the search query isn't matched.
          rescue RestClient::NotFound => e
            query_pending = false
            return nil
          end
        end

        # At this point, we should have all the records from the search
        return json_response['Record'][0]['Item']
    end

    # Given an array of record items returned from the BD search API, use the requestability API
    # to determine whether any of them are available for Cornell users to request.
    def requestable?(records)
      #Rails.logger.debug("mjc12test2: records array main #{records}")

      # The requestability API is not well-documented, but it essentially needs a body that looks like
      # the following:
      #   {
      #     "Catalog": [
      #       "CatalogName": "YALE",
      #       "Holding": [
      #         { 'holding' object from search API results }
      #       ]
      #     ]
      #   }
      # So we need to provide a request body that contains each catalog for which there are holdings, and an
      # array of all the holdings.
      url = "#{@credentials[:base_url]}/dws/item/requestability?aid=#{@aid}"
      flattened_records = records.map do |rec|
        {
          "CatalogName" => rec['CatalogName'],
          "Holding" => rec['Holding']
        }
      end

      body = { "Catalog" => flattened_records }.to_json

      begin
        response = RestClient.post url, body, { content_type: :json }
        # Assuming a successful response, the 'FulfillmentType' property should have a value of either
        # CONSORTIUM -- which indicates it's available through BD -- or LOCAL or ILL, which indicate
        # not available from BD.
        return JSON.parse(response.body)['FulfillmentType'] == 'CONSORTIUM'
      rescue RestClient::ExceptionWithResponse => e
        Rails.logger.debug "mjc12test2: error: #{e.response}"
        return false
      end
    end

    # Place an item request through the Borrow Direct API
    # :pickup_location is the BD location code (not CUL location code)
    # :notes are any notes on the request
    def request_from_bd(params)
      response = nil
      # This block can throw timeout errors if BD takes to long to respond
      begin
        if params[:isbn].present?
          # Note: [*<variable>] gives us an array if we don't already have one,
          # which we need for the map.
          response = BorrowDirect::RequestItem.new(@patron.barcode).make_request(params[:pickup_location], {:isbn => [*params[:isbn]].map!{|i| i = i.clean_isbn}[0]}, params[:notes])
        end

        return response  # response should be the BD request tracking number

      rescue Errno::ECONNREFUSED => e
        #  ExceptionNotifier.notify_exception(e)
        Rails.logger.warn 'Requests: Borrow Direct connection was refused'
        Rails.logger.warn e.message
        Rails.logger.warn e.backtrace.inspect
        return false
      rescue BorrowDirect::HttpTimeoutError => e
        Rails.logger.warn 'Requests: Borrow Direct check timed out'
        Rails.logger.warn e.message
        Rails.logger.warn e.backtrace.inspect
        return false
      rescue BorrowDirect::Error => e
        Rails.logger.warn 'Requests: Borrow Direct gave error.'
        Rails.logger.warn e.message
        Rails.logger.warn e.backtrace.inspect
        Rails.logger.warn response.inspect
        return false
      end

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
