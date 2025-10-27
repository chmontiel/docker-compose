/*
--------------------------------------------------------------------------------
Title:
    Data Composition by Host and Metric

Description:
    This query summarizes how much monitoring data each host (server) contributes
    overall and how that data is distributed across different metric types
    (StatNames).

Fields:
    • HostName    – the system or server being monitored (e.g., BSA-AZURE-DBP1)
    • StatName    – the specific metric category (e.g., ServiceUp, PingTime)
    • RowCounter  – how many rows exist for that (HostName, StatName) pair;
                    this shows how much that metric contributes for that host
    • TotalRows   – how many total rows that host contributed across all metrics;
                    this shows how "loud" or "chatty" that host is overall

Grafana Visualization:
    • Recommended panel: Horizontal bar chart
    • Y-Axis → HostName
    • X-Axis → RowCounter and/or TotalRows
    • Green Bar (RowCounter) → data volume for that specific metric
    • Yellow Bar (TotalRows) → total data volume for that host

Interpretation / Insights:
    • Shows which hosts produce the most total monitoring data.
    • Shows which specific metrics make up most of that host's data.
    • Helps identify:
        - very noisy hosts
        - dominant metric types (like ServiceUp, PingTime, etc.)
--------------------------------------------------------------------------------
*/
;WITH HostCounts AS (
    SELECT 
        Name AS HostName,
        COUNT(*) AS TotalRows
    FROM dbo.StatsDump
    GROUP BY Name
),
HostStatBreakdown AS (
    SELECT
        s.Name AS HostName,
        s.StatName,
        COUNT(*) AS RowCounter,
        hc.TotalRows
    FROM dbo.StatsDump s
    JOIN HostCounts hc
        ON s.Name = hc.HostName
    WHERE hc.TotalRows > 100   -- keep only "busy" hosts
    GROUP BY
        s.Name,
        s.StatName,
        hc.TotalRows
)
SELECT TOP 20
    HostName,
    StatName,
    RowCounter,
    TotalRows
FROM HostStatBreakdown
ORDER BY
    TotalRows DESC,
    RowCounter DESC;
-- Suggested Grafana panel title:
-- Data Composition by Host and Metric
--------------------------------------------------------------------------------


/*
--------------------------------------------------------------------------------
Title:
    Dataset Composition by StatName

Description:
    Summarizes the composition of the StatsDump dataset by metric type
    (StatName). This shows which metrics appear most often in the data.

Fields:
    • StatName      – the metric name (e.g., ServiceUp, PingTime, Percent Free)
    • RowCounter    – how many rows exist for that metric in total
    • ExampleUnit   – a representative unit for that metric (%, Bytes, ms);
                      taken with MAX(UnitStr) just to display something readable

Grafana Visualization:
    • Recommended panel: Bar chart
    • X-Axis → RowCounter
    • Y-Axis → StatName
    • Suggested title: "Dataset Composition by StatName"

Interpretation / Insights:
    • Shows which metric types dominate collection.
    • Helps answer "What are we actually monitoring the most?"
    • If one StatName is huge (like ServiceUp), that’s where most monitoring focus is.
--------------------------------------------------------------------------------
*/
SELECT 
    StatName,
    COUNT(*) AS RowCounter,
    MAX(UnitStr) AS ExampleUnit
FROM dbo.StatsDump
GROUP BY StatName
ORDER BY RowCounter DESC;
-- Suggested Grafana panel title:
-- Dataset Composition by StatName
--------------------------------------------------------------------------------

/*
--------------------------------------------------------------------------------
Title:
    Row Count per StatType

Description:
    Groups all rows by StatType (a numeric category code for metrics) and counts
    how many rows each StatType produced. StatType is cast to text so that
    Grafana can use it as a category label in a bar chart.

Fields:
    • StatTypeLabel – the StatType numeric code as text (for display)
    • Records       – how many rows in StatsDump have that StatType value

Grafana Visualization:
    • Recommended panel: Bar chart
    • X-Axis → Records
    • Y-Axis → StatTypeLabel
    • Suggested title: "Row Count per StatType"

Interpretation / Insights:
    • Shows which StatType classes are generating the most data.
    • Useful to spot which internal categories of monitoring are the “noisiest.”
    • If you later map StatType codes to meanings (ex: 22 = Free Bytes), the
      panel becomes even more readable.
--------------------------------------------------------------------------------
*/
SELECT
    CAST(StatType AS NVARCHAR(50)) AS StatTypeLabel,
    COUNT(*) AS Records
FROM dbo.StatsDump
GROUP BY StatType
ORDER BY Records DESC;
-- Suggested Grafana panel title:
-- Row Count per StatType
--------------------------------------------------------------------------------


