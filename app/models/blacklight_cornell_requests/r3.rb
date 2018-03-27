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
          items << Item.new(h, i)
        end
      end
      items
    end

    # If an item_id is specified, only results for that item will be returned
    # Otherwise, report includes all items in the record
    def report(item_id = '')
      linebreak
      puts "Reporting on bib #{@bibid} for #{@requester.netid}\n\n"
      if item_id.present?
        @items = @items.select do |i|
          i.id == item_id
        end
        puts "Focus on item #{item_id}"
      end
      linebreak
      puts "Requester: #{@requester.netid} (barcode: #{@requester.barcode}, group: #{@requester.group})\n"
      puts "\n\n\n"
      linebreak
      puts "Delivery methods available (i.e., not disabled in ENV file):"
      @methods.each do |m|
        puts "#{m.description}"
      end
      linebreak
      puts "Holdings contains #{@items.length} item records"
      puts "First item:"
      puts @items[0].inspect
      linebreak
      puts "Voyager delivery methods valid for this item:"
      puts RequestPolicy.policy(@items[0].circ_group, @requester.group, @items[0].type['id'])
      linebreak
      puts "Individual item report:"
      puts "ID\t\tStatus\tAvailable\tL2L\tHold\tRecall\n"
      policy_hash = {}
      @items.each do |i|
        rp = { }
        policy_key = "#{i.circ_group}-#{@requester.group}-#{i.type['id']}"
        if policy_hash[policy_key]
          rp = policy_hash[policy_key]
        else
          rp = RequestPolicy.policy(i.circ_group, @requester.group, i.type['id'])
          policy_hash[policy_key] = rp
        end
        puts "#{i.id}\t#{i.status['code'].keys[0]}\t#{i.status['available']}\t\t#{l2l_available?(i, rp)}\t#{hold_available?(i, rp)}\t#{recall_available?(i, rp)}"
      end
      linebreak
    end

    def linebreak
      puts "-" * 50
    end

    def l2l_available?(item, policy)
      (L2L.enabled? && policy[:l2l] && item.status['available']) ? 'Y' : 'N'
    end

    def hold_available?(item, policy)
      (Hold.enabled? && policy[:hold] && !item.status['available']) ? 'Y' : 'N'
    end

    def recall_available?(item, policy)
      (Recall.enabled? && policy[:recall] && !item.status['available']) ? 'Y' : 'N'
    end


  end

end
