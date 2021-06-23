module BlacklightCornellRequests
  # @author Matt Connolly

  class Item

    attr_reader :id, :holding_id, :holdings_data, :location, :type, :status #, :circ_group
    attr_reader :copy_number, :call_number, :enum_parts, :excluded_locations
    attr_reader :loan_type  # new FOLIO loan type and ID

    # Basic initializer
    #
    # @param holding_id [int] The ID of the holding record this item is linked to
    # @param item_data [hash] A JSON object containing data for a single item record
    # @param holdings_data [hash] A JSON object containing data for a single holdings record
    def initialize(holding_id, item_data, holdings_data = nil)
      return nil if (holding_id.nil? || item_data.nil?)

      @holding_id = holding_id
      @holdings_data = holdings_data
      @id = item_data['id']
      # @location is the actual current location of the item; Solr index
      # combines the permanent location and temporary location fields so we
      # don't have to worry about it
      @location = item_data['location']
      @type = item_data['matType']
      @chron = item_data['chron']
      @enum = item_data['enum']
      @year = item_data['year']
      @status = item_data['status']['status']
      #@circ_group = item_data['circGrp'].keys[0].to_i
      @onReserve = item_data['onReserve'] || @location['code'].include?('res')
      @copy_number = item_data['copy']
      if holdings_data.present?
        @call_number = holdings_data[holding_id]['call']
      end
      @loan_type = item_data['loanType']
      # TODO: excluded_locations can be removed entirely, but has to be taken out of the views first
      #@excluded_locations = RequestPolicy.excluded_locations(@circ_group, @location)
      @excluded_locations = []
    end

    # Enumeration is the single-string concatenation of three fields
    # from the item record: chron, enum, and year
    def enumeration
      [@enum, @chron, @year].compact.join(' - ')
    end

    def enum_parts
      { :enum => @enum, :chron => @chron, :year => @year }
    end

    def inspect
      @id
    end

    def report
      puts "Item record #{@id} (linked to holding record #{@holding_id}):"
      puts "Type: #{@type.inspect}"
      puts "Status: #{@status.inspect}"
      puts "Location: #{@location.inspect}"
      puts "Enumeration: " + enumeration
      puts "enum components: chron: #{@chron}, enum: #{@enum}, year: #{@year}"
      puts "Copy: #{@copy_number}"
      #puts "Circ group: #{@circ_group}"
      puts "Call number: #{@call_number}"
    end

    # def statusCode
    #   Rails.logger.debug("mjc12test: status #{@status}")
    #   @status['code'].keys[0].to_i
    # end

    def available?
      @status == 'Available'
    end

    def onReserve?
      !!@onReserve
    end

    # There is a specific nocirc loan typecode (9), but there could also be
    # a note in the holdings record that the item doesn't circulate (even
    # with a different typecode)
    def noncirculating?
      @type['id'] == '2e48e713-17f3-4c13-a9f8-23845bb210a4' || onReserve? || @location['name'].include?('Non-Circulating')
    end

    # TODO: is there a better way of determining these straight from the Voyager DB?
    # def loan_type

    #   return 'nocirc' if nocirc_loan?
    #   return 'day'    if day_loan?
    #   return 'minute' if minute_loan?
    #   return 'regular'

    # end

    # Check whether a loan type is a "day" loan
    def day_loan?
      #[1, 5, 6, 7, 8, 10, 11, 13, 14, 15, 17, 18, 19, 20, 21, 23, 24, 25, 28, 33].include? @type['id']
      [
        'a00b928e-39ef-4c32-aec9-f57dfb588456',  # '1 Day Loan'
        '3b102b62-90f9-4351-9d20-6f65714fc8a9',  # '14 Day Loan'
        '558f30ed-8def-4af6-bf89-c93a69dd51b9',  # '2 Day Loan'
        '23ed0bee-15c6-4043-923a-138b2e1cad8a',  # '3 Day Loan'
        '79b2aec0-2790-450a-930a-c37bd082653d',  # '7 Day Loan'
      ].include? @type['id']
    end

    # Check whether a loan type is a "minute" loan
    def minute_loan?
      #[12, 16, 22, 26, 27, 29, 30, 31, 32, 34, 35, 36, 37].include? @type['id']
      [
        '861998f8-3cc8-42b0-85eb-ff147b9683b9',  # '12 Hour Loan'
        '05efc087-adb9-43b5-857d-9d8af62ba660',  # '2 Hour Loan'
        '12326209-dd56-410c-8f02-1b7119b0c071',  # '3 Hour Loan'
        'fc69f8a6-1c5f-498c-9cec-7cca8ef740b8',  # '4 Hour Loan'
        'ae3214e1-8b4c-44ce-9c48-2e8a0cb8d928',  # '5 Hour Loan'
        '3dfe6532-e0af-4c72-b744-2bf035c49caf',  # '8 Hour Loan'
      ].include? @type['id']
    end

    # day loan types with a loan period of 1-2 days (that cannot use L2L)
    def no_l2l_day_loan?
      #[10, 17, 23, 24].include? @type['id']
      [
        'a00b928e-39ef-4c32-aec9-f57dfb588456',  # '1 Day Loan'
        '558f30ed-8def-4af6-bf89-c93a69dd51b9',  # '2 Day Loan'
      ].include? @type['id']
    end

    def regular_loan?
      !nocirc_loan? && !minute_loan? && !day_loan?
    end

    # Check whether a loan type is non-circulating
    def nocirc_loan?
      @type['id'] == '2e48e713-17f3-4c13-a9f8-23845bb210a4'
    end

  end
end
