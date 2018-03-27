module BlacklightCornellRequests
  # @author Matt Connolly

  # This class is only intended to be used as a diagnnostic tool to figure out why
  # a particular request might be failing.
  class R3

    def initialize(bibid, netid, document)
      @bibid = bibid
      @requester = Patron.new(netid)
      @document = document
      @items = get_items
      @methods = DeliveryMethod.enabled_methods
    end

    def get_items
      items = []
      holdings = JSON.parse(@document['items_json'])
      # Items are keyed by the associated holding record
      holdings.each do |h, item_array|
        item_array.each do |i|
          items << BlacklightCornellRequests::Item.new(h, i)
        end
      end
      items
    end

    def report
      linebreak
      puts "Reporting on bib #{@bibid} for #{@requester.netid}\n\n"
      linebreak
      puts "Requester: #{@requester.netid} (barcode: #{@requester.barcode})\n"
      puts "\n\n\n"
      linebreak
      puts "Delivery methods available:"
      @methods.each do |m|
        puts "#{m.description}"
      end
      linebreak
      puts "Holdings contains #{@items.length} item records"
      puts "First item:"
      puts @items[0].inspect
      linebreak
      puts "Voyager delivery methods valid for this item:"
      puts RequestPolicy.policy(@items[0].circ_group, @requester.patron_group, @items[0].type['id'])
      linebreak
    end

    def linebreak
      puts "-" * 50
    end


  end

end
