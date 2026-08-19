create schema safari_connect;
set search_path to safari_connect;


CREATE TABLE staging_bookings (
    booking_id        TEXT,
    passenger_name     TEXT,
    passenger_phone    TEXT,
    passenger_gender   TEXT,
    passenger_city     TEXT,
    route_code         TEXT,
    route_from         TEXT,
    route_to           TEXT,
    vehicle_plate      TEXT,
    vehicle_type       TEXT,
    driver_name        TEXT,
    driver_rating      TEXT,
    departure_date     TEXT,
    departure_time     TEXT,
    seat_class         TEXT,
    seats_booked       TEXT,
    fare_per_seat      TEXT,
    total_fare         TEXT,
    payment_method     TEXT,
    booking_status     TEXT,
    trip_rating        TEXT
);
TRUNCATE TABLE safari_connect.staging_bookings;

SELECT COUNT(*) FROM safari_connect.staging_bookings;


--=========================================================================
--================================DATA CLEANING============================= 
--=========================================================================


--================================PASSENGER NAME========================
select passenger_name, INITCAP(TRIM(passenger_name))
from safari_connect.staging_bookings;


update safari_connect.staging_bookings 
set passenger_name = INITCAP(TRIM(passenger_name))
where passenger_name is not null;


--=============================PHONE====================================
select  passenger_phone  
from safari_connect.staging_bookings;


-- Normalizing the casing for the passenger_name

update safari_connect.safari_connect_dirty
set passenger_name = Trim(initcap(passenger_name));

-- normalization of the passenger_phone 

update safari_connect.safari_connect_dirty
set passenger_phone  = regexp_replace(passenger_phone,'[^0-9]', '', 'g');

-- strip +254 and append with 0 
update safari_connect.safari_connect_dirty
set passenger_phone = (case 
		when passenger_phone like '254%' then substring(passenger_phone, 4, 9)
		else passenger_phone
	end);

update safari_connect.safari_connect_dirty
set passenger_phone = (
	case 
		when passenger_phone like '7%' then concat('0', passenger_phone)
		else passenger_phone
	end);

-- filling the blanks with null in the phone number column
update safari_connect.safari_connect_dirty
set passenger_phone = (CASE
				        WHEN TRIM(passenger_phone) = '' THEN NULL
				        ELSE passenger_phone
				       END);


-------=========================PHONE NUMBER CLEANING---------------------
WITH cleaned_phone AS (
    SELECT 
        booking_id,
        nullif(regexp_replace(regexp_replace(passenger_phone, '[^0-9]', '', 'g'), '^254', '0'),'') AS cleaned_number
    FROM safari_connect.staging_bookings
)
UPDATE safari_connect.staging_bookings sb
SET passenger_phone = cleaned_phone.cleaned_number
FROM cleaned_phone
WHERE sb.booking_id = cleaned_phone.booking_id;

--=============PASSENGER CITY================

select distinct(passenger_city) from safari_connect.staging.bookings;

update safari_connect.staging_bookings
set passenger_city = NULLIF(INITCAP(TRIM(passenger_city)),'')
where passenger_name is not null;


--=================================GENDER===============================

select 
	case
		when upper(trim(passenger_gender)) in ('M','MALE') then 'Male'
		when upper(trim(passenger_gender)) in ('F','FEMALE') then 'Female'
		else passenger_gender
	end
from safari_connect.staging_bookings;

update safari_connect.staging_bookings
set passenger_gender=
	case
		when upper(trim(passenger_gender)) in ('M','MALE') then 'Male'
		when upper(trim(passenger_gender)) in ('F','FEMALE') then 'Female'
		else passenger_gender
	end;

--=====================SEAT==========================


update safari_connect.staging_bookings
set seat_class = (case
when upper(trim(seat_class)) in ('ECO', 'ECONOMY','ECONOMY CLASS') then 'Economy'
when upper(trim(seat_class)) in ('BUS', 'BUSINESS', 'BUSINESS CLASS') then 'Business'
else seat_class
end);





--==================FARE_PER_SEAT====================================

SELECT fare_per_seat, regexp_replace(fare_per_seat,'[^0-9]', '', 'g') :: numeric
FROM safari_connect.staging_bookings;

