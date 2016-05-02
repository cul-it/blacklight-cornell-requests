module BlacklightCornellRequests
  # @author Matt Connolly

  class Item
    
    attr_reader :id, :mfhd_id, :enumeration, :location, :status
    
    # Basic initializer
    # 
    # @param item_data [Hash] Hash of item data values
    def initialize(options = {})
      set_options options
    end
    
    def inspect
      puts "Item record #{@id} (linked to MFHD #{@mfhd_id}):"
      puts "Status: #{@status.inspect}"
      puts "Location: #{@location.inspect}"
      puts "Enumeration: #{@enumeration.inspect}"
    end
    
    # Initialize item-level fields
    def set_options options
      
      # IDs
      @id = options['ITEM_ID'] or nil
      @mfhd_id = options['MFHD_ID'] or nil
    
      # Enumeration
      if options['ITEM_ENUM'] || options['CHRON'] || options['YEAR']
        @enumeration = {
          :enum => options['ITEM_ENUM'],
          :chron => options['CHRON'],
          :year => options['YEAR']
        }
      end
      
      # location
      if options['PERM_LOCATION'] || options['TEMP_LOCATION_CODE']
        @location = {
          :perm => options['PERM_LOCATION'],
          :temp => options['TEMP_LOCATION_CODE']
        }
      end
        
      #status
      if options['ITEM_STATUS']
        @status = {
          :code => options['ITEM_STATUS'],
          :date => options['ITEM_STATUS_DATE'],
          :due  => options['CURRENT_DUE_DATE']
        }
      end
      
    end
    
  end
end