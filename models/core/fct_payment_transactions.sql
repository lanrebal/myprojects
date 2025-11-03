with 
raw_payment_transactions as
(
select * from {{ref('stg_payment_transactions')}}
),

--- convert transaction time from utc to mst and all amount to usd
payment_transactions_in_usd_mst as 
(
select 
account_id,	invoice_id,	transaction_id,		
datetime(timestamp(transaction_time), "America/Edmonton") as transaction_time_mst,   ---- daylight saving aware
payment_method,
case 
when currency = 'AUD' then round (amount*0.65,0)
when currency = 'CAD' then round (amount*0.72,0)
when currency ='GBP' then round (amount*1.33,0)   
else amount 
end as amount_usd  ---rounded to zero decimal place for uniformity
from raw_payment_transactions
)

select * from payment_transactions_in_usd_mst




