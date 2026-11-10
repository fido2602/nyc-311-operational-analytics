CREATE DATABASE nyc_311_analytics;

USE nyc_311_analytics;

SELECT DATABASE();
USE nyc_311_analytics;

USE nyc_311_analytics;

CREATE TABLE stg_nyc_311_2024 (
    unique_key VARCHAR(30) PRIMARY KEY,
    created_date DATETIME,
    closed_date DATETIME,
    agency VARCHAR(20),
    agency_name VARCHAR(255),
    complaint_type VARCHAR(255),
    descriptor VARCHAR(500),
    borough VARCHAR(100),
    status VARCHAR(100)
);

USE nyc_311_analytics;

DESCRIBE stg_nyc_311_2024;

USE nyc_311_analytics;

SHOW VARIABLES LIKE 'local_infile';

SELECT COUNT(*) AS existing_rows
FROM stg_nyc_311_2024;

USE nyc_311_analytics;

LOAD DATA LOCAL INFILE
'C:/Users/riodo/OneDrive/Desktop/NYC_311_Operational_Analytics/02_Dataset/NYC_311_2024_Optimized.csv'
INTO TABLE stg_nyc_311_2024
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
    unique_key,
    @created_date,
    @closed_date,
    agency,
    agency_name,
    complaint_type,
    descriptor,
    borough,
    status
)
SET
    created_date = STR_TO_DATE(@created_date, '%Y-%m-%d %H:%i:%s'),
    closed_date = NULLIF(
        STR_TO_DATE(NULLIF(@closed_date, ''), '%Y-%m-%d %H:%i:%s'),
        '0000-00-00 00:00:00'
    );
    
    USE nyc_311_analytics;

SELECT COUNT(*) AS imported_rows
FROM stg_nyc_311_2024;

USE nyc_311_analytics;

LOAD DATA LOCAL INFILE
'C:/Users/riodo/OneDrive/Desktop/NYC_311_Operational_Analytics/02_Dataset/NYC_311_2024_Optimized.csv'
INTO TABLE stg_nyc_311_2024
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
    unique_key,
    @created_date,
    @closed_date,
    agency,
    agency_name,
    complaint_type,
    descriptor,
    borough,
    status
)
SET
    created_date = STR_TO_DATE(@created_date, '%Y-%m-%d %H:%i:%s'),
    closed_date = CASE
        WHEN @closed_date IS NULL OR TRIM(@closed_date) = ''
        THEN NULL
        ELSE STR_TO_DATE(@closed_date, '%Y-%m-%d %H:%i:%s')
    END;
    
    USE nyc_311_analytics;

-- ============================================================
-- PROJECT: NYC 311 Service Request & Operational Efficiency Analytics
-- PURPOSE: Validate the completeness and uniqueness of the
--          imported 2024 NYC 311 service request dataset.
-- TABLE:   stg_nyc_311_2024
-- ============================================================

SELECT
    -- Total number of service request records imported
    COUNT(*) AS total_records,

    -- Verify that each service request has a unique identifier
    COUNT(DISTINCT unique_key) AS unique_requests,

    -- Identify records with missing creation dates
    SUM(created_date IS NULL) AS missing_created_dates,

    -- Identify records without a recorded closure date
    -- These may represent requests that are still open
    SUM(closed_date IS NULL) AS missing_closed_dates,

    -- Identify the earliest service request creation date
    MIN(created_date) AS earliest_request,

    -- Identify the latest service request creation date
    MAX(created_date) AS latest_request

FROM stg_nyc_311_2024;

USE nyc_311_analytics;

-- ============================================================
-- PROJECT: NYC 311 Service Request & Operational Efficiency Analytics
-- QUERY:   SQL 02 - Service Request Status Analysis
-- PURPOSE: Analyze request status distribution and investigate
--          records with missing closure dates.
-- BUSINESS VALUE:
--          Helps distinguish open, closed, and other request
--          statuses before defining operational KPIs.
-- ============================================================

SELECT
    -- Service request status recorded by NYC 311
    status,

    -- Total number of requests under each status
    COUNT(*) AS total_requests,

    -- Requests without a recorded closure date
    SUM(closed_date IS NULL) AS requests_without_closed_date,

    -- Requests with a recorded closure date
    SUM(closed_date IS NOT NULL) AS requests_with_closed_date,

    -- Percentage of requests within this status
    -- that have no recorded closure date
    ROUND(
        100.0 * SUM(closed_date IS NULL) / COUNT(*),
        2
    ) AS pct_without_closed_date

FROM stg_nyc_311_2024

-- Group records by their reported status
GROUP BY status

-- Display the largest status groups first
ORDER BY total_requests DESC;

USE nyc_311_analytics;

-- ============================================================
-- PROJECT: NYC 311 Service Request & Operational Efficiency Analytics
-- QUERY:   SQL 03 - Status and Closure-Date Mismatch Analysis
-- PURPOSE: Identify inconsistencies between the reported request
--          status and the recorded closure date.
--
-- BUSINESS RULE:
--          A Closed status should normally have a closure date.
--          A non-Closed status should normally have no closure date.
--
-- BUSINESS VALUE:
--          Helps assess data reliability before calculating
--          closure rates and resolution-time KPIs.
-- ============================================================

SELECT
    CASE
        -- Requests marked Closed but missing a closure date
        WHEN status = 'Closed' AND closed_date IS NULL
            THEN 'Closed status - Missing closure date'

        -- Requests not marked Closed but having a closure date
        WHEN status <> 'Closed' AND closed_date IS NOT NULL
            THEN 'Non-Closed status - Closure date exists'
    END AS mismatch_type,

    -- Number of affected service requests
    COUNT(*) AS affected_requests

FROM stg_nyc_311_2024

-- Include only records that violate the expected relationship
WHERE
    (status = 'Closed' AND closed_date IS NULL)
    OR
    (status <> 'Closed' AND closed_date IS NOT NULL)

-- Summarize mismatches by category
GROUP BY mismatch_type

ORDER BY affected_requests DESC;

USE nyc_311_analytics;

-- ============================================================
-- PROJECT: NYC 311 Service Request & Operational Efficiency Analytics
-- QUERY:   SQL 04 - Closure-Date Mismatch by Status
-- PURPOSE: Identify which request statuses contribute to
--          inconsistencies between status and closure date.
--
-- BUSINESS VALUE:
--          Helps identify where data-quality issues are
--          concentrated and supports reliable KPI definitions.
-- ============================================================

SELECT
    -- Original status recorded in the NYC 311 dataset
    status,

    -- Closed requests without a recorded closure date
    SUM(
        CASE
            WHEN status = 'Closed' AND closed_date IS NULL
            THEN 1 ELSE 0
        END
    ) AS closed_without_date,

    -- Non-Closed requests with a recorded closure date
    SUM(
        CASE
            WHEN status <> 'Closed' AND closed_date IS NOT NULL
            THEN 1 ELSE 0
        END
    ) AS non_closed_with_date,

    -- Total requests in each status category
    COUNT(*) AS total_requests

FROM stg_nyc_311_2024

GROUP BY status

ORDER BY total_requests DESC;

USE nyc_311_analytics;

-- ============================================================
-- PROJECT: NYC 311 Service Request & Operational Efficiency Analytics
-- QUERY:   SQL 05 - Sample Data Quality Investigation
-- PURPOSE: Inspect individual records with inconsistent
--          status and closure-date information.
--
-- BUSINESS VALUE:
--          Understand the underlying records before deciding
--          how these exceptions should be handled.
-- ============================================================

