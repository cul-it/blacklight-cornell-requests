module BlacklightCornellRequests

  class Volume

    attr_reader :items, :enum, :chron, :year

    ####### Class methods #######

    # Given an array of Items, return an array of volumes that
    # include those items.
    def self.volumes(items)
      return_volumes = {}

      items.each do |i|
        enum_parts = i.enum_parts
        v = Volume.new(enum_parts[:enum], enum_parts[:chron], enum_parts[:year], [i])
        # Keep volumes unique. If a volume already exists, just add the item to its items array.
        if return_volumes[v.enumeration]
          return_volumes[v.enumeration].items << i
        else
          return_volumes[v.enumeration] = v
        end
      end

      Rails.logger.debug "mjc12test5: returning volumes #{return_volumes.values}"
      return_volumes.values
    end

    # Make a new volume from a parameter string of the form |enum|chron|year|
    def self.volume_from_params(param_string)
      rx =/\|(.*?)\|(.*?)\|(.*?)\|/.match(param_string)
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

    def add_item(item_id)
      @items << item
    end

    def remove_item(item_id)
      @items.delete(item_id)
    end

    # Following suggestion from https://stackoverflow.com/questions/1931604/whats-the-right-way-to-implement-equality-in-ruby
    def ==(o)
      o.class == self.class && o.state === state
    end

    def eql?(o)
      o.class == self.class && o.state === state
    end

    def state
      [@enum, @chron, @year]
    end

    def hash
      state.hash
    end

  end

end
