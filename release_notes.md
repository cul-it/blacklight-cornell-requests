# Release Notes - blacklight-cornell-requests

## v3.0.2
- Fixed a bug causing an "implicit nil conversion" error when a bad target is requested (DISCOVERYACCESS-5293).

## v3.0.1
- Fixed an indentation error in the PDA request view

## v3.0
- Updated code for Blacklight 7. This update is not backwards-compatible (due to use of the protected_attributes/protected_attributes_continued gem).

## v2.2.1
- Added an easier way to switch users for debugging


## v2.2.0
- Added the ability to specify callslip delivery rule exceptions in the .env file (DISCOVERYACCESS-4954)

## v2.1.2
- Fixed a 'bind type not given' error

## v2.1.1

### Bug fixes
- Fixed a bug that allowed some on-reserve items to be requested
- Added nil method protections (DISCOVERYACCESS-4258, DISCOVERYACCESS-4496)
- Made sure @ill_link was populated in request_controller.rb
- Changed parameter names sent to ILL from item view link

## v2.1

### New features
- Added a delivery option for Mann Special Collections reading room (DISCOVERYACCESS-3484)

### Bug fixes
- Added an exception allowing Geneva as a delivery destination for Mann materials (DISCOVERYACCESS-4345)
- Enabled ILL requests for renewed items

## v2.0.3
- Fixed a bug that excluded the Annex as an Annex pickup location
- Added code to handle other delivery location exceptions (Hortorium, Law, Olin/Uris) 
- Fixed a bug that allowed L2L to appear as a delivery option for noncirculating items

## v2.0.2

### Bug fixes
- Delivery locations are now properly excluded in pickup location list (DISCOVERYACCESS-4241; also fixes DISCOVERYACCESS-4235)
- PDA is offered as an option when appropriate (DISCOVERYACCESS-4231)
- Fixed formatting of copy number (DISCOVERYACCESS-4242)

## v2.0.1
- Fixed a bug causing the volume select box to appear when it shouldn't (DISCOVERYACCESS-4224)

## v2.0
This is a major release with three primary improvements:
- Determination of Voyager delivery methods is now aligned with the circ matrix defined in the Voyager DB
- Holdings-related data and item availability are taken from the Solr record, not the deprecated holdings service
- Primary request logic has been completely rewritten to be more efficient and streamlined

## v1.5.5
- Fixed a bug in formation of ILLiad links with ISBNs with additional text; only pass in the first ISBN (DISCOVERYACCESS-4106).

## v1.5.4

### Bug fixes
- Volume selection loop bug was reintroduced by the addition of SAML. Should be fixed now (DISCOVERYACCESS-4006).
- Mann Circulation now appears as a delivery location for Baily Hortorium circulating items (DISCOVERYACCESS-3631).
- Updated error handling.

## v1.5.3

### Improvements
- Support for notes added in Borrow Direct requests (DISCOVERYACCESS-3826)
- When a Borrow Direct request is submitted, a progress spinner appears next to the submit button until the AJAX call is complete (DISCOVERYACCESS-3827)
- ... and the success/failure message now appears below the request button for BD only ...
- ... and the submit button is disabled unless the request fails (DISCOVERYACCESS-3829)
- When offered as secondary request options, ILL and ScanIt now link directly to the
third-party forms (no intermediary request page) (DISCOVERYACCESS-3541)
- Fixed form element alignment of Borrow Direct form on mobile devices (DISCOVERYACCESS-3820)

## v1.5.2

- Borrow Direct pickup location list reworked to remove non-Borrow Direct locations (DISCOVERYACCESS-3830)

## v1.5.1

- FOD program display updated to accommodate enrollment in multiple programs

## v1.5.0

### New features
- Borrow Direct requests can now be placed directly from the requests page (DISCOVERYACCESS-3528)

### Improvements
- ScanIt link now prepopulates data in the request form (DISCOVERYACCESS-3552)
- Policy groups updated for new olin,av location (DISCOVERYACCESS-3447)

## v1.4.3
### Improvements
- Allow operation with SAML

## v1.4.2

### Improvements
- Moved Borrow Direct API parameters (URL, timeout) to .env file for easy adjustment
- Changed ScanIt/Document Delivery delivery estimate to 1-4 days

## v1.4.1

### Enhancements
- Made patron barcode lookup more efficient and speedy

### Bug fixes
- Fixed a bug preventing proper parsing of FOD/remote program query responses

## v1.4.0

### New features
- Adds support for faculty office delivery and special program delivery options using data from the external CUL "Special Delivery" web service (DISCOVERYACCESS-2445, #49)

### Enhancements
- Adds "loading" spinners to volume selection controls to indicate progress during long page load times (DISCOVERYACCESS-2983, #87)
- Volumes in selection list now indicate if they are on reserve or non-circulating (DISCOVERYACCESS-747, #33)

### Bug fixes

## v1.3.2
- Fixed a bug that caused a recall request to loop back to the volume selection screen (DISCOVERYACCESS-2471)

## v1.3.1

### Enhancements
- "Document Delivery" labels changed to "ScanIt" (DISCOVERYACCESS-2705)
- Delivery methods can now be individually disabled by using the ENV file configuration (#80)

### Bug fixes
- Fixed a TypeError bug (DISCOVERYACCESS-2766)
- Fix bug where a single multivol_b item (a bound-with) goes into an endless loop upon request (#74)

## v1.3
- Engine updated for compatibility with Blacklight 6
- Fixed a bug that prevented reserve items from being requested through BD

## v1.2.7
- Fixed a bug preventing reserve items from being requested through Borrow Direct

## v1.2.6
- Added a check for empty circ_policy_locs database table with AppSignal integration

## v1.2.5

### Bug fixes
- Fixed a bug that caused a fatal error if no request options were available for an item
- Fixed a bug in the circ policy database query
- Fixed a bug that made books and recordings at Music unrequestable

## v1.2.4

### Enhancements
- Greatly improved request page load time (DISCOVERYACCESS-2684)
- Added ILL link to volume select screen (DISCOVERYACCESS-2703)
- Restored volume selection via URL parameters (GH #62)
- Document Delivery now appears as an option for periodicals and all Annex items (DISCOVERYACCESS-1257) - Added support for item type 39 ('unbound') (DISCOVERYACCESS-1085 ; GH #36)

### Bug fixes
- Ensured that invalid pickup locations wouldn't appear as options in the location select list ( DISCOVERYACCESS-2682)
- Removed hold option for records without any item records (e.g., current newspapers) (DISCOVERYACCESS-1477)
- Voyager requests (L2L, hold, recall) are now excluded for items at the Music library (DISCOVERYACCESS-1381)

## v1.2.3

### Bug fixes
- RMC items no longer appear in the volume selection list

## v1.2.2

### Enhancements
- Cleaned up markup in request forms
- Updated tests
- Added item location to copy selection view (DISCOVERYACCESS-2278)

### Bug fixes


## v1.2.1
- Improved parsing of ISBNs for Borrow Direct searches

## v1.2

### Enhancements
- Borrow Direct settings have been updated to work with the new BD production database (DISCOVERYACCESS-2006)
- Added an option to route exception notifications (mostly for Borrow Direct) to HipChat

### Bug fixes
- Fixed the broken purchase request submit button (DISCOVERYACCESS-1790)
- Fixed a bug where request comments were not carried through to Voyager (DISCOVERYACCESS-2084)

## v1.1.4

### Bug fixes
- Added Borrow Direct API key and updated to latest version of borrow_direct gem to fix broken BD calling
