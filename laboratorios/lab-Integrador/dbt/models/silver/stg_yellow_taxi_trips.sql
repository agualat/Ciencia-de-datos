{#
  Vista intermedia: extrae el VARIANT de Bronze, tipa, renombra, estandariza
  y marca cada registro con la primera regla de calidad que incumple (dq_issue).
  Las tablas silver_yellow_taxi_trips y silver_yellow_taxi_trips_rejected la consumen.
#}

with source as (

    select * from {{ source('bronze', 'yellow_taxi_trips') }}

),

typed as (

    select
        raw_record,
        try_to_decimal(raw_record:VendorID::string, 38, 0)             as vendor_id,
        {{ variant_to_timestamp("raw_record:tpep_pickup_datetime") }}   as pickup_datetime,
        {{ variant_to_timestamp("raw_record:tpep_dropoff_datetime") }}  as dropoff_datetime,
        try_to_decimal(raw_record:passenger_count::string, 38, 0)      as passenger_count,
        try_to_decimal(raw_record:trip_distance::string, 12, 2)        as trip_distance_miles,
        try_to_decimal(raw_record:RatecodeID::string, 38, 0)           as rate_code_id,
        upper(trim(raw_record:store_and_fwd_flag::string))              as store_and_fwd_flag,
        try_to_decimal(raw_record:PULocationID::string, 38, 0)         as pickup_location_id,
        try_to_decimal(raw_record:DOLocationID::string, 38, 0)         as dropoff_location_id,
        try_to_decimal(raw_record:payment_type::string, 38, 0)         as payment_type_id,
        try_to_decimal(raw_record:fare_amount::string, 12, 2)          as fare_amount,
        try_to_decimal(raw_record:extra::string, 12, 2)                as extra_amount,
        try_to_decimal(raw_record:mta_tax::string, 12, 2)              as mta_tax_amount,
        try_to_decimal(raw_record:tip_amount::string, 12, 2)           as tip_amount,
        try_to_decimal(raw_record:tolls_amount::string, 12, 2)         as tolls_amount,
        try_to_decimal(raw_record:improvement_surcharge::string, 12, 2) as improvement_surcharge_amount,
        try_to_decimal(raw_record:total_amount::string, 12, 2)         as total_amount,
        try_to_decimal(raw_record:congestion_surcharge::string, 12, 2) as congestion_surcharge_amount,
        -- TLC cambió el nombre de la columna entre años (airport_fee / Airport_fee).
        try_to_decimal(coalesce(raw_record:Airport_fee, raw_record:airport_fee)::string, 12, 2) as airport_fee_amount,
        try_to_decimal(raw_record:cbd_congestion_fee::string, 12, 2)   as cbd_congestion_fee_amount,

        source_month,
        source_file,
        file_row_number,
        loaded_at
    from source

),

standardized as (

    select
        vendor_id,
        pickup_datetime,
        dropoff_datetime,
        -- 0 pasajeros no es un viaje real: es un dato no capturado por el conductor.
        nullif(passenger_count, 0)                              as passenger_count,
        trip_distance_miles,
        -- 99 es el código de TLC para "Null/unknown".
        coalesce(rate_code_id, 99)                              as rate_code_id,
        case store_and_fwd_flag
            when 'Y' then true
            when 'N' then false
        end                                                     as is_store_and_forward,
        pickup_location_id,
        dropoff_location_id,
        payment_type_id,
        fare_amount,
        -- Los cargos son componentes aditivos de total_amount: ausente = no cobrado.
        coalesce(extra_amount, 0)                               as extra_amount,
        coalesce(mta_tax_amount, 0)                             as mta_tax_amount,
        coalesce(tip_amount, 0)                                 as tip_amount,
        coalesce(tolls_amount, 0)                               as tolls_amount,
        coalesce(improvement_surcharge_amount, 0)               as improvement_surcharge_amount,
        total_amount,
        coalesce(congestion_surcharge_amount, 0)                as congestion_surcharge_amount,
        coalesce(airport_fee_amount, 0)                         as airport_fee_amount,
        coalesce(cbd_congestion_fee_amount, 0)                  as cbd_congestion_fee_amount,
        datediff('second', pickup_datetime, dropoff_datetime) / 60.0 as trip_duration_minutes,
        -- Distingue un valor ausente de uno presente que no se pudo convertir.
        (raw_record:VendorID is not null and vendor_id is null)
          or (raw_record:passenger_count is not null and passenger_count is null)
          or (raw_record:trip_distance is not null and trip_distance_miles is null)
          or (raw_record:RatecodeID is not null and rate_code_id is null)
          or (raw_record:PULocationID is not null and pickup_location_id is null)
          or (raw_record:DOLocationID is not null and dropoff_location_id is null)
          or (raw_record:payment_type is not null and payment_type_id is null)
          or (raw_record:fare_amount is not null and fare_amount is null)
          or (raw_record:extra is not null and extra_amount is null)
          or (raw_record:mta_tax is not null and mta_tax_amount is null)
          or (raw_record:tip_amount is not null and tip_amount is null)
          or (raw_record:tolls_amount is not null and tolls_amount is null)
          or (raw_record:improvement_surcharge is not null and improvement_surcharge_amount is null)
          or (raw_record:total_amount is not null and total_amount is null)
          or (raw_record:congestion_surcharge is not null and congestion_surcharge_amount is null)
          or (coalesce(raw_record:Airport_fee, raw_record:airport_fee) is not null and airport_fee_amount is null)
          or (raw_record:cbd_congestion_fee is not null and cbd_congestion_fee_amount is null)
                                                                as has_invalid_numeric,

        source_month,
        source_file,
        file_row_number,
        loaded_at
    from typed

)

select
    -- Identidad del viaje por contenido: dos filas idénticas son el mismo viaje.
    {{ hash_columns([
        'vendor_id', 'pickup_datetime', 'dropoff_datetime', 'passenger_count',
        'trip_distance_miles', 'rate_code_id', 'pickup_location_id', 'dropoff_location_id',
        'payment_type_id', 'fare_amount', 'extra_amount', 'mta_tax_amount', 'tip_amount',
        'tolls_amount', 'improvement_surcharge_amount', 'total_amount',
        'congestion_surcharge_amount', 'airport_fee_amount', 'cbd_congestion_fee_amount',
        'is_store_and_forward'
    ]) }}                                                       as trip_id,
    -- Identidad física del registro en Bronze.
    {{ hash_columns(['source_file', 'file_row_number']) }}      as source_record_id,
    *,
    case
        when has_invalid_numeric then 'invalid_numeric'
        when pickup_datetime is null or dropoff_datetime is null
            then 'missing_timestamp'
        when to_char(pickup_datetime, 'YYYY-MM') <> source_month
            then 'pickup_outside_source_month'
        when dropoff_datetime <= pickup_datetime
            then 'non_positive_duration'
        when trip_duration_minutes > 24 * 60
            then 'duration_over_24h'
        when pickup_location_id is null or pickup_location_id not between 1 and 265
          or dropoff_location_id is null or dropoff_location_id not between 1 and 265
            then 'invalid_location'
        when trip_distance_miles is null or trip_distance_miles < 0
            then 'invalid_distance'
        when trip_distance_miles > 500
            then 'distance_over_500_miles'
        when fare_amount is null or total_amount is null
            then 'missing_amount'
        when fare_amount < 0 or total_amount < 0
            then 'negative_amount'
    end                                                         as dq_issue
from standardized
