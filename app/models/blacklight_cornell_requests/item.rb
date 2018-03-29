module BlacklightCornellRequests
  # @author Matt Connolly

  class Item

    attr_reader :id, :holding_id, :enumeration, :location, :type, :status, :circ_group

    # Basic initializer
    #
    # @param holding_id [int] The ID of the holding record this item is linked to
    # @param item_data [hash] A JSON object containing data for a single item record
    def initialize(holding_id, item_data)
      return nil if (holding_id.nil? || item_data.nil?)

      @holding_id = holding_id
      @id = item_data['id']
      # @location is the actual current location of the item; Solr index
      # combines the permanent location and temporary location fields so we
      # don't have to worry about it
      @location = item_data['location']
      @type = item_data['type']
      @enumeration = item_data['enum']
      @status = item_data['status']
      @circ_group = item_data['circGrp'].keys[0].to_i
      @onReserve = item_data['onReserve']
    end

    def inspect
      puts "Item record #{@id} (linked to holding record #{@holding_id}):"
      puts "Type: #{@type.inspect}"
      puts "Status: #{@status.inspect}"
      puts "Location: #{@location.inspect}"
      puts "Enumeration: #{@enumeration.inspect}"
      puts "Circ group: #{@circ_group}"
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

    ######## Class methods for loan types ##########
    # TODO: is there a better way of determining these straight from the Voyager DB?
    def self.loan_type(item)

      return 'nocirc' if nocirc_loan? item
      return 'day'    if day_loan? item
      return 'minute' if minute_loan? item
      return 'regular'

    end

    # Check whether a loan type is a "day" loan
    def self.day_loan?(item)
      [1, 5, 6, 7, 8, 10, 11, 13, 14, 15, 17, 18, 19, 20, 21, 23, 24, 25, 28, 33].include? item.type['id']
    end

    # Check whether a loan type is a "minute" loan
    def self.minute_loan?(item)
      [12, 16, 22, 26, 27, 29, 30, 31, 32, 34, 35, 36, 37].include? item.type['id']
    end

    # day loan types with a loan period of 1-2 days (that cannot use L2L)
    def self.no_l2l_day_loan?(item)
      [10, 17, 23, 24].include? item.type['id']
    end

    # Check whether a loan type is non-circulating
    def self.nocirc_loan?(item)
      item.type['id'] == 9
    end

  end
end