SELECT
    unique_key,
    created_date,
    closed_date,
    agency,
    complaint_type,
    borough,
    status,

    -- Clearly label the identified data-quality issue
    CASE
        WHEN status = 'Closed' AND closed_date IS NULL
            THEN 'Closed status - Missing closure date'

        WHEN status <> 'Closed' AND closed_date IS NOT NULL
            THEN 'Non-Closed status - Closure date exists'
    END AS data_quality_issue

FROM stg_nyc_311_2024

WHERE
    (status = 'Closed' AND closed_date IS NULL)
    OR
    (status <> 'Closed' AND closed_date IS NOT NULL)

ORDER BY status, unique_key

LIMIT 20;

USE nyc_311_analytics;

-- ============================================================
-- PROJECT: NYC 311 Service Request & Operational Efficiency Analytics
-- QUERY:   SQL 06 - Resolution Date Validation
-- PURPOSE: Identify records with invalid date sequences.
--
-- BUSINESS RULE:
--          A valid resolution date must not occur before
--          the corresponding request creation date.
--
-- BUSINESS VALUE:
--          Prevents negative resolution times from distorting
--          operational performance metrics.
-- ============================================================

SELECT
    -- Total number of records with both dates available
    COUNT(*) AS records_with_both_dates,

    -- Records where closure occurred before request creation
    SUM(
        CASE
            WHEN closed_date < created_date THEN 1
            ELSE 0
        END
    ) AS negative_resolution_dates,

    -- Records where closure and creation timestamps are identical
    SUM(
        CASE
            WHEN closed_date = created_date THEN 1
            ELSE 0
        END
    ) AS zero_resolution_dates,

    -- Records with valid, positive resolution durations
    SUM(
        CASE
            WHEN closed_date > created_date THEN 1
            ELSE 0
        END
    ) AS positive_resolution_dates

FROM stg_nyc_311_2024

-- Only records with both timestamps can be evaluated
WHERE created_date IS NOT NULL
  AND closed_date IS NOT NULL;
  
  USE nyc_311_analytics;

-- ============================================================
-- PROJECT: NYC 311 Service Request & Operational Efficiency Analytics
-- QUERY:   SQL 07 - Negative Resolution Time Investigation
-- PURPOSE: Inspect records where the closure date is earlier
--          than the request creation date.
--
-- BUSINESS VALUE:
--          Helps identify potential timestamp or source-data
--          issues before calculating resolution-time KPIs.
--
-- DATA HANDLING:
--          Original source records remain unchanged.
-- ============================================================

SELECT
    -- Unique identifier for the service request
    unique_key,

    -- Original request creation timestamp
    created_date,

    -- Recorded closure timestamp
    closed_date,

    -- Agency responsible for the request
    agency,

    -- Type of reported service issue
    complaint_type,

    -- Geographic area of the request
    borough,

    -- Original request status
    status,

    -- Calculate the difference in minutes
    TIMESTAMPDIFF(
        MINUTE,
        created_date,
        closed_date
    ) AS resolution_difference_minutes

FROM stg_nyc_311_2024

-- Identify records with an invalid date sequence
WHERE closed_date < created_date

-- Show the most recent examples first
ORDER BY created_date DESC

-- Limit output to 20 records for investigation
LIMIT 20;

USE nyc_311_analytics;

-- ============================================================
-- PROJECT: NYC 311 Service Request & Operational Efficiency Analytics
-- QUERY:   SQL 08 - Negative Resolution Dates by Agency
-- PURPOSE: Identify agencies and complaint types with the
--          highest number of invalid resolution durations.
--
-- BUSINESS VALUE:
--          Helps prioritize data-quality investigation and
--          identify patterns in source-system inconsistencies.
--
-- DATA HANDLING:
--          Original records are not modified.
-- ============================================================

SELECT
    -- Agency responsible for the service request
    agency,

    -- Type of reported service issue
    complaint_type,

    -- Number of records where closure precedes creation
    COUNT(*) AS invalid_date_records

FROM stg_nyc_311_2024

-- Include only records with negative resolution durations
WHERE closed_date < created_date

-- Summarize the invalid records by agency and issue type
GROUP BY
    agency,
    complaint_type

-- Rank combinations by the number of invalid records
ORDER BY invalid_date_records DESC

-- Display the 20 combinations with the most invalid records
LIMIT 20;

USE nyc_311_analytics;



-- ============================================================
-- PROJECT: NYC 311 Service Request & Operational Efficiency Analytics
-- SCRIPT:  SQL 09 - Create Analytical View
-- VIEW:    vw_nyc_311_2024_analytics
--
-- PURPOSE:
-- Create an analytical view for business analysis and reporting.
--
-- WHAT THIS VIEW DOES:
-- 1. Retains original service request information.
-- 2. Identifies status and closure-date inconsistencies.
-- 3. Identifies invalid resolution-date sequences.
-- 4. Calculates resolution time in days.
--
-- DATA HANDLING:
-- Original staging data is not modified or deleted.
-- Invalid negative resolution durations are excluded
-- from the resolution-time calculation.
-- Zero-duration requests are retained.
-- ============================================================


-- Step 1: Select the project database
USE nyc_311_analytics;


-- Step 2: Create or replace the analytical view
CREATE OR REPLACE VIEW vw_nyc_311_2024_analytics AS

SELECT

    -- --------------------------------------------------------
    -- SECTION A: Original Service Request Information
    -- --------------------------------------------------------

    unique_key,
    created_date,
    closed_date,
    agency,
    agency_name,
    complaint_type,
    descriptor,
    borough,
    status,


    -- --------------------------------------------------------
    -- SECTION B: Status and Closure-Date Quality Check
    -- --------------------------------------------------------

    CASE

        -- Identify missing status values
        WHEN status IS NULL OR TRIM(status) = ''
            THEN 'Missing status'

        -- Closed requests without a recorded closure date
        WHEN status = 'Closed'
             AND closed_date IS NULL
            THEN 'Closed status - Missing closure date'

        -- Non-Closed requests with a recorded closure date
        WHEN status <> 'Closed'
             AND closed_date IS NOT NULL
            THEN 'Non-Closed status - Closure date exists'

        -- Records without these inconsistencies
        ELSE 'Consistent'

    END AS status_date_quality_flag,


    -- --------------------------------------------------------
    -- SECTION C: Resolution-Date Quality Check
    -- --------------------------------------------------------

    CASE

        -- Creation date is unavailable
        WHEN created_date IS NULL
            THEN 'Missing creation date'

        -- Closure date is unavailable
        WHEN closed_date IS NULL
            THEN 'Missing closure date'

        -- Closure date occurs before creation date
        WHEN closed_date < created_date
            THEN 'Negative resolution duration'

        -- Creation and closure timestamps are identical
        WHEN closed_date = created_date
            THEN 'Zero resolution duration'

        -- Closure date occurs after creation date
        ELSE 'Positive resolution duration'

    END AS resolution_date_quality_flag,


    -- --------------------------------------------------------
    -- SECTION D: Calculate Resolution Time in Days
    -- --------------------------------------------------------

    CASE

        -- Calculate duration only when both dates exist
        -- and the closure date is not earlier than creation
        WHEN created_date IS NOT NULL
             AND closed_date IS NOT NULL
             AND closed_date >= created_date

        THEN ROUND(

            TIMESTAMPDIFF(
                SECOND,
                created_date,
                closed_date
            ) / 86400.0,

            2

        )

        -- Return NULL for missing or invalid date sequences
        ELSE NULL

    END AS resolution_time_days


