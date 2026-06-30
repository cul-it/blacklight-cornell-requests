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
      @preferred_service_point = get_service_point
    end

    def get_folio_record
      # Use the cul-folio-edge gem to retrieve a user's FOLIO record.
      url = ENV['OKAPI_URL']
      tenant = ENV['OKAPI_TENANT']
      @token = CUL::FOLIO::Edge.authenticate(url, tenant, ENV['OKAPI_USER'], ENV['OKAPI_PW'])

      response = CUL::FOLIO::Edge.patron_record(url, tenant, @token[:token], 'zvbxrpl')
      user_record = response && response[:user]
      unless user_record
        Rails.logger.warn "Requests: No FOLIO patron record found for netid #{@netid}"
        return nil
      end

      user_record
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error "Requests: Failed to retrieve FOLIO patron record for netid #{@netid} (#{e.response&.code})"
      nil
    rescue StandardError => e
      Rails.logger.error "Requests: Unexpected error retrieving FOLIO patron record for netid #{@netid} (#{e.class}: #{e.message})"
      nil
    end

    # Use the FOLIO /service-points-users API to retrieve the patron's default service point ID,
    # if any
    def get_service_point
      return nil unless @record
      url = "#{ENV['OKAPI_URL']}/service-points-users?query=userId==#{@record['id']}"

      headers = {
        'X-Okapi-Tenant' => ENV['OKAPI_TENANT'],
        'x-okapi-token' => @token[:token],
        :accept => 'application/json',
      }

      response = RestClient.get(url, headers)
      JSON.parse(response.body).dig('servicePointsUsers', 0, 'defaultServicePointId')
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.debug "mjc12test: error #{e.response.code}"
      Rails.logger.debug "mjc12test: error #{e.response.body}"
      nil
    end

    def barcode
      @record && @record['barcode']
    end

    def group
      @record && @record['patronGroup']
    end

    def display_name
      personal_name = @record && @record['personal']
      if personal_name
        [personal_name['firstName'], personal_name['lastName']].join(' ').strip
      else
        ''
      end
    end
  end
end
