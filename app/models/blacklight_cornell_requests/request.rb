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

    attr_accessor :bibid, :holdings_data, :service, :document, :request_options, :alternate_options
    attr_accessor :au, :ti, :isbn, :document, :ill_link, :pub_info, :netid, :estimate, :items, :volumes
    attr_accessor :L2L, :BD, :HOLD, :RECALL, :PURCHASE, :PDA, :ILL, :ASK_CIRCULATION, :ASK_LIBRARIAN
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
    def magic_request(document, env_http_host, options = {})

      target = options[:target]
      volume = options[:volume]
      request_options = []
      alternate_options = []
      service = ASK_LIBRARIAN

      if self.bibid.nil?
        self.request_options = request_options
        self.service = { :service => service }
        self.document = document
        return
      end

      # Get holdings
      get_holdings 'retrieve_detail_raw' unless self.holdings_data

      # Get item status and location for each item in each holdings record; store in all_items
      all_items = []
      item_status = 'Charged'
      holdings = self.holdings_data[self.bibid.to_s]['records']
      holdings.each do |h|
        items = h['item_status']['itemdata']
        items.each do |i|
          # If volume is specified, only populate items with matching enum/chron/year values
          next if (!volume.blank? and ( volume != i['enumeration'] and volume != i['chron'] and volume != i['year']))

          status = item_status i['itemStatus']
          iid = deep_copy(i)
          all_items.push({ :id => i['itemid'], 
                           :status => status, 
                           'location' => i[:location],
                           :typeCode => i['typeCode'],
                           :enumeration => i['enumeration'],
                           :chron => i['chron'],
                           :year => i['year'],
                           :iid => iid
                         })
        end
      end

      self.items = all_items
      self.document = document

      unless document.nil?

        # Iterate through all items and get list of delivery methods
        bd_params = { :isbn => document[:isbn_display], :title => document[:title_display], :env_http_host => env_http_host }
        all_items.each do |item|
          services = get_delivery_options item, bd_params
          item[:services] = services
        end
        populate_document_values

        # Determine whether this is a multi-volume thing or not (i.e, multi-copy)
        # They will be handled differently depending
        if self.document[:multivol_b] and volume.blank?

          # Multi-volume
          volumes = {}
          all_items.each do |item|
            volumes[item[:enumeration]] = 1 unless item[:enumeration].blank? 
            volumes[item[:chron]] = 1 unless item[:chron].blank?
            volumes[item[:year]] = 1 unless item[:year].blank?
          end

          self.volumes = sort_volumes(volumes.keys)

        else

          # Multi-copy
          all_items.each do |item|
            request_options.push *item[:services]
          end
          request_options = sort_request_options request_options
        
        end

      end
  
      if !target.blank?
        self.service = target
      elsif request_options.present?
        self.service = request_options[0][:service]
      else
        self.service = ASK_LIBRARIAN
      end

      request_options.push ({:service => ASK_LIBRARIAN, :estimate => get_delivery_time(ASK_LIBRARIAN, nil)})
      populate_options self.service, request_options unless self.service == ASK_LIBRARIAN
      
      self.document = document
      
    end   
    
    def populate_options target, request_options
      self.alternate_options = []
      self.request_options = []
      seen = {}
      request_options.each do |option|
        if option[:service] == target
          self.estimate = option[:estimate] if self.estimate.blank?
          self.request_options.push option
        else
          if seen[option[:service]].blank?
            self.alternate_options.push option
            seen[option[:service]] = 1
          end
        end
      end
    end

    # Sort volumes in their logical order for display.
    # Volume strings typically look like 'v.1', 'v21-22', 'index v.1-10', etc.
    def sort_volumes(volumes)

      volumes = volumes.sort_by do |v|

        if v.is_a? Integer
          [Integer(v)]
        else
          a, b, c = v.split(/[\.\-,]/) 
          b = b.gsub(/[^0-9]/,'') unless b.nil?
          if b.blank? or b !~ /\d+/
            [a]
          else
            [a, Integer(b)] # Note: This forces whatever is left into an integer!
          end
        end
      end

      volumes

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
      [1, 5, 6, 7, 8, 10, 11, 13, 14, 15, 17, 18, 19, 20, 21, 23, 24, 25, 28, 33].include? loan_code.to_i
    end

    # Check whether a loan type is a "minute" loan
    def minute_loan?(loan_code)
      [12, 16, 22, 26, 27, 29, 30, 31, 32, 34, 35, 36, 37].include? loan_code.to_i
    end

    # Return an array of day loan types with a loan period of 1-2 days (that cannot use L2L)
    def self.no_l2l_day_loan_types
      [10, 17, 23, 24]
    end
    
    def no_l2l_day_loan_types?(loan_code)
      [10, 17, 23, 24].include? loan_code.to_i
    end

    # Check whether a loan type is non-circulating
    def nocirc_loan?(loan_code)
      [9].include? loan_code.to_i
    end

    # Locate and translate the actual item status from the text string in the holdings data
    def item_status item_status
      if item_status.include? 'Not Charged'
        'Not Charged'
      elsif item_status =~ /Charged/
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
    def get_delivery_options item, bd_params = {}

      patron_type = get_patron_type self.netid
      # Rails.logger.info "sk274_debug: " + "#{self.netid}, #{patron_type}"

      if patron_type == 'cornell'
        # Rails.logger.info "sk274_debug: get cornell options"
        options = get_cornell_delivery_options item, bd_params
      else
        # Rails.logger.info "sk274_debug: get guest options"
        options = get_guest_delivery_options item
      end

      # Get delivery time estimates for each option
      options.each do |option|
        option[:estimate] = get_delivery_time(option[:service], option)
        option[:iid] = item[:iid]
      end

      #return sort_request_options options
      return options

    end

    # Determine delivery options for a single item if the patron is a Cornell affiliate
    def get_cornell_delivery_options item, params

      item_loan_type = loan_type item[:typeCode]

      request_options = []
      if item_loan_type == 'nocirc'
        # if borrowDirect_available? bdParams
          # request_options.push({ :service => BD, :iid => [], :estimate => get_bd_delivery_time })
          # if target.blank?
            # target = BD
          # end
        # end
        # request_options.push({ :service => ILL, :iid => [], :estimate => get_ill_delivery_time })
        if borrowDirect_available? params
          request_options.push( {:service => BD, 'location' => item[:location] } )
        end
        request_options.push({:service => ILL, 'location' => item[:location]})
      elsif item_loan_type == 'regular' and item[:status] == 'Not Charged'

        request_options.push({:service => L2L, 'location' => item[:location] } )

      elsif ((item_loan_type == 'regular' and item[:status] == 'Charged') or
             (item_loan_type == 'regular' and item[:status] == 'Requested'))
        # TODO: Test and fix BD check with real params
        if borrowDirect_available? params
          request_options.push( {:service => BD, 'location' => item[:location] } )
        end
        request_options.push({:service => ILL, 'location' => item[:location]}, 
                             {:service => RECALL,'location' => item[:location]},
                             {:service => HOLD, 'location' => item[:location]})

      elsif ((item_loan_type == 'regular' and item[:status] == 'Missing') or
             (item_loan_type == 'regular' and item[:status] == 'Lost'))

         # TODO: Test and fix BD check with real params
        if borrowDirect_available? params
          request_options.push( {:service => BD, 'location' => item[:location] } )
        end
        request_options.push({:service => PURCHASE, 'location' => item[:location]}, 
                             {:service => ILL,'location' => item[:location]})   

      elsif ((item_loan_type == 'day' and item[:status] == 'Charged') or
             (item_loan_type == 'day' and item[:status] == 'Requested'))

         # TODO: Test and fix BD check with real params
        if borrowDirect_available? params
          request_options.push( {:service => BD, 'location' => item[:location] } )
        end
        request_options.push( {:service => ILL, 'location' => item[:location] } )       
        request_options.push( {:service => HOLD, 'location' => item[:location] } )

      elsif (item_loan_type == 'day' and item[:status] == 'Not Charged')

        unless Request.no_l2l_day_loan_types.include? item[:typeCode]
          request_options.push( {:service => L2L, 'location' => item[:location] } )
        end

      elsif item_loan_type == 'minute'

        # TODO: Test and fix BD check with real params
        if borrowDirect_available? params
          request_options.push( {:service => BD, 'location' => item[:location] } )
        end        
        request_options.push( {:service => ASK_CIRCULATION, 'location' => item[:location] } )

      end

      return request_options
    end

    # Determine delivery options for a single item if the patron is a guest (non-Cornell)
    def get_guest_delivery_options item
      item_loan_type = loan_type item[:typeCode]
      request_options = []

      if item_loan_type == 'nocirc'
        # do nothing
      elsif item_loan_type == 'regular' and item[:status] == 'Not Charged'
        request_options = [ { :service => L2L, 'location' => item[:location] } ] unless no_l2l_day_loan_types? item_loan_type
      elsif item_loan_type == 'regular' and item[:status] == 'Charged'
        request_options = [ { :service => HOLD, 'location' => item[:location] } ]
      elsif item_loan_type == 'regular' and item[:status] == 'Requested'
        request_options = [ { :service => HOLD, 'location' => item[:location] } ]
      elsif item_loan_type == 'regular' and item[:status] == 'Missing'
        ## do nothing
      elsif item_loan_type == 'regular' and item[:status] == 'Lost'
        ## do nothing
      elsif item_loan_type == 'day' and item[:status] == 'Not Charged'
        request_options = [ { :service => L2L, 'location' => item[:location] } ] unless no_l2l_day_loan_types? item_loan_type
      elsif item_loan_type == 'day' and item[:status] == 'Charged'
        request_options = [ { :service => HOLD, 'location' => item[:location] } ]
      elsif item_loan_type == 'day' and item[:status] == 'Requested'
        request_options = [ { :service => HOLD, 'location' => item[:location] } ]
      elsif item_loan_type == 'day' and item[:status] == 'Missing'
        ## do nothing
      elsif item_loan_type == 'day' and item[:status] == 'Lost'
        ## do nothing
      elsif item_loan_type == 'minute' and item[:status] == 'Not Charged'
        request_options = [ { :service => ASK_CIRCULATION, 'location' => item[:location] } ]
      elsif item_loan_type == 'minute' and item[:status] == 'Charged'
        request_options = [ { :service => ASK_CIRCULATION, 'location' => item[:location] } ]
      elsif item_loan_type == 'minute' and item[:status] == 'Requested'
        request_options = [ { :service => ASK_CIRCULATION, 'location' => item[:location] } ]
      elsif item_loan_type == 'minute' and item[:status] == 'Missing'
        ## do nothing
      elsif item_loan_type == 'minute' and item[:status] == 'Lost'
        ## do nothing
      end

      return request_options
    end

    # Custom sort method: sort by delivery time estimate from a hash
    def sort_request_options request_options
      return request_options.sort_by { |option| option[:estimate] }
    end

    def get_delivery_time service, item_data

      case service 

        when L2L
          if item_data['location'] == LIBRARY_ANNEX
            1
          else
            2
          end

        when BD
          6
        when ILL
          14

        when HOLD
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

        when RECALL
          30
        when PDA
          5
        when PURCHASE
          10
        when ASK_LIBRARIAN
          9999
        when ASK_CIRCULATION
          9998
        else
          9999
      end

    end
    
    def populate_document_values
      unless self.document.nil?
        self.isbn = self.document[:isbn_display]
        self.ti = self.document[:title_display]
        if !self.document[:author_display].blank?
          self.au = self.document[:author_display].split('|')[0]
        elsif !self.document[:author_addl_display].blank?
          self.au = self.document[:author_addl_display].map { |author| author.split('|')[0] }.join(', ')
        else
          self.au = ''
        end
        create_ill_link
      end
    end
    
    def create_ill_link
      document = self.document
      ill_link = '***REMOVED***?Action=10&Form=30&url_ver=Z39.88-2004&rfr_id=info%3Asid%2Flibrary.cornell.edu'
      if self.isbn.present?
        isbns = self.isbn.join(',')
        ill_link = ill_link + "&rft.isbn=#{isbns}"
        ill_link = ill_link + "&rft_id=urn%3AISBN%3A#{isbns}"
      end
      if !self.ti.blank?
        ill_link = ill_link + "&rft.btitle=#{CGI.escape(self.ti)}"
      end
      if !document[:author_display].blank?
        ill_link = ill_link + "&rft.aulast=#{document[:author_display]}"
      end
      if document[:pub_info_display].present?
        pub_info_display = document[:pub_info_display][0]
        self.pub_info = pub_info_display
        ill_link = ill_link + "&rft.place=#{pub_info_display}"
        ill_link = ill_link + "&rft.pub=#{pub_info_display}"
        ill_link = ill_link + "&rft.date=#{pub_info_display}"
      end
      if !document[:format].blank?
        ill_link = ill_link + "&rft.genre=#{document[:format][0]}"
      end
      if document[:lc_callnum_display].present?
        ill_link = ill_link + "&rft.identifier=#{document[:lc_callnum_display][0]}"
      end
      self.ill_link = ill_link
    end
    
    def deep_copy(o)
      Marshal.load(Marshal.dump(o))
    end
    
    ###################### Make Voyager requests ################################

    # Handle a request for a Voyager action
    # action: callslip|hold|recall
    # params: { :holding_id (actually item id), :request_action, :library_id, 'latest-date', :reqcomments }
    # Returns a status to be 'flashed' to the user
    def make_voyager_request params

      # Need bibid, netid, itemid to proceed
      if self.bibid.nil?
        return { :error => I18n.t('requests.errors.bibid.blank') }
      elsif netid.nil? 
        return { :error => I18n.t('requests.errors.email.blank') }
      elsif params[:holding_id].nil?
        #return { :error => I18n.t('requests.errors.holding_id.blank') }
        return { :error => 'test' }
      end

      # Set up Voyager request URL string
      voyager_request_handler_url = Rails.configuration.voyager_request_handler_host
      voyager_request_handler_url ||= request.env['HTTP_HOST']
      unless voyager_request_handler_url.starts_with?('http')
        voyager_request_handler_url = "http://#{voyager_request_handler_url}"
      end
      unless Rails.configuration.voyager_request_handler_port.blank?
        voyager_request_handler_url += ":" + Rails.configuration.voyager_request_handler_port.to_s
      end

      # Assemble complete request URL
      voyager_request_handler_url += "/holdings/#{params[:request_action]}/#{self.netid}/#{self.bibid}/#{params[:library_id]}"
      unless params[:holding_id].nil?
        voyager_request_handler_url += "/#{params[:holding_id]}" # holding_id is actually item id!
      end

      Rails.logger.info "mjc12test: fired #{voyager_request_handler_url}"


      # Send the request
      # puts voyager_request_handler_url
      body = { 'reqnna' => params['latest-date'], 'reqcomments' => params[:reqcomments] }
      result = HTTPClient.post(voyager_request_handler_url, body)
      response = JSON.parse(result.content)

      if response['status'] == 'failed'
        return { :failure => I18n.t('requests.failure') }
      else
        return { :success => I18n.t('requests.success') }
      end

    end

  end

end
