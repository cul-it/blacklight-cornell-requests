requests =
  # Initial setup
  onLoad: () ->
    this.originalPickupList
    this.bindEventListeners()
    this.checkForL2L()
    this.checkForBD()

  # Store original list of pickup locations for use later
  originalPickupList:  $('#pickup-locations').html()

  # Event listeners for all requests. Called on page load
  bindEventListeners: () ->
    # Listeners for request button (submit request)
    $('#requests_button').click ->
      this.preventDefault()
      requests.formSetup()

    $('#req').submit ->
      return false

    # Listener for most types of requests
    $('#request-submit').click ->
      requests.submitForm()
      return false

    # Listener for purchase requests
    $('#purch-request-submit').click ->
      requests.submitPurchaseForm()
      return false

    # ... and for Borrow Direct requests
    $('#bd-request-submit').click ->
      $.fn.spin.presets.requesting =
        lines: 9,
        length: 3,
        width: 2,
        radius: 6,
      $('#request-loading-spinner').spin('requesting')
      requests.submitForm('bd')
      return false

    # Listener for volume selection
    $('#volume-selection').change ->
      $.fn.spin.presets.requesting =
        lines: 9,
        length: 3,
        width: 2,
        radius: 6,
      $('#request-loading-spinner').spin('requesting')
      requestPath = $(this).data('request-path')
      requests.redirectVolume($(this).val(), requestPath)
      return false

  # Event listeners for library to library (l2l) location suppression
  bindPickupEventListeners: () ->
    # Listener for copy selection
    $('.copy-select').change ->
      requests.clearValidation()
      # Use JSON.parse to convert string to array
      excludedPickups = JSON.parse($(this).attr('data-exclude-location'))
      # Save the currently selected pickup location (if any)
      selectedPickup = $('#pickup-locations option:selected').val()

      $('#pickup-locations').html(requests.originalPickupList)
      requests.suppressPickup(excludedPickups, selectedPickup)

    # Listener for pickup location selection
    $('#pickup-locations').change ->
      requests.clearValidation()

  # Confirm we're dealing with a library to library request
  # before firing pickup event listeners
  checkForL2L: () ->
    if $('form#req.l2l-request').length == 1
      this.bindPickupEventListeners()
      this.checkForSingleCopy()

  # If this is a borrow direct request, modify the values in the location select
  # list to use the Borrow Direct location codes instead of CUL codes
  checkForBD: () ->
    if $('form#req.bd-request').length == 1
      options = $('#pickup-locations option')
      options.each (i, element) =>
        bdCode = $(element).data('bd-code')
        # Some options (e.g., faculty office delivery) don't have a corresponding
        # BD code. In those cases, we want to use the original CUL numeric code
        if bdCode
          $(element).val(bdCode)
      $('#pickup-locations').change ->
        $('#bd-request-submit').removeAttr('disabled')

  # When there's only a single copy of an item suppress the pickup location immediately
  # -- don't wait for a change event on .copy-select because it will never happen
  checkForSingleCopy: () ->
    if $('.copy-select').length == 1
      # Use JSON.parse to convert string to array
      excludedPickups = JSON.parse($('.copy-select').attr('data-exclude-location'))
      requests.suppressPickup(excludedPickups)

  # Suppress pickup location based on location of selected copy
  suppressPickup: (excludedPickups, selectedPickup) ->
    $.each excludedPickups, (i, location_id) ->
      # temporary Covid-19 hack for limited pickup locations. We do not want any of these 5 getting removed from the select
      if location_id != 172 and location_id != 159 and location_id != 188 and location_id != 151 and location_id != 157
        console.log(location_id)
        targetedPickup = '#pickup-locations option[value="' + location_id + '"]'
        $(targetedPickup).remove()

      # Track whether one of the excluded pickups was already selected
      if location_id == parseInt(selectedPickup)
        requests.notifyUser()
    # Restore previous selection if it hasn't been excluded
    if selectedPickup?
      $('#pickup-locations').val(selectedPickup)

  # Render flash message if user's selected pickup location was suppressed
  notifyUser: () ->
    requests.scrollToTop()
    $('.flash_messages').html('
      <div class="alert alert-danger">Please select a new pickup location that does not match the copy location.
       <a class="close" data-dismiss="alert" href="#">×</a>
      </div>')

  # Clear flash message
  clearValidation: () ->
    $('.flash_messages').empty()

  # Get initial data for form
  formSetup: () ->
    pathComponents = window.location.pathname.split('/')
    id = pathComponents.pop()
    $.get "/backend/request_item/" + id, (data,status) ->
      $("#requests_button").hide()
      $("#delivery_option").html(data)

  # Submit form via AJAX
  submitForm: (source = '') ->
    hu = $('#req').attr('action')
    reqnna = ''
    reqnna = $('form [name="latest-date"]:radio:checked').val()
    if reqnna  == 'undefined-undefined-undefined'
      reqnna = ''
    $('#bd-request-submit').attr('disabled', 'disabled')
    $.ajax
      type: 'POST',
      data: $('#req').serialize(),
      url:hu,
      success: (data) ->
        $('#request-loading-spinner').spin(false)

        # Ugly special condition wrangling for Borrow Direct messages,
        # which are _mostly_ not treated as ordinary flash messages!
        match = data.match(/Borrow Direct/gi)
        error = data.match(/error/gi)
        if (source == 'bd' && match)
          $('#request-message-well').html(data)
          if (error)
            $('#bd-request-submit').removeAttr('disabled')
        else
          requests.scrollToTop()
          $('.flash_messages').replaceWith(data)

  # Submit purchase form via AJAX
  # -- nac26 2013-04-10: I see no reason why we need both of these submit functions
  # -- will consult with Matt before refactoring
  submitPurchaseForm: () ->
    hu = $('#req').attr('action')
    $.ajax
      type: 'POST',
      data:
        'name':         $('#reqname').val(),
        'email':        $('#reqemail').val(),
        'status':       $('#reqstatus').val(),
        'title':        $('#reqtitle').val(),
        'author':       $('#reqauthor').val(),
        'series':       $('#reqseries').val(),
        'publication':  $('#reqpublication').val(),
        'identifier':   $('#reqidentifier').val(),
        'comments':     $('#reqcomments').val(),
        'notify':       $('#reqnotify').val(),

        "request_action": $("#request_action").val()
      url: hu,
      dataType: 'json',
      success: (data) ->
        st = data.status
        desc = (st == 'success') ? 'succeeded' : 'failed'
        act_desc = ($("#request_action").val() == 'callslip') ? 'delivery' : $("#request_action").val()
        $('#result').html("Your request for " + act_desc + " has " + desc)

  redirectVolume: (selectedVolume, requestPath) ->
    $.ajax
      url: '/request/volume/set',
      data: { volume: selectedVolume }
      success: (data, textStatus, jqXHR) ->
        redirectPath = requestPath# + '/' + selectedVolume
        window.location = redirectPath

  scrollToTop: () ->
    # Make sure we're at the top of the page so the flash messge is visible
    $('html,body').animate({scrollTop:0},0)

$(document).ready ->
  requests.onLoad()
