with 
accounts as 
(
select * from {{ref('dim_accounts')}}
),

account_geo as 
(
select * from {{ref('dim_account_geo')}}   
),

account_lifecycle_events as 
(
select * from {{ref('fct_account_lifecycle_events')}}
),

account_event_ranking as
(
select 
account_id,	event_time_mst, lifecycle_state,
dense_rank () over (partition by account_id order by event_time_mst desc) as event_rank
from account_lifecycle_events
),

lastest_event_for_account_with_time as
(
select 
account_id,	 lifecycle_state as current_lifecycle_state , event_time_mst as lifecycle_state_time_mst
from account_event_ranking
where event_rank = 1
)

select 
a.id as account_id,	a.sign_up_time_mst,
extract (year from a.sign_up_time_mst) as sign_up_year,
format_timestamp ('%B', a.sign_up_time_mst) as sign_up_month,
a.sign_up_platform,
b.country,	b.city,	b.region ,
c.current_lifecycle_state , c.lifecycle_state_time_mst,
date_diff(date(c.lifecycle_state_time_mst), date(a.sign_up_time_mst), day) as days_to_current_state
from accounts a 
left outer join account_geo b on a.id = b.account_id
left outer join lastest_event_for_account_with_time c on a.id = c.account_id

