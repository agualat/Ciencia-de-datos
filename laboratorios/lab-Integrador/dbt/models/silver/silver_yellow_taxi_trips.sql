{{
    config(
        materialized='incremental',
        unique_key='trip_id',
        incremental_strategy='merge',
        cluster_by=['to_date(pickup_datetime)']
    )
}}

select *
from {{ ref('stg_yellow_taxi_trips') }}
where dq_issue is null
{% if is_incremental() %}
    and loaded_at >= (select coalesce(max(loaded_at), '1900-01-01'::timestamp_ltz) from {{ this }})
{% endif %}
-- Duplicados exactos: se conserva la primera aparición cargada.
qualify row_number() over (
    partition by trip_id
    order by loaded_at, source_file, file_row_number
) = 1