update safari_connect.staging_bookings 
set fare_per_seat = regexp_replace(fare_per_seat,'[^0-9]', '', 'g') :: numeric;



--==========================TOTAL FARE===========================


SELECT total_fare, regexp_replace(total_fare,'[^0-9]', '', 'g') :: numeric 
FROM safari_connect.staging_bookings;


update safari_connect.staging_bookings
set total_fare = regexp_replace(total_fare,'[^0-9]', '', 'g') :: numeric;

--===================BOOKING_STATUS=========================

update safari_connect.staging_bookings
set booking_status = (
				case 
		when upper(trim(booking_status)) = 'CANCELLED' then 'Cancelled'
		when upper(trim(booking_status)) = 'NO SHOW' then 'No Show'
		when upper(trim(booking_status)) = 'COMPLETED' then 'Completed'
		else booking_status 
			end)
where booking_status is not null;
select distinct(booking_status) from safari_connect.staging_bookings;


--===================PAYMENT METHOD=============================
update safari_connect.staging_bookings
set payment_method = (case 
					 	when initcap(trim(payment_method)) = 'Card' then 'Card'
					 	when payment_method ilike '%esa' then 'M-Pesa'
					 	when initcap(trim(payment_method)) = 'Cash' then 'Cash'
					 	when trim(payment_method) = '' then null
					 	else payment_method
					 end)
where payment_method is not null;
select distinct(payment_method) from safari_connect.staging_bookings;

--=====================DRIVER'S NAME=============================

update safari_connect.staging_bookings sb 
set driver_name = initcap(trim(driver_name))
where driver_name is not null;


--==============TRIP RATING ==============================
update safari_connect.staging_bookings sb 
set trip_rating = (case 
						when trip_rating in ('0', '6', '7') then null 
						else trip_rating
					end)
where trip_rating is not null;


--============== VEHICLE TYPE================================
update safari_connect.staging_bookings sb 
set vehicle_type = initcap(vehicle_type)
where vehicle_type is not null;
select distinct(vehicle_type) from safari_connect.staging_bookings sb;


--============DELETE NEGATIVE BOOKED SEATS -1===================
delete from safari_connect.staging_bookings 
where seats_booked::int < 0;

-- ========================DELETE EXACT DUPLICATE REMOVAL===================
DELETE FROM safari_connect.staging_bookings 
WHERE ctid NOT IN (
    SELECT MIN(ctid)
    FROM safari_connect.staging_bookings sb 
    GROUP BY booking_id
);

--==========DATE========================================
update safari_connect.staging_bookings sb 
set departure_date = (
    CASE
        -- DD/MM/YYYY
        WHEN departure_date ~ '^\d{2}/\d{2}/\d{4}$'
            THEN TO_DATE(departure_date, 'DD/MM/YYYY')
        -- YYYY-MM-DD
        WHEN departure_date ~ '^\d{4}-\d{2}-\d{2}$'
            THEN TO_DATE(departure_date, 'YYYY-MM-DD')
        -- DD-MM-YY
        WHEN departure_date ~ '^\d{2}-\d{2}-\d{2}$'
            THEN TO_DATE(departure_date, 'DD-MM-YY')
        -- MM-DD-YYYY where middle number is > 12
        WHEN departure_date ~ '^\d{2}-\d{2}-\d{4}$'
             AND SPLIT_PART(departure_date, '-', 2)::INT > 12
            THEN TO_DATE(departure_date, 'MM-DD-YYYY')
        -- DD-MM-YYYY where middle number is <= 12
        WHEN departure_date ~ '^\d{2}-\d{2}-\d{4}$'
             AND SPLIT_PART(departure_date, '-', 2)::INT <= 12
            THEN TO_DATE(departure_date, 'DD-MM-YYYY')
        ELSE NULL
    end)
where departure_date is not null;

alter table safari_connect.booking_safari_staging
alter departure_date type date using departure_date::date;



