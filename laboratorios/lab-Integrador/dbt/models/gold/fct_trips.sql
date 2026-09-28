{{
    config(
        materialized='incremental',
        unique_key='trip_id',
        incremental_strategy='merge',
        cluster_by=['pickup_date_key']
    )
}}

-- Grano: un viaje válido de taxi amarillo.

with trips as (

    select * from {{ ref('silver_yellow_taxi_trips') }}
    {% if is_incremental() %}
    where loaded_at >= (select coalesce(max(loaded_at), '1900-01-01'::timestamp_ltz) from {{ this }})
    {% endif %}

)

select
    trips.trip_id,

    -- Foreign keys
    to_number(to_char(trips.pickup_datetime, 'YYYYMMDD'))       as pickup_date_key,
    hour(trips.pickup_datetime) * 100 + minute(trips.pickup_datetime)   as pickup_time_key,
    to_number(to_char(trips.dropoff_datetime, 'YYYYMMDD'))      as dropoff_date_key,
    hour(trips.dropoff_datetime) * 100 + minute(trips.dropoff_datetime) as dropoff_time_key,
    trips.pickup_location_id,
    trips.dropoff_location_id,
    -- Códigos fuera del diccionario de TLC apuntan al miembro desconocido (-1).
    coalesce(vendors.vendor_id, -1)                             as vendor_id,
    coalesce(payment_types.payment_type_id, -1)                 as payment_type_id,
    coalesce(rate_codes.rate_code_id, -1)                       as rate_code_id,

    -- Atributos degenerados
    trips.pickup_datetime,
    trips.dropoff_datetime,
    trips.is_store_and_forward,

    -- Métricas
    trips.passenger_count,
    trips.trip_distance_miles,
    trips.trip_duration_minutes,
    trips.fare_amount,
    trips.extra_amount,
    trips.mta_tax_amount,
    trips.tip_amount,
    trips.tolls_amount,
    trips.improvement_surcharge_amount,
    trips.congestion_surcharge_amount,
    trips.airport_fee_amount,
    trips.cbd_congestion_fee_amount,
    trips.total_amount,

    -- Linaje
    trips.source_month,
    trips.source_file,
    trips.loaded_at
from trips
left join {{ ref('dim_vendor') }} as vendors
    on trips.vendor_id = vendors.vendor_id
left join {{ ref('dim_payment_type') }} as payment_types
    on trips.payment_type_id = payment_types.payment_type_id
left join {{ ref('dim_rate_code') }} as rate_codes
    on trips.rate_code_id = rate_codes.rate_code_id
