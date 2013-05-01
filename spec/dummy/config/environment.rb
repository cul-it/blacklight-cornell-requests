# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Dummy::Application.initialize!

BlacklightCornellRequests.config do |config|
  # URL of service which returns JSON holding info.
  config.voyager_holdings = "http://culsearchdev.library.cornell.edu:8950"
  config.voyager_get_holds= "***REMOVED***/GetHoldingsService"
  
  # URL of service which handles item requests
  config.voyager_request_handler_host = "http://culsearchdev.library.cornell.edu"
  config.voyager_request_handler_port = 8950

  ## URL of metasearch service
  config.borrow_direct_webservices_host = ""
  config.borrow_direct_webservices_port = 9004
end