module BlacklightCornellRequests
  # @author Matt Connolly

  class DeliveryMethod
    
    def self.description
      'An item delivery method'
    end
    
    def self.time(options = {})
      # Delivery time range: [min, max] days
    end
    
  end
  
  
  class L2L < DeliveryMethod
    def self.description
      'Library-to-Library delivery'
    end
    
    def self.time(options = {})
      options[:annex] ? [1, 2] : [2, 2]
    end
  end

  class BD < DeliveryMethod
    def self.description
      'Borrow Direct'
    end
    
    def self.time(options = {})
      [3,5]
    end
  end

end
