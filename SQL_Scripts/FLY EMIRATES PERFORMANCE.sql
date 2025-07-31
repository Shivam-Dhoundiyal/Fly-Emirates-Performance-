CREATE TABLE flights (
    YEAR INT,
    MONTH INT,
    DAY INT,
    DAY_OF_WEEK INT,
    AIRLINE VARCHAR(10),
    FLIGHT_NUMBER VARCHAR(10),
    TAIL_NUMBER VARCHAR(20),
    ORIGIN_AIRPORT VARCHAR(10),
    DESTINATION_AIRPORT VARCHAR(10),
    SCHEDULED_DEPARTURE INT,
    DEPARTURE_TIME INT,
    DEPARTURE_DELAY INT,
    TAXI_OUT INT,
    WHEELS_OFF INT,
    SCHEDULED_TIME INT,
    ELAPSED_TIME INT,
    AIR_TIME INT,
    DISTANCE INT,
    WHEELS_ON INT,
    TAXI_IN INT,
    SCHEDULED_ARRIVAL INT,
    ARRIVAL_TIME INT,
    ARRIVAL_DELAY INT,
    DIVERTED INT,
    CANCELLED INT,
    CANCELLATION_REASON VARCHAR(5),
    AIR_SYSTEM_DELAY INT,
    SECURITY_DELAY INT,
    AIRLINE_DELAY INT,
    LATE_AIRCRAFT_DELAY INT,
    WEATHER_DELAY INT,
    FLIGHT_DATE DATE,
    SCHEDULED_DEPARTURE_TIME TIME,
    CANCELLATION_REASON_DESC VARCHAR(50)
);

CREATE TABLE airlines (
    iata_code VARCHAR(10) PRIMARY KEY,
    airline VARCHAR(100)
);

CREATE TABLE airports (
    iata_code VARCHAR(10) PRIMARY KEY,
    airport VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(10),
    country VARCHAR(50),
    latitude FLOAT,
    longitude FLOAT
);



select count(*) from flights;

ALTER TABLE flights ADD COLUMN flight_date DATE;

UPDATE flights
SET flight_date = TO_DATE(
    CONCAT(year, '-', LPAD(month::text, 2, '0'), '-', LPAD(day::text, 2, '0')),
    'YYYY-MM-DD'
)
WHERE flight_date IS NULL;


ALTER TABLE flights ADD COLUMN scheduled_departure_time TIME;

UPDATE flights
SET scheduled_departure_time = TO_TIMESTAMP(LPAD(scheduled_departure::text, 4, '0'), 'HH24MI')::TIME
WHERE scheduled_departure_time IS NULL;

UPDATE flights SET air_system_delay = 0 WHERE air_system_delay IS NULL;
UPDATE flights SET security_delay = 0 WHERE security_delay IS NULL;
UPDATE flights SET airline_delay = 0 WHERE airline_delay IS NULL;
UPDATE flights SET late_aircraft_delay = 0 WHERE late_aircraft_delay IS NULL;
UPDATE flights SET weather_delay = 0 WHERE weather_delay IS NULL;


ALTER TABLE flights ADD COLUMN cancellation_reason_desc VARCHAR(50);

UPDATE flights
SET cancellation_reason_desc = 
    CASE cancellation_reason
        WHEN 'A' THEN 'Carrier'
        WHEN 'B' THEN 'Weather'
        WHEN 'C' THEN 'NAS (National Air System)'
        WHEN 'D' THEN 'Security'
        ELSE NULL
    END
WHERE cancellation_reason_desc IS NULL;

-- -----------------------------------------------------------
-- I. EDA: Flight Volume, Cancellations, Diversions
-- -----------------------------------------------------------
-- 1. Total number of flights in the dataset
SELECT COUNT(*) AS total_flights
FROM flights;

-- 2a. Total number of cancelled flights
SELECT COUNT(*) AS total_cancellations
FROM flights
WHERE CANCELLED = 1;

-- 2b. Cancellations grouped by reason (with descriptive labels)
SELECT 
    CANCELLATION_REASON_DESC,
    COUNT(*) AS cancellations
FROM flights
WHERE CANCELLED = 1
GROUP BY CANCELLATION_REASON_DESC;

