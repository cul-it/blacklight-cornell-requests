module BlacklightCornellRequests

  class Volume

    attr_reader :items  

    ####### Class methods #######

    # Given an array of Items, return a hash with keys corresponding to each
    # volume in the item array, and values being arrays of all the item records
    # associated with that volume. E.g.:
    #
    # { "vol. 1" => [14141, 14142, 14145], "vol. 2" => [14143] }
    def self.volumes(items)
      volumes = {}
      items.each do |i|
        enum_parts = i.enum_parts
        volumes[i.enumeration] ? volumes[i.enumeration] << Volume.new(enum_parts[:enum], enum_parts[:chron], enum_parts[:year], [i.id]) : volumes[i.enumeration] = [i.id]
      end
      volumes
    end

    #############################

    def initialize(enum, chron, year, items = [])
      @enum = enum
      @chron = chron
      @year = year
      @items = items
    end

    # Enumeration is the single-string concatenation of three fields
    # from the item record: chron, enum, and year
    def enumeration
      [@enum, @chron, @year].compact.join(' - ')
    end

    def add_item(item_id)
      @items << item
    end

    def remove_item(item_id)
      @items.delete(item_id)
    end

  end

end
