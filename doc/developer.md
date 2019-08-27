# Blacklight Requests Developer Documentation

The Requests system is a Rails engine intended to work as a subcomponent of a Blacklight instance (ideally any Blacklight instance, but in practice the code is tightly coupled to Cornell’s custom Blacklight code). This document is intended to help developers understand how it all works and to debug common issues.

## Installation

## Important files

## Important external systems

## Authentication and debugging without SAML
By default, MA uses SAML authentication to authenticate a user and retrieve a netid (see the `authenticate_user` and `user` methods in `my_account_controller.rb`). Since SAML is a little tricky to get up and running on an individual development machine, there is a workaround. If Blacklight/Rails is running in `development` mode, a special key can be added to the Blacklight `.env` file: `DEBUG_USER=<netid>`. (This has no effect if Rails is running in `production` mode, to prevent bad things from happening. This value can also be used to debug the Requests engine.) In that case, SAML authentication is bypassed and MA loads with the account information for the specified netid.
### Debugging tools

## Main event loop

## Common problems