--=============================================================
--============CREATING PRODUCTION & LOAD CLEAN DATA===========
--==============================================================
CREATE TABLE IF NOT EXISTS safari_connect.bookings (
    booking_id        VARCHAR(10) PRIMARY KEY,
    passenger_name    VARCHAR(100),  passenger_phone  VARCHAR(15),
    passenger_gender  VARCHAR(10),   passenger_city   VARCHAR(60),
    route_code        VARCHAR(10),   route_from       VARCHAR(60),
    route_to          VARCHAR(60),   vehicle_plate    VARCHAR(15),
    vehicle_type      VARCHAR(20),   driver_name      VARCHAR(100),
    driver_rating     NUMERIC(3,1),  departure_date   DATE,
    departure_time    VARCHAR(10),   seat_class       VARCHAR(20),
    seats_booked      INTEGER,       fare_per_seat    NUMERIC(10,2),
    total_fare        NUMERIC(12,2), payment_method   VARCHAR(20),
    booking_status    VARCHAR(20),   trip_rating      INTEGER
);

select * from safari_connect.bookings;

INSERT INTO safari_connect.bookings
SELECT
    booking_id, TRIM(passenger_name),
    NULLIF(TRIM(passenger_phone),''),
    passenger_gender, COALESCE(NULLIF(TRIM(passenger_city),''),'Unknown'),
    route_code, route_from, route_to, vehicle_plate, INITCAP(TRIM(vehicle_type)),
    TRIM(driver_name),
    NULLIF(REGEXP_REPLACE(driver_rating,'[^0-9.]','','g'),'')::NUMERIC,
    departure_date::DATE,  departure_time, seat_class,
    NULLIF(REGEXP_REPLACE(seats_booked,'[^0-9]','','g'),'')::INTEGER,
    NULLIF(REGEXP_REPLACE(fare_per_seat,'[^0-9.]','','g'),'')::NUMERIC,
    NULLIF(REGEXP_REPLACE(total_fare,'[^0-9.]','','g'),'')::NUMERIC,
    payment_method, booking_status,
    NULLIF(trip_rating,'')::INTEGER
FROM safari_connect.staging_bookings 
WHERE departure_date SIMILAR TO '[0-9]{4}-[0-9]{2}-[0-9]{2}'
  AND NULLIF(REGEXP_REPLACE(seats_booked,'[^0-9]','','g'),'')::INTEGER > 0;




















set search_path to safari_connect;

select * from safari_connect.v_trips;

-- ===============================================================================================================================
/*1. ROUTE ANALYSIS
* a) Which routes earn the most?
* b) Which are most popular?
* c) Which is most efficient per seat sold?
* 
* Specific route codes with KES figures. A clear top route and a clear underperformer.
*/

-- 1a) Which routes earn the most?

select 
	route_code, 
	route_from,
	route_to,
	sum(total_fare) as total_revenue
from safari_connect.v_trips
group by route_code, route_from, route_to
order by total_revenue desc;

-- including the seats booked
select 
	route_code, 
	sum(seats_booked) as total_seats_booked, 
	sum(total_fare) as total_revenue
from safari_connect.v_trips
group by route_code
order by total_revenue desc;

-- 1b) Which are most popular?
-- what defines a popular route? no. of seats booked per route? or rating? i doubt. bookings per route?

select 
	route_code,
	route_from,
	route_to,
	sum(seats_booked) as total_seats
from safari_connect.v_trips
group by route_code, route_from, route_to
order by total_seats desc;





-- 1c) Which is most efficient per seat sold?
-- which route makes the most money on average from each seat it sells?
-- revenue/seats

select
	route_code,
	route_from,
	route_to,
	sum(seats_booked) as seats_sold,
	sum(total_fare) as total_revenue,
	round((sum(total_fare) / sum(seats_booked)), 2) as revenue_per_seat
from safari_connect.v_trips
group by route_code, route_from, route_to
order by revenue_per_seat desc;


/*1D - Vehicle type performance
Compare Bus vs Matatu vs Minibus - total bookings, revenue, avg rating.
 Which vehicle type is most profitable?
*/

select
vct.vehicle_type,
sum(vct.seats_booked) as seats_booked,
round(sum(vct.total_fare),2) as total_revenue,
round(avg(vct.trip_rating ),2) as avg_rating
from v_trips vct
group by vehicle_type 
order by total_revenue desc ;

