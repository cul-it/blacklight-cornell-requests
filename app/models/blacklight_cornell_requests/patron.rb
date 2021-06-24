require 'oci8'
require 'cul/folio/edge'

module BlacklightCornellRequests
  # @author Matt Connolly

  class Patron

    attr_reader :record, :netid # , :barcode, :group

    def initialize(netid)
      @netid = netid
      @record = get_folio_record
      # @barcode = get_barcode(netid)
      # @group = patron_group
    end

    def get_folio_record
      # Use the cul-folio-edge gem to retrieve a user's FOLIO record.
      url = ENV['OKAPI_URL']
      tenant = ENV['OKAPI_TENANT']
      token = CUL::FOLIO::Edge.authenticate(url, tenant, ENV['OKAPI_USER'], ENV['OKAPI_PW'])
     # Rails.logger.debug("mjc12test: Got FOLIO token #{token}")
     
     # TODO: add error handling
      account = CUL::FOLIO::Edge.patron_record(url, tenant, token[:token], @netid)[:user]
      #Rails.logger.debug "mjc12test: patron record for #{@netid}, #{url}, #{tenant}: #{account}"

      #Rails.logger.debug("mjc12test: Got FOLIO account #{account.inspect}")
      #render json: account
      account
    end

    def barcode

      @record['barcode']

      # uri = URI.parse(ENV['NETID_URL'] + "?netid=#{@netid}")
      # response = Net::HTTP.get_response(uri)

      # # Make sure that we got a real result. Unfortunately, the CGI doesn't
      # # return a nice error code
      # return nil if response.body.include? 'Software error'

      # # Return the barcode
      # JSON.parse(response.body)['bc']

    end

    def group
      @record['patronGroup']
      # connection = nil
      # begin
      #   connection = OCI8.new(ENV['ORACLE_RDONLY_PASSWORD'], ENV['ORACLE_RDONLY_PASSWORD'], "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=" + ENV['ORACLE_HOST'] + ")(PORT=1521))(CONNECT_DATA=(SID=" + ENV['ORACLE_SID'] + ")))")
      #   connection.exec("select patron_group_id from patron_barcode where patron_barcode.patron_barcode='#{@barcode}'") do |record|
      #     return record[0]
      #   end
      # rescue OCIError
      #   Rails.logger.debug "mjc12test: ERROR - #{$!}"
      #   return nil
      # end

    end

    def display_name
      personal_name = @record['personal']
      if personal_name.present?
        return [personal_name['firstName'], personal_name['lastName']].join(' ').strip
      else
        return ''
      end
    end

  end
end