-- Source: Original imported staging table
FROM stg_nyc_311_2024;


-- ============================================================
-- STEP 3: VERIFY THAT THE VIEW WAS CREATED
-- ============================================================

SHOW FULL TABLES
WHERE Table_type = 'VIEW';


-- ============================================================
-- STEP 4: PREVIEW THE ANALYTICAL DATA
-- ============================================================

SELECT *
FROM vw_nyc_311_2024_analytics
LIMIT 10;


-- ============================================================
-- STEP 5: VERIFY THE TOTAL NUMBER OF RECORDS
-- ============================================================

SELECT
    COUNT(*) AS total_analytical_records
FROM vw_nyc_311_2024_analytics;

USE nyc_311_analytics;

-- ============================================================
-- SQL 10: Overall Service Request KPIs
-- Business Purpose:
-- Establish a high-level view of NYC 311 service request
-- volume and operational closure performance for 2024.
--
-- Important:
-- Closure rate is based on the source Status field.
-- It does not assume that every Closed status has a valid
-- closure date. Date-quality issues are analyzed separately.
-- ============================================================

SELECT
    COUNT(*) AS total_requests,

    SUM(status = 'Closed') AS closed_status_requests,

    SUM(status <> 'Closed' OR status IS NULL)
        AS non_closed_status_requests,

    ROUND(
        SUM(status = 'Closed') * 100.0 / COUNT(*),
        2
    ) AS status_based_closure_rate_pct,

    SUM(closed_date IS NULL)
        AS requests_without_closure_date,

    SUM(status = 'Closed' AND closed_date IS NULL)
        AS closed_status_missing_closure_date

FROM vw_nyc_311_2024_analytics;


USE nyc_311_analytics;

-- ============================================================
-- SQL 10.2: Resolution Time Analysis
--
-- Business Purpose:
-- Measure how long service requests took to resolve.
--
-- Inclusion Rules:
-- 1. Creation date must exist.
-- 2. Closure date must exist.
-- 3. Closure date must not be earlier than creation date.
--
-- Zero-day resolution records are retained because they
-- represent requests closed at the same recorded timestamp.
--
-- Average and median are calculated across all records
-- meeting these date-validity rules, regardless of Status.
-- Status/date mismatches remain separately flagged.
-- ============================================================

WITH valid_resolution_times AS (
    SELECT
        unique_key,

        -- Calculate elapsed resolution time in days.
        TIMESTAMPDIFF(
            SECOND,
            created_date,
            closed_date
        ) / 86400.0 AS resolution_days

    FROM vw_nyc_311_2024_analytics

    WHERE created_date IS NOT NULL
      AND closed_date IS NOT NULL
      AND closed_date >= created_date
),

ranked_resolution_times AS (
    SELECT
        resolution_days,

        -- Assign a position after sorting from shortest
        -- to longest resolution time.
        ROW_NUMBER() OVER (
            ORDER BY resolution_days
        ) AS row_num,

        -- Count all valid resolution records.
        COUNT(*) OVER () AS total_valid_records

    FROM valid_resolution_times
)

SELECT
    COUNT(*) AS valid_resolution_records,

    ROUND(
        AVG(resolution_days),
        2
    ) AS average_resolution_days,

    ROUND(
        AVG(
            CASE
                WHEN row_num IN (
                    FLOOR((total_valid_records + 1) / 2),
                    FLOOR((total_valid_records + 2) / 2)
                )
                THEN resolution_days
            END
        ),
        2
    ) AS median_resolution_days

FROM ranked_resolution_times;

USE nyc_311_analytics;

USE nyc_311_analytics;

-- ============================================================
-- SQL 10.3: Average Resolution Time by Borough
--
-- Business Purpose:
-- Compare average service request resolution times
-- across NYC boroughs.
--
-- Inclusion Rules:
-- 1. Borough must be populated.
-- 2. Both timestamps must exist.
-- 3. Closure timestamp must not precede creation.
--
-- Resolution time is measured in calendar days.
-- ============================================================

SELECT
    borough,

    COUNT(*) AS valid_resolution_records,

    ROUND(
        AVG(
            TIMESTAMPDIFF(
                SECOND,
                created_date,
                closed_date
            ) / 86400.0
        ),
        2
    ) AS average_resolution_days

FROM vw_nyc_311_2024_analytics

WHERE borough IS NOT NULL
  AND TRIM(borough) <> ''
  AND created_date IS NOT NULL
  AND closed_date IS NOT NULL
  AND closed_date >= created_date

GROUP BY borough

ORDER BY average_resolution_days DESC;

USE nyc_311_analytics;

-- ============================================================
-- SQL 10.4: Service Request Volume by Borough
--
-- Business Purpose:
-- Measure the distribution of 311 service requests
-- across NYC boroughs.
--
-- Analysis:
-- 1. Count total requests by borough.
-- 2. Calculate each borough's percentage of total requests.
-- 3. Rank boroughs by request volume.
--
-- Note:
-- Unspecified boroughs are retained as a separate category
-- so that records are not silently excluded.
-- ============================================================

SELECT
    CASE
        WHEN borough IS NULL OR TRIM(borough) = ''
            THEN 'Unspecified'
        ELSE UPPER(TRIM(borough))
    END AS borough_name,

    COUNT(*) AS total_requests,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS request_volume_percentage

FROM vw_nyc_311_2024_analytics

GROUP BY
    CASE
        WHEN borough IS NULL OR TRIM(borough) = ''
            THEN 'Unspecified'
        ELSE UPPER(TRIM(borough))
    END

ORDER BY total_requests DESC;


USE nyc_311_analytics;

-- ============================================================
-- SQL 10.5: Monthly Service Request Trends
--
-- Business Purpose:
-- Identify monthly patterns in NYC 311 service request demand
-- during 2024.
--
-- Analysis:
-- 1. Count requests created in each month.
-- 2. Calculate each month's share of annual demand.
-- 3. Sort months chronologically.
--
-- Business Rule:
-- Requests are assigned to a month using Created Date,
-- even if they were closed in a different month.
-- ============================================================

SELECT
    DATE_FORMAT(created_date, '%Y-%m') AS request_month,

    COUNT(*) AS total_requests,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_annual_requests

FROM vw_nyc_311_2024_analytics

WHERE created_date >= '2024-01-01'
  AND created_date < '2025-01-01'

GROUP BY DATE_FORMAT(created_date, '%Y-%m')

ORDER BY request_month;


USE nyc_311_analytics;


USE nyc_311_analytics;

-- ============================================================
-- SQL 10.6: Top 10 Complaint Types
--
-- Business Purpose:
-- Identify the most frequently reported service problems
-- across NYC during 2024.
--
-- Analysis:
-- 1. Count requests by complaint type.
-- 2. Calculate each complaint type's share of total demand.
-- 3. Rank complaint types by request volume.
--
-- Business Rule:
-- All 2024 requests are included.
-- Missing complaint types are classified as Unspecified.
-- ============================================================

SELECT
    CASE
        WHEN complaint_type IS NULL
             OR TRIM(complaint_type) = ''
        THEN 'Unspecified'
        ELSE TRIM(complaint_type)
    END AS complaint_type,

    COUNT(*) AS total_requests,

    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_total_requests

FROM vw_nyc_311_2024_analytics

GROUP BY
    CASE
        WHEN complaint_type IS NULL
             OR TRIM(complaint_type) = ''
        THEN 'Unspecified'
        ELSE TRIM(complaint_type)
    END