-- 3. Total number of diverted flights
SELECT COUNT(*) AS total_diverted
FROM flights
WHERE DIVERTED = 1;


-- -----------------------------------------------------------
-- II. Delay Analysis – Departure & Arrival
-- -----------------------------------------------------------
-- 4. Summary of departure delays: average, min, max
SELECT
    ROUND(AVG(DEPARTURE_DELAY), 2) AS avg_departure_delay,
    MIN(DEPARTURE_DELAY) AS min_departure_delay,
    MAX(DEPARTURE_DELAY) AS max_departure_delay
FROM flights
WHERE DEPARTURE_DELAY IS NOT NULL;

-- 5. Summary of arrival delays: average, min, max
SELECT
    ROUND(AVG(ARRIVAL_DELAY), 2) AS avg_arrival_delay,
    MIN(ARRIVAL_DELAY) AS min_arrival_delay,
    MAX(ARRIVAL_DELAY) AS max_arrival_delay
FROM flights
WHERE ARRIVAL_DELAY IS NOT NULL;


-- -----------------------------------------------------------
-- III. Delay Type Distribution
-- -----------------------------------------------------------
-- 6. Total minutes lost due to each delay type
SELECT
    ROUND(SUM(AIRLINE_DELAY), 0) AS airline_delay,
    ROUND(SUM(LATE_AIRCRAFT_DELAY), 0) AS late_aircraft_delay,
    ROUND(SUM(AIR_SYSTEM_DELAY), 0) AS air_system_delay,
    ROUND(SUM(SECURITY_DELAY), 0) AS security_delay,
    ROUND(SUM(WEATHER_DELAY), 0) AS weather_delay
FROM flights;

