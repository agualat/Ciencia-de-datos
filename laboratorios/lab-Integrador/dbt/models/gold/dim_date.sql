{%- set start = modules.datetime.date.fromisoformat(var('date_start')) -%}
{%- set end = modules.datetime.date.fromisoformat(var('date_end')) -%}
{%- set day_count = (end - start).days + 1 -%}

with days as (

    select dateadd(
        day,
        row_number() over (order by seq4()) - 1,
        '{{ start }}'::date
    ) as date_day
    from table(generator(rowcount => {{ day_count }}))

)

select
    to_number(to_char(date_day, 'YYYYMMDD'))    as date_key,
    date_day,
    year(date_day)                              as year,
    quarter(date_day)                           as quarter,
    month(date_day)                             as month,
    decode(month(date_day),
        1, 'Enero', 2, 'Febrero', 3, 'Marzo', 4, 'Abril', 5, 'Mayo', 6, 'Junio',
        7, 'Julio', 8, 'Agosto', 9, 'Septiembre', 10, 'Octubre', 11, 'Noviembre', 12, 'Diciembre'
    )                                           as month_name,
    to_char(date_day, 'YYYY-MM')                as year_month,
    day(date_day)                               as day_of_month,
    dayofweekiso(date_day)                      as day_of_week,
    decode(dayofweekiso(date_day),
        1, 'Lunes', 2, 'Martes', 3, 'Miércoles', 4, 'Jueves', 5, 'Viernes', 6, 'Sábado', 7, 'Domingo'
    )                                           as day_name,
    weekiso(date_day)                           as week_of_year,
    dayofweekiso(date_day) in (6, 7)            as is_weekend
from days
