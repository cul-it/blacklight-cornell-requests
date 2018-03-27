module BlacklightCornellRequests
  # @author Matt Connolly

  class RequestPolicy

    def self.policy(circ_group, patron_group, item_type)
      connection = nil
      begin
        connection = OCI8.new(ENV['ORACLE_RDONLY_PASSWORD'], ENV['ORACLE_RDONLY_PASSWORD'], "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=" + ENV['ORACLE_HOST'] + ")(PORT=1521))(CONNECT_DATA=(SID=" + ENV['ORACLE_SID'] + ")))")
        cursor = connection.parse('select place_call_slip, place_hold, place_recall from circ_policy_matrix c where c.circ_group_id=:circgroup and patron_group_id=:patrongroup and item_type_id=:itemtype')
        cursor.bind_param('circgroup', circ_group)
        cursor.bind_param('patrongroup', patron_group)
        cursor.bind_param('itemtype', item_type)

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

  end

end

    #     cursor.exec() do |record|
    #       return {
    #         :hold => (record[1] == "Y"),
    #         :recall => (record[2] == "Y"),
    #         :l2l => (record[0] == "Y")
    #       }
    #     end
    #   rescue OCIError
    #     Rails.logger.debug "mjc12test: ERROR - #{$!}"
    #     return nil
    #   end
