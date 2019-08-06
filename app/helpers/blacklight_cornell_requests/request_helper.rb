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
    
    def author_display
      # This is supposed to use Blacklight's show_presenter, but I haven't been able to get it to work
      # in Blacklight 7...
      # show_presenter(@document).field_value 'title_responsibility_display'
      @document['title_responsibility_display'] ? @document['title_responsibility_display'][0] : nil
    end

    # Return an array of select list option parameters corresponding to the
    # special programs specified in params. Example:
    # "programs"=>[{"location_id"=>250, "name"=>"NYC-CFEM"}]
    def parsed_special_delivery(params)

      return [] unless params['programs'] && params['programs'].length > 0

      # The reject operator is used here to filter out the faculty office delivery
      # option, which has its own entry in the select list and shouldn't be repeated here.
      params['programs'].reject{|p| p['location_id'] == 224}.sort_by{|p| p['name']}.map do |p|
        formatted_label = "Special Program Delivery: #{p['name']}"
        { :label => formatted_label, :value => p['location_id'] }
      end

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