ORDER BY total_requests DESC;
USE nyc_311_analytics;

CREATE TABLE complaint_resolution_summary (
    complaint_type VARCHAR(255) PRIMARY KEY,
    total_requests BIGINT,
    valid_resolution_records BIGINT,
    average_resolution_days DECIMAL(12,2)
);

SHOW TABLES LIKE 'complaint_resolution_summary';


USE nyc_311_analytics;

-- ============================================================
-- SQL 10.7: Populate Complaint Resolution Summary
--
-- Business Purpose:
-- Aggregate request volume and valid resolution performance
-- by complaint type.
--
-- Valid resolution rules:
-- 1. Creation date must exist.
-- 2. Closure date must exist.
-- 3. Closure date must be >= creation date.
-- 4. Zero-day resolutions are included.
-- ============================================================
USE nyc_311_analytics;

-- ============================================================
-- SQL 10.7: COMPLAINT TYPE RESOLUTION PERFORMANCE
-- ============================================================
-- Business question:
-- Do the most frequently reported complaint types also take
-- longer to resolve?
--
-- Purpose:
-- Create a pre-aggregated summary table to make the analysis
-- faster and avoid repeatedly scanning the full 3.45M records.
--
-- Business rules:
-- 1. Include all complaint types in the summary.
-- 2. Count all requests, including those without valid
--    resolution timestamps.
-- 3. Calculate average resolution time only when both dates
--    exist and closed_date >= created_date.
-- 4. Retain zero-day resolution records.
-- ============================================================

INSERT INTO complaint_resolution_summary (
    complaint_type,
    total_requests,
    valid_resolution_records,
    average_resolution_days
)
SELECT
    COALESCE(
        NULLIF(TRIM(complaint_type), ''),
        'Unspecified'
    ) AS complaint_type,

    COUNT(*) AS total_requests,

    SUM(
        CASE
            WHEN created_date IS NOT NULL
             AND closed_date IS NOT NULL
             AND closed_date >= created_date
            THEN 1
            ELSE 0
        END
    ) AS valid_resolution_records,

    ROUND(
        AVG(
            CASE
                WHEN created_date IS NOT NULL
                 AND closed_date IS NOT NULL
                 AND closed_date >= created_date
                THEN TIMESTAMPDIFF(
                    SECOND,
                    created_date,
                    closed_date
                ) / 86400.0
                ELSE NULL
            END
        ),
        2
    ) AS average_resolution_days

FROM stg_nyc_311_2024

GROUP BY
    COALESCE(
        NULLIF(TRIM(complaint_type), ''),
        'Unspecified'
    );
    
    USE nyc_311_analytics;

TRUNCATE TABLE complaint_resolution_summary;

SELECT
    LOWER(TRIM(complaint_type)) AS normalized_complaint_type,
    COUNT(DISTINCT complaint_type) AS source_variations,
    COUNT(*) AS total_requests
FROM stg_nyc_311_2024
WHERE complaint_type IS NOT NULL
GROUP BY LOWER(TRIM(complaint_type))
HAVING COUNT(DISTINCT complaint_type) > 1
ORDER BY source_variations DESC
LIMIT 20;

SHOW CREATE TABLE complaint_resolution_summary;

USE nyc_311_analytics;

ALTER TABLE complaint_resolution_summary
MODIFY complaint_type VARCHAR(255)
CHARACTER SET utf8mb4
COLLATE utf8mb4_0900_bin
NOT NULL;

SHOW CREATE TABLE complaint_resolution_summary;


USE nyc_311_analytics;

-- SQL 10.7: Aggregate request volume and resolution time
-- by normalized complaint type.
--
-- All requests contribute to total_requests.
-- Only records with valid date chronology contribute
-- to average_resolution_days.
-- Zero-day resolution records are retained.

INSERT INTO complaint_resolution_summary (
    complaint_type,
    total_requests,
    valid_resolution_records,
    average_resolution_days
)
SELECT
    COALESCE(
        NULLIF(TRIM(complaint_type), ''),
        'Unspecified'
    ) AS complaint_type,

    COUNT(*) AS total_requests,

    SUM(
        CASE
            WHEN created_date IS NOT NULL
             AND closed_date IS NOT NULL
             AND closed_date >= created_date
            THEN 1
            ELSE 0
        END
    ) AS valid_resolution_records,

    ROUND(
        AVG(
            CASE
                WHEN created_date IS NOT NULL
                 AND closed_date IS NOT NULL
                 AND closed_date >= created_date
                THEN TIMESTAMPDIFF(
                    SECOND,
                    created_date,
                    closed_date
                ) / 86400.0
                ELSE NULL
            END
        ),
        2
    ) AS average_resolution_days
    FROM stg_nyc_311_2024

GROUP BY
    COALESCE(
        NULLIF(TRIM(complaint_type), ''),
        'Unspecified'
    );
    
    USE nyc_311_analytics;

SELECT
    COUNT(*) AS complaint_categories,
    SUM(total_requests) AS total_requests,
    SUM(valid_resolution_records) AS valid_resolution_records
FROM complaint_resolution_summary;



USE nyc_311_analytics;

SELECT
    COUNT(*) AS complaint_categories,
    SUM(total_requests) AS total_requests,
    SUM(valid_resolution_records) AS valid_resolution_records
FROM complaint_resolution_summary;


USE nyc_311_analytics;

-- SQL 10.7: Top 10 complaint types by request volume
-- and their average resolution performance.
--
-- Business question:
-- Do the most frequently reported complaints also
-- take longer to resolve?

SELECT
    complaint_type,
    total_requests,
    ROUND(
        total_requests * 100.0 /
        (SELECT SUM(total_requests)
         FROM complaint_resolution_summary),
        2
    ) AS request_volume_pct,
    valid_resolution_records,
    average_resolution_days
FROM complaint_resolution_summary
ORDER BY total_requests DESC
LIMIT 10;


-- ============================================================
-- BUSINESS INSIGHTS:
--
-- 1. The top 10 complaint categories represent 54.47% of
--    all NYC 311 requests in the 2024 dataset.
--
-- 2. Illegal Parking has the highest request volume
--    (505,728 requests; 14.63%) but an average resolution
--    time of only 0.13 days.
--
-- 3. Plumbing and Unsanitary Condition have substantially
--    longer average resolution times:
--    Plumbing: 21.76 days.
--    Unsanitary Condition: 20.22 days.
--
-- 4. Request volume alone does not explain resolution
--    performance. Both demand and resolution duration
--    should be considered when evaluating operations.
--
-- BUSINESS RECOMMENDATION:
-- Investigate the operational processes, agency workload,
-- and case complexity associated with Plumbing and
-- Unsanitary Condition requests.
--
-- DATA LIMITATION:
-- Average resolution time is calculated only for records
-- with valid creation and closure timestamps. These are
-- calendar days, not business days. Results are descriptive
-- and do not establish the cause of longer resolution times.
-- ============================================================



USE nyc_311_analytics;

