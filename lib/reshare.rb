# frozen-string-literal: true

# Interface to Project ReShare APIs
# APIs are documented here: https://3.basecamp.com/5319802/buckets/26606684/documents/5132521312
#
# NOTE: After implementing the availability check and API requesting, we decided to use the ILLiad-to-ReShare
# workflow instead of direct-to-ReShare. That means that we won't be distinguishing between BD and ILL on the
# UI side of things; instead, all requests that match our defined criteria for fulfillment via BD *or* ILL
# will be routed into a single form -- basically the old ILL form. Whether the request gets resolved through BD
# or ILL will be up to ReShare (and our staff) to decide.
module Reshare
  require 'rest-client'

  def bd_requestable_id(isn)
    records = _search_by_isn(isn)
    records.each do |r|
      return r['id'] if r['lendingStatus'].include?('LOANABLE')
    end
  end

  def _search_by_isn(isn)
    # TODO: guard against missing RESHARE_URL value and missing isn
    url = "#{ENV['RESHARE_SEARCH_URL']}?type=ISN&lookfor=#{isn}&field[]=id&field[]=lendingStatus"
    response = RestClient.get(url)
    # TODO: check that response is in the proper form and there are no returned errors
    JSON.parse(response)['records']
  rescue RestClient::Exception
    # TODO: Provide proper log message here
    {}
  end

  # Use the ReShare APIs to place a Borrow Direct request. Return the created request's ID if successful, :error otherwise.
  def request_from_reshare(patron:, item:, pickup_location:, note:)
    url = "#{ENV['RESHARE_REQUEST_URL']}?svc_id=json&req_id=#{patron}&rft_id=#{item}&svc.pickupLocation=#{pickup_location}&res.org=ISIL%3AUS-NIC"
    url += "&svc.note=" + note.to_s.html_safe if note.present?

    response = RestClient.get(url)
    parsed_response = JSON.parse(response.body)
    message = JSON.parse(parsed_response['message'])
    return message['id'] if parsed_response['status'] == 201

    return :error

  rescue RestClient::Exception
    Rails.logger.warn "Requests: Got a RestClient error when trying to make a ReShare request."
    return :error
  rescue TypeError
    Rails.logger.warn "Requests: Couldn't parse JSON response from ReShare request (#{response})."
    return :error
  end
end