--===================================DRIVER PERFORMANCE===================================================
/*Question 2 - 
Business need: HR wants to know who to promote, who needs training, and whether driver rating affects passenger satisfaction.
2A - DRIVER SUMMARY
Show: driver_name, total_trips, total_seats_carried, total_revenue, avg_trip_rating, driver_rating. Order by total_revenue descending.
*/

select driver_name,
count(route_code) as total_trips,
sum(seats_booked) as total_seats_booked, 
sum(total_fare) as total_revenue,
avg(trip_rating) as avg_trip_rating,
avg(driver_rating) as avg_driver_rating
from safari_connect.v_trips
group by driver_name;


/*2B - Driver ranking - overall + by vehicle type
Using a CTE for driver totals, rank drivers overall by revenue AND within their vehicle type using PARTITION BY vehicle_type.
*/

with driver_totals as (
select  vehicle_type, driver_name,
count(route_code) as total_trips,
sum(seats_booked) as total_seats_booked, 
sum(total_fare) as total_revenue,
avg(trip_rating) as avg_trip_rating,
avg(driver_rating) as avg_driver_rating
from safari_connect.v_trips
group by vehicle_type, driver_name 
)
select driver_name, vehicle_type, total_trips, total_seats_booked, total_revenue, avg_trip_rating, avg_driver_rating,
rank() over (order by total_revenue desc) as driver_rank,
rank() over (partition by vehicle_type order by total_revenue ) as vehicle_rank
from driver_totals
order by driver_rank ;



/*2C - Does driver rating predict passenger satisfaction?
Group drivers into high-rated (≥ 4.5) and standard (< 4.5). Compare average passenger trip_rating for each group. Does a higher driver rating lead to happier passengers?
*/
select 
    driver_name,
    AVG(trip_rating) as avg_trip_rating,
    AVG(driver_rating) as  avg_driver_rating,
    case 
        when  AVG(driver_rating) >= 4.5 then  'High-rated'
        ELSE 'Standard'
    end as driver_group
from  safari_connect.v_trips
group by  driver_name
order by avg_driver_rating desc;


--===========================REVENUE TRENDS=======================================
/*3A - Monthly revenue with month-over-month change (CTE + LAG)*/

select
	travel_month,
	sum(total_fare) as total_revenue
	from safari_connect.v_trips
	group by travel_month ;


with month_totals as (
select
	travel_month,
	sum(total_fare) as total_revenue
	from safari_connect.v_trips
	group by travel_month 
	)
select travel_month,
lag(total_revenue) over (order by travel_month) as prev_month,
total_revenue  - lag(total_revenue ) OVER (ORDER BY travel_month) AS change
from month_totals order by travel_month ;


/*3B - Running total of revenue
Show each month with its revenue and a cumulative running total from January onwards.
*/


select travel_month,
sum(total_fare) as total_revenue,
sum(seats_booked) as total_seats,
count(route_code) as total_trips
from v_trips vt 
group by travel_month
order by travel_month  asc;
	

/*3C - Best and worst 3 months
Using a CTE for monthly revenue, show the top 3 months and 
the bottom 3 months by revenue. Use RANK().
*/
with month_ranks as
(
select travel_month,
sum(total_fare) as total_revenue,
rank() over (order by travel_month desc) as first_three_months,
rank() over (order by travel_month asc ) as last_three_months
from v_trips vt 
group by travel_month
order by travel_month  asc
)
select travel_month, total_revenue, first_three_months, last_three_months
from month_ranks
where first_three_months <= 3 or last_three_months <=3
order by  total_revenue desc;



/*3D - Revenue by route per month (pivot)
Show one row per month with separate columns for the top 3 routes 
(RT001, RT002, RT003) using CASE WHEN + SUM.
*/
select travel_month,
    SUM(CASE
        WHEN route_code = 'RT001' THEN total_fare
        ELSE 0
    END) AS rt001,
    SUM(CASE
        WHEN route_code = 'RT002' THEN total_fare
        ELSE 0
    END) AS rt002,
    SUM(CASE
        WHEN route_code = 'RT003' THEN total_fare
        ELSE 0
    END) AS rt003
FROM safari_connect.v_trips vt 
group by travel_month
ORDER BY travel_month;


