require 'oci8'

module BlacklightCornellRequests
  # @author Matt Connolly

  class Patron

    attr_reader :netid, :barcode

    def initialize(netid)
      @netid = netid
      @barcode = get_barcode(netid)
    end

    def get_barcode(netid)

      return @barcode if @barcode.present?

      uri = URI.parse(ENV['NETID_URL'] + "?netid=#{@netid}")
      response = Net::HTTP.get_response(uri)

      # Make sure that we got a real result. Unfortunately, the CGI doesn't
      # return a nice error code
      return nil if response.body.include? 'Software error'

      # Return the barcode
      JSON.parse(response.body)['bc']

    end

    def patron_group
      connection = nil
      begin
        connection = OCI8.new(ENV['ORACLE_RDONLY_PASSWORD'], ENV['ORACLE_RDONLY_PASSWORD'], "(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=" + ENV['ORACLE_HOST'] + ")(PORT=1521))(CONNECT_DATA=(SID=" + ENV['ORACLE_SID'] + ")))")
        connection.exec('select patron_group_id from patron_barcode where patron_barcode.patron_barcode=' + @barcode) do |record|
          return record[0]
        end
      rescue OCIError
        Rails.logger.debug "mjc12test: ERROR - #{$!}"
        return nil
      end

    end

  end
end