/*
--------------------------------------------------------------------------------
Title:
    Top 20 Hosts by Metric Coverage

Description:
    Shows how broadly each host is being monitored by counting how many distinct
    metric types (StatName) exist for that host.

Fields:
    • HostName              – the machine / server being monitored
    • MetricTypesCollected  – how many unique StatName values that host has

Grafana Visualization:
    • Recommended panel: Horizontal bar chart
    • Y-Axis → HostName
    • X-Axis → MetricTypesCollected
    • Suggested title: "Top 20 Hosts by Metric Coverage"

Interpretation / Insights:
    • Higher MetricTypesCollected = this host is being monitored in more ways
      (disk, ping, bandwidth, services, DB, etc.).
    • Helps you identify:
        - Hosts with strong/complete monitoring
        - Hosts that might be under-monitored (low coverage)
    • Good for answering "Which systems have full visibility?"
--------------------------------------------------------------------------------
*/
SELECT TOP 20
    Name AS HostName,
    COUNT(DISTINCT StatName) AS MetricTypesCollected
FROM dbo.StatsDump
GROUP BY Name
ORDER BY MetricTypesCollected DESC;
-- Suggested Grafana panel title:
-- Top 20 Hosts by Metric Coverage
--------------------------------------------------------------------------------

/*
--------------------------------------------------------------------------------
Title:
    Database & Log Metric Coverage

Description:
    Focuses on database-related and log-related metrics only. It shows how many
    records we have for each DB/log metric type, and how many distinct database
    targets are being monitored for that metric.

Filters:
    • Only includes rows where StatName contains 'DB' or 'LOG'.
      Examples might include:
        - DB_PLUS_INDEX_SIZE
        - LOG_SIZE
        - LOG_PCT_USED
        - DATABASE_PCT_USED

Fields:
    • StatName           – which DB/log metric this is
    • Records            – how many total rows in StatsDump use that StatName
    • DistinctDatabases  – how many different ItemName values are being tracked
                           for that StatName (ItemName in this case is usually
                           the database name, like SLN_MDX_PROD, etc.)

Grafana Visualization:
    • Recommended panel: Table OR vertical bar chart
    • Bar chart:
        - Y-Axis → StatName
        - X-Axis → Records
    • Suggested title: "Database & Log Metric Coverage"

Interpretation / Insights:
    • Shows which DB/log health metrics are collected the most.
    • Tells you how many distinct databases are actually being monitored.
    • Helps answer:
        - "Are we collecting DB size and log usage across multiple DBs?"
        - "Which DB metrics are we relying on the most?"
--------------------------------------------------------------------------------
*/
SELECT 
    StatName,
    COUNT(*) AS Records,
    COUNT(DISTINCT ItemName) AS DistinctDatabases
FROM dbo.StatsDump
WHERE StatName LIKE '%DB%' OR StatName LIKE '%LOG%'
GROUP BY StatName
ORDER BY Records DESC;
-- Suggested Grafana panel title:
-- Database & Log Metric Coverage
--------------------------------------------------------------------------------

/*
--------------------------------------------------------------------------------
Title:
    Top 10 Hosts by Drives Monitored (Percent Free)

Description:
    Shows the top 10 hosts that are tracking the most drives for the "Percent Free"
    metric. "Percent Free" is the disk space remaining on each drive.

Fields:
    • HostName          – the server / machine name
    • DrivesMonitored   – how many distinct drives (ItemName) on that host are
                           being monitored for Percent Free

Query Behavior:
    • Looks only at rows where StatName = 'Percent Free'.
    • Groups by host.
    • Counts how many different drives that host is tracking.
    • Returns only the top 10 hosts, sorted from highest to lowest.

Grafana Visualization:
    • Recommended panel: Horizontal bar chart
    • Y-Axis → HostName
    • X-Axis → DrivesMonitored
    • Suggested title: "Top 10 Hosts by Drive Monitoring (Percent Free)"

Interpretation / Insights:
    • Shows which systems have the most storage volumes being actively monitored.
    • If a host you expect is missing or has a low count, that could mean
      incomplete disk monitoring.
    • Helpful for checking drive coverage across the environment.
--------------------------------------------------------------------------------
*/
SELECT TOP 10
    Name AS HostName,
    COUNT(DISTINCT ItemName) AS DrivesMonitored
FROM dbo.StatsDump
WHERE StatName = 'Percent Free'
GROUP BY Name
ORDER BY DrivesMonitored DESC;
-- Suggested Grafana panel title:
-- Top 10 Hosts by Drive Monitoring (Percent Free)
--------------------------------------------------------------------------------


/*
--------------------------------------------------------------------------------
Title:
    Top 10 Hosts by Total Rows Collected

Description:
    Shows which hosts are producing the most total monitoring records overall.
    This is basically "who is the noisiest / most monitored system" in terms
    of sheer volume.

Fields:
    • HostName   – the machine / system name
    • TotalRows  – how many rows in StatsDump came from that host, across
                   all StatName types

Grafana Visualization:
    • Recommended panel: Horizontal bar chart
    • Y-Axis → HostName
    • X-Axis → TotalRows
    • Suggested title: "Top 10 Hosts by Total Rows"

Interpretation / Insights:
    • High TotalRows = that host is heavily monitored or generates lots of data.
    • Lets you spot "high attention" systems (maybe critical servers).
    • Also helps identify imbalance: if one host has way more rows than others,
      it may be doing more work OR duplicating data.
--------------------------------------------------------------------------------
*/
SELECT TOP 10
    Name AS HostName,
    COUNT(*) AS TotalRows
