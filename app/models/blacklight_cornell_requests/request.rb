require 'blacklight_cornell_requests/cornell'
require 'blacklight_cornell_requests/borrow_direct'

module BlacklightCornellRequests
  class Request

    L2L = 'l2l'
    BD = 'bd'
    HOLD = 'hold'
    RECALL = 'recall'
    PURCHASE = 'purchase' # Note: this is a *purchase request*, which is different from a patron-driven acquisition
    PDA = 'pda'
    ILL = 'ill'
    ASK_CIRCULATION = 'circ'
    ASK_LIBRARIAN = 'ask'
    LIBRARY_ANNEX = 'Library Annex'
    HOLD_PADDING_TIME = 3

    # attr_accessible :title, :body
    include ActiveModel::Validations
    include Cornell::LDAP
    include BorrowDirect

    attr_accessor :bibid, :holdings_data, :service, :document, :request_options, :netid
    validates_presence_of :bibid
    def save(validate = true)
      validate ? valid? : true
    end

    def initialize(bibid)
      self.bibid = bibid
    end

    def save!
      save
    end

    def get_hold_padding
      HOLD_PADDING_TIME
    end

    ##################### Calculate optimum request method ##################### 
    def magic_request

      request_options = []
      service = 'ask'
      document = nil

      if self.bibid.nil?
        self.request_options = request_options
        self.service = service
        self.document = document
        return
      end

      # Get holdings
      get_holdings 'retrieve_detail_raw' unless self.holdings_data
       puts self.holdings_data

      # Get item status and location for each item in each holdings record; store in all_items
      all_items = []
      item_status = 'Charged'
      holdings = self.holdings_data[self.bibid.to_s]['records']
      holdings.each do |h|
        items = h['item_status']['itemdata']
        items.each do |i|
          status = item_status i['itemStatus']
          all_items.push({ :id => i['itemid'], 
                           :status => status, 
                           'location' => i[:location]
                         })
        end
      end

      # Iterate through all items and get list of delivery methods
      all_items.each do |item|
        services = get_delivery_options item
        item[:services] = services
      end

      # TODO: Do something useful with sorted items

      puts "all items: #{all_items.inspect}"

      best_choice = all_items.pop
      self.request_options = all_items
      self.service = best_choice
      self.document = document

    end   

    ##################### Manipulate holdings data #####################

    # Set holdings data from the Voyager service configured in the
    # environments file.
    # holdings_param = { :bibid => <bibid>, :type => retrieve|retrieve_detail_raw}
    def get_holdings(type = 'retrieve')

      return nil unless self.bibid

      response = JSON.parse(HTTPClient.get_content(Rails.configuration.voyager_holdings + "/holdings/#{type}/#{self.bibid}"))

      # return nil if there is no meaningful response (e.g., invalid bibid)
      return nil if response[self.bibid.to_s].nil?

      self.holdings_data = response

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
    def delivery_services
      [L2L, BD, HOLD, RECALL, PURCHASE, PDA, ILL, ASK_LIBRARIAN, ASK_CIRCULATION]
    end

    # Main entry point for determining which delivery services are available for a given item
    # Returns an array of hashes with the following structure:
    # { :service => SERVICE NAME, :estimate => ESTIMATED DELIVERY TIME }
    # The array is sorted by delivery time estimate, so the first array item should be 
    # the fastest (i.e., the "best") delivery option.
    def get_delivery_options item

      patron_type = get_patron_type self.netid

      if patron_type == 'cornell'
        options = get_cornell_delivery_options item
      else
        options = get_guest_delivery_options item
      end

      # Get delivery time estimates for each option
      options.each do |option|
        option[:estimate] = get_delivery_time(option[:service], option)
      end

      return sort_request_options options

    end

    # Determine delivery options for a single item if the patron is a Cornell affiliate
    def get_cornell_delivery_options item

      item_loan_type = loan_type item['typeCode']
      # print "item: #{item.inspect}"
      # print "type: #{item_loan_type}"

      request_options = []
      if item_loan_type == 'regular' and item[:status] == 'Not Charged'

        service = 'l2l'
        request_options = [ {:service => service, 'location' => item[:location] } ]

      elsif ((item_loan_type == 'regular' and item[:status] == 'Charged') or
             (item_loan_type == 'regular' and item[:status] == 'Requested'))
        # TODO: Test and fix BD check with real params
        params = {}
        if borrowDirect_available? params
          request_options.push( {:service => 'bd', 'location' => item[:location] } )
        end
        request_options.push({:service => 'ill', 'location' => item[:location]}, 
                             {:service => 'recall','location' => item[:location]},
                             {:service => 'hold', 'location' => item[:location]})

      elsif ((item_loan_type == 'regular' and item[:status] == 'Missing') or
             (item_loan_type == 'regular' and item[:status] == 'Lost'))

         # TODO: Test and fix BD check with real params
        params = {}
        if borrowDirect_available? params
          request_options.push( {:service => 'bd', 'location' => item[:location] } )
        end
        request_options.push({:service => 'purchase', 'location' => item[:location]}, 
                             {:service => 'ill','location' => item[:location]})   

      elsif ((item_loan_type == 'day' and item[:status] == 'Charged') or
             (item_loan_type == 'day' and item[:status] == 'Requested'))

         # TODO: Test and fix BD check with real params
        params = {}
        if borrowDirect_available? params
          request_options.push( {:service => 'bd', 'location' => item[:location] } )
        end
        request_options.push( {:service => 'ill', 'location' => item[:location] } )       
        request_options.push( {:service => 'hold', 'location' => item[:location] } )

      elsif (item_loan_type == 'day' and item[:status] == 'Not Charged')

        unless Request.no_l2l_day_loan_types.include? item['typeCode']
          request_options.push( {:service => 'l2l', 'location' => item[:location] } )
        end

      elsif ((item_loan_type == 'minute' and item[:status] == 'Charged') or
             (item_loan_type == 'minute' and item[:status] == 'Not Charged') or
             (item_loan_type == 'minute' and item[:status] == 'Requested'))

        # TODO: Test and fix BD check with real params
        params = {}
        if borrowDirect_available? params
          request_options.push( {:service => 'bd', 'location' => item[:location] } )
        end        
        request_options.push( {:service => 'circ', 'location' => item[:location] } )


      end

      return request_options
    end

    # Determine delivery options for a single item if the patron is a guest (non-Cornell)
    def get_guest_delivery_options item
      [{:service => 'ask', 'location' => 'Mann'}]
    end

    # Custom sort method: sort by delivery time estimate from a hash
    def sort_request_options request_options
      return request_options.sort_by { |option| option[:estimate] }
    end

    def get_delivery_time service, item_data

      case service 

        when 'l2l'
          if item_data['location'] == LIBRARY_ANNEX
            1
          else
            2
          end

        when 'bd'
          6
        when 'ill'
          14

        when 'hold'
          ## if it got to this point, it means it is not available and should have Due on xxxx-xx-xx
          dueDate = /.*Due on (\d\d\d\d-\d\d-\d\d)/.match(item_data['itemStatus'])
          if ! dueDate.nil?
            estimate = (Date.parse(dueDate[1]) - Date.today).to_i
            if (estimate < 0)
              ## this item is overdue
              ## use default value instead
              return 180
            end
            ## pad for extra days for processing time?
            ## also padding would allow l2l to be always first option
            return estimate.to_i + get_hold_padding
          else
            ## due date not found... use default
            return 180
          end

        when 'recall'
          30
        when 'pda'
          5
        when 'purchase'
          10
        when 'ask'
          9999
        when 'circ'
          9998
        else
          9999
      end

    end


  end

end
