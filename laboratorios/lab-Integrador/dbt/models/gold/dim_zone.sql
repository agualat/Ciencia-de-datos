-- Dimensión de rol doble: se usa como zona de subida y de bajada.
select
    location_id,
    borough,
    zone_name,
    service_zone,
    location_id in (1, 132, 138)    as is_airport
from {{ ref('silver_taxi_zones') }}
