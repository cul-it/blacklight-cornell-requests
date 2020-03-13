require 'oci8'
module BlacklightCornellRequests
  # @author Matt Connolly

  # TODO: DRY this class up. Plenty of OCI connection stuff that should be refactored out
  class RequestPolicy

    # Given an item's circulation group and type, and a patron's patron group,
    # determine which Voyager delivery methods (hold, recall, callslip/L2L)
    # are allowed
    def self.policy(circ_group, patron_group, item_type)
      Rails.logger.debug "mjc12test: cg, pg, it #{circ_group}, #{patron_group}, #{item_type}"
      return self.default_policy(circ_group, item_type) if patron_group == 0
      connection = nil
      begin
        connection = OCI8.new(ENV['ORACLE_RDONLY_PASSWORD'], ENV['ORACLE_RDONLY_PASSWORD'], "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=" + ENV['ORACLE_HOST'] + ")(PORT=1521))(CONNECT_DATA=(SID=" + ENV['ORACLE_SID'] + ")))")
        cursor = connection.parse('select place_call_slip, place_hold, place_recall from circ_policy_matrix c where c.circ_group_id=:circgroup and patron_group_id=:patrongroup and item_type_id=:itemtype')
        cursor.bind_param('circgroup', circ_group, Integer)
        cursor.bind_param('patrongroup', patron_group, Integer)
        cursor.bind_param('itemtype', item_type, Integer)

        cursor.exec
        record = cursor.fetch
        if record.nil?
          return {}
        else
          return {
            :hold => (record[1] == "Y"),
            :recall => (record[2] == "Y"),
            :l2l => (record[0] == "Y"),
          }
        end

      rescue OCIError
        Rails.logger.debug "mjc12test: ERROR - #{$!}"
        return nil
      end

    end

    def self.default_policy(circ_group, item_type)
      connection = nil
      begin
        connection = OCI8.new(ENV['ORACLE_RDONLY_PASSWORD'], ENV['ORACLE_RDONLY_PASSWORD'], "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=" + ENV['ORACLE_HOST'] + ")(PORT=1521))(CONNECT_DATA=(SID=" + ENV['ORACLE_SID'] + ")))")
        cursor = connection.parse('select place_call_slip, place_hold, place_recall from circ_policy_matrix c where c.circ_group_id=:circgroup and item_type_id=:itemtype')
        cursor.bind_param('circgroup', circ_group, Integer)
        cursor.bind_param('itemtype', item_type, Integer)

        cursor.exec
        record = cursor.fetch
        if record.nil?
          return {}
        else
          return {
            :hold => (record[1] == "Y"),
            :recall => (record[2] == "Y"),
            :l2l => (record[0] == "Y"),
          }
        end

      rescue OCIError
        Rails.logger.debug "mjc12test: ERROR - #{$!}"
        return nil
      end

    end

    def self.excluded_locations(circ_group, item_location)
      return [] if ENV['REQUEST_BYPASS_ROUTING_CHECK'].present?
      
      connection = nil
      begin
        connection = OCI8.new(ENV['ORACLE_RDONLY_PASSWORD'], ENV['ORACLE_RDONLY_PASSWORD'], "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=" + ENV['ORACLE_HOST'] + ")(PORT=1521))(CONNECT_DATA=(SID=" + ENV['ORACLE_SID'] + ")))")
        cursor = connection.parse('select location_id from circ_policy_locs where circ_group_id=:circgroup')
        cursor.bind_param('circgroup', circ_group, Integer)
        cursor.exec
        records = []
        while r = cursor.fetch()
          records << r[0]
        end

        ## handle exceptions
        ## group id 3  - Olin
        ## group id 19 - Uris
        ## group id 5  - Annex
        ## group id 14 - Law
        ## group id 16 - Mann 
        ## Olin or Uris can't deliver to itselves and each other
        ## Annex group can deliver to itself
        ## Law group can deliver to itself
        ## Baily Hortorium CAN be delivered to Mann despite being in same group (16)
        ## Geneva should be a delivery location for Mann (why isn't it already? circ groups are different)
        ## Others can't deliver to themselves
        # TODO: move these hard-coded exceptions into the .env file now that the
        # new check_additional_exclusions is operational
        case circ_group
        when 3, 19
          ## exclude both group id if Olin (181) or Uris (188)
          records << 181 << 188
        when 14
          records.delete 171 # Law circ
        when 5
          records.delete 151 # Annex circ
        when 16 # Mann
          records.delete 162 # Geneva circ
        end

        # Allow Bailey Hortorium (77) delivery to Mann circ (172)
        records.delete(172) if item_location['number'] == 77

        records = self.check_additional_exclusions(circ_group, records)
        Rails.logger.debug("mjc12test: Returning records: #{records}" )
        return records
  
      rescue OCIError
        Rails.logger.debug "mjc12test: ERROR - #{$!}"
        return nil
      end
    end

    # Receives an array of excluded locations.
    # Returns a similar array modified by any additional exceptions 
    # that may be in the .env config file.
    def self.check_additional_exclusions(circ_group, records)
        if ENV['REQUEST_ROUTING_EXCEPTIONS']
          # This parameter has to be decoded. It should be in the form:
          # 'g<circ_group>:<a|d><location>,<a|d><location>...;g<circ_group>:...'
          # where a = allow, d = deny
          # e.g., the Olin, Uris, and Law exceptions above could be
          # represented as: 'g3:d181,d188;g14:a171'
          additional_groups = ENV['REQUEST_ROUTING_EXCEPTIONS'].split ';'
          Rails.logger.debug "mjc12test: Additional delivery rules found in .env file"
          additional_groups.each do |g|
            group, locs = g.split ':'
            # strip off the initial 'g' so we just have the group number
            group = group[1..-1].to_i
            next if group != circ_group
            locs = locs.split ','
            locs.each do |location|
              # each location is in the form <action><loc>, e.g. 'a171'
              parts = location.match /(.)(.+)/
              action = parts[1]
              location = parts[2].to_i

              if action == 'a'
                # allow this location as a group self-delivery exception
                Rails.logger.debug "mjc12test: group #{circ_group}: allowing #{location}"
                records.delete location
              elsif action == 'd'
                # deny this location as a group self-delivery exception
                Rails.logger.debug "mjc12test: group #{circ_group}: excluding #{location}"
                records << location
              end
            end
          end
        end

        records
    end

  end

end