-- ============================================================
-- SQL 10.8: AGENCY WORKLOAD AND RESOLUTION PERFORMANCE
-- ============================================================
-- Business question:
-- Which agencies handle the highest request volumes, and
-- how do their average resolution times compare?
--
-- Metrics:
-- 1. Total requests handled by each agency.
-- 2. Percentage of total annual requests.
-- 3. Valid resolution records.
-- 4. Average resolution time in calendar days.
--
-- Data rules:
-- Include all requests in workload counts.
-- Calculate resolution averages only for records with
-- valid creation and closure timestamps.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(TRIM(agency), ''),
        'Unspecified'
    ) AS agency,

    COUNT(*) AS total_requests,

    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM stg_nyc_311_2024),
        2
    ) AS request_volume_pct,

    SUM(
        CASE
            WHEN created_date IS NOT NULL
             AND closed_date IS NOT NULL
             AND closed_date >= created_date
            THEN 1
            ELSE 0
        END
    ) AS valid_resolution_records,

    ROUND(
        AVG(
            CASE
                WHEN created_date IS NOT NULL
                 AND closed_date IS NOT NULL
                 AND closed_date >= created_date
                THEN TIMESTAMPDIFF(
                    SECOND,
                    created_date,
                    closed_date
                ) / 86400.0
            END
        ),
        2
    ) AS average_resolution_days

FROM stg_nyc_311_2024

GROUP BY
    COALESCE(
        NULLIF(TRIM(agency), ''),
        'Unspecified'
    )

ORDER BY total_requests DESC;


-- ============================================================
-- BUSINESS INSIGHTS:
--
-- 1. NYPD handled the largest workload:
--    1,548,070 requests, representing 44.78% of total volume.
--
-- 2. HPD was the second-largest agency:
--    733,927 requests, representing 21.23% of total volume.
--
-- 3. NYPD recorded an average resolution time of 0.11 days,
--    while HPD recorded 14.18 days.
--
-- 4. DPR recorded the highest average resolution time
--    among the agencies analyzed (119.21 days).
--
-- 5. DOB, TLC, DOHMH, and EDC also showed relatively high
--    average resolution durations.
--
-- 6. DHS had only 24,437 valid resolution records out of
--    51,990 requests (approximately 47%). Its average
--    should therefore be interpreted with caution.
--
-- BUSINESS RECOMMENDATION:
-- Investigate agencies with longer average resolution times
-- by examining complaint mix, case complexity, and workload.
-- Consider data completeness before comparing agencies.
--
-- DATA LIMITATIONS:
-- Resolution time is measured in calendar days.
-- Only records with valid creation and closure timestamps
-- contribute to average resolution time.
-- Averages can be influenced by unusually long cases.
-- These results do not establish agency efficiency or
-- identify the cause of resolution delays.
-- ============================================================


USE nyc_311_analytics;

-- ============================================================
-- SQL 10.9: AGENCY AND COMPLAINT TYPE ANALYSIS
-- ============================================================
-- Business question:
-- Which complaint types generate the highest workload
-- within each agency?
--
-- Purpose:
-- Identify the most common complaint categories handled
-- by each agency.
--
-- Metrics:
-- 1. Request count by agency and complaint type.
-- 2. Percentage of each agency's workload.
--
-- Business rule:
-- Calculate complaint-type percentages using the total
-- requests handled by the corresponding agency.
-- ============================================================

SELECT
    agency,
    complaint_type,
    total_requests,

    ROUND(
        total_requests * 100.0 /
        SUM(total_requests) OVER (
            PARTITION BY agency
        ),
        2
    ) AS pct_of_agency_workload

FROM (
    SELECT
        COALESCE(
            NULLIF(TRIM(agency), ''),
            'Unspecified'
        ) AS agency,

        COALESCE(
            NULLIF(TRIM(complaint_type), ''),
            'Unspecified'
        ) AS complaint_type,

        COUNT(*) AS total_requests

    FROM stg_nyc_311_2024

    GROUP BY
        COALESCE(
            NULLIF(TRIM(agency), ''),
            'Unspecified'
        ),
        COALESCE(
            NULLIF(TRIM(complaint_type), ''),
            'Unspecified'
        )
) AS agency_complaints

ORDER BY
    agency,
    total_requests DESC;
    
    
    USE nyc_311_analytics;

-- SQL 10.9A: Top 3 complaint types by agency.
-- Rank complaint categories by request volume within each agency.

SELECT
    agency,
    complaint_type,
    total_requests,
    pct_of_agency_workload,
    agency_rank
FROM (
    SELECT
        agency,
        complaint_type,
        total_requests,

        ROUND(
            total_requests * 100.0 /
            SUM(total_requests) OVER (
                PARTITION BY agency
            ),
            2
        ) AS pct_of_agency_workload,

        ROW_NUMBER() OVER (
            PARTITION BY agency
            ORDER BY total_requests DESC
        ) AS agency_rank

    FROM (
        SELECT
            COALESCE(NULLIF(TRIM(agency), ''), 'Unspecified')
                AS agency,

            COALESCE(NULLIF(TRIM(complaint_type), ''), 'Unspecified')
                AS complaint_type,

            COUNT(*) AS total_requests

        FROM stg_nyc_311_2024

        GROUP BY
            COALESCE(NULLIF(TRIM(agency), ''), 'Unspecified'),
            COALESCE(NULLIF(TRIM(complaint_type), ''), 'Unspecified')
    ) AS agency_complaints
) AS ranked_complaints

WHERE agency_rank <= 3

ORDER BY agency, agency_rank;


-- ============================================================
-- BUSINESS INSIGHTS:
--
-- 1. NYPD's top three complaint categories are Illegal Parking,
--    Noise - Residential, and Blocked Driveway.
--
-- 2. HPD's top three categories are HEAT/HOT WATER,
--    UNSANITARY CONDITION, and PLUMBING, together representing
--    61.52% of its total workload.
--
-- 3. DEP's largest categories are Water System (34.30%),
--    Noise (28.97%), and Sewer (13.68%).
--
-- 4. DHS workload is concentrated in Homeless Person
--    Assistance (76.10%).
--
-- 5. DOB has a more diversified workload across construction,
--    building/use, and elevator complaints.
--
-- 6. Complaint distributions differ considerably by agency,
--    indicating that agency comparisons should account for
--    complaint mix and operational responsibilities.
--
-- BUSINESS RECOMMENDATION:
-- Evaluate agency performance at the complaint-category
-- level rather than relying exclusively on agency-wide
-- average resolution times.
--
-- DATA LIMITATION:
-- Percentages represent each complaint category's share
-- of its agency's 2024 request volume.
-- These results describe reported requests, not the complete
-- scope of each agency's responsibilities.
-- ============================================================



USE nyc_311_analytics;

-- ============================================================
-- SQL 10.10: HPD COMPLAINT RESOLUTION PERFORMANCE
-- ============================================================
-- Business question:
-- How do resolution times differ across HPD's major
-- complaint categories?
--
-- Focus categories:
-- 1. HEAT/HOT WATER
-- 2. UNSANITARY CONDITION
-- 3. PLUMBING
--
-- Metrics:
-- 1. Total requests
-- 2. Valid resolution records
-- 3. Average resolution time
-- 4. Median resolution time
--
-- Data rules:
-- Include all requests in volume counts.
-- Calculate resolution metrics only when both dates
-- are present and closed_date >= created_date.
-- Retain zero-day resolution records.
-- ============================================================

SELECT
    complaint_type,
    COUNT(*) AS total_requests,

    SUM(
        CASE
            WHEN created_date IS NOT NULL
             AND closed_date IS NOT NULL
             AND closed_date >= created_date
            THEN 1
            ELSE 0
        END
    ) AS valid_resolution_records,

    ROUND(
        AVG(
            CASE
                WHEN created_date IS NOT NULL
                 AND closed_date IS NOT NULL
                 AND closed_date >= created_date
                THEN TIMESTAMPDIFF(
                    SECOND,
                    created_date,
                    closed_date
                ) / 86400.0
            END
        ),
        2
    ) AS average_resolution_days

