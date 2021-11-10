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
        bd_value = p['bd_loc_code'].present? ? p['bd_loc_code'] : ""
        { :label => formatted_label, :value => p['location_id'], :bd_value => bd_value }
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

    # Provide a list of delivery locations that can be used to build options for a select dropdown
    # Doing it this way to make it easier to mark a default location as selected in HAML....
    def pickup_locations
      [ 
        { name: 'Africana', id: '7c5abc9f-f3d7-4856-b8d7-6712462ca007', bd_code: 'F' },
        { name: 'Annex Reading Room Use Only', id: '91f726ff-cbb1-4d60-821e-543ec1e91cc5', bd_code: ''},
        { name: 'Catherwood ILR', id: 'ab1fce49-e832-41a4-8afc-7179a62332e2', bd_code: 'I'},
        { name: 'Contactless Pickup - Annex', id: 'b232d619-3441-4fd0-b94c-210002e1fbec', bd_code: 'G'},
        { name: 'Contactless Pickup - Law', id: '041d6c8d-20a1-4fd7-8588-458286782aea', bd_code: 'B'},
        { name: 'Contactless Pickup - Mann', id: '4752a822-380b-446c-860f-bccf641d7118', bd_code: 'P'},
        { name: 'Contactless Pickup - Math', id: '1a072083-330f-4e1b-afa6-1ef15e24e3c3', bd_code: 'Q'},
        { name: 'Contactless Pickup - Ornithology', id: 'd2248b50-9388-4b40-83e2-b2d1200e112c', bd_code: ''},
        { name: 'Contactless Pickup - Uris Tower', id: 'e2f7ad76-ef2a-454f-8fd4-712caaa0f72b', bd_code: 'O'},
        { name: 'Contactless Pickup - Vet', id: '23b28dd9-cd7b-4ac1-a19a-6f4d3fce77d8', bd_code: 'E'},
        # { name: 'Faculty Department Office', id: 'a27d5cda-4810-4b58-874c-1fe1955829e3', bd_code: ''},
        { name: 'Fine Arts', id: '86932cca-3b71-4d29-b0e9-0680b1fffabf', bd_code: 'H'},
        #{ name: 'Geneva Circulation', id: '8eba8e43-90ae-4be5-b786-1282474301b0', bd_code: 'A'},
        { name: 'Law Circulation', id: '8d40f52a-02cf-4753-b423-0615d4c98479', bd_code: ''},
        { name: 'Management', id: 'f4b8e9e3-831b-44eb-aafe-20f583c555a1', bd_code: 'K'},
        { name: 'Mann', id: '872beba0-1bdf-4870-95f3-8781baddc02e', bd_code: 'C'},
        { name: 'Math', id: 'd6756e21-b828-4a0f-9346-2a10633c3b7a', bd_code: 'J'},
        { name: 'Music', id: '1eb3510f-c403-44bf-b3ce-cf693b20ba56', bd_code: 'L'},
        { name: 'Nestlé', id: '8e4f5d73-2f77-4906-8d6a-329fc79c5994', bd_code: 'L'},
        { name: 'Olin', id: '760beccd-362d-45b6-bfae-639565a877f2', bd_code: 'D'},
        { name: 'Ornithology Circulation Desk', id: 'debc685c-e905-48d3-9571-bff4742e7249', bd_code: 'M'},
        #{ name: 'Uris Clock Tower', id: 'cce94bc5-bb31-4054-96d2-260ba832ef2a'}
      ]
    end

  end
end
