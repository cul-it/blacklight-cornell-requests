module BlacklightCornellRequests
  # @author Matt Connolly

  # Delivery method superclass
  class DeliveryMethod

    # TODO: some of these class methods should not be inherited by
    # subclasses ...

    # Return an array of all the methods that are currently ENABLED
    # (i.e., not disabled in the ENV file)
    def self.enabled_methods
      available_request_methods = []
      DELIVERY_METHODS.each do |m|
        # Turn string name into actual class
        # TODO: is this necessary? Could we maybe just store the actual
        # classes in the constants array?
        method_class = "BlacklightCornellRequests::#{m}".constantize
        available_request_methods << method_class if method_class.enabled?
      end
      available_request_methods
    end

    def self.description
      'An item delivery method'
    end

    # Whether the method can be used (i.e., has not been disabled in the env file)
    def self.enabled?
      true
    end

    # The estimated delivery time using this method
    def self.time(options = {})
      # Delivery time range: [min, max] days
    end

    # Whether this method can be used for the specified item and requestor
    def self.available?(item, patron)

    end

    # Receive a hash of valid delivery methods (e.g.,
    # { Hold => [item1, item2, item3...], Recall => [item1, item3, ...]})
    # Sort them by delivery time, then return an object in the form
    # { :fastest => {:method => Hold, :items => []}, :alternate => [{methods, items]}
    def self.sorted_methods(options_hash)
      options_hash = options_hash.keep_if { |key, value| value.length > 0 }

      # Get fastest delivery method
      sorted_keys = options_hash.keys.sort { |x, y| x.time.min <=> y.time.min }
      fastest_method = sorted_keys.shift
      alternate_methods = []
      sorted_keys.each do |k|
        alternate_methods << { :method => k, :items => options_hash[k] }
      end

      # Document delivery/ScanIt never comes first
      if fastest_method == DocumentDelivery && alternate_methods.length > 0
        fastest_method = alternate_methods.shift[:method]
        alternate_methods.unshift({ :method => DocumentDelivery, :items => options_hash[DocumentDelivery] })
      end

      {
        :fastest => {:method => fastest_method, :items => options_hash[fastest_method] },
        :alternate => alternate_methods
      }
    end

    # def self.loan_type(type_code)
    #   return LOAN_TYPES[:nocirc] if nocirc_loan? type_code
    #   return LOAN_TYPES[:day]    if day_loan? type_code
    #   return LOAN_TYPES[:minute] if minute_loan? type_code
    #   return LOAN_TYPES[:regular]
    # end
    #
    # # Check whether a loan type is non-circulating
    # def self.nocirc_loan?(loan_code)
    #   [9].include? loan_code.to_i
    # end
    #
    # def self.day_loan?(loan_code)
    #   [1, 5, 6, 7, 8, 10, 11, 13, 14, 15, 17, 18, 19, 20, 21, 23, 24, 25, 28, 33].include? loan_code.to_i
    # end
    #
    # def self.no_l2l_day_loan_types?(loan_code)
    #   [10, 17, 23, 24].include? loan_code.to_i
    # end
    #
    # # Check whether a loan type is a "minute" loan
    # def self.minute_loan?(loan_code)
    #   [12, 16, 22, 26, 27, 29, 30, 31, 32, 34, 35, 36, 37].include? loan_code.to_i
    # end
    #
    # def self.regular_loan?(loan_code)
    #   !nocirc_loan?(loan_code) && !minute_loan?(loan_code) && !day_loan?(loan_code)
    # end

  end

  ###### Individual delivery method class definitions follow ########

  class L2L < DeliveryMethod

    TemplateName = 'l2l'

    def self.description
      'Cornell library to library'
    end

    def self.enabled?
      !ENV['DISABLE_L2L'].present?
    end

    def self.time(options = {})
      options[:annex] ? [1, 2] : [2, 2]
    end

    def self.available?(item, patron)
      # Disabled for now - using the l2l_available? method in RequestController instead
    end
  end

  class BD < DeliveryMethod

    TemplateName = 'bd'

    def self.description
      'Borrow Direct'
    end

    def self.enabled?
      !ENV['DISABLE_BORROW_DIRECT'].present?
    end

    def self.time(options = {})
      [3,5]
    end

    def self.available?(patron)
      # Unfortunately, the rules governing which patron groups are eligible to use BD
      # are not programmatically accessible. Thus, they are hard-coded here for your
      # enjoyment (based on a table provided by Joanne Leary as of 3/30/18). See also
      # the logic for ILL below. TODO: unify these two in a separate function. They're the same
      bd_patron_group_ids = [1,2,3,4,5,6,7,8,10,17]

      bd_patron_group_ids.include? patron.group
    end
  end

  class ILL < DeliveryMethod

    TemplateName = 'ill'

    def self.description
      'Interlibrary Loan'
    end

    def self.enabled?
      !ENV['DISABLE_ILL'].present?
    end

    def self.time(options = {})
      [7,14]
    end

    def self.available?(item, patron, noncirculating = false)
      # ILL is available for CORNELL only under the following conditions:
      # (1) Loan type is regular or day AND
      # (2) Status is charged or missing or lost
      # OR 
      # (1) Item is nocirc or noncirculating
      # OR
      # (1) Item is at bindery

      return false unless self.enabled?
      
      # Unfortunately, the rules governing which patron groups are eligible to use ILL
      # are not programmatically accessible. Thus, they are hard-coded here for your
      # enjoyment (based on a table provided by Joanne Leary as of 3/30/18).
      ill_patron_group_ids = [1,2,3,4,5,6,7,8,10,17]
      return false unless ill_patron_group_ids.include? patron.group

      return true if item.statusCode == STATUSES[:at_bindery]
      return true if item.nocirc_loan? || noncirculating
      if item.regular_loan? || item.day_loan?
        return item.statusCode == STATUSES[:charged] ||
               item.statusCode == STATUSES[:renewed] ||
               item.statusCode == STATUSES[:missing] ||
               item.statusCode == STATUSES[:lost]
      else
        return false
      end
      return false
    end
  end

  class Hold < DeliveryMethod

    TemplateName = 'hold'

    def self.description
      'Hold'
    end

    def self.enabled?
      !ENV['DISABLE_HOLD'].present?
    end

    def self.time(options = {})
      [180,180]
    end

    def self.available?(item, patron)
      # Disabled for now - using the hold_available? method in RequestController instead
    end

  end

  class Recall < DeliveryMethod

    TemplateName = 'recall'

    def self.description
      'Recall'
    end

    def self.enabled?
      !ENV['DISABLE_RECALL'].present?
    end

    def self.time(options = {})
      [15,15]
    end

    def self.available?(item, patron)
      # Disabled for now - using the recall_available? method in RequestController instead
    end
  end

  class PDA < DeliveryMethod

    TemplateName = 'pda'

    def self.description
      'Patron-driven acquisition'
    end

    def self.time(options = {})
      [5, 5]
    end

    def self.available?(item, patron)
      item.nil?
    end

    def self.pda_data(solrdoc)
      return nil unless solrdoc['url_pda_display']
      url, note = solrdoc['url_pda_display'][0].split('|')
      {
        :url => url,
        :note => note
      }
    end
  end

  class PurchaseRequest < DeliveryMethod

    TemplateName = 'purchase'

    def self.description
      'Purchase Request'
    end

    def self.time(options = {})
      [10,10]
    end

    def self.available?(item, patron)
      # RULE: Cornell patron, missing/lost status
      [12,13,14].include? item.statusCode
    end
  end

  class AskLibrarian < DeliveryMethod

    TemplateName = 'ask'

    def self.description
      'Ask a librarian'
    end

    def self.time(options = {})
      [9999, 9999]
    end

    def self.available?(item, patron)
      return true
    end
  end

  class AskCirculation < DeliveryMethod

    TemplateName = 'circ'

    def self.description
      'Ask at circulation desk'
    end

    def self.time(options = {})
      [9998, 9998]
    end

    def self.available?(item, patron)
      # Items are available for 'ask at circulation' under the following conditions:
      # (1) Loan type is minute, and status is charged or not charged
      # (2) Loan type is nocirc
      item.noncirculating? || (item.minute_loan? && (item.statusCode == 1 || item.statusCode == 2 ))
    end
  end

  class DocumentDelivery < DeliveryMethod

    TemplateName = 'document_delivery'

    def self.description
      'ScanIt'
    end

    def self.enabled?
      !ENV['DISABLE_DOCUMENT_DELIVERY'].present?
    end

    def self.time(options = {})
      # TODO: add the logic for this
      return [1,4]
    end

    def self.available?(item, patron)
      # Document delivery (ScanIt) is available if the following criteria are met:
      # 1. Cornell patron
      # 2. Item is at the Annex (this is assumed to be
      #    anything with the Annex circ group of 5)
      # 3. Item is one of the valid scannable formats
      # eligible_formats = ['Book', (3)
      #                     'Image', (7)
      #                     'Journal', (2)
      #                     'Manuscript/Archive', (8)
      #                     'Musical Recording', (18)
      #                     'Musical Score', (5)
      #                     'Non-musical Recording',
      #                     'Journal/Periodical', (15)
      #                     'Research Guide',
      #                     'Thesis',
      #                     'Newspaper' (20)
      #                     'Microform'] (19)
      eligible_formats = [2, 3, 5, 7, 8, 15, 18, 19, 20]

      return self.enabled? && item.circ_group == 5 && eligible_formats.include?(item.type['id'])
    end
  end

end