FROM stg_nyc_311_2024

WHERE agency = 'HPD'
  AND complaint_type IN (
      'HEAT/HOT WATER',
      'UNSANITARY CONDITION',
      'PLUMBING'
  )

GROUP BY complaint_type

ORDER BY average_resolution_days DESC;

-- ============================================================
-- BUSINESS INSIGHTS:
--
-- 1. Unsanitary Condition recorded 120,854 requests,
--    with an average resolution time of 20.22 days.
--
-- 2. Plumbing recorded 65,904 HPD requests,
--    with an average resolution time of 19.60 days.
--
-- 3. Heat/Hot Water recorded the largest workload
--    (264,750 requests), but averaged only 1.77 days.
--
-- 4. High request volume does not necessarily correspond
--    to longer resolution duration.
--
-- BUSINESS RECOMMENDATION:
-- Investigate the longer resolution cycles for
-- Unsanitary Condition and Plumbing requests.
-- Examine case complexity, operational workflows,
-- and potential resource constraints.
--
-- DATA LIMITATIONS:
-- Resolution times are measured in calendar days.
-- Only records with valid chronological timestamps
-- are included in the average.
-- Average resolution time does not explain the cause
-- of delays or account for case complexity.
-- ============================================================


USE nyc_311_analytics;

-- ============================================================
-- SQL 10.11: HPD RESOLUTION PERFORMANCE BY BOROUGH
-- ============================================================
-- Business question:
-- Do HPD resolution times differ across boroughs?
--
-- Metrics:
-- 1. Total HPD requests
-- 2. Valid resolution records
-- 3. Average resolution time in calendar days
--
-- Data rules:
-- Include all HPD requests in volume counts.
-- Calculate average resolution only for records with
-- valid creation and closure timestamps.
-- Retain zero-day resolution records.
-- ============================================================

SELECT
    COALESCE(
        NULLIF(TRIM(borough), ''),
        'Unspecified'
    ) AS borough,

    COUNT(*) AS total_requests,

    SUM(
        CASE
            WHEN created_date IS NOT NULL
             AND closed_date IS NOT NULL
             AND closed_date >= created_date
            THEN 1
            ELSE 0
        END
    ) AS valid_resolution_records,

    ROUND(
        AVG(
            CASE
                WHEN created_date IS NOT NULL
                 AND closed_date IS NOT NULL
                 AND closed_date >= created_date
                THEN TIMESTAMPDIFF(
                    SECOND,
                    created_date,
                    closed_date
                ) / 86400.0
            END
        ),
        2
    ) AS average_resolution_days

FROM stg_nyc_311_2024

WHERE agency = 'HPD'

GROUP BY
    COALESCE(
        NULLIF(TRIM(borough), ''),
        'Unspecified'
    )

ORDER BY average_resolution_days DESC;


-- ============================================================
-- BUSINESS INSIGHTS:
--
-- 1. Manhattan recorded the longest HPD average resolution
--    time at 17.47 days.
--
-- 2. Brooklyn followed at 15.05 days.
--
-- 3. The Bronx had the highest HPD request volume:
--    259,983 requests.
--
-- 4. Queens recorded the shortest average resolution
--    time at 12.24 days.
--
-- 5. Manhattan's average resolution time was approximately
--    43% higher than Queens'.
--
-- BUSINESS RECOMMENDATION:
-- Investigate borough-level differences in HPD resolution
-- performance, particularly Manhattan and Brooklyn.
-- Examine complaint mix, case complexity, and operational
-- capacity before attributing the differences to performance.
--
-- DATA LIMITATION:
-- Averages include only valid chronological resolution
-- records and are measured in calendar days.
-- Borough-level averages do not control for complaint type.
-- ============================================================

USE nyc_311_analytics;

-- ============================================================
-- SQL 10.12: HPD COMPLAINT TYPE ANALYSIS BY BOROUGH
-- ============================================================
-- Business question:
-- Which complaint types drive HPD workload in each borough?
--
-- Metrics:
-- 1. Total requests
-- 2. Percentage of borough-level HPD workload
-- 3. Valid resolution records
-- 4. Average resolution time in calendar days
--
-- Data rules:
-- Include all requests in volume counts.
-- Calculate resolution averages only for valid date sequences.
-- Retain zero-day resolution records.
-- ============================================================

SELECT
    borough,
    complaint_type,
    total_requests,

    ROUND(
        total_requests * 100.0 /
        SUM(total_requests) OVER (
            PARTITION BY borough
        ),
        2
    ) AS pct_of_borough_workload,

    valid_resolution_records,
    average_resolution_days

FROM (
    SELECT
        COALESCE(NULLIF(TRIM(borough), ''), 'Unspecified')
            AS borough,

        COALESCE(NULLIF(TRIM(complaint_type), ''), 'Unspecified')
            AS complaint_type,

        COUNT(*) AS total_requests,

        SUM(
            CASE
                WHEN created_date IS NOT NULL
                 AND closed_date IS NOT NULL
                 AND closed_date >= created_date
                THEN 1
                ELSE 0
            END
        ) AS valid_resolution_records,

        ROUND(
            AVG(
                CASE
                    WHEN created_date IS NOT NULL
                     AND closed_date IS NOT NULL
                     AND closed_date >= created_date
                    THEN TIMESTAMPDIFF(
                        SECOND,
                        created_date,
                        closed_date
                    ) / 86400.0
                END
            ),
            2
        ) AS average_resolution_days

    FROM stg_nyc_311_2024

    WHERE agency = 'HPD'

    GROUP BY
        COALESCE(NULLIF(TRIM(borough), ''), 'Unspecified'),
        COALESCE(NULLIF(TRIM(complaint_type), ''), 'Unspecified')
) AS hpd_borough_complaints

ORDER BY borough, total_requests DESC;

-- BUSINESS FINDINGS:
-- 1. Heat/Hot Water is the highest-volume HPD complaint
--    category in all five boroughs.
--
-- 2. Manhattan has longer average resolution times than
--    Queens across several major categories:
--    Unsanitary Condition, Plumbing, Water Leak, General,
--    and Appliance.
--
-- 3. High request volume does not necessarily correspond
--    to longer resolution time. Bronx has the highest
--    Heat/Hot Water volume but a shorter average duration
--    than Manhattan.
--
-- 4. Staten Island has a more balanced demand distribution
--    between Heat/Hot Water and Unsanitary Condition.
--
-- BUSINESS RECOMMENDATION:
-- Investigate borough-level differences in HPD resolution
-- times, particularly Manhattan. Examine case complexity,
-- severity, inspection requirements, repeat complaints,
-- and operational capacity before recommending changes.
--
-- LIMITATIONS:
-- Resolution time is measured in calendar days.
-- Only records with valid chronological timestamps are
-- included in average resolution calculations.
-- These comparisons are descriptive and do not establish
-- causation or prove differences in operational efficiency.

USE nyc_311_analytics;

-- ============================================================
-- SQL 10.13: MONTHLY HPD COMPLAINT DEMAND BY BOROUGH
-- ============================================================
-- Business question:
-- How does HPD complaint demand change month by month
-- across the five NYC boroughs?
--
-- Metrics:
-- 1. Monthly HPD request volume
-- 2. Percentage of annual HPD requests within each borough
-- 3. Percentage of each borough's annual requests
--    contributed by each month
--
-- Business purpose:
-- Identify seasonal demand patterns and potential periods
-- when borough-level operational capacity may need attention.
--
-- Data rules:
-- - Include only HPD requests.
-- - Reporting period is based on Created Date in 2024.
-- - Count all requests, regardless of current status.
-- ============================================================

