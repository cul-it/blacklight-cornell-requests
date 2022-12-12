# Blacklight Requests ENV Key Documentation

(Work in progress)
## Required keys

	COOKIE_STORE=<path to local cookie store>
	DUMMY_GET_HOLDS=<URL to Voyager holdings service used for 'dummy' test app>
	DUMMY_SOLR_URL=<URL to Solr instance used for 'dummy' test app>
	DUMMY_VOYAGER_HOLDINGS=<URL to Rick's holdings service used for 'dummy' test app>
	DUMMY_VOYAGER_GET_HOLDS
	ILLIAD_URL=<URL to the ILLiad forms directory>
	NETID_URL=<URL to the patron info/netid lookup service>
	RAILS_ENV=<Rails environment (test, production, etc)>
	TEST_FIRSTNAME=<patron first name used to run tests>
	TEST_LASTNAME=<patron last name used to run tests>
	TEST_NETID=<patron netid used to run tests>
	TEST_NETID_2=<additional netid for tests>
	TEST_REQ_HOLDS=<URL to Voyager patron request service used to run tests>
	TEST_USER_BARCODE=<patron barcode used to run tests>

	OKAPI_URL=<URL of a FOLIO *Okapi* interface
	OKAPI_TENANT=<Okapi tenant ID>
	OKAPI_USER=<FOLIO username for requests API access>
	OKAPI_PW=<password for FOLIO user>

## Optional keys
`FOD_DB_URL=<URL to special delivery web service> (optional)`

### Deprecated keys (to be removed in future)
	VOYAGER_DB=<Voyager identifier for Cornell database>
	VOYAGER_DB_ID=1@#{DB} 
	HOLDINGS_URL=<URL to Rick's holdings service> (no longer used?)
	HOLDING_ID_DN=<ID for Cornell's LDAP service>
	HOLDING_PW=<password for Cornell's LDAP service>
	LDAP_HOST=<hostname for Cornell's LDAP service>
	LDAP_PORT=<port number for Cornell's LDAP service>
	MYACC_URL=<URL to the **Voyager** myaccount service>
	ORACLE_HOST=<Oracle database hostname>
	ORACLE_RDONLY_PASSWORD=<Oracle password>
	ORACLE_SID=<Oracle SID>
	REQUEST_URL=<URL for Voyager request services>
	REST_URL=<URL to the Voyager REST services URL>
	BORROW_DIRECT_PROD_API_KEY=<API key for Borrow Direct web services>
	BORROW_DIRECT_TEST_API_KEY=<API key for Borrow Direct test web services>
	BORROW_DIRECT_URL=<TEST|PRODUCTION>
	BORROW_DIRECT_TIMEOUT=<Borrow Direct timeout in seconds>

### Disabling services
Most delivery services can be “disabled” (i.e., won’t be offered as choices in the Requests system, though of course this has no effect on the services themselves). This is achieved by adding an appropriate key to the `.env` file. For example, `DISABLE_BORROW_DIRECT=1` will remove Borrow Direct from the equation. The exact key value doesn’t matter so long as it evaluates as `true` using Rails’ `present?` method; thus, it’s best to remove the key-value pair entirely when re-enabling the service.

This feature can be used, for example, if Voyager services should be made temporarily unavailable during a system upgrade.

The service keys that work at present are:
* `DISABLE_BORROW_DIRECT`
* `DISABLE_DOCUMENT_DELIVERY`
* `DISABLE_HOLD`
* `DISABLE_ILL`
* `DISABLE_L2L`
* `DISABLE_MANNSPECIAL`
* `DISABLE_RECALL`

### Modifying behavior
*(NOTE: all of the following will probably be deprecated in the near future; paging limitations are supposedly going away.)*

Library-to-library delivery requests usually are not allowed to be made to the circ desk of the owning library (e.g., books in Olin can't be paged/L2Led to Olin Circ). There are exceptions to this rule (see below), but that's how things normally operate. If for some drastic reason one wants to disable this behavior and allow delivery to own circ desks throughout the entire library system (say, a viral epidemic shutting down normal university life altogether), this can be done by setting the `.env` flag `REQUEST_BYPASS_ROUTING_CHECK=1`. That affects *all* CUL libraries.

Library-to-library paging options can be modified on a case-by-case by adding an especially cryptic key-value pair to the `.env` file. This has the effect of enabling or disabling delivery between specific libraries.

For example: `REQUEST_ROUTING_EXCEPTIONS='g3:d181,d188;g14:a171'`

The value here encodes a set of rules. Each rule is separated by a semicolon; thus, the two rules in this example are `g3:d181,d188`  and `g14:a171`. Each rule consists of a circulation group (beginning with a ‘g’ and separated by a colon) and a comma-separated list of locations and delivery choices. Choices are either ‘a’ (allow) or ‘d’ (deny). 

This probably won’t make much sense without a fuller explanation of circulation groups and delivery locations, but in brief: libraries are divided into different circulation groups. In general, paging/library-to-library delivery is not allowed between libraries within the same circulation group but is allowed between different groups. For example, Olin and Uris libraries are in different groups, but users may not request books from Olin to be delivered to Uris or vice versa. There is a hard-coded exception in `request_policy.rb` that prevents this. On the other hand, items within the Law circulation group _may_ be routed to the Law circulation desk for pickup. There is a similarly hard-coded exception for that rule. In order to avoid hard-coding future exceptions, the `REQUEST_ROUTING_EXCEPTIONS` .env key was created.

The first rule in the example, `g3:d181,d188`, encodes the first exception described above. `g3` is circulation group 3, the Olin circulation group; 181 is the Voyager location code for the Olin circulation desk, and 188 the code for the Uris circulation desk. ‘d’ means disallow, so this rule states that items may not be delivered from Olin to Olin or to Uris. 

The second rule in the example corresponds to the Law exception: `g14:a71`. As you might guess, circulation group 14 is the Law circulation group, and 71 is the location code for the Law circulation desk. In this case, the ‘a’ signals that the circulation desk is an allowable delivery destination for items paged from Law.

Specific location and circulation group codes can be derived from tables in the Voyager database.