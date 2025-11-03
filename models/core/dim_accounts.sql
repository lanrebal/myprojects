with
raw_accounts as
(
select * from {{ref('stg_accounts')}}
),

--- changing the sign_up_time from utc to mst
accounts_in_mst as
(
select
id,
datetime(timestamp(sign_up_time), "America/Edmonton") as sign_up_time_mst,   ---- daylight saving aware
sign_up_platform
from raw_accounts
)

select * from accounts_in_mst