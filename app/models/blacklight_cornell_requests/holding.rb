module BlacklightCornellRequests
  # @author Matt Connolly

  class Holding
    
    attr_reader :items
    
    # Basic initializer
    # 
    # @param holdings_data [Array] Array of grouped holdings records
    def initialize(holdings_data)
      @records = parse_holdings holdings_data
    end
    
    # Pass in an array of holdings records and create item records for each
    def parse_holdings data
      items = []
      data.each do |h|
        items << BlacklightCornellRequests::Item.new(h)
      end
      @items = items
    end
    
  end
  
end