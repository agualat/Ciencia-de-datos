{#
  Los timestamps de Parquet cargados en VARIANT pueden llegar como número epoch
  (segundos, milisegundos, microsegundos o nanosegundos) o como texto.
  Se detecta la unidad por magnitud.
#}
{% macro variant_to_timestamp(expr) %}
    case
        when {{ expr }} is null then null
        when typeof({{ expr }}) in ('INTEGER', 'DECIMAL', 'DOUBLE') then
            case
                when abs({{ expr }}::number(38, 0)) >= 1e17 then to_timestamp_ntz({{ expr }}::number(38, 0), 9)
                when abs({{ expr }}::number(38, 0)) >= 1e14 then to_timestamp_ntz({{ expr }}::number(38, 0), 6)
                when abs({{ expr }}::number(38, 0)) >= 1e11 then to_timestamp_ntz({{ expr }}::number(38, 0), 3)
                else to_timestamp_ntz({{ expr }}::number(38, 0), 0)
            end
        else try_to_timestamp_ntz({{ expr }}::string)
    end
{% endmacro %}

{# Hash estable de varias columnas; los nulos se representan explícitamente. #}
{% macro hash_columns(columns) %}
    md5(concat_ws('|'
    {%- for column in columns %},
        coalesce(to_varchar({{ column }}), '<null>')
    {%- endfor %}
    ))
{% endmacro %}
