CLASS ycl_rap_eml_eyjfc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.

  PRIVATE SECTION.
    DATA out TYPE REF TO if_oo_adt_classrun_out.
    "DATA lt_uuid TYPE STANDARD TABLE OF sysuuid_x16.
    DATA mt_uuid TYPE TABLE FOR READ IMPORT YI_RAP_Travel_eyjfc.

    METHODS simple_read.
    METHODS read_with_fields.
    METHODS read_all_fields.
    METHODS read_by_association.
    METHODS read_unsuccessfull.
    METHODS modify_update.
    METHODS modify_create.
    METHODS modify_delete.
ENDCLASS.



CLASS ycl_rap_eml_eyjfc IMPLEMENTATION.


  METHOD simple_read.
     " step 1 - READ
     READ ENTITIES OF YI_RAP_Travel_eyjfc
       ENTITY Travel
         from mt_uuid
       RESULT data(travels).
     out->write( travels ).
  ENDMETHOD.

  METHOD read_with_fields.
     " step 2 - READ with Fields
     READ ENTITIES OF YI_RAP_Travel_eyjfc
       ENTITY Travel
         FIELDS ( AgencyID CustomerID )
         with mt_uuid
       RESULT data(travels).
     out->write( travels ).
  ENDMETHOD.

  METHOD read_all_fields.
     " step 3 - READ with All Fields
     READ ENTITIES OF YI_RAP_Travel_eyjfc
       ENTITY Travel
         ALL FIELDS
         with mt_uuid
       RESULT data(travels).
     out->write( travels ).
  ENDMETHOD.

  METHOD read_by_association.
     " step 4 - READ by Association
     DATA lt_uuid TYPE TABLE FOR READ IMPORT YI_RAP_Travel_eyjfc\_Booking.

     lt_uuid = CORRESPONDING #( mt_uuid ).
     READ ENTITIES OF YI_RAP_Travel_eyjfc
       ENTITY Travel BY \_Booking
         ALL FIELDS with lt_uuid
       RESULT data(bookings).
     out->write( bookings ).
  ENDMETHOD.

  METHOD read_unsuccessfull.
     " step 5 - Unsuccessfull READ
     READ ENTITIES OF YI_RAP_Travel_eyjfc
       ENTITY Travel
         ALL FIELDS
         with VALUE #( ( TravelUUID = '123219024042302340232302302' ) )
       RESULT data(travels)
       FAILED data(failed)
       REPORTED data(reported).

     out->write( travels ).
     out->write( failed ).   " complex structures not supported by the console output
     out->write( reported ). " complex structures not supported by the console output
  ENDMETHOD.

  METHOD modify_update.
     " step 6 - MODIFY UPDATE
     MODIFY ENTITIES OF YI_RAP_Travel_eyjfc
       ENTITY Travel
         UPDATE
           SET FIELDS WITH VALUE
             #(  (  TravelUUID = mt_uuid[ 1 ]-TravelUUID
                    Description = 'I like RAP@openSAP'  ) )
       FAILED data(failed)
       REPORTED data(reported).

     out->write( 'Update done' ).
     " step 6b - Commit Entities
     COMMIT ENTITIES
       RESPONSE OF Yi_RAP_TRavel_eyjfc
       FAILED Data(failed_commit)
       REPORTED Data(reported_commit).
  ENDMETHOD.

  METHOD modify_create.
     " step 7 - MODIFY CREATE
     MODIFY ENTITIES OF YI_RAP_Travel_eyjfc
       ENTITY Travel
         CREATE
           SET FIELDS WITH VALUE
             #(  (  %cid = 'MyContentID_1'
                    AgencyID = '70012'
                    CustomerID = '14'
                    BeginDate = cl_abap_context_info=>get_system_date( )
                    EndDate = cl_abap_context_info=>get_system_date( ) + 10
                    Description = 'I like RAP@openSAP'  ) )
       MAPPED data(mapped)
       FAILED data(failed)
       REPORTED data(reported).

     out->write( mapped-travel ).
     " step 7b - Commit Entities
     COMMIT ENTITIES
       RESPONSE OF Yi_RAP_TRavel_eyjfc
       FAILED Data(failed_commit)
       REPORTED Data(reported_commit).

     out->write( 'Create done' ).
  ENDMETHOD.

  METHOD modify_delete.
     " step 8 - MODIFY CREATE
     MODIFY ENTITIES OF YI_RAP_Travel_eyjfc
       ENTITY Travel
         DELETE FROM
           VALUE
             #( ( TravelUUID  = 'MyContentID_1'  ) )
       FAILED data(failed)
       REPORTED data(reported).

     COMMIT ENTITIES
       RESPONSE OF Yi_RAP_TRavel_eyjfc
       FAILED Data(failed_commit)
       REPORTED Data(reported_commit).

     out->write( 'Delete done' ).
  ENDMETHOD.

  METHOD if_oo_adt_classrun~main.
     me->out = out.
     mt_uuid = VALUE #( ( TravelUUID = 'BD400EF0733C49481700090256409A63' ) ).
     "simple_read( ).
     "read_with_fields( ).
     "read_all_fields( ).
     "read_by_association( ).
     "read_unsuccessfull( ).
     "modify_update( ).
     "modify_create( ).
     modify_delete( ).
  ENDMETHOD.



ENDCLASS.
