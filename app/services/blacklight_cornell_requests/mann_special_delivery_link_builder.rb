module BlacklightCornellRequests
  class MannSpecialDeliveryLinkBuilder
    # Create a link to the Mann Special Collections delivery request form with
    # fields prepopulated from the work metadata and patron's FOLIO record.
    #
    # This is here, rather than in the Work model, because it needs
    # access to the patron object to populate some fields.
    def self.build(work, patron)
      link = "https://cornell.libwizard.com/f/mann-special-collections-registration?"

      # Item metadata. LibWizrd allows field identification by label or ID; using IDs here
      # because the form provides fields for multiple items, each with the same labels but
      # different IDs. If we use labels, the work metadata is repeated multiple times in the form.
      link += "3859729=#{CGI.escape(work.author.to_s)}" # Author
      link += "&3859730=#{CGI.escape(work.title.to_s)}" # Title
      link += "&3859728=#{CGI.escape(work.call_number.to_s)}" # Call number

      # Patron metadata from FOLIO
      patron_record = patron.get_folio_record
      if patron_record.present?
        if patron_record['personal']&.[]('addresses').present?
          # FOLIO addresses have a primaryAddress flag that we can use to find the preferred address.
          # Some patrons don't have an address record at all, and some may have multiple. The LibWizard
          # form for Mann Special Collections requires both a local address and home address, so we can
          # populate the local address field from the primaryAddress and hope that that's right most of the time.
          address_record = patron_record['personal']['addresses'].find { |addr| addr['primaryAddress'] == true }
          # Weirdly, patrons can have an address but no primary address. In that case, just use the first address.
          address_record ||= patron_record['personal']['addresses'].first
          address = [
            address_record['addressLine1'], 
            address_record['addressLine2'], 
            address_record['city'], 
            address_record['region'], 
            address_record['postalCode'], 
          ].compact.join(', ')
          link += "&3859679=#{address}"
        end
        patron_name = "#{patron_record['personal']['firstName']} #{patron_record['personal']['lastName']}"
        link += "&name=#{CGI.escape(patron_name)}"
        link += "&local_phone=#{CGI.escape(patron_record.dig("personal", "phone").to_s)}"
        link += "&department=#{CGI.escape(patron_record.dig("customFields", "department").to_s)}"
      end

      link
    end
  end
end
