with 
account_geo as 
(
select * from {{ ref('stg_account_geo') }}
)

select * from account_geo