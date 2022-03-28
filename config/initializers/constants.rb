module BlacklightCornellRequests
  
  # The strings defined in the DELIVERY_METHODS array are the class names
  # of the actual delivery method definitions.
  DELIVERY_METHODS = %W(
    L2L
    BD
    ILL 
    Hold
    Recall
    PDA
    PurchaseRequest
    AskLibrarian
    AskCirculation
    DocumentDelivery
    MannSpecial
  )
  
  LOAN_TYPES = {
    :nocirc  => 0,
    :minute  => 1,
    :day     => 2,
    :regular => 3
  }

  # This map of request options by item status is taken directly
  # from the FOLIO ui-requests module, requestTypesByItemStatus, at 
  # https://github.com/folio-org/ui-requests/blob/master/src/constants.js
  REQUEST_TYPES_BY_ITEM_STATUS = {
    'Checked out': [:hold, :recall],
    'Available': [:l2l],
    'Awaiting pickup': [:hold, :recall],
    'Awaiting delivery': [:hold, :recall],
    'In transit': [:hold, :recall],
    'Missing': [:hold],
    'Paged': [:hold, :recall],
    'On order': [:hold, :recall],
    'In process': [:hold, :recall]
  }
  
  # STATUSES = {
  #   :not_charged            => 1,
  #   :charged                => 2,
  #   :renewed                => 3,
  #   :overdue                => 4,
  #   :recall_request         => 5,
  #   :hold_request           => 6,
  #   :on_hold                => 7,
  #   :in_transit             => 8,
  #   :in_transit_discharged  => 9,
  #   :in_transit_on_hold     => 10,
  #   :discharged             => 11,
  #   :missing                => 12,
  #   :lost_library_applied   => 13,
  #   :lost_system_applied    => 14,
  #   :lost                   => 26, # means LOST_LIBRARY_APPLIED or LOST_SYSTEM_APPLIED
  #   :claims_returned        => 15,
  #   :damaged                => 16,
  #   :withdrawn              => 17,
  #   :at_bindery             => 18,
  #   :catalog_review         => 19,
  #   :circulation_review     => 20,
  #   :scheduled              => 21,
  #   :in_process             => 22,
  #   :call_slip_request      => 23,
  #   :short_loan_request     => 24,
  #   :remote_storage_request => 25,
  #   :requested              => 27
  # }
  
  OCLC_TYPE_ID = 'OCoLC'
  
  
end