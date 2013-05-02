require 'net/ldap'

module BlacklightCornellRequests

  module Cornell

    module LDAP
      # Authenticate and bind to Cornell's Active Directory LDAP service
      # Returns an ldap object that can be used for searches (or nil on failure)
      def bind_ldap

        # Login credentials (provided by Desktop Services)
        holding_id_dn = '***REMOVED***'
        holding_pw = '***REMOVED***'

        # Set up LDAP connection
        ldap = Net::LDAP.new
        ldap.host = '***REMOVED***'
        ldap.port = ***REMOVED***
        ldap.auth holding_id_dn, holding_pw

        if ldap.bind
        return ldap
        else
          return nil
        end
      end

      # Return our requests-specific patron type by looking at
      # the LDAP entry's reference groups.
      # Our basic assumption: a person is student/faculty/staff if he/she belongs to
      #  one of the following reference groups:
      #    rg.cuniv.employee, rg.cuniv.student
      # Reference Groups reference page is http://www.it.cornell.edu/services/group/about/reference.cfm
      def get_patron_type netid

        unless netid.nil?
          patron_dn = get_ldap_dn netid
          return nil if patron_dn.nil?

          ldap = bind_ldap
          return unless ldap

          # Do our search
          search_params = { :base =>   patron_dn,
            :scope =>  Net::LDAP::SearchScope_BaseObject,
            :attrs =>  ['tokenGroups'] }
          ldap.search(search_params) do |entry|

          # This is a brute-force approach because I can't make sense of LDAP
          # Just match all the attributes of the form 'CN=rg.whatever'
            reference_groups = entry.to_ldif.scan(/CN=(rg.*?),/).flatten
            if reference_groups.include? "rg.cuniv.employee" or reference_groups.include? "rg.cuniv.student"
              return "cornell"
            else
              return "guest"
            end
          end

        end
      end

      # Return a user's distinguished name (dn) from an LDAP lookup
      # This is based heavily on sample Perl code from ss488, CIT, at
      #    https://confluence.cornell.edu/download/attachments/118767666/tokengroups.pl
      def get_ldap_dn netid

        # Login credentials (provided by Desktop Services)
        holding_id_dn = '***REMOVED***'
        holding_pw = '***REMOVED***'

        ldap = bind_ldap
        return unless ldap

        # Do our search
        search_params = { :base => 'DC=cornell,DC=edu',
          :filter => Net::LDAP::Filter.eq('sAMAccountName', netid),
          :attrs => ['distinguishedName'] }
        ldap.search(search_params) do |entry|
          return entry.dn
        end
      end

    end

  end

end