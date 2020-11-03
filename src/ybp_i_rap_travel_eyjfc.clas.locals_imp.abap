CLASS lhc_Travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF travel_status,
        open TYPE c LENGTH 1 VALUE 'O',       " Open
        accepted TYPE c LENGTH 1 VALUE 'A',   " Accepted
        cancelled TYPE c LENGTH 1 VALUE 'X',  " Cancelled
      END OF travel_status.

    METHODS calculateTotalPrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Travel~calculateTotalPrice.

    METHODS calculateTravelID FOR DETERMINE ON SAVE
      IMPORTING keys FOR Travel~calculateTravelID.

    METHODS setInitialStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Travel~setInitialStatus.

    METHODS validateAgency FOR VALIDATE ON SAVE
      IMPORTING keys FOR Travel~validateAgency.

    METHODS validateCustomer FOR VALIDATE ON SAVE
      IMPORTING keys FOR Travel~validateCustomer.

    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR Travel~validateDates.

    METHODS acceptTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~acceptTravel RESULT result.

    METHODS rejectTravel FOR MODIFY
      IMPORTING keys FOR ACTION Travel~rejectTravel RESULT result.

    METHODS recalcTotalPrice FOR MODIFY
      IMPORTING keys FOR ACTION Travel~recalcTotalPrice.

    METHODS get_features FOR FEATURES
      IMPORTING keys REQUEST requested_features FOR Travel RESULT result.

ENDCLASS.

