module BlacklightCornellRequests
  class Volume
    attr_reader :items, :enum, :chron, :year

    ####### Class methods #######

    # Given an array of Items, return an array of volumes that
    # include those items. (Currently one item per volume; there may
    # be duplicate volumes.)
    def self.volumes(items)
      items.map do |i|
        enum_parts = i.enum_parts
        Volume.new(enum_parts[:enum], enum_parts[:chron], enum_parts[:year], [i])
      end
    end

    # Make a new volume from a parameter string of the form |enum|chron|year|
    def self.volume_from_params(param_string)
      rx = /\|(.*?)\|(.*?)\|(.*?)\|/.match(param_string)
      rx && Volume.new(rx[1], rx[2], rx[3])
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

    # Return a formatted object that can be used as an option in a select list
    def select_option
      "|#{@enum}|#{@chron}|#{@year}|"
    end

    # FIXME
    def add_item(item_id)
      @items << item
    end

    def remove_item(item_id)
      @items.delete(item_id)
    end

    # Following suggestion from https://stackoverflow.com/questions/1931604/whats-the-right-way-to-implement-equality-in-ruby
    def ==(other)
      other.class == self.class && other.state == state
    end

    def eql?(other)
      other.class == self.class && other.state == state
    end

    def state
      [@enum, @chron, @year]
    end

    def hash
      state.hash
    end
  end
end
