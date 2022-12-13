require 'rest-client'
require 'json'
require 'cul/folio/edge'

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

    # Provide a list of delivery locations that can be used to build options for a select dropdown
    # Doing it this way to make it easier to mark a default location as selected in HAML....
    def pickup_locations
      # Borrow Direct requests need to provide a library-specific BD code, provided here
      bd_codes = {
        '7c5abc9f-f3d7-4856-b8d7-6712462ca007' => 'F', # Africana
        'ab1fce49-e832-41a4-8afc-7179a62332e2' => 'I', # Catherwood ILR
        'b232d619-3441-4fd0-b94c-210002e1fbec' => 'G', # Annex
        '041d6c8d-20a1-4fd7-8588-458286782aea' => 'B', # Law
        '4752a822-380b-446c-860f-bccf641d7118' => 'C', # Mann
        '1a072083-330f-4e1b-afa6-1ef15e24e3c3' => 'Q', # Math
        'e2f7ad76-ef2a-454f-8fd4-712caaa0f72b' => 'O', # Uris
        '23b28dd9-cd7b-4ac1-a19a-6f4d3fce77d8' => 'E', # Vet
        '86932cca-3b71-4d29-b0e9-0680b1fffabf' => 'H', # Fine Arts
        '8eba8e43-90ae-4be5-b786-1282474301b0' => 'A', # Geneva
        'f4b8e9e3-831b-44eb-aafe-20f583c555a1' => 'K', # Management
        'd6756e21-b828-4a0f-9346-2a10633c3b7a' => 'J', # Math
        '1eb3510f-c403-44bf-b3ce-cf693b20ba56' => 'L', # Music
        '760beccd-362d-45b6-bfae-639565a877f2' => 'D', # Olin
        'debc685c-e905-48d3-9571-bff4742e7249' => 'M', # Ornithology
        '4752a822-380b-446c-860f-bccf641d7118' => 'P', # Contactless pickup - Mann (?)
        '1a072083-330f-4e1b-afa6-1ef15e24e3c3' => 'Q'  # Contactless pickup - Math (?)
      }

      # Retrieve a list of service points from FOLIO
      url = "#{ENV['OKAPI_URL']}/service-points?limit=1000"
      begin
        token = CUL::FOLIO::Edge.authenticate(ENV['OKAPI_URL'], ENV['OKAPI_TENANT'], ENV['OKAPI_USER'], ENV['OKAPI_PW'])[:token]
        headers = {
          'X-Okapi-Tenant' => ENV['OKAPI_TENANT'],
          'x-okapi-token' => token,
          :accept => 'application/json',
        }
        response = RestClient.get(url, headers)
        if response.code == 200
          points = JSON.parse(response.body)['servicepoints']
          points.sort_by! { |p| p['discoveryDisplayName'] }
          # As per discussion with Andy Horbal (1/12/22), the criteria to display a service
          # point to the user as a pickup location are:
          #   1. pickupLocation == true
          #   2. discoveryDisplayName != 'Staff Use Only' (used to indicate internal SPs for request routing)
          #   3. discoveryDisplayName doesn't start with 'Special Program Delivery'
          points.select! do |p|
            p['pickupLocation'] &&
            p['discoveryDisplayName'] != 'Staff Use Only' &&
            !(p['discoveryDisplayName'] =~ /^Special Program Delivery/)
          end
          result = points.map do |p|
            {
              name: p['discoveryDisplayName'],
              id: p['id'],
              bd_code: bd_codes[p['id']]
            }
          end
          Rails.logger.debug "mjc12test6: results: #{result}"
          return result
        end
      rescue RestClient::ExceptionWithResponse => err
        Rails.logger.debug "Requests: Couldn't retrieve list of service points (#{err})"
        return []
      end

      # [
      #   { name: 'Africana', id: '7c5abc9f-f3d7-4856-b8d7-6712462ca007', bd_code: 'F' },
      #   # { name: 'Annex Reading Room Use Only', id: '91f726ff-cbb1-4d60-821e-543ec1e91cc5', bd_code: ''},
      #   { name: 'Catherwood ILR', id: 'ab1fce49-e832-41a4-8afc-7179a62332e2', bd_code: 'I'},
      #   { name: 'Contactless Pickup - Annex', id: 'b232d619-3441-4fd0-b94c-210002e1fbec', bd_code: 'G'},
      #   # { name: 'Contactless Pickup - Law', id: '041d6c8d-20a1-4fd7-8588-458286782aea', bd_code: 'B'},
      #   { name: 'Contactless Pickup - Mann', id: '4752a822-380b-446c-860f-bccf641d7118', bd_code: 'P'},
      #   { name: 'Contactless Pickup - Math', id: '1a072083-330f-4e1b-afa6-1ef15e24e3c3', bd_code: 'Q'},
      #   # { name: 'Contactless Pickup - Ornithology', id: 'd2248b50-9388-4b40-83e2-b2d1200e112c', bd_code: ''},
      #   { name: 'Contactless Pickup - Uris Tower', id: 'e2f7ad76-ef2a-454f-8fd4-712caaa0f72b', bd_code: 'O'},
      #   { name: 'Contactless Pickup - Vet College community only', id: '23b28dd9-cd7b-4ac1-a19a-6f4d3fce77d8', bd_code: 'E'},
      #   # { name: 'Faculty Department Office', id: 'a27d5cda-4810-4b58-874c-1fe1955829e3', bd_code: ''},
      #   # { name: 'Fine Arts', id: '86932cca-3b71-4d29-b0e9-0680b1fffabf', bd_code: 'H'},
      #   #{ name: 'Geneva Circulation', id: '8eba8e43-90ae-4be5-b786-1282474301b0', bd_code: 'A'},
      #   { name: 'Law Circulation', id: '8d40f52a-02cf-4753-b423-0615d4c98479', bd_code: ''},
      #   # { name: 'Management', id: 'f4b8e9e3-831b-44eb-aafe-20f583c555a1', bd_code: 'K'},
      #   { name: 'Mann', id: '872beba0-1bdf-4870-95f3-8781baddc02e', bd_code: 'C'},
      #   { name: 'Math', id: 'd6756e21-b828-4a0f-9346-2a10633c3b7a', bd_code: 'J'},
      #   { name: 'Music', id: '1eb3510f-c403-44bf-b3ce-cf693b20ba56', bd_code: 'L'},
      #   # { name: 'Nestlé', id: '8e4f5d73-2f77-4906-8d6a-329fc79c5994', bd_code: 'L'},
      #   # { name: 'Olin', id: '760beccd-362d-45b6-bfae-639565a877f2', bd_code: 'D'},
      #   # { name: 'Ornithology Circulation Desk', id: 'debc685c-e905-48d3-9571-bff4742e7249', bd_code: 'M'},
      #   #{ name: 'Uris Clock Tower', id: 'cce94bc5-bb31-4054-96d2-260ba832ef2a'}
      # ]
    end

  end
end
