require 'dotenv'
require 'borrow_direct'

module BlacklightCornellRequests

  module CULBorrowDirect

    # Set parameters for the Borrow Direct API
    def configure_bd
      unless ENV['DISABLE_BORROW_DIRECT'].present?
        BorrowDirect::Defaults.api_key = ENV['BORROW_DIRECT_TEST_API_KEY']

        # Set api_base to the value specified in the .env file. possible values:
        # TEST - use default test URL
        # PRODUCTION - use default production URL
        # any other URL beginning with http - use that
        api_base = ''
        case ENV['BORROW_DIRECT_URL']
        when 'TEST'
          api_base = BorrowDirect::Defaults::TEST_API_BASE
        when 'PRODUCTION'
          api_base = BorrowDirect::Defaults::PRODUCTION_API_BASE
          BorrowDirect::Defaults.api_key = ENV['BORROW_DIRECT_PROD_API_KEY']
        when /^http/
          api_base = ENV['BORROW_DIRECT_URL']
        else
          api_base = BorrowDirect::Defaults::TEST_API_BASE
        end
        BorrowDirect::Defaults.api_base = api_base

        BorrowDirect::Defaults.library_symbol = 'CORNELL'
        BorrowDirect::Defaults.find_item_patron_barcode = patron_barcode(netid)
        BorrowDirect::Defaults.timeout = ENV['BORROW_DIRECT_TIMEOUT'].to_i || 30 # (seconds)
      end
    end

    # Determine Borrow Direct availability for an ISBN or title
    # params = { :isbn, :title }
    # ISBN is best, but title will work if ISBN isn't available.
    def available_in_bd? netid, params

      # Don't bother if BD has been disabled in .env
      return false if ENV['DISABLE_BORROW_DIRECT'].present?

      configure_bd

      response = nil
      # This block can throw timeout errors if BD takes to long to respond
      begin
        if !params[:isbn].nil?
          # Note: [*<variable>] gives us an array if we don't already have one,
          # which we need for the map.
          response = BorrowDirect::FindItem.new.find(:isbn => ([*params[:isbn]].map!{|i| i = i.clean_isbn}))
        elsif !params[:title].nil?
          response = BorrowDirect::FindItem.new.find(:phrase => params[:title])
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
    #
    # params should contain the following:
    #   :netid
    #   :pickup_location (code)
    #   :isbn
    def request_from_bd(params)
      response = nil
      # This block can throw timeout errors if BD takes to long to respond
      begin
        if params[:isbn].present?
          # Note: [*<variable>] gives us an array if we don't already have one,
          # which we need for the map.
          response = BorrowDirect::RequestItem.new(patron_barcode(params[:netid])).make_request(params[:pickup_location], {:isbn => [*params[:isbn]].map!{|i| i = i.clean_isbn}[0]}, params[:notes])
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

  end # module

end
