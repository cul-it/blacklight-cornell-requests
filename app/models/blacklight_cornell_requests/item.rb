module BlacklightCornellRequests
  # @author Matt Connolly

  class Item

    attr_reader :id, :holding_id, :location, :type, :status, :circ_group
    attr_reader :copy_number, :call_number

    # Basic initializer
    #
    # @param holding_id [int] The ID of the holding record this item is linked to
    # @param item_data [hash] A JSON object containing data for a single item record
    # @param holdings_data [hash] A JSON object containing data for a single holdings record
    def initialize(holding_id, item_data, holdings_data = nil)
      return nil if (holding_id.nil? || item_data.nil?)

      @holding_id = holding_id
      @id = item_data['id']
      # @location is the actual current location of the item; Solr index
      # combines the permanent location and temporary location fields so we
      # don't have to worry about it
      @location = item_data['location']
      @type = item_data['type']
      @chron = item_data['chron']
      @enum = item_data['enum']
      @year = item_data['year']
      @status = item_data['status']
      @circ_group = item_data['circGrp'].keys[0].to_i
      @onReserve = item_data['onReserve']
      @copy_number = item_data['copy']
      if holdings_data.present?
        @call_number = holdings_data[holding_id]['call']
      end
    end

    # Enumeration is the single-string concatenation of three fields
    # from the item record: chron, enum, and year
    def enumeration
      [@enum, @chron, @year].compact.join(' - ')
    end

    def inspect
      puts "Item record #{@id} (linked to holding record #{@holding_id}):"
      puts "Type: #{@type.inspect}"
      puts "Status: #{@status.inspect}"
      puts "Location: #{@location.inspect}"
      puts "Enumeration: " + enumeration
      puts "enum components: chron: #{@chron}, enum: #{@enum}, year: #{@year}"
      puts "Copy: #{@copy_number}"
      puts "Circ group: #{@circ_group}"
      puts "Call number: #{@call_number}"
    end

    def statusCode
      @status['code'].keys[0].to_i
    end

    def available?
      @status['available']
    end

    def onReserve?
      !!@onReserve
    end

    # There is a specific nocirc loan typecode (9), but there could also be
    # a note in the holdings record that the item doesn't circulate (even
    # with a different typecode)
    def noncirculating?
      @type['id'] == 9 || onReserve? || @location['name'].include?('Non-Circulating')
    end

    # TODO: is there a better way of determining these straight from the Voyager DB?
    def loan_type

      return 'nocirc' if nocirc_loan?
      return 'day'    if day_loan?
      return 'minute' if minute_loan?
      return 'regular'

    end

    # Check whether a loan type is a "day" loan
    def day_loan?
      [1, 5, 6, 7, 8, 10, 11, 13, 14, 15, 17, 18, 19, 20, 21, 23, 24, 25, 28, 33].include? @type['id']
    end

    # Check whether a loan type is a "minute" loan
    def minute_loan?
      [12, 16, 22, 26, 27, 29, 30, 31, 32, 34, 35, 36, 37].include? @type['id']
    end

    # day loan types with a loan period of 1-2 days (that cannot use L2L)
    def no_l2l_day_loan?
      [10, 17, 23, 24].include? @type['id']
    end

    def regular_loan?
      !nocirc_loan? && !minute_loan? && !day_loan?
    end

    # Check whether a loan type is non-circulating
    def nocirc_loan?
      @type['id'] == 9
    end

  end
end
