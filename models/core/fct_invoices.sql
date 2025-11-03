with 
raw_invoices as
(
select * from {{ref('stg_invoices')}}
),

--- convert invoice_created_time and invoice_sent_time from utc to mst and all amount to usd
invoices_in_usd_mst as 
(
select 
account_id,	invoice_id,	
datetime(timestamp(invoice_created_time), "America/Edmonton") as invoice_created_time_mst,   ---- daylight saving aware
datetime(timestamp(invoice_sent_time), "America/Edmonton") as invoice_sent_time_mst,   ---- daylight saving aware
case 
when currency = 'AUD' then round (amount*0.65,0)
when currency = 'CAD' then round (amount*0.72,0)
when currency ='GBP' then round (amount*1.33,0)   
else amount 
end as amount_usd  ---rounded to zero decimal place for uniformity
from raw_invoices
)

select * from invoices_in_usd_mst