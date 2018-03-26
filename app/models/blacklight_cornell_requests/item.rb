module BlacklightCornellRequests
  # @author Matt Connolly

  class Item

    attr_reader :id, :holding_id, :enumeration, :location, :status, :circ_group

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
      @enumeration = item_data['enum']
      @status = item_data['status']
      @circ_group = item_data['circGrp'].keys[0]
    end

    def inspect
      puts "Item record #{@id} (linked to holding record #{@holding_id}):"
      puts "Status: #{@status.inspect}"
      puts "Location: #{@location.inspect}"
      puts "Enumeration: #{@enumeration.inspect}"
      puts "Circ group: #{@circ_group}"
    end

    def available?
      @status['available']
    end

  end
end
