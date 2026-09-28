{{ config(materialized='table') }}

select
    try_to_number(trim(location_id))                        as location_id,
    -- TLC usa 'N/A' y 'Unknown' indistintamente; se unifican.
    coalesce(nullif(nullif(trim(borough), 'N/A'), 'Unknown'), 'Unknown')       as borough,
    coalesce(nullif(nullif(trim(zone), 'N/A'), 'Unknown'), 'Unknown')          as zone_name,
    coalesce(nullif(nullif(trim(service_zone), 'N/A'), 'Unknown'), 'Unknown')  as service_zone,
    source_file,
    loaded_at
from {{ source('bronze', 'taxi_zone_lookup') }}
where try_to_number(trim(location_id)) is not null
qualify row_number() over (partition by try_to_number(trim(location_id)) order by loaded_at desc) = 1