FROM dbo.StatsDump
GROUP BY Name
ORDER BY TotalRows DESC;
-- Suggested Grafana panel title:
-- Top 10 Hosts by Total Rows
--------------------------------------------------------------------------------


/*
--------------------------------------------------------------------------------
Title:
    Top 10 Hosts by Drives Monitored (All Disk Metrics)

Description:
    Shows which hosts are reporting on the most distinct drives, based on any
    disk-related metric (`Free Bytes`, `Used Bytes`, `Percent Free`). This is a
    broader view than just 'Percent Free'.

Fields:
    • HostName          – the host/server name
    • DrivesMonitored   – how many different drive names (ItemName) are being
                           tracked for that host

Query Behavior:
    • Filters to rows where StatName is one of the core disk metrics:
        - 'Free Bytes'   (remaining space in bytes)
        - 'Used Bytes'   (used space in bytes)
        - 'Percent Free' (percent of space available)
    • Groups by host.
    • Counts DISTINCT drives per host.
    • Returns the top 10 results.

Grafana Visualization:
    • Recommended panel: Horizontal bar chart
    • Y-Axis → HostName
    • X-Axis → DrivesMonitored
    • Suggested title: "Top 10 Hosts by Drive Monitoring Coverage"

Interpretation / Insights:
    • Shows storage monitoring depth per host.
    • Helps validate that all drives are actually being watched.
    • If a critical host shows only 1 drive monitored and you know it has more,
      that’s a configuration gap.
--------------------------------------------------------------------------------
*/
SELECT TOP 10
    Name AS HostName,
    COUNT(DISTINCT ItemName) AS DrivesMonitored
FROM dbo.StatsDump
WHERE StatName IN ('Free Bytes', 'Used Bytes', 'Percent Free')
GROUP BY Name
ORDER BY DrivesMonitored DESC;
-- Suggested Grafana panel title:
-- Top 10 Hosts by Drive Monitoring Coverage
--------------------------------------------------------------------------------



-- Host part before the dash
LEFT(Name, CHARINDEX('-', Name + '-') - 1)        AS HostName,

-- User part after the dash
SUBSTRING(
    Name,
    CHARINDEX('-', Name + '-') + 1,
    LEN(Name)
)                                                AS UserName

SELECT
    -- Host part (everything before the first dash)
    LEFT(Name, CHARINDEX('-', Name + '-') - 1) AS HostName,

    -- User part (everything after the first dash)
    SUBSTRING(
        Name,
        CHARINDEX('-', Name + '-') + 1,
        LEN(Name)
    ) AS UserName
FROM dbo.StatsDump;

SELECT
    LEFT(Name, CHARINDEX('-', Name + '-') - 1) AS HostName,
    COUNT(*) AS MetricCount
FROM dbo.StatsDump
GROUP BY LEFT(Name, CHARINDEX('-', Name + '-') - 1)
ORDER BY MetricCount DESC;

SELECT
    LEFT(Name, CHARINDEX('-', Name + '-') - 1) AS HostName,
    SUBSTRING(Name, CHARINDEX('-', Name + '-') + 1, LEN(Name)) AS UserName,
    COUNT(*) AS MetricCount
FROM dbo.StatsDump
GROUP BY
    LEFT(Name, CHARINDEX('-', Name + '-') - 1),
    SUBSTRING(Name, CHARINDEX('-', Name + '-') + 1, LEN(Name))
ORDER BY
    HostName,
    MetricCount DESC;

SELECT
    CASE OwnerType
        WHEN 1 THEN 'Disk IO'
        WHEN 3 THEN 'Service Up'
        ELSE CONCAT('Type ', CONVERT(VARCHAR(10), OwnerType))
    END AS MetricCategory,
    COUNT(*) AS MetricCount
FROM dbo.StatsDump
GROUP BY
    CASE OwnerType
        WHEN 1 THEN 'Disk IO'
        WHEN 3 THEN 'Service Up'
        ELSE CONCAT('Type ', CONVERT(VARCHAR(10), OwnerType))
    END
ORDER BY MetricCount DESC;



SELECT
    LEFT(Name, CHARINDEX('-', Name + '-') - 1) AS HostName,
    COUNT(*) AS ServiceUpChecks
FROM dbo.StatsDump
WHERE OwnerType = 3
GROUP BY LEFT(Name, CHARINDEX('-', Name + '-') - 1)
ORDER BY ServiceUpChecks DESC;


SELECT
    LEFT(Name, CHARINDEX('-', Name + '-') - 1) AS HostName,
    COUNT(*) AS DiskIOMetrics
FROM dbo.StatsDump
WHERE OwnerType = 1
GROUP BY LEFT(Name, CHARINDEX('-', Name + '-') - 1)
ORDER BY DiskIOMetrics DESC;