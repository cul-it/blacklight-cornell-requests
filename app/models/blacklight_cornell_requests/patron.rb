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
    end

    def group
      @record['patronGroup']
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
