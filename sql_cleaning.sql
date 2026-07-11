/* ================================================================
   CYCLISTIC BIKE-SHARE CASE STUDY -- DATA CLEANING
   ----------------------------------------------------------------
   Data source : Cyclistic bike-share trip data 
   Time range  : May 2025 - May 2026
   Tool        : PostgreSQL 16
   Goal        : Clean and prepare raw trip data for analysis of
                 behavioral differences between casual riders and
                 annual members.
   ================================================================ */

-- Initial look at the raw data shape
SELECT *
FROM "202505_divvy_tripdata"
LIMIT 1;


/* ----------------------------------------------------------------
   MISSING VALUES
---------------------------------------------------------------- */

-- Step 1: Count NULLs in every column
SELECT
    COUNT(CASE WHEN ride_id IS NULL THEN 1 END) AS trip_id_nulls,
    COUNT(CASE WHEN rideable_type IS NULL THEN 1 END) AS rideable_type_nulls,
    COUNT(CASE WHEN started_at IS NULL THEN 1 END) AS started_at_nulls,
    COUNT(CASE WHEN ended_at IS NULL THEN 1 END) AS ended_at_nulls,
    COUNT(CASE WHEN start_station_name IS NULL THEN 1 END) AS start_station_name_nulls,
    COUNT(CASE WHEN start_station_id IS NULL THEN 1 END) AS start_station_id_nulls,
    COUNT(CASE WHEN end_station_name IS NULL THEN 1 END) AS end_station_name_nulls,
    COUNT(CASE WHEN end_station_id IS NULL THEN 1 END) AS end_station_id_nulls,
    COUNT(CASE WHEN member_casual IS NULL THEN 1 END) AS member_casual_nulls
FROM "202505_divvy_tripdata";
-- 1,328,474 blank start_station_name / start_station_id
-- 1,394,175 blank end_station_name / end_station_id

-- Step 1.1: Break the missing station data down by rideable_type
SELECT
    rideable_type,
    COUNT(CASE WHEN start_station_name IS NULL THEN 1 END) AS start_station_name_nulls,
    COUNT(CASE WHEN start_station_id IS NULL THEN 1 END) AS start_station_id_nulls,
    COUNT(CASE WHEN end_station_name IS NULL THEN 1 END) AS end_station_name_nulls,
    COUNT(CASE WHEN end_station_id IS NULL THEN 1 END) AS end_station_id_nulls
FROM "202505_divvy_tripdata"
WHERE start_station_name IS NULL
   OR start_station_id IS NULL
   OR end_station_name IS NULL
   OR end_station_id IS NULL
GROUP BY rideable_type;
-- Electric bikes can be locked anywhere, so most of the missing station
-- data belongs to them and is expected. Only 6,333 records are missing
-- end_station_id / end_station_name for classic bikes, which must be
-- docked at a station -- likely a data-entry issue rather than a true gap.


/* ----------------------------------------------------------------
   DUPLICATES
---------------------------------------------------------------- */

-- Step 1: Back up the raw table before making any changes
CREATE TABLE "202505_divvy_tripdata_backup" AS
SELECT * FROM "202505_divvy_tripdata";

-- Step 2: Row count before removing duplicates
SELECT COUNT(*) FROM "202505_divvy_tripdata";
-- 6,213,372 rows

-- Step 3: Check for duplicate ride_id values
SELECT
    COUNT(*) AS duplicate_count
FROM "202505_divvy_tripdata"
GROUP BY ride_id
HAVING COUNT(*) > 1;
-- 35 duplicates found

-- Step 4: Build a de-duplicated version of the table
CREATE TABLE "202505_divvy_tripdata_backup_nodups" AS
SELECT DISTINCT * FROM "202505_divvy_tripdata";

-- Step 5: Confirm the duplicate rows were removed
SELECT COUNT(*) FROM "202505_divvy_tripdata_backup_nodups";
-- 6,213,337 rows (35 removed)

-- Step 6: Promote the de-duplicated table as the working table
DROP TABLE "202505_divvy_tripdata";

ALTER TABLE "202505_divvy_tripdata_backup_nodups" RENAME TO "202505_divvy_tripdata";

CREATE TABLE "202505_divvy_tripdata_backup_nodups" AS
SELECT * FROM "202505_divvy_tripdata";
-- checkpoint backup of the de-duplicated state


/* ----------------------------------------------------------------
   INCONSISTENCIES
---------------------------------------------------------------- */

-- Step 1: Sanity-check the lat/lng ranges (Chicago metro area)
SELECT
    MIN(start_lat) AS min_start_lat,
    MAX(start_lat) AS max_start_lat,
    MIN(start_lng) AS min_start_lng,
    MAX(start_lng) AS max_start_lng,
    MIN(end_lat) AS min_end_lat,
    MAX(end_lat) AS max_end_lat,
    MIN(end_lng) AS min_end_lng,
    MAX(end_lng) AS max_end_lng
