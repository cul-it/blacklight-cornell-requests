# frozen-string-literal: true

# Interface to Project ReShare APIs
# APIs are documented here: https://3.basecamp.com/5319802/buckets/26606684/documents/5132521312
module Reshare
  require 'rest-client'

  def borrow_direct_requestable?(isn)
    records = _search_by_isn(isn)
    Rails.logger.debug "mjc12a: got records #{records}"
    records.any? { |r| r['lendingStatus'].include?('LOANABLE') }
  end

  def _search_by_isn(isn)
    # TODO: guard against missing RESHARE_URL value and missing isn
    url = "#{ENV['RESHARE_URL']}?type=ISN&lookfor=#{isn}&field[]=id&field[]=lendingStatus"
    response = RestClient.get(url)
    # TODO: check that response is in the proper form and there are no returned errors
    JSON.parse(response)['records']
  rescue RestClient::Exception
    # TODO: Provide proper log message here
    Rails.logger.warn("Warning: Unable to retrieve FOD/remote program eligibility data (from #{uri})")
    {}
  end
end
