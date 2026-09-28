{{
    config(
        materialized='incremental',
        unique_key='source_record_id',
        incremental_strategy='merge'
    )
}}

-- Registros que no pasan las reglas de calidad, con el motivo en dq_issue.
-- Se guardan para auditoría en lugar de borrarlos en silencio.
select *
from {{ ref('stg_yellow_taxi_trips') }}
where dq_issue is not null
{% if is_incremental() %}
    and loaded_at >= (select coalesce(max(loaded_at), '1900-01-01'::timestamp_ltz) from {{ this }})
{% endif %}