FROM "202505_divvy_tripdata";
-- Ranges are reasonable overall; min_end_lng (-88.1) and max_end_lng (-87.42)
-- sit slightly outside the expected Chicago bounding box.

SELECT *
FROM "202505_divvy_tripdata"
WHERE start_lat < 41.6 OR start_lat > 42.1 OR start_lng < -88.0 OR start_lng > -87.5
   OR end_lat < 41.6 OR end_lat > 42.1 OR end_lng < -88.0 OR end_lng > -87.5;
-- Fine -- electric bikes can be locked at points outside the usual station grid.

-- Step 2: Confirm ride_id format is consistent (16 characters)
SELECT
    COUNT(*) AS ride_ids
FROM "202505_divvy_tripdata"
WHERE LENGTH(ride_id) = 16;
-- No invalid ride IDs

-- Step 3: Check for negative trip durations
SELECT
    COUNT(*)
FROM "202505_divvy_tripdata"
WHERE ended_at < started_at;
-- 29 records with negative durations

-- Step 4: Check for trips under 1 minute
SELECT
    COUNT(*)
FROM "202505_divvy_tripdata"
WHERE ended_at - started_at < INTERVAL '1 minute';
-- 169,868 records with durations under 1 minute

-- Step 5: Break down sub-1-minute, same-station trips by bike type
SELECT
    rideable_type,
    COUNT(rideable_type) AS rideable_type_count
FROM "202505_divvy_tripdata"
WHERE ended_at - started_at < INTERVAL '1 minute'
  AND start_station_id = end_station_id
GROUP BY rideable_type;
-- 37,184 -- almost entirely electric bikes; likely false starts / test unlocks

-- Step 6: Back up, then remove invalid trips (negative duration, or
--         under 1 minute at the same station)
CREATE TABLE "202505_divvy_tripdata_backup_nodups_oktrips" AS
SELECT * FROM "202505_divvy_tripdata";

SELECT
    COUNT(*)
FROM "202505_divvy_tripdata"
WHERE (ended_at < started_at)
   OR (ended_at - started_at < INTERVAL '1 minute' AND start_station_id = end_station_id);
-- 37,212 invalid trips

DELETE FROM "202505_divvy_tripdata"
WHERE (ended_at < started_at)
   OR (ended_at - started_at < INTERVAL '1 minute' AND start_station_id = end_station_id);

-- Step 7: Confirm the row count after removing invalid trips
SELECT
    COUNT(*)
FROM "202505_divvy_tripdata";
-- 6,176,125 rows

-- Step 8: Confirm rideable_type only contains expected values
SELECT DISTINCT rideable_type
FROM "202505_divvy_tripdata";
-- classic_bike, electric_bike -- correct

-- Step 9: Confirm member_casual only contains expected values
SELECT DISTINCT member_casual
FROM "202505_divvy_tripdata";
-- member, casual -- correct

-- Step 10: Back up, inspect, then remove trips longer than 24 hours
SELECT
    COUNT(*),
    member_casual
FROM "202505_divvy_tripdata"
WHERE ended_at - started_at > INTERVAL '24 hours'
GROUP BY member_casual;
-- 6,208 total -- 5,191 casual riders, 1,017 members

SELECT
    MAX(ended_at - started_at) AS max_duration,
    member_casual
FROM "202505_divvy_tripdata"
GROUP BY member_casual;
-- Both member types have trips lasting 1+ day before cleanup

CREATE TABLE "202505_divvy_tripdata_backup_nodups_oktrips_nolong" AS
SELECT * FROM "202505_divvy_tripdata";

DELETE FROM "202505_divvy_tripdata"
WHERE ended_at - started_at > INTERVAL '24 hours';
-- 6,208 records removed -- likely bikes not properly docked / lost / stolen

SELECT
    COUNT(*)
FROM "202505_divvy_tripdata";
-- 6,169,917 rows (6,176,125 - 6,208)

-- Step 11: Check for and trim leading/trailing whitespace in station names
SELECT
    COUNT(*)
FROM "202505_divvy_tripdata"
WHERE TRIM(start_station_name) != start_station_name
   OR TRIM(end_station_name) != end_station_name;
-- 64,816 station names needed trimming

UPDATE "202505_divvy_tripdata"
SET start_station_name = TRIM(start_station_name),
    end_station_name = TRIM(end_station_name);

-- Step 12: Confirm no trips start in the future
SELECT COUNT(*)
FROM "202505_divvy_tripdata"
WHERE started_at > CURRENT_DATE;
-- 0 records -- correct

-- Step 13: Identify station names mapped to more than one station ID
SELECT
    start_station_name,
    COUNT(DISTINCT start_station_id) AS id_count