SELECT
    borough,
    request_month,
    monthly_requests,

    ROUND(
        monthly_requests * 100.0 /
        SUM(monthly_requests) OVER (
            PARTITION BY borough
        ),
        2
    ) AS pct_of_borough_annual_requests

FROM (
    SELECT
        COALESCE(NULLIF(TRIM(borough), ''), 'Unspecified')
            AS borough,

        DATE_FORMAT(created_date, '%Y-%m')
            AS request_month,

        COUNT(*) AS monthly_requests

    FROM stg_nyc_311_2024

    WHERE agency = 'HPD'
      AND created_date >= '2024-01-01'
      AND created_date < '2025-01-01'

    GROUP BY
        COALESCE(NULLIF(TRIM(borough), ''), 'Unspecified'),
        DATE_FORMAT(created_date, '%Y-%m')
) AS monthly_hpd_demand

ORDER BY
    borough,
    request_month;
    
    USE nyc_311_analytics;

-- ============================================================
-- SQL 10.14: MONTHLY HEAT/HOT WATER VS. OTHER HPD COMPLAINTS
-- ============================================================
-- Business question:
-- Are seasonal increases in HPD demand primarily driven
-- by Heat/Hot Water complaints?
--
-- Metrics:
-- 1. Heat/Hot Water requests
-- 2. Other HPD requests
-- 3. Total monthly HPD requests
-- 4. Heat/Hot Water share of monthly HPD demand
--
-- Reporting period: Created Date in calendar year 2024.
-- All HPD requests are included in volume calculations.
-- ============================================================

