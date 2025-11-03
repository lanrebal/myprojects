with 
invoices as 
(
select * from {{ref('fct_invoices')}}
),

invoice_line_items as 
(
select * from {{ref('fct_invoice_line_items')}}
),

payment_transactions as 
(
select * from {{ref('fct_payment_transactions')}}
),

invoice_line_items_aggregate as 
(
select invoice_id , count (id) as invoice_line_item_count
from invoice_line_items
group by invoice_id
),

payment_amount_aggregation as 
(
select invoice_id, sum (amount_usd) as total_payment_made_usd
from payment_transactions
group by invoice_id
)

select 
a.account_id,	a.invoice_id,	a.invoice_created_time_mst, 	a.invoice_sent_time_mst, 	
date_diff(date(a.invoice_sent_time_mst), date(a.invoice_created_time_mst), day) as days_to_send_invoice,
a.amount_usd as invoice_amount_usd ,
b.invoice_line_item_count,
c.total_payment_made_usd,

case 
when c.total_payment_made_usd is null then 'unpaid'
else 'paid'
end as invoice_status

from invoices a
left outer join invoice_line_items_aggregate b on a.invoice_id = b.invoice_id
left outer join payment_amount_aggregation c on a.invoice_id = c.invoice_id