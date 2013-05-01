require 'blacklight_cornell_requests/cornell'
require 'blacklight_cornell_requests/borrow_direct'

module BlacklightCornellRequests
  class Request
    # attr_accessible :title, :body
    include ActiveModel::Validations
    include Cornell::LDAP
    include BorrowDirect

    attr_accessor :bibid, :holdings_data
    validates_presence_of :bibid
    def save(validate = true)
      validate ? valid? : true
    end

    def save!
      save
    end

    ##################### Manipulate holdings data #####################

    # Retrieve holdings data from the Voyager service configured in the
    # environments file.
    # holdings_param = { :bibid => <bibid>, :type => retrieve|retrieve_detail_raw}
    def get_holdings(type = 'retrieve')

      return nil unless self.bibid

      response = JSON.parse(HTTPClient.get_content(Rails.configuration.voyager_holdings + "/holdings/#{type}/#{self.bibid}"))

      # return nil if there is no meaningful response (e.g., invalid bibid)
      return nil if response[self.bibid.to_s].nil?

      return response

    end

    def loan_type(type_code)

      return 'nocirc' if nocirc_loan? type_code
      return 'day'    if day_loan? type_code
      return 'minute' if minute_loan? type_code
      return 'regular'

    end

    # Check whether a loan type is a "day" loan
    def day_loan?(loan_code)
      [1, 5, 6, 7, 8, 10, 11, 13, 14, 15, 17, 18, 19, 20, 21, 23, 24, 25, 28, 33].include? loan_code
    end

    # Check whether a loan type is a "minute" loan
    def minute_loan?(loan_code)
      [12, 16, 22, 26, 27, 29, 30, 31, 32, 34, 35, 36, 37].include? loan_code
    end

    # Return an array of day loan types with a loan period of 1-2 days (that cannot use L2L)
    def self.no_l2l_day_loan_types
      [10, 17, 23, 24]
    end

    # Check whether a loan type is non-circulating
    def nocirc_loan?(loan_code)
      [9].include? loan_code
    end

    # Locate and translate the actual item status from the text string in the holdings data
    def item_status item_status
      if item_status.include? 'Not Charged'
        'Not Charged'
      elsif item_status =~ /^Charged/
        'Charged'
      elsif item_status =~ /Renewed/
        'Charged'
      elsif item_status.include? 'Requested'
        'Requested'
      elsif item_status.include? 'Missing'
        'Missing'
      elsif item_status.include? 'Lost'
        'Lost'
      else
      item_status
      end
    end

    ############  Return eligible delivery services for request #################
    def eligible_services

      return nil unless self.bibid

      'test'

    end
  end
end