--=====================================PASSENGER INSIGHTS==============================
/*4A - Top passenger cities
Show: passenger_city, total_bookings, total_seats, total_revenue, avg_fare. 
Order by total_bookings descending. Only include cities with 3+ bookings.
*/
select passenger_city, 
sum(seats_booked) as total_seats,
count(booking_id) as total_bookings,
sum(total_fare) as total_revenue,
round(avg(total_fare),2) as avg_fare
from v_trips vct 
group by passenger_city 
having count(booking_id) >=3
order by total_bookings desc;

/*4B - Gender split and seat class preference
Show bookings and revenue broken down by passenger_gender and seat_class. 
Use a CASE WHEN pivot to show Economy and Business as separate columns.
*/

select
   passenger_gender,
    -- bookings
    sum(case
        when seat_class = 'economy' then 1
        else 0
    end) as total_bookings_economy,
    sum(case
        when seat_class = 'business' then 1
        else 0
    end) as total_bookings_business,
    --revenue
    sum(case
        when seat_class = 'economy' then total_fare
        else 0
    end) as total_revenue_economy,
    sum(case
        when seat_class = 'business' then total_fare
        else 0
    end) as total_revenue_business
from v_trips
group by passenger_gender;

/*4C - Satisfaction breakdown (CTE)
Using a CTE, count how many trips fall into each satisfaction category
 (Satisfied / Neutral / Unsatisfied / No Rating). Show count and percentage of 
 total completed trips.
*/

with trip_satisfaction as (
    select
        booking_id,
        case
            when trip_rating is null then 'no rating'
            when trip_rating >= 4 then 'satisfied'
            when trip_rating >= 3 then 'neutral'
            else 'unsatisfied'
        end as satisfaction_category
    from v_trips
)
select
    satisfaction_category,
    count(booking_id) as trip_count,
    round(count(booking_id) * 100.0 / sum(count(booking_id)) over (), 1) as pct
from trip_satisfaction
group by satisfaction_category
order by trip_count desc;
    

/*4D - Passenger quartiles by spend (NTILE)
Using a CTE for total spend per passenger, 
divide passengers into 4 quartiles using NTILE(4). 
Show: passenger_name, total_spent, quartile. Label quartile 4 as 'Top Spender'.
*/

select passenger_name, 
sum(total_fare) as total_spending
from v_trips
group by passenger_name ;



with passenger_spendings as 
(
select passenger_name, 
sum(total_fare) as total_spending
from v_trips
group by passenger_name 
),
passenger_quartiles as 
(
select passenger_name, total_spending,
ntile(4) over(order by  total_spending ) as quartile_4
from passenger_spendings 
)
select passenger_name, total_spending,
case 
	when quartile_4 = 4 
	then 'Top Spender'
	else 'quartile' || quartile_4 
end
from passenger_quartiles;



--===========================CANCELLATIONS & LOST REVENUE============================

/*5A - Overall status breakdown*/

SELECT
    booking_status,
    COUNT(booking_id) AS total_bookings,
    SUM(total_fare :: numeric) AS total_revenue,
    ROUND(COUNT(booking_id) * 100.0 / SUM(COUNT(booking_id)) OVER (), 1) AS pct_of_bookings
FROM staging_bookings
GROUP BY booking_status
ORDER BY total_bookings DESC;

/*5B - Cancellation rate by route
Show: route_code, route, total_bookings, completed, cancelled, no_show, 
cancellation_rate_pct.
*/

SELECT
    route_code,
    CONCAT(route_from, '->', route_to) AS route,
    COUNT(booking_id) AS total_bookings,
    sum (case when booking_status = 'Completed' then 1 else 0 end) as completed,
  	sum(case when booking_status = 'Cancelled' then 1 else 0 end) as cancelled,
   	sum(case when booking_status = 'No Show' then 1 else 0 end) as No_show,
   	ROUND(
    sum(case when booking_status = 'cancelled' then 1 else 0 end) * 100.0
    / count(booking_id), 1
) as cancellation_pct
from staging_bookings
group by route_code,route_from, route_to
order by total_bookings desc;

--5C - Revenue lost from cancellations and no-shows

select booking_status, 
sum(total_fare :: numeric) as lost_revenue
from staging_bookings
where booking_status in ('Cancelled', 'No Show')
group by booking_status;


--============================OPERATIONAL PATTERNS=============================

