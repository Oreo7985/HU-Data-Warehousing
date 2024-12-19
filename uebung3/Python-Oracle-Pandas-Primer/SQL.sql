-- 1:Ursach der Verspätung
-- SQL:
SELECT 
    CASE 
        WHEN delay_type = 'air_system_delay' THEN 'Air System Delay'
        WHEN delay_type = 'security_delay' THEN 'Security Delay'
        WHEN delay_type = 'airline_delay' THEN 'Airline Delay'
        WHEN delay_type = 'late_aircraft_delay' THEN 'Late Aircraft Delay'
        WHEN delay_type = 'weather_delay' THEN 'Weather Delay'
    END as delay_category,
    SUM(delay_minutes) as total_minutes,
    ROUND(SUM(delay_minutes) * 100.0 / SUM(SUM(delay_minutes)) OVER (), 2) as percentage
FROM (
    SELECT 'air_system_delay' as delay_type, COALESCE(air_system_delay, 0) as delay_minutes FROM delays
    UNION ALL
    SELECT 'security_delay', COALESCE(security_delay, 0) FROM delays
    UNION ALL
    SELECT 'airline_delay', COALESCE(airline_delay, 0) FROM delays
    UNION ALL
    SELECT 'late_aircraft_delay', COALESCE(late_aircraft_delay, 0) FROM delays
    UNION ALL
    SELECT 'weather_delay', COALESCE(weather_delay, 0) FROM delays
) unpivoted
GROUP BY delay_type
HAVING SUM(delay_minutes) > 0
ORDER BY total_minutes DESC;

--2
SELECT 
    f.origin_state as STATE,
    f.origin_airport as AIRPORT,
    f.origin_city as City,
    f.origin_latitude/100000.0 as LATITUDE,  
    f.origin_longitude/100000.0 as LONGITUDE,  
    COUNT(*) as TOTAL_FLIGHTS,
    SUM(CASE WHEN d.departure_delay > 0 THEN 1 ELSE 0 END) as DELAYED_FLIGHTS,
    ROUND(SUM(CASE WHEN d.departure_delay > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as DELAY_PERCENTAGE,
    ROUND(AVG(CASE WHEN d.departure_delay > 0 THEN d.departure_delay ELSE NULL END), 2) as AVG_DELAY_MINUTES
FROM Flight f
JOIN Delays d ON f.flight_id = d.flight_id
GROUP BY 
    f.origin_state,
    f.origin_airport,
    f.origin_city,
    f.origin_latitude,
    f.origin_longitude
HAVING COUNT(*) > 100;

--3.1
SELECT 
    f.year,
    f.month,
    f.day,
    COUNT(*) as WEATHER_CANCELLATIONS,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) 
                              FROM Delays 
                              WHERE cancelled = 1 
                              AND cancellation_reason = 'B'), 2) as PERCENTAGE_OF_TOTAL
FROM Delays f
WHERE f.cancelled = 1 
AND f.cancellation_reason = 'B'
GROUP BY f.year, f.month, f.day;

--3.2
SELECT 
    f.origin_state as STATE,
    f.origin_airport as AIRPORT,
    COUNT(*) as TOTAL_CANCELLATIONS,
    SUM(CASE WHEN d.cancellation_reason = 'B' THEN 1 ELSE 0 END) as WEATHER_CANCELLATIONS,
    ROUND(
        (SUM(CASE WHEN d.cancellation_reason = 'B' THEN 1 ELSE 0 END) * 100.0) / 
        NULLIF(COUNT(*), 0), 
        2
    ) as CANCELLATION_PERCENTAGE,
    COUNT(DISTINCT TRUNC(f.scheduled_departure)) as AFFECTED_DAYS
FROM Flight f
JOIN Delays d ON f.flight_id = d.flight_id
WHERE d.cancelled = 1
GROUP BY 
    f.origin_state,
    f.origin_airport
