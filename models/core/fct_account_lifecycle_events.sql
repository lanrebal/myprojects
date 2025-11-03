with 
raw_account_lifecycle_events as
(
select * from {{ref('stg_account_lifecycle_events')}}
),

---change the timestamp from utc to mst
account_lifecycle_events_in_mst as  ----with mst time 
(
select 
account_id,
datetime(timestamp(event_time), "America/Edmonton") as event_time_mst,   ---- daylight saving aware
lifecycle_state
from raw_account_lifecycle_events
)

select * from account_lifecycle_events_in_mst