/*6A - Revenue by day of week*/

select day_name,
sum(total_fare) as total_revenue,
sum(seats_booked) as total_seats
from v_trips
group by day_name
order by day_name desc;


/*6B - Busiest departure times
Group by departure_time. Show which time slots carry the most passengers
 and generate the most revenue.
*/

select departure_time,
count(booking_id) as no_of_passengers,
sum(total_fare) as total_revenue
from v_trips 
group by departure_time
order by no_of_passengers desc;


/*6C - Seat utilisation by vehicle type
Compare how full each vehicle type typically runs.
 Show: vehicle_type, avg_seats_booked, and a label - 
 'High Load' if avg > 3, 'Medium Load' if 2-3, 'Low Load' if below 2.
*/


with avg_booked_seats as (
    select
        vehicle_type,
        round(avg(seats_booked), 1) as avg_seats
    from v_trips
    group by vehicle_type
)
select
    vehicle_type,
    avg_seats,
    case
        when avg_seats > 3 then 'high load'
        when avg_seats >= 2 then 'medium load'
        else 'low load'
    end as load_label
from avg_booked_seats
order by avg_seats desc;

--=======================Create Your Views - Hand Off to BI Developer================

-- view 1: route performance (from 1a)
create or replace view v_route_performance as
select
    route_code,
    route_from,
    route_to,
    sum(total_fare) as total_revenue
from safari_connect.v_trips
group by route_code, route_from, route_to
order by total_revenue desc;

-- view 2: driver performance (from 2a)
create or replace view v_driver_performance as
select
    driver_name,
    count(route_code) as total_trips,
    sum(seats_booked) as total_seats_booked,
    sum(total_fare) as total_revenue,
    avg(trip_rating) as avg_trip_rating,
    avg(driver_rating) as avg_driver_rating
from safari_connect.v_trips
group by driver_name
order by total_revenue desc;

-- view 3: monthly revenue trend (from 3a, the cte)
create or replace view v_monthly_revenue as
with month_totals as (
    select
        travel_month,
        sum(total_fare) as total_revenue
    from safari_connect.v_trips
    group by travel_month
)
select
    travel_month,
    total_revenue,
    lag(total_revenue) over (order by travel_month) as prev_month,
    total_revenue - lag(total_revenue) over (order by travel_month) as change
from month_totals
order by travel_month;

-- view 4: cancellation analysis (from 5b)

DROP VIEW v_cancellation_analysis;

CREATE VIEW v_cancellation_analysis AS
SELECT
    route_code,
    CONCAT(route_from, '->', route_to) AS route,
    COUNT(booking_id) AS total_bookings,
    SUM(CASE WHEN booking_status = 'Completed' THEN 1 ELSE 0 END) AS completed,
    SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled,
    SUM(CASE WHEN booking_status = 'No Show' THEN 1 ELSE 0 END) AS no_show,
    ROUND(
        SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0
        / COUNT(booking_id), 1
    ) AS cancellation_pct
FROM staging_bookings
GROUP BY route_code, route_from, route_to
ORDER BY total_bookings DESC;




-- view 5: passenger city insights (from 4a)
create or replace view v_passenger_insights as
select
    passenger_city,
    sum(seats_booked) as total_seats,
    count(booking_id) as total_bookings,
    sum(total_fare) as total_revenue,
    round(avg(total_fare), 2) as avg_fare
from safari_connect.v_trips
group by passenger_city
having count(booking_id) >= 3
order by total_bookings desc;

SELECT * FROM v_route_performance;
SELECT * FROM v_driver_performance;
SELECT * FROM v_monthly_revenue;
SELECT * FROM v_cancellation_analysis;
SELECT * FROM v_passenger_insights;


CREATE VIEW v_satisfaction_breakdown AS
SELECT
    CASE
        WHEN trip_rating IS NULL THEN 'No Rating'
        WHEN trip_rating >= 4 THEN 'Satisfied'
        WHEN trip_rating >= 3 THEN 'Neutral'
        ELSE 'Unsatisfied'
    END AS satisfaction_category,
    COUNT(booking_id) AS trip_count
FROM v_trips
GROUP BY 1;






select distinct vt.vehicle_type  from safari_connect.v_trips vt ;

























