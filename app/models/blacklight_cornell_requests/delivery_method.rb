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
      BlacklightCornellRequests::DELIVERY_METHODS.each do |m|
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

    def self.loan_type(type_code)
      return LOAN_TYPES[:nocirc] if nocirc_loan? type_code
      return LOAN_TYPES[:day]    if day_loan? type_code
      return LOAN_TYPES[:minute] if minute_loan? type_code
      return LOAN_TYPES[:regular]
    end

    # Check whether a loan type is non-circulating
    def self.nocirc_loan?(loan_code)
      [9].include? loan_code.to_i
    end

    def self.day_loan?(loan_code)
      [1, 5, 6, 7, 8, 10, 11, 13, 14, 15, 17, 18, 19, 20, 21, 23, 24, 25, 28, 33].include? loan_code.to_i
    end

    def self.no_l2l_day_loan_types?(loan_code)
      [10, 17, 23, 24].include? loan_code.to_i
    end

    # Check whether a loan type is a "minute" loan
    def self.minute_loan?(loan_code)
      [12, 16, 22, 26, 27, 29, 30, 31, 32, 34, 35, 36, 37].include? loan_code.to_i
    end

    def self.regular_loan?(loan_code)
      !nocirc_loan?(loan_code) && !minute_loan?(loan_code) && !day_loan?(loan_code)
    end

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
      # L2L is available for both Cornell and Guest patrons when:
      # (1) the status is NOT_CHARGED, and
      # (2) loan type is regular or (day AND not in the list of no L2L day loan types)
      if status == STATUSES[:not_charged]
        return regular_loan?(loan_type) ||
               (day_loan?(loan_type) && !no_l2l_day_loan_types?(loan_type))
      else
        return false
      end
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

    def self.available?(item, patron, bd_available = false)
      # Since BD availability is done at the request level,
      # it's already been established when the request was instantiated. But it
      # could be moved here ... this may be a more logical place to put that code.
      # For now, we're just parroting back whatever value is passed in
      return bd_available
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

    def self.available?(item,patron, noncirculating = false)
      # ILL is available for CORNELL only under the following conditions:
      # (1) Loan type is regular or day AND
      # (2) Status is charged or missing or lost
      # OR
      # (1) Item is nocirc or noncirculating
      # OR
      # (1) Item is at bindery
      return false unless patron_type == 'cornell'
      return true if status == STATUSES[:at_bindery]
      return true if nocirc_loan?(loan_type) || noncirculating
      if regular_loan?(loan_type) || day_loan?(loan_type)
        return status == STATUSES[:charged] ||
               status == STATUSES[:missing] ||
               status == STATUSES[:lost]
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
      # Items are available for hold under the following conditions:
      # (1) status is charged and loan type is regular or day, OR
      # (2) type is regular, patron type is cornell, and status is in transit
      # TODO: ask Joanne about that condition. Should it matter for transit status
      # whether patron is cornell-affiliated or not?
      if regular_loan?(loan_type)
        return true if status == STATUSES[:charged]
        return patron_type == 'cornell' &&
               (status == STATUSES[:in_transit_discharged] ||
                status == STATUSES[:in_transit_on_hold])
      elsif day_loan?(loan_type)
        return status == STATUSES[:charged]
      end
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
      # Items are available for recall under the following conditions:
      # (1) patron is cornell-affililated, loan type is regular, and
      #     status is charged or in-transit-discharged or in-transit-on-hold
      if patron_type == 'cornell' && regular_loan?(loan_type)
        return (status == STATUSES[:charged] ||
                status == STATUSES[:in_transit_discharged] ||
                status == STATUSES[:in_transit_on_hold])
      else
        return false
      end
    end
  end

  class PDA < DeliveryMethod

    TemplateName = ''

    def self.description
      'Patron-driven acquisition'
    end

    def self.time(options = {})
      [5, 5]
    end

    def self.available?(item, patron)

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
      [12,13,14].include? item.status['code'].keys[0]
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
      return minute_loan?(loan_type) && (status == STATUSES[:charged] ||
                                         status == STATUSES[:not_charged])
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
      return nil
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