FROM "202505_divvy_tripdata"
WHERE start_station_name IS NOT NULL
GROUP BY start_station_name
HAVING COUNT(DISTINCT start_station_id) > 1;
-- 1,305 records -- flagged as a known inconsistency, not corrected (see README)

-- Step 14: Confirm no trips have identical start/end timestamps
SELECT COUNT(*)
FROM "202505_divvy_tripdata"
WHERE started_at = ended_at;
-- 0 records -- correct

-- Step 15: Check the year/month distribution of started_at and ended_at
SELECT
    EXTRACT(YEAR FROM started_at) AS year_num,
    EXTRACT(MONTH FROM started_at) AS month_num,
    COUNT(*) AS row_count
FROM "202505_divvy_tripdata"
GROUP BY year_num, month_num
ORDER BY year_num, month_num;

SELECT
    EXTRACT(YEAR FROM ended_at) AS year_num_ended,
    EXTRACT(MONTH FROM ended_at) AS month_num_ended,
    COUNT(*) AS row_count
FROM "202505_divvy_tripdata"
GROUP BY year_num_ended, month_num_ended
ORDER BY year_num_ended, month_num_ended;
-- Reveals a small number of rows with corrupted timestamps outside May 2025

-- Step 16: Remove rows with out-of-range timestamps
DELETE FROM "202505_divvy_tripdata"
WHERE (EXTRACT(YEAR FROM started_at) = 2025 AND EXTRACT(MONTH FROM started_at) = 4)
   OR (EXTRACT(YEAR FROM started_at) = 2026 AND EXTRACT(MONTH FROM started_at) = 1);

SELECT COUNT(*) FROM "202505_divvy_tripdata";
-- 6,169,867 rows (6,169,917 - 50)


/* ----------------------------------------------------------------
   FINAL VALIDATION
---------------------------------------------------------------- */

-- Re-run every check above in one pass to confirm the table is clean
SELECT
    COUNT(*) AS total_rows,
    COUNT(CASE WHEN LENGTH(ride_id) != 16 THEN 1 END) AS invalid_ride_ids,
    COUNT(CASE WHEN ended_at < started_at THEN 1 END) AS negative_duration,
    COUNT(CASE WHEN ended_at - started_at < INTERVAL '1 minute' AND start_station_id = end_station_id THEN 1 END) AS short_same_station,
    COUNT(CASE WHEN ended_at - started_at > INTERVAL '24 hours' THEN 1 END) AS over_24hrs,
    COUNT(CASE WHEN started_at = ended_at THEN 1 END) AS zero_duration,
    COUNT(CASE WHEN rideable_type NOT IN ('classic_bike', 'electric_bike') THEN 1 END) AS invalid_bike_type,
    COUNT(CASE WHEN member_casual NOT IN ('member', 'casual') THEN 1 END) AS invalid_member_type,
    COUNT(CASE WHEN TRIM(start_station_name) != start_station_name THEN 1 END) AS untrimmed_stations,
    COUNT(CASE WHEN EXTRACT(YEAR FROM started_at) = 2025 AND EXTRACT(MONTH FROM started_at) = 4 THEN 1 END) AS wrong_april,
    COUNT(CASE WHEN EXTRACT(YEAR FROM started_at) = 2026 AND EXTRACT(MONTH FROM started_at) = 1 THEN 1 END) AS wrong_january
FROM "202505_divvy_tripdata";
-- All cleaning checks pass -- data is ready for analysis


/* ----------------------------------------------------------------
   PREPARE FOR ANALYSIS
---------------------------------------------------------------- */

-- Preview the derived columns needed for downstream analysis
SELECT
    started_at,
    ended_at,
    ended_at - started_at AS trip_duration,
    TO_CHAR(started_at, 'Day') AS day_of_week,
    EXTRACT(HOUR FROM started_at) AS start_hour
FROM "202505_divvy_tripdata"
LIMIT 100;

-- Create the final cleaned table with derived columns for analysis in Excel
CREATE TABLE "202505_divvy_tripdata_cleaned" AS
SELECT
    *,
    ended_at - started_at AS trip_duration,
    TO_CHAR(started_at, 'Day') AS day_of_week,
    EXTRACT(HOUR FROM started_at) AS start_hour
FROM "202505_divvy_tripdata";


/* ================================================================
   CLEANING SUMMARY
   ----------------------------------------------------------------
   Rows before cleaning : 6,213,372
   Rows after cleaning  : 6,169,867
   Total rows removed   : 43,505

   Breakdown of removals:
     - 35     exact duplicate rows (same ride_id)
     - 37,212 logically invalid trips (negative duration, or under
               1 minute at the same start/end station -- likely
               false starts / test unlocks)
     - 6,208  trips longer than 24 hours (likely bikes not properly
               docked, lost, or stolen)
     - 50     rows with corrupted timestamps outside the May 2025
               reporting window (data export artifact)
   ================================================================ */
