with 
raw_invoice_line_items as 
(
select * from {{ref('stg_invoice_line_items')}}
),

invoice_line_items as   
(
select  invoice_id, id, service_type, amount   
from raw_invoice_line_items 
)

select * from invoice_line_items
