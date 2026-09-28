select payment_type_id, payment_type_name, payment_type_description
from {{ ref('payment_types') }}