HAVING SUM(CASE WHEN d.cancellation_reason = 'B' THEN 1 ELSE 0 END) > 0
ORDER BY WEATHER_CANCELLATIONS DESC;

--4.1
SELECT 
    t.DAY_OF_WEEK AS DAY_OF_WEEK,
    ROUND(AVG(f.DEPARTURE_DELAY + 
        NVL(f.TAXI_OUT, 0) + 
        NVL(f.SECURITY_DELAY, 0) + 
        NVL(f.AIRLINE_DELAY, 0) + 
        NVL(f.WEATHER_DELAY, 0) + 
        NVL(f.AIR_SYSTEM_DELAY, 0)
    ), 2) AS AVERAGE_DELAY_MINUTES,
    COUNT(*) AS TOTAL_FLIGHTS
FROM DELAYS f
JOIN TIME t ON 
    f.DAY = t.DAY AND 
    f.MONTH = t.MONTH AND 
    f.YEAR = t.YEAR
WHERE f.CANCELLED = 0
GROUP BY t.DAY_OF_WEEK
ORDER BY AVERAGE_DELAY_MINUTES ASC;

--4.2
SELECT 
    t.MONTH AS MONTH,
    ROUND(AVG(
        NVL(f.DEPARTURE_DELAY, 0) + 
        NVL(f.TAXI_OUT, 0) + 
        NVL(f.SECURITY_DELAY, 0) + 
        NVL(f.AIRLINE_DELAY, 0) + 
        NVL(f.WEATHER_DELAY, 0) + 
        NVL(f.AIR_SYSTEM_DELAY, 0)
    ), 2) AS AVERAGE_DELAY_MINUTES,
    COUNT(*) AS TOTAL_FLIGHTS
FROM DELAYS f
JOIN TIME t ON 
    f.DAY = t.DAY AND 
    f.MONTH = t.MONTH AND 
    f.YEAR = t.YEAR
WHERE f.CANCELLED = 0
GROUP BY t.MONTH
ORDER BY t.MONTH ASC;

--5.1
SELECT 
    a.AIRLINE AS AIRLINE_NAME, 
    COUNT(*) AS TOTAL_FLIGHTS
FROM DELAYS f
JOIN AIRLINE a ON f.AIRLINE_IATA = a.IATA_CODE
WHERE f.CANCELLED = 0 
GROUP BY a.AIRLINE
ORDER BY TOTAL_FLIGHTS DESC;

--5.2
SELECT 
    a.AIRLINE AS AIRLINE_NAME, 
    ROUND(AVG(f.DEPARTURE_DELAY), 2) AS AVERAGE_DEPARTURE_DELAY
FROM DELAYS f
JOIN AIRLINE a ON f.AIRLINE_IATA = a.IATA_CODE
WHERE f.CANCELLED = 0
  AND f.DEPARTURE_DELAY IS NOT NULL
GROUP BY a.AIRLINE
ORDER BY AVERAGE_DEPARTURE_DELAY DESC;

--6.1
SELECT 
    f.destination_city AS CITY_NAME,
    f.destination_state AS STATE,
    COUNT(*) AS INCOMING_FLIGHTS
FROM FLIGHT f
JOIN DELAYS d ON f.flight_id = d.flight_id
WHERE d.CANCELLED = 0
GROUP BY 
    f.destination_city,
    f.destination_state
ORDER BY INCOMING_FLIGHTS DESC;

--6.2
SELECT 
    f.ORIGIN_AIRPORT AS AIRPORT_NAME,
    f.ORIGIN_CITY AS CITY,
    f.ORIGIN_STATE AS STATE,
    COUNT(*) AS OUTBOUND_FLIGHTS
FROM FLIGHT f, DELAYS d
WHERE d.FLIGHT_ID = f.FLIGHT_ID 
    AND d.CANCELLED = 0
GROUP BY 
    f.ORIGIN_AIRPORT,
    f.ORIGIN_CITY,
    f.ORIGIN_STATE
ORDER BY OUTBOUND_FLIGHTS DESC;