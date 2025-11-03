{{ config(
    materialized='table'
) }}

with trading_data as (
    select distinct
        *
    from public.trading_data_staging
),
first_last_times as (
    select 
        to_char(open_time, 'YYYY-MM-DD') as day,
        EXTRACT(HOUR FROM open_time) as hour,
        MIN(open_time) as first_time_for_hour,
        MAX(open_time) as last_time_for_hour
    from trading_data
    group by day, hour
)
select
    fl.day,
    fl.hour,

    case
        when fl.hour = 0 then '12:00 AM to 12:59 AM'
        when fl.hour = 1 then '1:00 AM to 1:59 AM'
        when fl.hour = 2 then '2:00 AM to 2:59 AM'
        when fl.hour = 3 then '3:00 AM to 3:59 AM'
        when fl.hour = 4 then '4:00 AM to 4:59 AM'
        when fl.hour = 5 then '5:00 AM to 5:59 AM'
        when fl.hour = 6 then '6:00 AM to 6:59 AM'
        when fl.hour = 7 then '7:00 AM to 7:59 AM'
        when fl.hour = 8 then '8:00 AM to 8:59 AM'
        when fl.hour = 9 then '9:00 AM to 9:59 AM'
        when fl.hour = 10 then '10:00 AM to 10:59 AM'
        when fl.hour = 11 then '11:00 AM to 11:59 AM'
        when fl.hour = 12 then '12:00 PM to 12:59 PM'
        when fl.hour = 13 then '1:00 PM to 1:59 PM'
        when fl.hour = 14 then '2:00 PM to 2:59 PM'
        when fl.hour = 15 then '3:00 PM to 3:59 PM'
        when fl.hour = 16 then '4:00 PM to 4:59 PM'
        when fl.hour = 17 then '5:00 PM to 5:59 PM'
        when fl.hour = 18 then '6:00 PM to 6:59 PM'
        when fl.hour = 19 then '7:00 PM to 7:59 PM'
        when fl.hour = 20 then '8:00 PM to 8:59 PM'
        when fl.hour = 21 then '9:00 PM to 9:59 PM'
        when fl.hour = 22 then '10:00 PM to 10:59 PM'
        when fl.hour = 23 then '11:00 PM to 11:59 PM'
    end as hour_details,

    fl.first_time_for_hour,
    b1.open as open_price_for_hour,

    fl.last_time_for_hour,
    b2.close as close_price_for_hour,

    (b2.close - b1.open ) as gain_or_loss_for_hour

from first_last_times fl

left join trading_data b1
    on fl.first_time_for_hour = b1.open_time

left join trading_data b2
    on fl.last_time_for_hour = b2.open_time