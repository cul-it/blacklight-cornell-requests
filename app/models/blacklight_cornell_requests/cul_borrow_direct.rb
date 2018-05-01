require 'dotenv'
require 'borrow_direct'

module BlacklightCornellRequests

  class CULBorrowDirect

    attr_reader :mode, :patron, :work, :available

    # patron should be a Patron instance
    # work = { :isbn, :title }
    # ISBN is best, but title will work if ISBN isn't available.
    def initialize(patron, work)
      @patron = patron
      @work = work

      # Set parameters for the Borrow Direct API
      BorrowDirect::Defaults.library_symbol = 'CORNELL'
      BorrowDirect::Defaults.find_item_patron_barcode = @patron.barcode
      BorrowDirect::Defaults.timeout = ENV['BORROW_DIRECT_TIMEOUT'].to_i || 30 # (seconds)

      # Set api_base to the value specified in the .env file. possible values:
      # TEST - use default test URL
      # PRODUCTION - use default production URL
      # any other URL beginning with http - use that
      set_mode ENV['BORROW_DIRECT_URL']

      @available = available_in_bd?
    end

    # Switch between test and production configuration
    def set_mode mode
      BorrowDirect::Defaults.api_key = ENV['BORROW_DIRECT_TEST_API_KEY']
      @mode = 'TEST'
      api_base = ''

      case mode
      when 'TEST'
        api_base = BorrowDirect::Defaults::TEST_API_BASE
      when 'PRODUCTION'
        api_base = BorrowDirect::Defaults::PRODUCTION_API_BASE
        BorrowDirect::Defaults.api_key = ENV['BORROW_DIRECT_PROD_API_KEY']
        @mode = 'PRODUCTION'
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
      end

      BorrowDirect::Defaults.api_base = api_base
    end

    # Determine Borrow Direct availability for an ISBN or title
    def available_in_bd?

      # Don't bother if BD has been disabled in .env
      return false if ENV['DISABLE_BORROW_DIRECT'].present?

      set_mode(ENV['BORROW_DIRECT_URL']) unless @mode.present?

      response = nil
      # This block can throw timeout errors if BD takes to long to respond
      begin
        if @work.isbn.present?
          # Note: [*<variable>] gives us an array if we don't already have one,
          # which we need for the map.
          response = BorrowDirect::FindItem.new.find(:isbn => ([*@work.isbn].map!{|i| i = i.clean_isbn}))
        elsif params[:title].present?
          response = BorrowDirect::FindItem.new.find(:phrase => @work.title)
        end

        #Rails.logger.debug "mjc12test :#{__FILE__}:#{__LINE__} response from bd ."+ response.inspect
        return response.requestable?

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

    # Place an item request through the Borrow Direct API
    # :pickup_location is the BD location code (not CUL location code)
    # :notes are any notes on the request
    def request_from_bd(params)
      response = nil
      # This block can throw timeout errors if BD takes to long to respond
      begin
        if @work.isbn.present?
          # Note: [*<variable>] gives us an array if we don't already have one,
          # which we need for the map.
          response = BorrowDirect::RequestItem.new(@patron.barcode).make_request(params[:pickup_location], {:isbn => [*@work.isbn.map!{|i| i = i.clean_isbn}[0]]}, params[:notes])
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

end
