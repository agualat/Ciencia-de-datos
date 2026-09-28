-- Una fila por minuto del día (1440 filas). time_key = HHMM.
with minutes as (

    select row_number() over (order by seq4()) - 1 as minute_of_day
    from table(generator(rowcount => 1440))

)

select
    floor(minute_of_day / 60) * 100 + mod(minute_of_day, 60)       as time_key,
    floor(minute_of_day / 60)                                       as hour,
    mod(minute_of_day, 60)                                          as minute,
    lpad(floor(minute_of_day / 60), 2, '0') || ':' || lpad(mod(minute_of_day, 60), 2, '0') as time_label,
    case
        when floor(minute_of_day / 60) between 0 and 5 then 'Madrugada'
        when floor(minute_of_day / 60) between 6 and 11 then 'Mañana'
        when floor(minute_of_day / 60) between 12 and 17 then 'Tarde'
        else 'Noche'
    end                                                             as day_period,
    floor(minute_of_day / 60) in (7, 8, 9, 16, 17, 18, 19)          as is_rush_hour
from minutes
