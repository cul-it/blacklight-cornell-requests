# Blacklight Requests Developer Documentation

The Requests system is a Rails engine intended to work as a subcomponent of a Blacklight instance (ideally any Blacklight instance, but in practice the code is tightly coupled to Cornell’s custom Blacklight code). This document is intended to help developers understand how it all works and to debug common issues.

## Installation
Requests runs as a Rails engine. Assuming a working `blacklight-cornell` instance, Requests can be added by doing the following:
1. In `config/routes.rb`, mount the engine:
	  mount BlacklightCornellRequests::Engine => '/request', :as => 'blacklight_cornell_request'
2. In the root-level `.env` file, add the necessary [key-value pairs](envkeys.md).
Note that some keys are also used by the MyAccount engine.

After restarting the Blacklight server, Requests should be accessible at `/request`.

## Important files

## Important external systems
Requests communicates with FOLIO (to determine whether holds, recalls, and pages can be placed for an item, and to place those types of requests), BorrowDirect, and ILLiad.

## Authentication and debugging without SAML
By default, Requests uses SAML authentication to authenticate a user and retrieve a netid (see the `authenticate_user` and `user` methods in `my_account_controller.rb`). Since SAML is a little tricky to get up and running on an individual development machine, there is a workaround. If Blacklight/Rails is running in `development` mode, a special key can be added to the Blacklight `.env` file: `DEBUG_USER=<netid>`. (This has no effect if Rails is running in `production` mode, to prevent bad things from happening. This value can also be used to debug the MyAccount engine.) In that case, SAML authentication is bypassed and Requests loads with the account information for the specified netid.
### Debugging tools

## Main event loop

## Common problems

## Disabling or modifying services
\<env keys\>
DISABLE_ REQUEST_ROUTING_EXCEPTIONS