CLASS lhc_Travel IMPLEMENTATION.

  METHOD calculateTotalPrice.
    MODIFY ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
      ENTITY Travel
        EXECUTE recalcTotalPrice
        FROM CORRESPONDING #( keys )
      REPORTED DATA(execute_reported).

    reported = CORRESPONDING #( DEEP execute_reported ).
  ENDMETHOD.

  METHOD calculateTravelID.
    " check if TravelID is already filled
    READ ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
      ENTITY Travel
        FIELDS ( TravelID ) WITH CORRESPONDING #( keys )
    RESULT DATA(travels).

    " Remove lines where TravelID is already filled
    DELETE travels WHERE TravelID IS NOT INITIAL.

    " anything left?
    CHECK travels IS NOT INITIAL.

    " Please note this is just an example for calculating a field during onSave.
    " This approach dies NOT ensure for gap free or unique travel IDs! It just helps to provide a readable ID.
    " The key of this business object is a UUID, calculated by the framework

    " Select max travel ID
    SELECT SINGLE
      FROM yrap_atrav_eyjfc
      FIELDS MAX( travel_id ) AS travelID
      INTO @DATA(max_travelid).

    " Set the travel ID
    MODIFY ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
    ENTITY TRAVEL
      UPDATE
        FROM VALUE #( FOR travel IN travels INDEX INTO i ( %tky = travel-%tky
                                                           TravelID = max_travelid + 1
                                                           %control-TravelID = if_abap_behv=>mk-on ) )
    REPORTED DATA(update_reported).

    reported = CORRESPONDING #( DEEP update_reported ).
  ENDMETHOD.

  METHOD setInitialStatus.
    " Read relevant travel instance data
    READ ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
      ENTITY Travel
        FIELDS ( TravelStatus ) WITH CORRESPONDING #( keys )
    RESULT DATA(travels).

    " Remove all travel instance data with defined status
    DELETE travels WHERE TravelStatus IS NOT INITIAL.
    CHECK travels IS NOT INITIAL.

    " Set default travel status
    MODIFY ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
    ENTITY Travel
      UPDATE
        FIELDS ( TravelStatus )
        WITH VALUE #( FOR travel IN travels
                      (  %tky = travel-%tky
                         TravelStatus = travel_status-open ) )
    REPORTED DATA(update_reported).

    reported = CORRESPONDING #(  DEEP update_reported ).
  ENDMETHOD.

  METHOD validateAgency.
    " Read relevant travel instance data
    READ ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
      ENTITY Travel
        FIELDS ( AgencyId ) WITH CORRESPONDING #( keys )
    RESULT DATA(travels).

    DATA agencies TYPE SORTED TABLE OF /dmo/agency WITH UNIQUE KEY agency_id.

    " Optimization of DB select: extract disctint non-initial agency IDs
    agencies = CORRESPONDING #( travels DISCARDING DUPLICATES MAPPING agency_id = AgencyID EXCEPT * ).
    DELETE agencies WHERE agency_id IS INITIAL.

    IF agencies IS NOT INITIAL.
      " Check if agency ID exist
      SELECT FROM /dmo/agency FIELDS agency_id
        FOR ALL ENTRIES IN @agencies
        WHERE agency_id = @agencies-agency_id
        INTO TABLE @DATA(agencies_db).
    ENDIF.

    " Raise msg for non existing and initial agencyID
    LOOP AT travels INTO DATA(travel).
      " Clear state messages that might exist
      APPEND VALUE #( %tky = travel-%tky
                      %state_area = 'VALIDATE_AGENCY' ) TO reported-travel.

      CHECK travel-AgencyID IS INITIAL OR NOT line_exists( agencies_db[ agency_id = travel-AgencyID ] ).
      APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

      APPEND VALUE #( %tky = travel-%tky
                      %state_area = 'VALIDATE_AGENCY'
                      %msg = NEW ycm_rap_eyjfc( severity = if_abap_behv_message=>severity-error
                                                textid = ycm_rap_eyjfc=>agency_unknown
                                                agencyid = travel-AgencyID )
                      %element-AgencyID = if_abap_behv=>mk-on ) TO reported-travel.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateCustomer.
   " Read relevant travel instance data
    READ ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
      ENTITY Travel
        FIELDS ( CustomerId ) WITH CORRESPONDING #( keys )
    RESULT DATA(travels).

    DATA customers TYPE SORTED TABLE OF /dmo/customer WITH UNIQUE KEY customer_id.

    " Optimization of DB select: extract disctint non-initial customer IDs
    customers = CORRESPONDING #( travels DISCARDING DUPLICATES MAPPING customer_id = CustomerID EXCEPT * ).
    DELETE customers WHERE customer_id IS INITIAL.

    IF customers IS NOT INITIAL.
      " Check if customer ID exist
      SELECT FROM /dmo/customer FIELDS customer_id
        FOR ALL ENTRIES IN @customers
        WHERE customer_id = @customers-customer_id
        INTO TABLE @DATA(customers_db).
    ENDIF.

    " Raise msg for non existing and initial customerID
    LOOP AT travels INTO DATA(travel).
      " Clear state messages that might exist
      APPEND VALUE #( %tky = travel-%tky
                      %state_area = 'VALIDATE_CUSTOMER' ) TO reported-travel.

      CHECK travel-CustomerID IS INITIAL OR NOT line_exists( customers_db[ customer_id = travel-CustomerID ] ).
      APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

      APPEND VALUE #( %tky = travel-%tky
                      %state_area = 'VALIDATE_CUSTOMER'
                      %msg = NEW ycm_rap_eyjfc( severity = if_abap_behv_message=>severity-error
                                                textid = ycm_rap_eyjfc=>customer_unknown
                                                customerid = travel-CustomerID )
                      %element-CustomerID = if_abap_behv=>mk-on ) TO reported-travel.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDates.
   " Read relevant travel instance data
    READ ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
      ENTITY Travel
        FIELDS ( TravelID BeginDate EndDate ) WITH CORRESPONDING #( keys )
    RESULT DATA(travels).

    LOOP AT travels INTO DATA(travel).
      " Clear state messages that might exist
      APPEND VALUE #( %tky = travel-%tky
                      %state_area = 'VALIDATE_DATES' ) TO reported-travel.

      IF travel-EndDate < travel-BeginDate.
        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.
        APPEND VALUE #( %tky = travel-%tky
                        %state_area = 'VALIDATE_DATES'
                        %msg = NEW ycm_rap_eyjfc( severity = if_abap_behv_message=>severity-error
                                                  textid = ycm_rap_eyjfc=>customer_unknown
                                                  begindate = travel-BeginDate
                                                  enddate = travel-EndDate
                                                  travelid = travel-TravelID )
                        %element-BeginDate = if_abap_behv=>mk-on
                        %element-EndDate = if_abap_behv=>mk-on ) TO reported-travel.
     ELSEIF travel-BeginDate < cl_abap_context_info=>get_system_date( ).
        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.
        APPEND VALUE #( %tky = travel-%tky
                        %state_area = 'VALIDATE_DATES'
                        %msg = NEW ycm_rap_eyjfc( severity = if_abap_behv_message=>severity-error
                                                  textid = ycm_rap_eyjfc=>begin_date_before_system_date
                                                  begindate = travel-BeginDate )
                        %element-BeginDate = if_abap_behv=>mk-on ) TO reported-travel.
     ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD acceptTravel.
    " Set the new overall status
    MODIFY ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
      ENTITY Travel
        UPDATE
          FIELDS ( TravelStatus )
          WITH VALUE #(  FOR key IN keys
                 (  %tky = key-%tky
                    TravelStatus = travel_status-accepted ) )
      FAILED failed
      REPORTED reported.
    " Fill the response table
    READ ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
      ENTITY Travel
        ALL FIELDS WITH CORRESPONDING #( keys )
     RESULT data(travels).

    result = VALUE #( FOR travel IN travels
                      (  %tky = travel-%tky
                         %param = travel ) ).
  ENDMETHOD.

  METHOD rejectTravel.
    " Set the new overall status
    MODIFY ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
      ENTITY Travel
        UPDATE
          FIELDS ( TravelStatus )
          WITH VALUE #(  FOR key IN keys
                 (  %tky = key-%tky
                    TravelStatus = travel_status-cancelled ) )
      FAILED failed
      REPORTED reported.
    " Fill the response table
    READ ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
      ENTITY Travel
        ALL FIELDS WITH CORRESPONDING #( keys )
     RESULT data(travels).

    result = VALUE #( FOR travel IN travels
                      (  %tky = travel-%tky
                         %param = travel ) ).
  ENDMETHOD.

  METHOD recalcTotalPrice.
    TYPES: BEGIN OF ts_amount_per_currencycode,
             amount TYPE /dmo/total_price,
             currency_code TYPE /dmo/currency_code,
           END OF ts_amount_per_currencycode.
    "
    DATA amount_per_currencycode TYPE STANDARD TABLE OF ts_amount_per_currencycode.
    " Set the new overall status
    READ ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
      ENTITY Travel
          FIELDS ( BookingFee CurrencyCode )
          WITH CORRESPONDING #( keys )
      RESULT data(travels).

    DELETE travels WHERE CurrencyCode IS INITIAL.

    LOOP AT travels ASSIGNING FIELD-SYMBOL(<travel>).
      " Set the start of the calculation by adding the booking fee
      amount_per_currencycode = VALUE #( ( amount = <travel>-BookingFee
                                           currency_code = <travel>-CurrencyCode ) ).
      " Read all associated bookings and add them to the total price
      READ ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
          ENTITY Travel BY \_Booking
              FIELDS ( FlightPrice CurrencyCode )
              WITH VALUE  #( (  %tky = <travel>-%tky ) )
          RESULT data(bookings).

      LOOP AT bookings INTO DATA(booking) WHERE CurrencyCode IS NOT INITIAL.
        COLLECT VALUE ts_amount_per_currencycode( amount = booking-FlightPrice
                                                  currency_code = booking-CurrencyCode ) INTO amount_per_currencycode.
      ENDLOOP.

      CLEAR <travel>-TotalPrice.
      LOOP AT amount_per_currencycode INTO DATA(single_amount_per_currencycode).
        " If needed do a Currency Conversion
        IF single_amount_per_currencycode-currency_code = <travel>-CurrencyCode.
          <travel>-TotalPrice += single_amount_per_currencycode-amount.
        ELSE.
           /dmo/cl_flight_amdp=>convert_currency(
           EXPORTING iv_amount = single_amount_per_currencycode-amount
                     iv_currency_code_source = single_amount_per_currencycode-currency_code
                     iv_currency_code_target = <travel>-CurrencyCode
                     iv_exchange_rate_date = cl_abap_context_info=>get_system_date( )
          IMPORTING ev_amount = DATA(total_booking_price_per_curr) ).

        <travel>-TotalPrice += total_booking_price_per_curr.
        ENDIF.
      ENDLOOP.

   ENDLOOP.

   " write back the modified total_price of travels
   MODIFY ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
     ENTITY travel
       UPDATE FIELDS ( TotalPrice )
       WITH CORRESPONDING #( travels ).
  ENDMETHOD.

  METHOD get_features.
    " Read the travel status of the existing travels
    READ ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
      ENTITY Travel
          FIELDS ( TravelStatus ) WITH CORRESPONDING #( keys )
      RESULT data(travels)
      FAILED failed.

    result = VALUE #(
      FOR travel IN travels
        LET is_accepted = COND #( WHEN travel-TravelStatus = travel_status-accepted
                                  THEN if_abap_behv=>fc-o-disabled
                                  ELSE if_abap_behv=>fc-o-enabled  )
            is_rejected = COND #( WHEN travel-TravelStatus = travel_status-cancelled
                                  THEN if_abap_behv=>fc-o-disabled
                                  ELSE if_abap_behv=>fc-o-enabled  )
       IN (  %tky = travel-%tky
             %action-acceptTravel = is_accepted
             %action-rejectTravel = is_rejected ) ).

  ENDMETHOD.

ENDCLASS.
