module BlacklightCornellRequests
  module RequestHelper

  	# Time estimates are now delivered from the model in ranges (e.g., [1, 3])
  	# instead of integers. This function converts the range into a string for display
  	def delivery_estimate_display time_estimate

  		if time_estimate[0] == time_estimate[1]
  			pluralize(time_estimate[0], 'working day')
  		else
  			"#{time_estimate[0]} to #{time_estimate[1]} working days"
  		end

  	end

    def parsed_special_delivery(params)

      unless params['program'].present? && params['program']['location_id'] > 0
        Rails.logger.warn("Special Delivery: unable to find delivery location code in #{params.inspect}")
        return {}
      end

      program = params['program']
      office_delivery = program['location_id'] == 224
      formatted_label = office_delivery ? "Office Delivery" : "Special Program Delivery"
      formatted_label += " (#{params['delivery_location']})"

      {
        fod:   office_delivery,
        code:  params['program']['location_id'],
        value: formatted_label
      }
    end
    
    def borrowdirect_url_from_isbn(isbns)

      # For now, just take the first isbn if there are more than one. BD seems to do fine with any.
      if isbns.length > 0
        isbn = isbns[0]
      else
        isbn = isbns
      end

      # Chop off any dangling text (e.g., 13409872342X (pbk))
      isbn = isbn.scan(/[0-9xX]+/)[0]
      return if isbn.nil?

      link_url = "http://resolver.library.cornell.edu/net/parsebd/?&url_ver=Z39.88-2004&rft_id=urn%3AISBN%3A" + isbn + "&req_id=info:rfa/oclc/institutions/3913"

      link_url

    end

    def borrowdirect_url_from_title(title)

      link_url = "http://resolver.library.cornell.edu/net/parsebd/?&url_ver=Z39.88-2004&rft.btitle=" + title + "&req_id=info:rfa/oclc/institutions/3913"

      link_url

    end

  end
end
