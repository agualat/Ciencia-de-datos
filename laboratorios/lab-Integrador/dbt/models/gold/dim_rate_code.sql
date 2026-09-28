select rate_code_id, rate_code_name, rate_code_description
from {{ ref('rate_codes') }}
