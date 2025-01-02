CREATE TABLE stops (
    trip_id TEXT,
    arrival_time TIME,
    departure_time TIME,
    stop_id TEXT,
    stop_sequence INTEGER,
    stop_headsign TEXT,
    pickup_type INTEGER,
    drop_off_type INTEGER,
    timepoint INTEGER
);

CREATE TABLE staging_stops (
    trip_id TEXT,
    arrival_time TEXT,
    departure_time TEXT,
    stop_id TEXT,
    stop_sequence TEXT,
    stop_headsign TEXT,
    pickup_type TEXT,
    drop_off_type TEXT,
    timepoint TEXT
);

COPY staging_stops(trip_id, arrival_time, departure_time, stop_id, stop_sequence, stop_headsign, pickup_type, drop_off_type, timepoint)
FROM '/data/stop_times.txt'
DELIMITER ','
CSV HEADER;

CREATE INDEX idx_stop_id ON stops(stop_id);
CREATE INDEX idx_trip_id ON stops(trip_id);

INSERT INTO stops (trip_id, arrival_time, departure_time, stop_id, stop_sequence, stop_headsign, pickup_type, drop_off_type, timepoint)
SELECT 
    trip_id,
    CASE 
        WHEN arrival_time ~ '^[0-9]{2}:[0-9]{2}:[0-9]{2}$' THEN 
            CASE 
                WHEN LEFT(arrival_time, 2)::INTEGER >= 24 THEN 
                    (LEFT(arrival_time, 2)::INTEGER - 24)::TEXT || SUBSTRING(arrival_time FROM 3 FOR 6)
                ELSE 
                    arrival_time
            END
        ELSE 
            NULL
    END::TIME AS arrival_time,
    CASE 
        WHEN departure_time ~ '^[0-9]{2}:[0-9]{2}:[0-9]{2}$' THEN 
            CASE 
                WHEN LEFT(departure_time, 2)::INTEGER >= 24 THEN 
                    (LEFT(departure_time, 2)::INTEGER - 24)::TEXT || SUBSTRING(departure_time FROM 3 FOR 6)
                ELSE 
                    departure_time
            END
        ELSE 
            NULL
    END::TIME AS departure_time,
    stop_id,
    stop_sequence::INTEGER,
    stop_headsign,
    pickup_type::INTEGER,
    drop_off_type::INTEGER,
    timepoint::INTEGER
FROM staging_stops;

DROP TABLE staging_stops;

CREATE TABLE trips (
    route_id TEXT,
    service_id TEXT,
    trip_id TEXT,
    trip_headsign TEXT,
    trip_short_name TEXT,
    direction_id INTEGER,
    block_id TEXT,
    shape_id TEXT
);

COPY trips(route_id, service_id, trip_id, trip_headsign, trip_short_name, direction_id, block_id, shape_id)
FROM '/data/trips.txt'
DELIMITER ','
CSV HEADER;

CREATE INDEX idx_route_id ON trips(route_id);
CREATE INDEX idx_trip_id_trips ON trips(trip_id);