SELECT
    borough,
    request_month,

    SUM(
        CASE
            WHEN complaint_type = 'HEAT/HOT WATER'
            THEN 1
            ELSE 0
        END
    ) AS heat_hot_water_requests,

    SUM(
        CASE
            WHEN complaint_type <> 'HEAT/HOT WATER'
                 OR complaint_type IS NULL
            THEN 1
            ELSE 0
        END
    ) AS other_hpd_requests,

    COUNT(*) AS total_hpd_requests,

    ROUND(
        SUM(
            CASE
                WHEN complaint_type = 'HEAT/HOT WATER'
                THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS heat_hot_water_share_pct

FROM (
    SELECT
        COALESCE(NULLIF(TRIM(borough), ''), 'Unspecified')
            AS borough,

        DATE_FORMAT(created_date, '%Y-%m')
            AS request_month,

        complaint_type

    FROM stg_nyc_311_2024

    WHERE agency = 'HPD'
      AND created_date >= '2024-01-01'
      AND created_date < '2025-01-01'
) AS hpd_monthly_categories

GROUP BY
    borough,
    request_month

ORDER BY
    borough,
    request_month;
    
    /*
BUSINESS INSIGHTS:

1. Heat/Hot Water complaints show a strong seasonal pattern
   across all five boroughs.

2. During December, Heat/Hot Water represents:
   - Bronx: 62.03%
   - Brooklyn: 57.03%
   - Manhattan: 65.24%
   - Queens: 62.85%
   - Staten Island: 48.47%

3. During the lowest summer-share month, the category
   represents less than 12% of monthly HPD demand in
   every borough.

4. Seasonal changes in Heat/Hot Water complaints are
   strongly associated with changes in overall HPD demand.

BUSINESS RECOMMENDATION:

Use historical seasonal demand to prepare HPD inspection
and response capacity ahead of winter. Monitor the increase
in heating-related complaints beginning in autumn and
evaluate borough-specific resource requirements.

LIMITATIONS:

- This analysis measures complaint volume, not weather
  conditions or actual heating-system failures.
- Seasonal association does not establish causation.
- Complaint resolution performance has not yet been
  evaluated by month in this analysis.
*/



USE nyc_311_analytics;

-- ============================================================
-- SQL 10.15: MONTHLY HEAT/HOT WATER RESOLUTION PERFORMANCE
-- ============================================================
-- Business question:
-- Does seasonal demand for Heat/Hot Water complaints
-- coincide with changes in average resolution time?
--
-- Metrics:
-- 1. Monthly complaint volume
-- 2. Valid resolution records
-- 3. Average resolution time in calendar days
--
-- Data rules:
-- - HPD agency only
-- - HEAT/HOT WATER complaint category only
-- - Created Date within 2024
-- - Average resolution time includes only valid
--   chronological date sequences
-- ============================================================

SELECT
    COALESCE(NULLIF(TRIM(borough), ''), 'Unspecified')
        AS borough,

    DATE_FORMAT(created_date, '%Y-%m')
        AS request_month,

    COUNT(*) AS total_requests,

    SUM(
        CASE
            WHEN closed_date IS NOT NULL
             AND closed_date >= created_date
            THEN 1
            ELSE 0
        END
    ) AS valid_resolution_records,

    ROUND(
        AVG(
            CASE
                WHEN closed_date IS NOT NULL
                 AND closed_date >= created_date
                THEN TIMESTAMPDIFF(
                    SECOND,
                    created_date,
                    closed_date
                ) / 86400.0
            END
        ),
        2
    ) AS average_resolution_days

FROM stg_nyc_311_2024

WHERE agency = 'HPD'
  AND complaint_type = 'HEAT/HOT WATER'
  AND created_date >= '2024-01-01'
  AND created_date < '2025-01-01'

GROUP BY
    COALESCE(NULLIF(TRIM(borough), ''), 'Unspecified'),
    DATE_FORMAT(created_date, '%Y-%m')

ORDER BY
    borough,
    request_month;
    
    
   /*
BUSINESS INSIGHTS:

1. Heat/Hot Water complaints experience substantially higher
   demand during winter months.

2. Higher winter complaint volume does not produce a
   proportional increase in average resolution time.

3. December average resolution times range from 1.80 to
   2.49 calendar days across the five boroughs.

4. Some low-volume summer months show higher averages.
   Examples include Brooklyn in August (5.11 days) and
   Staten Island in August (4.92 days).

5. Low-volume groups should be interpreted cautiously
   because a small number of long-duration cases can
   materially affect the average.

BUSINESS RECOMMENDATION:

Plan for increased winter intake while monitoring
resolution performance separately. Investigate unusually
high resolution times in low-volume periods before
drawing conclusions about operational efficiency.

LIMITATIONS:

- Average resolution time can be affected by outliers.
- Only valid chronological date records are included.
- Results are grouped by request creation month.
- These findings do not establish a causal relationship
  between demand and resolution time.
*/



USE nyc_311_analytics;

-- ============================================================
-- SQL 10.16: WINTER VS. SUMMER RESOLUTION-TIME DISTRIBUTION
-- ============================================================
-- Business question:
-- Are Heat/Hot Water complaints resolved within similar
-- time ranges during winter and summer?
--
-- Seasonal definitions:
-- Winter: January, February, November, December
-- Summer: June, July, August, September
--
-- Resolution categories:
-- 1. Within 1 day (0 to 1 day)
-- 2. More than 1 day and up to 3 days
-- 3. More than 3 days
--
-- Data rules:
-- - HPD agency only
-- - HEAT/HOT WATER complaints only
-- - Valid chronological dates only
-- - Zero-day resolutions are included in the first category
-- ============================================================

SELECT
    season,

    COUNT(*) AS valid_resolution_requests,

    SUM(
        CASE
            WHEN resolution_days <= 1 THEN 1
            ELSE 0
        END
    ) AS resolved_within_1_day,

    ROUND(
        SUM(
            CASE
                WHEN resolution_days <= 1 THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS pct_within_1_day,

    SUM(
        CASE
            WHEN resolution_days > 1
             AND resolution_days <= 3
            THEN 1
            ELSE 0
        END
    ) AS resolved_1_to_3_days,

    ROUND(
        SUM(
            CASE
                WHEN resolution_days > 1
                 AND resolution_days <= 3
                THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS pct_1_to_3_days,

    SUM(
        CASE
            WHEN resolution_days > 3 THEN 1
            ELSE 0
        END
    ) AS resolved_after_3_days,

    ROUND(
        SUM(
            CASE
                WHEN resolution_days > 3 THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS pct_after_3_days

FROM (
    SELECT
        CASE
            WHEN MONTH(created_date) IN (1, 2, 11, 12)
                THEN 'Winter'
            WHEN MONTH(created_date) IN (6, 7, 8, 9)
                THEN 'Summer'
        END AS season,

        TIMESTAMPDIFF(
            SECOND,
            created_date,
            closed_date
        ) / 86400.0 AS resolution_days

    FROM stg_nyc_311_2024

    WHERE agency = 'HPD'
      AND complaint_type = 'HEAT/HOT WATER'
      AND created_date >= '2024-01-01'
      AND created_date < '2025-01-01'
      AND closed_date IS NOT NULL
      AND closed_date >= created_date
      AND MONTH(created_date) IN (1, 2, 6, 7, 8, 9, 11, 12)
) AS seasonal_resolution_data

GROUP BY season

ORDER BY
    CASE
        WHEN season = 'Winter' THEN 1
        WHEN season = 'Summer' THEN 2
    END; 
    
    USE nyc_311_analytics;

-- ============================================================
-- SQL 10.17: SEASONAL RESOLUTION DISTRIBUTION BY BOROUGH
-- ============================================================
-- Business question:
-- Does the winter-versus-summer resolution pattern differ
-- across NYC boroughs?
--
-- Seasons:
-- Winter: January, February, November, December
-- Summer: June, July, August, September
--
-- Metrics:
-- 1. Valid resolution records
-- 2. Requests resolved within 1 day
-- 3. Requests resolved in more than 1 and up to 3 days
-- 4. Requests taking more than 3 days
--
-- Percentages are calculated within each borough and season.
-- ============================================================

SELECT
    borough,
    season,
    COUNT(*) AS valid_resolution_requests,

    ROUND(
        SUM(CASE WHEN resolution_days <= 1 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*),
        2
    ) AS pct_within_1_day,

    ROUND(
        SUM(
            CASE
                WHEN resolution_days > 1
                 AND resolution_days <= 3
                THEN 1 ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS pct_1_to_3_days,

    ROUND(
        SUM(CASE WHEN resolution_days > 3 THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*),
        2
    ) AS pct_after_3_days

FROM (
    SELECT
        COALESCE(NULLIF(TRIM(borough), ''), 'Unspecified')
            AS borough,

        CASE
            WHEN MONTH(created_date) IN (1, 2, 11, 12)
                THEN 'Winter'
            ELSE 'Summer'
        END AS season,

        TIMESTAMPDIFF(
            SECOND,
            created_date,
            closed_date
        ) / 86400.0 AS resolution_days

    FROM stg_nyc_311_2024

    WHERE agency = 'HPD'
      AND complaint_type = 'HEAT/HOT WATER'
      AND created_date >= '2024-01-01'
      AND created_date < '2025-01-01'
      AND closed_date IS NOT NULL
      AND closed_date >= created_date
      AND MONTH(created_date) IN (1, 2, 6, 7, 8, 9, 11, 12)
) AS borough_seasonal_resolution

GROUP BY
    borough,
    season

ORDER BY
    borough,
    CASE WHEN season = 'Winter' THEN 1 ELSE 2 END;
    
    
 ### SQL 10.17 — Seasonal Resolution Distribution by Borough

-- ============================================================
-- SQL 10.17: SEASONAL RESOLUTION DISTRIBUTION BY BOROUGH
-- ============================================================
--
-- BUSINESS QUESTION:
-- Does the resolution-time distribution for HPD Heat/Hot Water
-- requests differ between winter and summer across NYC boroughs?
--
-- KEY FINDINGS:
-- 1. Brooklyn's share of requests taking more than 3 days
--    increased from 21.26% in winter to 27.67% in summer.
--
-- 2. The Bronx increased from 9.36% in winter to 15.34%
--    in summer.
--
-- 3. Manhattan decreased from 23.62% to 22.06%.
--
-- 4. Queens decreased from 16.49% to 12.55%.
--
-- 5. Staten Island recorded 47.89% in summer compared with
--    15.22% in winter. However, its summer sample contained
--    only 213 valid records.
--
-- 6. Winter had substantially more valid resolution records
--    than summer across every borough.
--
-- BUSINESS INSIGHT:
-- Seasonal resolution patterns vary across boroughs.
-- Brooklyn and the Bronx show higher proportions of longer-
-- resolution requests during summer, while Manhattan and
-- Queens show the opposite pattern.
--
-- Staten Island's summer result deserves further investigation,
-- but its small sample size limits the strength of the finding.
--
-- BUSINESS RECOMMENDATION:
-- Investigate seasonal differences by reviewing complaint
-- characteristics, case severity, inspection requirements,
-- and operational capacity.
--
-- Use these findings to identify where additional monitoring
-- or process improvements may be useful.
--
-- LIMITATIONS:
-- 1. Resolution time is measured in calendar days, not
--    business days.
-- 2. Only records with valid chronological creation and
--    closure dates are included.
-- 3. Summer has substantially fewer valid records than winter.
-- 4. Seasonal comparisons are descriptive and do not
--    establish causation.
-- 5. Staten Island's summer result should be interpreted
--    cautiously because of its small sample size.
--
-- ============================================================
-- STATUS: COMPLETED
-- ============================================================


USE nyc_311_analytics;

-- ============================================================
-- SQL 11.1: POWER BI DASHBOARD DATASET
-- Purpose: Create a curated view for Power BI reporting.
-- Source: vw_nyc_311_2024_analytics
-- ============================================================

CREATE OR REPLACE VIEW vw_nyc_311_2024_powerbi AS

SELECT
    unique_key,
    created_date,
    closed_date,

    YEAR(created_date) AS created_year,
    MONTH(created_date) AS created_month_number,
    DATE_FORMAT(created_date, '%b') AS created_month_name,
    DATE_FORMAT(created_date, '%Y-%m') AS created_year_month,

    CASE
        WHEN MONTH(created_date) IN (1, 2, 11, 12)
            THEN 'Winter'
        WHEN MONTH(created_date) IN (6, 7, 8, 9)
            THEN 'Summer'
        ELSE 'Other'
    END AS season,

    agency,
    agency_name,
    complaint_type,
    descriptor,
    borough,
    status,

    status_date_quality_flag,
    resolution_date_quality_flag,
    resolution_time_days

FROM vw_nyc_311_2024_analytics;

SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT unique_key) AS unique_requests,
    MIN(created_date) AS first_request,
    MAX(created_date) AS last_request
FROM vw_nyc_311_2024_powerbi;

