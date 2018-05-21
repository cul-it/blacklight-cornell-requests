module BlacklightCornellRequests

  class Volume

    attr_reader :items  

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

  end

end
