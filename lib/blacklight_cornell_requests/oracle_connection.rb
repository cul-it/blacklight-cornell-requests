module BlacklightCornellRequests

  # This is based on the OracleConnection class from cornell-voyager-backend
  class OracleConnection

    def initialize(user, password, service)
      @connection = OCI8.new(user, password, service)
      @connection.prefetch_rows(1000)
    end


  end

end
