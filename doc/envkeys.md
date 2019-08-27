# Blacklight Requests ENV Key Documentation

(Work in progress)
```
	BORROW_DIRECT_PROD_API_KEY=<API key for Borrow Direct web services>
	BORROW_DIRECT_TEST_API_KEY=<API key for Borrow Direct test web services>
	BORROW_DIRECT_URL=<TEST|PRODUCTION>
	BORROW_DIRECT_TIMEOUT=<Borrow Direct timeout in seconds>
	COOKIE_STORE=<path to local cookie store>
	DUMMY_GET_HOLDS=<URL to Voyager holdings service used for 'dummy' test app>
	DUMMY_SOLR_URL=<URL to Solr instance used for 'dummy' test app>
	DUMMY_VOYAGER_HOLDINGS=<URL to Rick's holdings service used for 'dummy' test app>
	DUMMY_VOYAGER_GET_HOLDS
	VOYAGER_DB=<Voyager identifier for Cornell database>
	VOYAGER_DB_ID=1@#{DB}
	FOD_DB_URL=<URL to special delivery web service> (optional)
	HOLDINGS_URL=<URL to Rick's holdings service> (no longer used?)
	HOLDING_ID_DN=<ID for Cornell's LDAP service>
	HOLDING_PW=<password for Cornell's LDAP service>
	ILLIAD_URL=<URL to the ILLiad forms directory>
	LDAP_HOST=<hostname for Cornell's LDAP service>
	LDAP_PORT=<port number for Cornell's LDAP service>
	MYACC_URL=<URL to the **Voyager** myaccount service>
	NETID_URL=<URL to the patron info/netid lookup service>
	ORACLE_HOST=<Oracle database hostname>
	ORACLE_RDONLY_PASSWORD=<Oracle password>
	ORACLE_SID=<Oracle SID>
	RAILS_ENV=<Rails environment (test, production, etc)>
	REQUEST_URL=<URL for Voyager request services>
	REST_URL=<URL to the Voyager REST services URL>
	TEST_FIRSTNAME=<patron first name used to run tests>
	TEST_LASTNAME=<patron last name used to run tests>
	TEST_NETID=<patron netid used to run tests>
	TEST_NETID_2=<additional netid for tests>
	TEST_REQ_HOLDS=<URL to Voyager patron request service used to run tests>
	TEST_USER_BARCODE=<patron barcode used to run tests>
```