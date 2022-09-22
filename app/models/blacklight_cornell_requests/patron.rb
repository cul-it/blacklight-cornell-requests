# frozen-string-literal: true

require 'cul/folio/edge'
require 'rest-client'
require 'json'

module BlacklightCornellRequests
  # @author Matt Connolly

  class Patron
    attr_reader :record, :netid, :preferred_service_point # , :barcode, :group

    def initialize(netid)
      @netid = netid
      @record = get_folio_record
      # @barcode = get_barcode(netid)
      # @group = patron_group
      @preferred_service_point = get_service_point
      @record['preferred_service_point'] = @preferred_service_point
    end

    def get_folio_record
      # Use the cul-folio-edge gem to retrieve a user's FOLIO record.
      url = ENV['OKAPI_URL']
      tenant = ENV['OKAPI_TENANT']
      @token = CUL::FOLIO::Edge.authenticate(url, tenant, ENV['OKAPI_USER'], ENV['OKAPI_PW'])
      # Rails.logger.debug("mjc12test: Got FOLIO token #{token}")

      # TODO: add error handling
      CUL::FOLIO::Edge.patron_record(url, tenant, @token[:token], @netid)[:user]
      # Rails.logger.debug "mjc12test: patron record for #{@netid}, #{url}, #{tenant}: #{account}"

      # Rails.logger.debug("mjc12test: Got FOLIO account #{account.inspect}")
      # render json: account
      # account
    end

    # Use the FOLIO /service-points-users API to retrieve the patron's default service point ID,
    # if any
    def get_service_point
      url = "#{ENV['OKAPI_URL']}/service-points-users?query=userId==#{@record['id']}"
      Rails.logger.debug "mjc12test2: Using URL #{url}"
      headers = {
        'X-Okapi-Tenant' => ENV['OKAPI_TENANT'],
        'x-okapi-token' => @token[:token],
        :accept => 'application/json',
      }

      begin
        response = RestClient.get(url, headers)
        Rails.logger.debug "mjc12test: got PSP response #{JSON.parse(response.body)}"
        JSON.parse(response.body).dig('servicePointsUsers', 0, 'defaultServicePointId')
      rescue RestClient::ExceptionWithResponse => e
        Rails.logger.debug "mjc12test: error #{e.response.code}"
        Rails.logger.debug "mjc12test: error #{e.response.body}"
        nil
      end
    end

    def barcode
      @record && @record['barcode']

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
        [personal_name['firstName'], personal_name['lastName']].join(' ').strip
      else
        ''
      end
    end
  end
end
