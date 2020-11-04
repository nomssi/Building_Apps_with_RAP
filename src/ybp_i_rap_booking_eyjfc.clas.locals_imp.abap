CLASS lhc_Booking DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS calculateBookingId FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Booking~calculateBookingId.

    METHODS calculateTotalPrice FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Booking~calculateTotalPrice.

ENDCLASS.

CLASS lhc_Booking IMPLEMENTATION.

  METHOD calculateBookingId.
    DATA max_bookingid TYPE /dmo/booking_id.
    DATA update TYPE TABLE FOR UPDATE yi_rap_Travel_eyjfc\\Booking.

    " Read all travels for the requested bookings
    " If multiple bookings of the same travel are requested, the travel is returned only once.
    READ ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
    ENTITY Booking BY \_Travel
      FIELDS ( TravelUUID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(travels).

    LOOP AT travels INTO DATA(travel).
      READ ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
        ENTITY Travel BY \_Booking
          FIELDS (  BookingID )
        WITH VALUE #(  (  %tky = travel-%tky ) )
        RESULT DATA(bookings).

      " Find max used BookingID in all bookings of this travel
      max_bookingid = '0000'.
      LOOP AT bookings INTO DATA(booking).
        CHECK booking-BookingID > max_bookingid.
        max_bookingid = booking-BookingID.
      ENDLOOP.

      " Provide a booking ID for all booking that have none
      LOOP AT bookings INTO booking WHERE BookingID IS INITIAL.
        max_bookingid += 10.
        APPEND VALUE #( %tky = booking-%tky
                        BookingID = max_bookingid ) TO update.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

  METHOD calculateTotalPrice.

    " Read all travels for the requested bookings
    " If multiple bookings of the same travel are requested, the travel is returned only once.
    READ ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
    ENTITY Booking BY \_Travel
      FIELDS (  TravelUUID )
      WITH CORRESPONDING #( keys )
      RESULT DATA(travels)
      FAILED DATA(read_failed).

   " Trigger calculation of the total price
   MODIFY ENTITIES OF yi_rap_travel_eyjfc IN LOCAL MODE
   ENTITY Travel
     EXECUTE recalcTotalPrice
     FROM CORRESPONDING #( travels )
   REPORTED DATA(execute_reported).

   reported = CORRESPONDING #(  DEEP execute_reported ).

  ENDMETHOD.

ENDCLASS.
