require 'cul/folio/edge'

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

    # Use the cul-folio-edge gem to determine which FOLIO delivery methods are available for the
    # item/patron combo specified
    def self.available_folio_methods(item, patron)
      # Get a FOLIO Okapi token for further requests
      url = ENV['OKAPI_URL']
      tenant = ENV['OKAPI_TENANT']
      token = CUL::FOLIO::Edge.authenticate(url, tenant, ENV['OKAPI_USER'], ENV['OKAPI_PW'])

      Rails.logger.debug "mjc12test: Trying to get AFM options ..."
      Rails.logger.debug "mjc12test: tenant: #{tenant}"
      Rails.logger.debug "mjc12test: token: #{token[:token]}"
      Rails.logger.debug "mjc12test: patron group: #{patron.record['patronGroup']}"
      Rails.logger.debug "mjc12test: item type: #{item.type&.dig('id')}"
      Rails.logger.debug "mjc12test: item loan type: #{item&.loan_type['id']}"
      Rails.logger.debug "mjc12test: item location: #{item&.location['id']}"
      Rails.logger.debug "mjc12test: item status: #{item&.status}"

      # TODO: add error handling
      result = CUL::FOLIO::Edge.request_options(
        url,
        tenant,
        token[:token],
        patron.record['patronGroup'],
        item.type&.dig('id'),
        item.loan_type['id'],
        item.location['id']
      )
      Rails.logger.debug "mjc12test: AFM lookup results: #{result}"
      return [] if result[:code] >= 300

      # The options returned from FOLIO reflect the request policy determined for the item and patron.
      # They do not consider item status, e.g., whether it's available or checked out. So we have
      # to do this. Not the prettiest code....
      res = REQUEST_TYPES_BY_ITEM_STATUS[:"#{item.status}"]
      Rails.logger.debug "mjc12test: RTBYS: #{res}"
      return result[:request_methods].select { |rm| res.include?(rm) } unless res.nil?

      []
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
    def self.available?(item, patron); end

    # Receive a hash of valid delivery methods (e.g.,
    # { Hold => [item1, item2, item3...], Recall => [item1, item3, ...]})
    # Sort them by delivery time, then return an object in the form
    # { :fastest => {:method => Hold, :items => []}, :alternate => [{methods, items]}
    def self.sorted_methods(options_hash)
      options_hash = options_hash.keep_if { |key, value| value.length.positive? }

      # Get fastest delivery method
      sorted_keys = options_hash.keys.sort { |x, y| x.time.min <=> y.time.min }
      fastest_method = sorted_keys.shift
      alternate_methods = []
      sorted_keys.each do |k|
        alternate_methods << { method: k, items: options_hash[k] }
      end

      # Document delivery/ScanIt never comes first
      if fastest_method == DocumentDelivery && alternate_methods.length.positive?
        fastest_method = alternate_methods.shift[:method]
        alternate_methods.unshift({ method: DocumentDelivery, items: options_hash[DocumentDelivery] })
      end

      {
        fastest: { method: fastest_method, items: options_hash[fastest_method] },
        alternate: alternate_methods
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
      # temporary covid change
      # options[:annex] ? [1, 2] : [2, 2]
      [2, 4]
    end

    def self.available?(item, patron)
      # Disabled for now - using the available_folio_methods method instead
    end
  end

  class BD < DeliveryMethod
    TemplateName = 'bd'

    def self.description
      'BorrowDirect'
    end

    def self.enabled?
      !ENV['DISABLE_BORROW_DIRECT'].present?
    end

    def self.time(options = {})
      # temporary covid change
      # [3,5]
      [7, 7]
    end

    # patron is a Patron instance; holdings is a holdings_json object from the bib record @document
    def self.available?(patron, holdings)
      # NOTE: In transitioning from the old BorrowDirect system to ReShare, we are eliminating the distinction
      # between BD and ILL, routing all requests into a single ILL form from which ReShare will figure out how to
      # fulfill them. The most expedient way to remove the old BD approach from the system is to always return
      # false for method availability.
      return false

      # Unfortunately, the rules governing which patron groups are eligible to use BD
      # are not programmatically accessible. Thus, they are hard-coded here for your
      # enjoyment (based on a list provided by Caitlin on 7/1/21). See also
      # the logic for ILL below. TODO: unify these two in a separate function. They're the same
      bd_patron_group_ids = [
        '503a81cd-6c26-400f-b620-14c08943697c',  # faculty
        'ad0bc554-d5bc-463c-85d1-5562127ae91b',  # graduate
        '3684a786-6671-4268-8ed0-9db82ebca60b',  # staff
        'bdc2b6d4-5ceb-4a12-ab46-249b9a68473e'   # undergraduate
      ]

      # BD shouldn't be available if an item is available locally. The {items: {avail: x}} object is
      # present if there is a positive value x for number of available items, but absent otherwise.
      available_locally = holdings.values.any? { |h| h['circ'] && !h.dig('items', 'avail').nil? }

      bd_patron_group_ids.include?(patron.group) && !available_locally
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
      [4, 14]
    end

    def self.available?(item, patron, noncirculating = false)
      # ILL is available for CORNELL only under the following conditions:
      # (1) Loan type is regular or day AND
      # (2) Status is charged or missing or lost
      # OR
      # (1) Item is nocirc or noncirculating
      # OR
      # (1) Item is at bindery

      return false unless enabled?

      # Unfortunately, the rules governing which patron groups are eligible to use ILL
      # are not programmatically accessible. Thus, they are hard-coded here for your
      # enjoyment (based on a table provided by Caitlin on 7/1/21).
      ill_patron_group_ids = [
        '503a81cd-6c26-400f-b620-14c08943697c',  # faculty
        'ad0bc554-d5bc-463c-85d1-5562127ae91b',  # graduate
        '3684a786-6671-4268-8ed0-9db82ebca60b',  # staff
        'bdc2b6d4-5ceb-4a12-ab46-249b9a68473e'   # undergraduate
      ]
      return false unless ill_patron_group_ids.include? patron.group

      # return true if item.statusCode == STATUSES[:at_bindery]
      return true if noncirculating

      if item.regular_loan? || item.day_loan?
        allowed_statuses = [
          'Aged to lost',
          'Checked out',
          'Claimed returned',
          'Declared lost',
          'In process',
          'In transit',
          'Long missing',
          'Lost and paid',
          'Missing',
          'On order',
          'Paged',
          'Unavailable'
        ]
        return allowed_statuses.include?(item.status)
      else
        return false
      end
      false
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
      [180, 180]
    end

    def self.available?(item, patron)
      # Disabled for now - using the available_folio_methods method instead
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
      [15, 15]
    end

    def self.available?(item, patron)
      # Disabled for now - using the available_folio_methods method instead
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

    def self.available?(solrdoc)
      solrdoc['callnum_sort'] == 'Available for the Library to Purchase'
    end

    # def self.pda_data(solrdoc)
    #   return nil unless solrdoc['url_pda_display']

    #   url, note = solrdoc['url_pda_display'][0].split('|')
    #   {
    #     url: url,
    #     note: note
    #   }
    # end
  end

  class PurchaseRequest < DeliveryMethod
    TemplateName = 'purchase'

    def self.description
      'Purchase Request'
    end

    def self.time(options = {})
      [10, 10]
    end

    def self.available?(item, patron)
      # RULE: Cornell patron, missing/lost status
      [
        'Aged to lost',
        'Claimed returned',
        'Declared lost',
        'Long missing',
        'Lost and paid',
        'Missing'
      ].include? item.status
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

    def self.available?(*)
      true
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

    def self.available?(item, _)
      # Items are available for 'ask at circulation' under the following conditions:
      # (1) Loan type is minute, and status is charged or not charged
      # (2) Loan type is nocirc
      item.noncirculating? || (item.minute_loan? && (item.status == 'Available' || item.status == 'Checked out'))
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
      return [1, 4]
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
      # eligible_formats = [2, 3, 5, 7, 8, 15, 18, 19, 20]
      # 4. Item is not on order or in process (see https://culibrary.atlassian.net/browse/DACCESS-248)

      eligible_formats = [
        '1a54b431-2e4f-452d-9cae-9cee66c9a892', # Book
        '30b3e36a-d3b2-415e-98c2-47fbdf878862', # Visual
        'a0a83d6c-2898-4e42-9aff-999c1fdd7c8f', # Periodical
        '14a1925d-148e-46a6-ada3-4cbcfad810e5', # Serial
        'd9acad2f-2aac-4b48-9097-e6ab85906b25', # Textual resource
        'cd9e54bc-d3c0-45d9-818d-0de1ec57a6e7', # Newspaper
        'd5dd238b-dcdb-421d-b2a7-4f004091466b', # Music (score)
        'fd6c6515-d470-4561-9c32-3e3290d4ca98', # Microform
        'dd0bf600-dbd9-44ab-9ff2-e2a61a6539f1', # Soundrec
      ]

      return false if ['On order', 'In process'].include? item.status
      return self.enabled? && eligible_formats.include?(item.type['id'])
    end
  end

  class MannSpecial < DeliveryMethod
    TemplateName = 'mann_special'

    def self.description
      'Mann Special Collections Request Form'
    end

    def self.enabled?
      !ENV['DISABLE_MANNSPECIAL'].present?
    end

    def self.time(options = {})
      [1, 2]
    end

    # For availability here, the patron rules are copied from ILL (a guess?)
    # Item-related rules are taken from the discussion at
    # https://culibrary.atlassian.net/browse/DISCOVERYACCESS-3484
    def self.available?(item, patron)
      return false unless enabled?

      # eligibile_patron_group_ids = [1,2,3,4,5,6,7,8,10,17]
      # Unfortunately, the rules governing which patron groups are eligible to use ILL
      # are not programmatically accessible. Thus, they are hard-coded here for your
      # enjoyment (based on a table provided by Caitlin on 7/1/21).
      # TODO: Why are there more groups in the Voyager list than in the FOLIO list now being used?
      eligible_patron_group_ids = [
        '503a81cd-6c26-400f-b620-14c08943697c',  # faculty
        'ad0bc554-d5bc-463c-85d1-5562127ae91b',  # graduate
        '3684a786-6671-4268-8ed0-9db82ebca60b',  # staff
        'bdc2b6d4-5ceb-4a12-ab46-249b9a68473e'   # undergraduate
      ]
      return false unless eligible_patron_group_ids.include? patron.group

      folio_locations = {
        mnsc: 'a8ce2842-0def-4260-a5ae-3f9a8feeb1eb',      # Mann Special Collections (mnsc)
        mnsc_anx: '66074f1b-078b-4e46-9677-ac9aa5a9fae8',  # Mann Special Collections, Annex (mnsc,anx)
        mann_hort: '909a4980-940d-4416-b200-13a8d8e5d35c', # Mann Hortorium (mann,hort)
        mann_href: 'a82d2c6b-fe17-4fd5-a762-6b1a3ef1f491'  # Mann Hortorium Reference (mann,href)
      }

      location = item.location['id']
      if [folio_locations[:mnsc], folio_locations[:mnsc_anx]].include? location
        true
      elsif [folio_locations[:mann_hort], folio_locations[:mann_href]].include? location
        holdings = item.holdings_data
        does_not_circulate = false
        special_collections = false
        if holdings[item.holding_id]['notes'].present?
          holdings[item.holding_id]['notes'].each do |note|
            does_not_circulate = true if note.include? 'DOES NOT CIRCULATE'
            special_collections = true if note.include? 'Mann Library Special Collections'
          end
        end
        if special_collections || (location == folio_locations[:mann_hort] && does_not_circulate)
          true
        elsif item.type['id'] == '2e48e713-17f3-4c13-a9f8-23845bb210a4' # nocirc
          false
        else
          # Not special collections and not nocirc, so this is a Hortorium L2L item
          false
        end
      end
    end
  end
end