-- -----------------------------------------------------------
-- IV. Key Performance Indicators (KPIs)
-- -----------------------------------------------------------
-- 7. On-Time Performance (OTP): % of flights arriving ≤15 mins late
SELECT 
    ROUND(SUM(CASE WHEN ARRIVAL_DELAY <= 15 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS otp_rate_percent
FROM flights
WHERE CANCELLED = 0 AND ARRIVAL_DELAY IS NOT NULL;


-- 8. Avg Arrival & Departure Delays (only for non-cancelled flights)
SELECT
    ROUND(AVG(ARRIVAL_DELAY), 2) AS avg_arrival_delay,
    ROUND(AVG(DEPARTURE_DELAY), 2) AS avg_departure_delay
FROM flights
WHERE CANCELLED = 0;

-- 9. Overall Cancellation Rate
SELECT 
    ROUND(SUM(CAST(CANCELLED AS INTEGER)) * 100.0 / COUNT(*), 2) AS cancellation_rate_percent
FROM flights;

SELECT 
    SUM(AIRLINE_DELAY),
    SUM(LATE_AIRCRAFT_DELAY),
    SUM(AIR_SYSTEM_DELAY),
    SUM(SECURITY_DELAY),
    SUM(WEATHER_DELAY)
FROM flights;

-- 10. % contribution of each delay type
-- Calculates percentage share of each delay type from total delay time
WITH total_delays AS (
    SELECT 
        SUM(CAST(AIRLINE_DELAY AS INTEGER)) AS airline,
        SUM(CAST(LATE_AIRCRAFT_DELAY AS INTEGER)) AS late_aircraft,
        SUM(CAST(AIR_SYSTEM_DELAY AS INTEGER)) AS air_system,
        SUM(CAST(SECURITY_DELAY AS INTEGER)) AS security,
        SUM(CAST(WEATHER_DELAY AS INTEGER)) AS weather
    FROM flights
),
delay_sum AS (
    SELECT 
        (airline + late_aircraft + air_system + security + weather) AS total_delay,
        airline, late_aircraft, air_system, security, weather
    FROM total_delays
)
SELECT 'Airline' AS delay_type, ROUND(airline * 100.0 / total_delay, 2) AS percentage FROM delay_sum
UNION
SELECT 'Late Aircraft', ROUND(late_aircraft * 100.0 / total_delay, 2) FROM delay_sum
UNION
SELECT 'Air System', ROUND(air_system * 100.0 / total_delay, 2) FROM delay_sum
UNION
SELECT 'Security', ROUND(security * 100.0 / total_delay, 2) FROM delay_sum
UNION
SELECT 'Weather', ROUND(weather * 100.0 / total_delay, 2) FROM delay_sum;

-- -----------------------------------------------------------
-- V. Aggregation by Airline, Airport, Time
-- -----------------------------------------------------------
-- 11. KPI Breakdown by Airline:
-- Shows: OTP %, Avg Arrival Delay, Avg Departure Delay, Cancellation Rate
SELECT 
    AIRLINE,
    
    -- On-Time Performance: % of flights arriving within 15 minutes of schedule (excluding cancelled)
    ROUND(SUM(CASE 
              WHEN CANCELLED = 0 AND ARRIVAL_DELAY <= 15 THEN 1 
              ELSE 0 END) * 100.0 / COUNT(*), 2) AS otp_percent,
    
    -- Average arrival delay in minutes
    ROUND(AVG(ARRIVAL_DELAY), 2) AS avg_arrival_delay,
    
    -- Average departure delay in minutes
    ROUND(AVG(DEPARTURE_DELAY), 2) AS avg_departure_delay,
    
    -- Cancellation rate (% of cancelled flights)
    ROUND(SUM(CANCELLED) * 100.0 / COUNT(*), 2) AS cancellation_percent

FROM flights
GROUP BY AIRLINE
ORDER BY otp_percent DESC;


-- 12. KPIs grouped by origin airport
SELECT 
    a.airport AS origin_airport_name,
    f.ORIGIN_AIRPORT,
    ROUND(AVG(f.ARRIVAL_DELAY), 2) AS avg_arrival_delay,
    ROUND(AVG(f.DEPARTURE_DELAY), 2) AS avg_departure_delay,
    ROUND(SUM(f.CANCELLED)::decimal / COUNT(*) * 100, 2) AS cancellation_percent
FROM flights f
JOIN airports a ON f.ORIGIN_AIRPORT = a.IATA_CODE
GROUP BY a.airport, f.ORIGIN_AIRPORT
ORDER BY avg_arrival_delay DESC;


-- 13. KPIs by Month
SELECT 
    MONTH,
    ROUND(AVG(ARRIVAL_DELAY), 2) AS avg_arrival_delay,
    ROUND(AVG(DEPARTURE_DELAY), 2) AS avg_departure_delay,
    ROUND(SUM(CAST(CANCELLED AS INTEGER)) * 100.0 / COUNT(*), 2) AS cancellation_percent
FROM flights
GROUP BY MONTH
ORDER BY MONTH;


-- 14. KPIs by Day of Week (1=Monday, ..., 7=Sunday)
SELECT 
    DAY_OF_WEEK,
    ROUND(AVG(ARRIVAL_DELAY), 2) AS avg_arrival_delay,
    ROUND(AVG(DEPARTURE_DELAY), 2) AS avg_departure_delay,
    ROUND(SUM(CANCELLED)::decimal / COUNT(*) * 100, 2) AS cancellation_percent
FROM flights
GROUP BY DAY_OF_WEEK
ORDER BY DAY_OF_WEEK;


-- 15. KPIs by Time of Day (Hourly bins from Scheduled Departure Time)
-- Assumes you created SCHEDULED_DEPARTURE_TIME (TIME type column)
SELECT 
    EXTRACT(HOUR FROM scheduled_departure_time) AS hour_of_day,
    ROUND(AVG(arrival_delay), 2) AS avg_arrival_delay,
    ROUND(AVG(departure_delay), 2) AS avg_departure_delay,
    ROUND(SUM(CAST(cancelled AS INTEGER)) * 100.0 / COUNT(*), 2) AS cancellation_percent
FROM flights
WHERE scheduled_departure_time IS NOT NULL
GROUP BY hour_of_day
ORDER BY hour_of_day;


GRANT SELECT ON ALL TABLES IN SCHEMA public TO postgres;
-- or: GRANT SELECT ON public.flights TO postgres;

SELECT COUNT(*) FROM public.flights;


SELECT * FROM information_schema.tables WHERE table_schema = 'public';

