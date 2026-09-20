-- =============================================================
-- DATABASE & CORE STAR-SCHEMA SETUP
-- Creates the main manufacturing dimensions and fact tables.
-- =============================================================
﻿USE ManufacturingEfficiencyDB;
GO
CREATE TABLE dbo.Dim_Plant
(
    PlantID      VARCHAR(20)  NOT NULL,
    PlantName    VARCHAR(100) NOT NULL,
    City         VARCHAR(100) NOT NULL,
    Country      VARCHAR(100) NOT NULL,
    GridRegion   VARCHAR(100) NOT NULL,
    IndustryType VARCHAR(100) NOT NULL,

    CONSTRAINT PK_Dim_Plant
        PRIMARY KEY (PlantID)
);
GO
CREATE TABLE dbo.Dim_Line
(
    LineID   VARCHAR(20)  NOT NULL,
    LineName VARCHAR(100) NOT NULL,
    PlantID  VARCHAR(20)  NOT NULL,

    CONSTRAINT PK_Dim_Line
        PRIMARY KEY (LineID)
);
GO
CREATE TABLE dbo.Dim_Machine
(
    MachineID   VARCHAR(20)  NOT NULL,
    MachineName VARCHAR(100) NOT NULL,
    MachineType VARCHAR(100) NOT NULL,
    LineID      VARCHAR(20)  NOT NULL,
    PlantID     VARCHAR(20)  NOT NULL,

    CONSTRAINT PK_Dim_Machine
        PRIMARY KEY (MachineID)
);
GO
CREATE TABLE dbo.Dim_Product
(
    ProductID            VARCHAR(20)  NOT NULL,
    ProductName          VARCHAR(100) NOT NULL,
    ProductFamily        VARCHAR(100) NOT NULL,
    StandardCycleTimeSec INT          NOT NULL,

    CONSTRAINT PK_Dim_Product
        PRIMARY KEY (ProductID)
);
GO
CREATE TABLE dbo.Dim_Shift
(
    ShiftID         VARCHAR(20)  NOT NULL,
    ShiftName       VARCHAR(100) NOT NULL,
    StartTime       VARCHAR(10)  NOT NULL,
    EndTime         VARCHAR(10)  NOT NULL,
    StartTimeParsed VARCHAR(20)  NOT NULL,
    EndTimeParsed   VARCHAR(20)  NOT NULL,

    CONSTRAINT PK_Dim_Shift
        PRIMARY KEY (ShiftID)
);
GO
CREATE TABLE dbo.Dim_Status
(
    StatusID      INT          NOT NULL,
    StatusName    VARCHAR(100) NOT NULL,
    IsProductive  BIT          NOT NULL,
    SeverityLevel VARCHAR(50)  NOT NULL,

    CONSTRAINT PK_Dim_Status
        PRIMARY KEY (StatusID)
);
GO
CREATE TABLE dbo.Dim_DowntimeReason
(
    ReasonID       VARCHAR(20)  NOT NULL,
    ReasonCategory VARCHAR(100) NOT NULL,
    ReasonName     VARCHAR(150) NOT NULL,
    IsPlanned      BIT          NOT NULL,
    SeverityWeight INT          NOT NULL,

    CONSTRAINT PK_Dim_DowntimeReason
        PRIMARY KEY (ReasonID)
);
GO
CREATE TABLE dbo.Dim_EnergyTariff
(
    TariffID     VARCHAR(20)   NOT NULL,
    TariffName   VARCHAR(100)  NOT NULL,
    CalendarYear INT           NOT NULL,
    TimeBand     VARCHAR(50)   NOT NULL,
    StartTime    VARCHAR(10)   NOT NULL,
    EndTime      VARCHAR(10)   NOT NULL,
    RatePerKWh   DECIMAL(10,4) NOT NULL,
    IsPeak       BIT           NOT NULL,

    CONSTRAINT PK_Dim_EnergyTariff
        PRIMARY KEY (TariffID)
);
GO
-- =============================================================
-- DIMENSION FOREIGN KEYS
-- Links Line, Machine, and Plant tables to maintain referential integrity.
-- =============================================================
ALTER TABLE dbo.Dim_Line
ADD CONSTRAINT FK_Dim_Line_Plant
FOREIGN KEY (PlantID)
REFERENCES dbo.Dim_Plant(PlantID);
GO
ALTER TABLE dbo.Dim_Machine
ADD CONSTRAINT FK_Dim_Machine_Line
FOREIGN KEY (LineID)
REFERENCES dbo.Dim_Line(LineID);
GO
ALTER TABLE dbo.Dim_Machine
ADD CONSTRAINT FK_Dim_Machine_Plant
FOREIGN KEY (PlantID)
REFERENCES dbo.Dim_Plant(PlantID);
GO
-- =============================================================
-- DATABASE STRUCTURE VALIDATION
-- Checks existing tables and primary keys after schema creation.
-- =============================================================
SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
SELECT
    t.name AS TableName,
    i.name AS PrimaryKey
FROM sys.tables t
JOIN sys.indexes i
    ON t.object_id = i.object_id
WHERE i.is_primary_key = 1
ORDER BY t.name;
-- =============================================================
-- DOWNTIME FACT TABLE
-- Stores downtime events together with quality/data-validation flags.
-- =============================================================
CREATE TABLE dbo.Fact_DowntimeEvents
(
    DowntimeEventID          VARCHAR(30)    NOT NULL,
    PlantID                  VARCHAR(20)    NOT NULL,
    MachineID                VARCHAR(20)    NOT NULL,
    LineID                   VARCHAR(20)    NOT NULL,
    ShiftID                  VARCHAR(20)    NOT NULL,

    StartTimestamp           DATETIME2(6)   NOT NULL,
    EndTimestamp             DATETIME2(6)   NOT NULL,
    DurationMinutes          INT            NOT NULL,

    ReasonID                 VARCHAR(20)    NOT NULL,
    ProductID                VARCHAR(20)    NOT NULL,

    EnergyDuringDowntimeKWh  DECIMAL(18,6)  NOT NULL,

    DQ_InvalidTimeOrder      BIT            NOT NULL,
    DQ_InvalidDuration       BIT            NOT NULL,
    DQ_InvalidForeignKey     BIT            NOT NULL,
    DQ_HasError              BIT            NOT NULL,

    DQ_Status                VARCHAR(50)    NOT NULL,

    CONSTRAINT PK_Fact_DowntimeEvents
        PRIMARY KEY (DowntimeEventID)
);
GO
-- =============================================================
-- PRODUCTION & ENERGY FACT TABLE
-- Main operational fact table containing production, energy, quality,
-- cycle-time, anomaly, and data-quality information.
-- =============================================================
CREATE TABLE dbo.Fact_ProductionEnergy
(
    ReadingID                    BIGINT         NOT NULL,
    Timestamp                    DATETIME2(6)   NOT NULL,

    PlantID                      VARCHAR(20)    NOT NULL,
    ShiftID                      VARCHAR(20)    NOT NULL,
    TariffID                     VARCHAR(20)    NOT NULL,
    StatusID                     INT            NOT NULL,
    MachineID                    VARCHAR(20)    NOT NULL,
    LineID                       VARCHAR(20)    NOT NULL,

    ProductID                    VARCHAR(20)    NULL,

    ItemsProduced                INT            NOT NULL,
    RejectedItems                INT            NOT NULL,

    ActualCycleTimeSec           DECIMAL(18,6)  NULL,

    PowerAvgKW                   DECIMAL(18,6)  NOT NULL,
    PowerMaxKW                   DECIMAL(18,6)  NOT NULL,
    PowerMinKW                   DECIMAL(18,6)  NOT NULL,

    EnergyKWh                    DECIMAL(18,6)  NOT NULL,
    AmbientTempC                 DECIMAL(10,4)  NOT NULL,

    OUT_Energy_Contextual        BIT            NOT NULL,
    OUT_CycleTime_Contextual     BIT            NOT NULL,

    DQ_InvalidQuantity           BIT            NOT NULL,
    DQ_InvalidPower              BIT            NOT NULL,
    DQ_InvalidEnergy             BIT            NOT NULL,
    DQ_InvalidCycleTime          BIT            NOT NULL,
    DQ_DuplicateMachineTimestamp BIT            NOT NULL,
    DQ_InvalidForeignKey         BIT            NOT NULL,
    DQ_ShiftMismatch             BIT            NOT NULL,
    DQ_ZeroOutputWarning         BIT            NOT NULL,
    DQ_HasError                  BIT            NOT NULL,
    DQ_OperationalAnomaly        BIT            NOT NULL,

    DQ_Status                    VARCHAR(50)     NOT NULL,

    CONSTRAINT PK_Fact_ProductionEnergy
        PRIMARY KEY (ReadingID)
);
GO
-- =============================================================
-- FACT-TABLE FOREIGN KEYS
-- Connects downtime and production facts to their related dimensions.
-- =============================================================
ALTER TABLE dbo.Fact_DowntimeEvents
ADD CONSTRAINT FK_Downtime_Plant
FOREIGN KEY (PlantID)
REFERENCES dbo.Dim_Plant(PlantID);
GO

ALTER TABLE dbo.Fact_DowntimeEvents
ADD CONSTRAINT FK_Downtime_Machine
FOREIGN KEY (MachineID)
REFERENCES dbo.Dim_Machine(MachineID);
GO

ALTER TABLE dbo.Fact_DowntimeEvents
ADD CONSTRAINT FK_Downtime_Line
FOREIGN KEY (LineID)
REFERENCES dbo.Dim_Line(LineID);
GO

ALTER TABLE dbo.Fact_DowntimeEvents
ADD CONSTRAINT FK_Downtime_Shift
FOREIGN KEY (ShiftID)
REFERENCES dbo.Dim_Shift(ShiftID);
GO

ALTER TABLE dbo.Fact_DowntimeEvents
ADD CONSTRAINT FK_Downtime_Reason
FOREIGN KEY (ReasonID)
REFERENCES dbo.Dim_DowntimeReason(ReasonID);
GO

ALTER TABLE dbo.Fact_DowntimeEvents
ADD CONSTRAINT FK_Downtime_Product
FOREIGN KEY (ProductID)
REFERENCES dbo.Dim_Product(ProductID);
GO
----------------------------------------------------------
ALTER TABLE dbo.Fact_ProductionEnergy
ADD CONSTRAINT FK_Production_Plant
FOREIGN KEY (PlantID)
REFERENCES dbo.Dim_Plant(PlantID);
GO

ALTER TABLE dbo.Fact_ProductionEnergy
ADD CONSTRAINT FK_Production_Machine
FOREIGN KEY (MachineID)
REFERENCES dbo.Dim_Machine(MachineID);
GO

ALTER TABLE dbo.Fact_ProductionEnergy
ADD CONSTRAINT FK_Production_Line
FOREIGN KEY (LineID)
REFERENCES dbo.Dim_Line(LineID);
GO

ALTER TABLE dbo.Fact_ProductionEnergy
ADD CONSTRAINT FK_Production_Shift
FOREIGN KEY (ShiftID)
REFERENCES dbo.Dim_Shift(ShiftID);
GO

ALTER TABLE dbo.Fact_ProductionEnergy
ADD CONSTRAINT FK_Production_Status
FOREIGN KEY (StatusID)
REFERENCES dbo.Dim_Status(StatusID);
GO

ALTER TABLE dbo.Fact_ProductionEnergy
ADD CONSTRAINT FK_Production_Tariff
FOREIGN KEY (TariffID)
REFERENCES dbo.Dim_EnergyTariff(TariffID);
GO

ALTER TABLE dbo.Fact_ProductionEnergy
ADD CONSTRAINT FK_Production_Product
FOREIGN KEY (ProductID)
REFERENCES dbo.Dim_Product(ProductID);
GO
-- =============================================================
-- SCHEMA / COLUMN / KEY VALIDATION
-- Verifies table structure, columns, primary keys, and foreign keys.
-- =============================================================
SELECT
    TABLE_SCHEMA,
    TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Fact_ProductionEnergy'
ORDER BY ORDINAL_POSITION;
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Fact_DowntimeEvents'
ORDER BY ORDINAL_POSITION;
SELECT
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Fact_DowntimeEvents'
ORDER BY ORDINAL_POSITION;
SELECT
    t.name AS TableName,
    i.name AS PrimaryKeyName
FROM sys.tables t
JOIN sys.indexes i
    ON t.object_id = i.object_id
WHERE i.is_primary_key = 1
ORDER BY t.name;
SELECT
    fk.name AS ForeignKeyName,
    OBJECT_NAME(fk.parent_object_id) AS FromTable,
    COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS FromColumn,
    OBJECT_NAME(fk.referenced_object_id) AS ToTable,
    COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS ToColumn
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc
    ON fk.object_id = fkc.constraint_object_id
ORDER BY FromTable, ForeignKeyName;
-- =============================================================
-- DIMENSION ROW-COUNT CHECKS
-- Confirms the number of records stored in the dimension tables.
-- =============================================================
SELECT COUNT(*) AS [RowCount]
FROM dbo.Dim_Plant;

---------------------------------------------------------------------
SELECT 'Dim_Plant' AS [TableName], COUNT(*) AS [RowCount]
FROM dbo.Dim_Plant

UNION ALL

SELECT 'Dim_Line' AS [TableName], COUNT(*) AS [RowCount]
FROM dbo.Dim_Line

UNION ALL

SELECT 'Dim_Machine' AS [TableName], COUNT(*) AS [RowCount]
FROM dbo.Dim_Machine

UNION ALL

SELECT 'Dim_Product' AS [TableName], COUNT(*) AS [RowCount]
FROM dbo.Dim_Product

UNION ALL

SELECT 'Dim_Shift' AS [TableName], COUNT(*) AS [RowCount]
FROM dbo.Dim_Shift

UNION ALL

SELECT 'Dim_Status' AS [TableName], COUNT(*) AS [RowCount]
FROM dbo.Dim_Status

UNION ALL

SELECT 'Dim_EnergyTariff' AS [TableName], COUNT(*) AS [RowCount]
FROM dbo.Dim_EnergyTariff

UNION ALL

SELECT 'Dim_DowntimeReason' AS [TableName], COUNT(*) AS [RowCount]
FROM dbo.Dim_DowntimeReason

UNION ALL

SELECT 'Fact_DowntimeEvents' AS [TableName], COUNT(*) AS [RowCount]
FROM dbo.Fact_DowntimeEvents;
-------------------------------------------------------------------------------
-- =============================================================
-- FULL TABLE ROW-COUNT CHECK
-- Includes both fact tables in the row-count validation.
-- =============================================================
SELECT 'Dim_Plant' AS [TableName], COUNT(*) AS [RowCount]
FROM dbo.Dim_Plant

UNION ALL

SELECT 'Dim_Line', COUNT(*)
FROM dbo.Dim_Line

UNION ALL

SELECT 'Dim_Machine', COUNT(*)
FROM dbo.Dim_Machine

UNION ALL

SELECT 'Dim_Product', COUNT(*)
FROM dbo.Dim_Product

UNION ALL

SELECT 'Dim_Shift', COUNT(*)
FROM dbo.Dim_Shift

UNION ALL

SELECT 'Dim_Status', COUNT(*)
FROM dbo.Dim_Status

UNION ALL

SELECT 'Dim_EnergyTariff', COUNT(*)
FROM dbo.Dim_EnergyTariff

UNION ALL

SELECT 'Dim_DowntimeReason', COUNT(*)
FROM dbo.Dim_DowntimeReason

UNION ALL

SELECT 'Fact_DowntimeEvents', COUNT(*)
FROM dbo.Fact_DowntimeEvents

UNION ALL

SELECT 'Fact_ProductionEnergy', COUNT(*)
FROM dbo.Fact_ProductionEnergy;
-------------------------------------------------------------------------------
-- =============================================================
-- FOREIGN-KEY INTEGRITY CHECK
-- Identifies fact rows whose referenced dimension records are missing.
-- =============================================================
SELECT 'Production → Plant' AS [Relationship],
       COUNT(*) AS [InvalidRows]
FROM dbo.Fact_ProductionEnergy f
LEFT JOIN dbo.Dim_Plant d
    ON f.PlantID = d.PlantID
WHERE d.PlantID IS NULL

UNION ALL

SELECT 'Production → Machine',
       COUNT(*)
FROM dbo.Fact_ProductionEnergy f
LEFT JOIN dbo.Dim_Machine d
    ON f.MachineID = d.MachineID
WHERE d.MachineID IS NULL

UNION ALL

SELECT 'Production → Line',
       COUNT(*)
FROM dbo.Fact_ProductionEnergy f
LEFT JOIN dbo.Dim_Line d
    ON f.LineID = d.LineID
WHERE d.LineID IS NULL

UNION ALL

SELECT 'Production → Product',
       COUNT(*)
FROM dbo.Fact_ProductionEnergy f
LEFT JOIN dbo.Dim_Product d
    ON f.ProductID = d.ProductID
WHERE f.ProductID IS NOT NULL
  AND d.ProductID IS NULL

UNION ALL

SELECT 'Production → Shift',
       COUNT(*)
FROM dbo.Fact_ProductionEnergy f
LEFT JOIN dbo.Dim_Shift d
    ON f.ShiftID = d.ShiftID
WHERE d.ShiftID IS NULL

UNION ALL

SELECT 'Production → Status',
       COUNT(*)
FROM dbo.Fact_ProductionEnergy f
LEFT JOIN dbo.Dim_Status d
    ON f.StatusID = d.StatusID
WHERE d.StatusID IS NULL

UNION ALL

SELECT 'Production → Tariff',
       COUNT(*)
FROM dbo.Fact_ProductionEnergy f
LEFT JOIN dbo.Dim_EnergyTariff d
    ON f.TariffID = d.TariffID
WHERE d.TariffID IS NULL

UNION ALL

SELECT 'Downtime → Plant',
       COUNT(*)
FROM dbo.Fact_DowntimeEvents f
LEFT JOIN dbo.Dim_Plant d
    ON f.PlantID = d.PlantID
WHERE d.PlantID IS NULL

UNION ALL

SELECT 'Downtime → Machine',
       COUNT(*)
FROM dbo.Fact_DowntimeEvents f
LEFT JOIN dbo.Dim_Machine d
    ON f.MachineID = d.MachineID
WHERE d.MachineID IS NULL

UNION ALL

SELECT 'Downtime → Line',
       COUNT(*)
FROM dbo.Fact_DowntimeEvents f
LEFT JOIN dbo.Dim_Line d
    ON f.LineID = d.LineID
WHERE d.LineID IS NULL

UNION ALL

SELECT 'Downtime → Product',
       COUNT(*)
FROM dbo.Fact_DowntimeEvents f
LEFT JOIN dbo.Dim_Product d
    ON f.ProductID = d.ProductID
WHERE d.ProductID IS NULL

UNION ALL

SELECT 'Downtime → Shift',
       COUNT(*)
FROM dbo.Fact_DowntimeEvents f
LEFT JOIN dbo.Dim_Shift d
    ON f.ShiftID = d.ShiftID
WHERE d.ShiftID IS NULL

UNION ALL

SELECT 'Downtime → Reason',
       COUNT(*)
FROM dbo.Fact_DowntimeEvents f
LEFT JOIN dbo.Dim_DowntimeReason d
    ON f.ReasonID = d.ReasonID
WHERE d.ReasonID IS NULL;
-- =============================================================
-- PERFORMANCE INDEXES
-- Adds indexes to frequently filtered/joined fact-table columns.
-- =============================================================
CREATE INDEX IX_FactProduction_Timestamp
ON dbo.Fact_ProductionEnergy ([Timestamp]);

CREATE INDEX IX_FactProduction_MachineID
ON dbo.Fact_ProductionEnergy (MachineID);

CREATE INDEX IX_FactProduction_LineID
ON dbo.Fact_ProductionEnergy (LineID);

CREATE INDEX IX_FactProduction_ProductID
ON dbo.Fact_ProductionEnergy (ProductID);

CREATE INDEX IX_FactProduction_ShiftID
ON dbo.Fact_ProductionEnergy (ShiftID);

CREATE INDEX IX_FactProduction_StatusID
ON dbo.Fact_ProductionEnergy (StatusID);

CREATE INDEX IX_FactProduction_TariffID
ON dbo.Fact_ProductionEnergy (TariffID);

CREATE INDEX IX_FactDowntime_StartTimestamp
ON dbo.Fact_DowntimeEvents (StartTimestamp);

CREATE INDEX IX_FactDowntime_MachineID
ON dbo.Fact_DowntimeEvents (MachineID);

CREATE INDEX IX_FactDowntime_ReasonID
ON dbo.Fact_DowntimeEvents (ReasonID);
-------------------------------------------------------------------------------
-- =============================================================
-- FACT TABLE QUALITY VALIDATION
-- Validates row counts and primary-key uniqueness.
-- =============================================================
-- Table row counts
SELECT 'Fact_ProductionEnergy' AS [TableName],
       COUNT(*) AS [RowCount]
FROM dbo.Fact_ProductionEnergy

UNION ALL

SELECT 'Fact_DowntimeEvents',
       COUNT(*)
FROM dbo.Fact_DowntimeEvents;


-- Production primary key validation
SELECT
    COUNT(*) AS [RowCount],
    COUNT(DISTINCT ReadingID) AS [UniqueReadingIDs]
FROM dbo.Fact_ProductionEnergy;


-- Downtime primary key validation
SELECT
    COUNT(*) AS [RowCount],
    COUNT(DISTINCT DowntimeEventID) AS [UniqueDowntimeEventIDs]
FROM dbo.Fact_DowntimeEvents;
-------------------------------------------------------------------------------
-- =============================================================
-- INDEX VALIDATION
-- Lists indexes created on the two fact tables.
-- =============================================================
SELECT
    t.name AS [TableName],
    i.name AS [IndexName],
    i.type_desc AS [IndexType]
FROM sys.indexes i
INNER JOIN sys.tables t
    ON i.object_id = t.object_id
WHERE t.name IN (
    'Fact_ProductionEnergy',
    'Fact_DowntimeEvents'
)
AND i.name IS NOT NULL
ORDER BY
    [TableName],
    [IndexName];
-- =============================================================
-- ANALYTICS SCHEMA SETUP
-- Creates the analytics schema if it does not already exist.
-- =============================================================
	-------------------------------------------------------------------------------
	IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'analytics'
)
BEGIN
    EXEC('CREATE SCHEMA analytics');
END;

SELECT name AS [SchemaName]
FROM sys.schemas
WHERE name = 'analytics';



-- =============================================================
-- ANALYTICS VIEW: PRODUCTION + ENERGY DETAIL
-- Enriches production facts with descriptive dimension attributes
-- and derives production, quality, cycle-time, and energy-cost metrics.
-- =============================================================
CREATE OR ALTER VIEW analytics.vw_ProductionEnergyAnalysis
AS

SELECT
    f.ReadingID,
    f.[Timestamp],

    CAST(f.[Timestamp] AS DATE) AS [ProductionDate],
    YEAR(f.[Timestamp]) AS [Year],
    MONTH(f.[Timestamp]) AS [Month],

    f.PlantID,
    p.PlantName,

    f.LineID,
    l.LineName,

    f.MachineID,
    m.MachineName,
    m.MachineType,

    f.ProductID,
    pr.ProductName,
    pr.ProductFamily,
    pr.StandardCycleTimeSec,

    f.ShiftID,
    s.ShiftName,

    f.StatusID,
    st.StatusName,
    st.IsProductive,

    f.TariffID,
    t.TariffName,
    t.TimeBand,
    t.RatePerKWh,
    t.IsPeak,

    f.ItemsProduced,
    f.RejectedItems,

    f.ItemsProduced - f.RejectedItems AS [GoodItems],

    CASE
        WHEN f.ItemsProduced > 0
        THEN CAST(f.RejectedItems AS DECIMAL(18,6)) / f.ItemsProduced
        ELSE NULL
    END AS [RejectRate],

    f.ActualCycleTimeSec,

    CASE
        WHEN pr.StandardCycleTimeSec > 0
             AND f.ActualCycleTimeSec IS NOT NULL
        THEN f.ActualCycleTimeSec - pr.StandardCycleTimeSec
        ELSE NULL
    END AS [CycleTimeDeviationSec],

    f.PowerAvgKW,
    f.PowerMaxKW,
    f.PowerMinKW,
    f.EnergyKWh,

    f.EnergyKWh * t.RatePerKWh AS [EnergyCost],

    f.AmbientTempC,

    f.OUT_Energy_Contextual,
    f.OUT_CycleTime_Contextual,
    f.DQ_OperationalAnomaly,
    f.DQ_Status

FROM dbo.Fact_ProductionEnergy f
INNER JOIN dbo.Dim_Plant p
    ON f.PlantID = p.PlantID
INNER JOIN dbo.Dim_Line l
    ON f.LineID = l.LineID
INNER JOIN dbo.Dim_Machine m
    ON f.MachineID = m.MachineID
LEFT JOIN dbo.Dim_Product pr
    ON f.ProductID = pr.ProductID
INNER JOIN dbo.Dim_Shift s
    ON f.ShiftID = s.ShiftID
INNER JOIN dbo.Dim_Status st
    ON f.StatusID = st.StatusID
INNER JOIN dbo.Dim_EnergyTariff t
    ON f.TariffID = t.TariffID;
-------------------------------------------------------------------------------
-- =============================================================
-- VIEW VALIDATION: PRODUCTION + ENERGY DETAIL
-- Compares the analytical view row count with the source fact table.
-- =============================================================
SELECT
    COUNT(*) AS [ViewRowCount]
FROM analytics.vw_ProductionEnergyAnalysis;

SELECT
    COUNT(*) AS [FactRowCount]
FROM dbo.Fact_ProductionEnergy;
-------------------------------------------------------------------------------
-- =============================================================
-- ANALYTICS VIEW: DOWNTIME DETAIL
-- Enriches downtime events with plant, machine, product, shift,
-- and downtime-reason attributes.
-- =============================================================
CREATE OR ALTER VIEW analytics.vw_DowntimeAnalysis
AS

SELECT
    f.DowntimeEventID,

    f.StartTimestamp,
    f.EndTimestamp,

    CAST(f.StartTimestamp AS DATE) AS [DowntimeDate],
    YEAR(f.StartTimestamp) AS [Year],
    MONTH(f.StartTimestamp) AS [Month],

    f.PlantID,
    p.PlantName,

    f.LineID,
    l.LineName,

    f.MachineID,
    m.MachineName,
    m.MachineType,

    f.ProductID,
    pr.ProductName,
    pr.ProductFamily,

    f.ShiftID,
    s.ShiftName,

    f.ReasonID,
    r.ReasonCategory,
    r.ReasonName,
    r.IsPlanned,
    r.SeverityWeight,

    f.DurationMinutes,
    f.EnergyDuringDowntimeKWh,

    f.DQ_Status

FROM dbo.Fact_DowntimeEvents f

INNER JOIN dbo.Dim_Plant p
    ON f.PlantID = p.PlantID

INNER JOIN dbo.Dim_Line l
    ON f.LineID = l.LineID

INNER JOIN dbo.Dim_Machine m
    ON f.MachineID = m.MachineID

INNER JOIN dbo.Dim_Product pr
    ON f.ProductID = pr.ProductID

INNER JOIN dbo.Dim_Shift s
    ON f.ShiftID = s.ShiftID

INNER JOIN dbo.Dim_DowntimeReason r
    ON f.ReasonID = r.ReasonID;
-------------------------------------------------------------------------------
-- =============================================================
-- ANALYTICS VIEW: PRODUCTION PERFORMANCE SUMMARY
-- Aggregates operational performance by date and operating context.
-- =============================================================
CREATE OR ALTER VIEW analytics.vw_ProductionPerformanceSummary
AS

SELECT
    ProductionDate,

    PlantID,
    PlantName,

    LineID,
    LineName,

    MachineID,
    MachineName,
    MachineType,

    ProductID,
    ProductName,
    ProductFamily,

    ShiftID,
    ShiftName,

    StatusID,
    StatusName,
    IsProductive,

    SUM(ItemsProduced) AS [TotalItemsProduced],

    SUM(GoodItems) AS [GoodItems],

    SUM(RejectedItems) AS [RejectedItems],

    CASE
        WHEN SUM(ItemsProduced) > 0
        THEN
            CAST(SUM(RejectedItems) AS DECIMAL(18,6))
            / SUM(ItemsProduced)
        ELSE NULL
    END AS [RejectRate],

    SUM(EnergyKWh) AS [TotalEnergyKWh],

    SUM(EnergyCost) AS [TotalEnergyCost],

    CASE
        WHEN SUM(GoodItems) > 0
        THEN
            SUM(EnergyKWh)
            / SUM(GoodItems)
        ELSE NULL
    END AS [EnergyPerGoodItem],

    AVG(ActualCycleTimeSec) AS [AvgCycleTimeSec],

    AVG(CycleTimeDeviationSec) AS [AvgCycleTimeDeviationSec],

    SUM(
        CASE
            WHEN DQ_OperationalAnomaly = 1
            THEN 1
            ELSE 0
        END
    ) AS [OperationalAnomalyCount],

    COUNT(*) AS [ReadingCount]

FROM analytics.vw_ProductionEnergyAnalysis

GROUP BY
    ProductionDate,

    PlantID,
    PlantName,

    LineID,
    LineName,

    MachineID,
    MachineName,
    MachineType,

    ProductID,
    ProductName,
    ProductFamily,

    ShiftID,
    ShiftName,

    StatusID,
    StatusName,
    IsProductive;

-- =============================================================
-- PRODUCTION SUMMARY VALIDATION & SAMPLE OUTPUT
-- Checks summary size/date range and displays sample records.
-- =============================================================
-------------------------------------------------------------------------------
SELECT
    COUNT(*) AS [SummaryRowCount],
    MIN(ProductionDate) AS [MinDate],
    MAX(ProductionDate) AS [MaxDate]
FROM analytics.vw_ProductionPerformanceSummary;

SELECT TOP 10
    ProductionDate,
    PlantName,
    LineName,
    MachineName,
    ProductName,
    ShiftName,
    StatusName,
    TotalItemsProduced,
    GoodItems,
    RejectRate,
    TotalEnergyKWh,
    EnergyPerGoodItem
FROM analytics.vw_ProductionPerformanceSummary
ORDER BY ProductionDate, MachineName;
-------------------------------------------------------------------------------
-- =============================================================
-- ANALYTICS VIEW: DOWNTIME PERFORMANCE SUMMARY
-- Aggregates downtime duration, events, energy, and severity.
-- =============================================================
CREATE OR ALTER VIEW analytics.vw_DowntimePerformanceSummary
AS

SELECT
    DowntimeDate,

    PlantID,
    PlantName,

    LineID,
    LineName,

    MachineID,
    MachineName,
    MachineType,

    ProductID,
    ProductName,
    ProductFamily,

    ShiftID,
    ShiftName,

    ReasonID,
    ReasonCategory,
    ReasonName,
    IsPlanned,
    SeverityWeight,

    COUNT(*) AS [DowntimeEventCount],

    SUM(DurationMinutes) AS [TotalDowntimeMinutes],

    AVG(CAST(DurationMinutes AS DECIMAL(18,6)))
        AS [AvgDowntimeMinutes],

    MAX(DurationMinutes) AS [MaxDowntimeMinutes],

    SUM(EnergyDuringDowntimeKWh)
        AS [DowntimeEnergyKWh],

    SUM(
        DurationMinutes * SeverityWeight
    ) AS [SeverityWeightedDowntime]

FROM analytics.vw_DowntimeAnalysis

GROUP BY
    DowntimeDate,

    PlantID,
    PlantName,

    LineID,
    LineName,

    MachineID,
    MachineName,
    MachineType,

    ProductID,
    ProductName,
    ProductFamily,

    ShiftID,
    ShiftName,

    ReasonID,
    ReasonCategory,
    ReasonName,
    IsPlanned,
    SeverityWeight;
-------------------------------------------------------------------------------
-- =============================================================
-- ANALYTICS VIEW: DAILY OPERATIONAL CONTEXT
-- Combines production, quality, energy, and operational-anomaly measures
-- at the daily operating-context level.
-- =============================================================
CREATE OR ALTER VIEW analytics.vw_DailyOperationalContext
AS

SELECT
    ProductionDate,

    PlantID,
    PlantName,

    LineID,
    LineName,

    MachineID,
    MachineName,
    MachineType,

    ProductID,
    ProductName,
    ProductFamily,

    ShiftID,
    ShiftName,

    SUM(TotalItemsProduced) AS [TotalItemsProduced],
    SUM(GoodItems) AS [GoodItems],
    SUM(RejectedItems) AS [RejectedItems],

    CASE
        WHEN SUM(TotalItemsProduced) > 0
        THEN
            CAST(SUM(RejectedItems) AS DECIMAL(18,6))
            / SUM(TotalItemsProduced)
        ELSE NULL
    END AS [RejectRate],

    SUM(TotalEnergyKWh) AS [TotalEnergyKWh],

    SUM(
        CASE
            WHEN IsProductive = 1
            THEN TotalEnergyKWh
            ELSE 0
        END
    ) AS [ProductiveEnergyKWh],

    SUM(
        CASE
            WHEN IsProductive = 0
            THEN TotalEnergyKWh
            ELSE 0
        END
    ) AS [NonProductiveEnergyKWh],

    SUM(TotalEnergyCost) AS [TotalEnergyCost],

    CASE
        WHEN SUM(GoodItems) > 0
        THEN
            SUM(TotalEnergyKWh) / SUM(GoodItems)
        ELSE NULL
    END AS [EnergyPerGoodItem],

    AVG(AvgCycleTimeSec) AS [AvgCycleTimeSec],

    AVG(AvgCycleTimeDeviationSec)
        AS [AvgCycleTimeDeviationSec],

    SUM(OperationalAnomalyCount)
        AS [OperationalAnomalyCount],

    SUM(ReadingCount) AS [ReadingCount]

FROM analytics.vw_ProductionPerformanceSummary

GROUP BY
    ProductionDate,

    PlantID,
    PlantName,

    LineID,
    LineName,

    MachineID,
    MachineName,
    MachineType,

    ProductID,
    ProductName,
    ProductFamily,

    ShiftID,
    ShiftName;
-------------------------------------------------------------------------------
SELECT
    COUNT(*) AS [ContextRowCount],
    MIN(ProductionDate) AS [MinDate],
    MAX(ProductionDate) AS [MaxDate],
    SUM(TotalItemsProduced) AS [TotalItemsProduced],
    SUM(TotalEnergyKWh) AS [TotalEnergyKWh]
FROM analytics.vw_DailyOperationalContext;

-- =============================================================
-- ANALYTICS VIEW: DOWNTIME CONTEXT SUMMARY
-- Aggregates downtime metrics to the same context grain used for integration.
-- =============================================================
-------------------------------------------------------------------------------
CREATE OR ALTER VIEW analytics.vw_DowntimeContextSummary
AS

SELECT
    DowntimeDate,

    PlantID,
    LineID,
    MachineID,
    ProductID,
    ShiftID,

    SUM(DowntimeEventCount) AS [DowntimeEventCount],
    SUM(TotalDowntimeMinutes) AS [TotalDowntimeMinutes],
    SUM(DowntimeEnergyKWh) AS [DowntimeEnergyKWh],

    SUM(
        CASE
            WHEN IsPlanned = 0
            THEN DowntimeEventCount
            ELSE 0
        END
    ) AS [UnplannedDowntimeEvents],

    SUM(
        CASE
            WHEN IsPlanned = 0
            THEN TotalDowntimeMinutes
            ELSE 0
        END
    ) AS [UnplannedDowntimeMinutes],

    SUM(SeverityWeightedDowntime)
        AS [SeverityWeightedDowntime]

FROM analytics.vw_DowntimePerformanceSummary

GROUP BY
    DowntimeDate,
    PlantID,
    LineID,
    MachineID,
    ProductID,
    ShiftID;
-------------------------------------------------------------------------------
-- =============================================================
-- ANALYTICS VIEW: INTEGRATED OPERATIONAL PERFORMANCE
-- Combines production context with matching downtime context.
-- =============================================================
CREATE OR ALTER VIEW analytics.vw_OperationalPerformance
AS

SELECT
    p.*,

    COALESCE(d.DowntimeEventCount, 0)
        AS [DowntimeEventCount],

    COALESCE(d.TotalDowntimeMinutes, 0)
        AS [TotalDowntimeMinutes],

    COALESCE(d.DowntimeEnergyKWh, 0)
        AS [DowntimeEnergyKWh],

    COALESCE(d.UnplannedDowntimeEvents, 0)
        AS [UnplannedDowntimeEvents],

    COALESCE(d.UnplannedDowntimeMinutes, 0)
        AS [UnplannedDowntimeMinutes],

    COALESCE(d.SeverityWeightedDowntime, 0)
        AS [SeverityWeightedDowntime]

FROM analytics.vw_DailyOperationalContext p

LEFT JOIN analytics.vw_DowntimeContextSummary d
    ON p.ProductionDate = d.DowntimeDate
    AND p.PlantID = d.PlantID
    AND p.LineID = d.LineID
    AND p.MachineID = d.MachineID
    AND p.ShiftID = d.ShiftID
    AND (
        p.ProductID = d.ProductID
        OR (p.ProductID IS NULL AND d.ProductID IS NULL)
    );

GO
-- =============================================================
-- INTEGRATION VALIDATION
-- Checks integrated totals and detects duplicate operating contexts.
-- =============================================================
-------------------------------------------------------------------------------
SELECT
    COUNT(*) AS [IntegratedRowCount],
    SUM(TotalItemsProduced) AS [TotalItemsProduced],
    SUM(TotalEnergyKWh) AS [TotalEnergyKWh]
FROM analytics.vw_OperationalPerformance;


SELECT
    COUNT(*) AS [DuplicateContexts]
FROM
(
    SELECT
        ProductionDate,
        PlantID,
        LineID,
        MachineID,
        ProductID,
        ShiftID
    FROM analytics.vw_OperationalPerformance
    GROUP BY
        ProductionDate,
        PlantID,
        LineID,
        MachineID,
        ProductID,
        ShiftID
    HAVING COUNT(*) > 1
) d;

-------------------------------------------------------------------------------
-- =============================================================
-- COMPARABLE OPERATING CONTEXTS: INITIAL VERSION
-- Creates production-volume bands for comparing similar contexts.
-- =============================================================
CREATE OR ALTER VIEW analytics.vw_ComparableOperatingContexts
AS

SELECT
    *,

    CASE
        WHEN GoodItems <= 0 THEN 'No Output'
        WHEN GoodItems <= 100 THEN 'Low'
        WHEN GoodItems <= 250 THEN 'Medium'
        WHEN GoodItems <= 500 THEN 'High'
        ELSE 'Very High'
    END AS [ProductionVolumeBand]

FROM analytics.vw_OperationalPerformance;

GO

-------------------------------------------------------------------------------
SELECT
    ProductionVolumeBand,
    COUNT(*) AS [ContextCount],
    SUM(GoodItems) AS [GoodItems],
    SUM(TotalEnergyKWh) AS [TotalEnergyKWh]
FROM analytics.vw_ComparableOperatingContexts
GROUP BY ProductionVolumeBand
ORDER BY [ContextCount] DESC;

-------------------------------------------------------------------------------
-- =============================================================
-- COMPARABLE OPERATING CONTEXTS: QUARTILE VERSION
-- Rebuilds the view using NTILE-based volume segmentation.
-- =============================================================
CREATE OR ALTER VIEW analytics.vw_ComparableOperatingContexts
AS

WITH VolumeRanking AS
(
    SELECT
        op.*,

        NTILE(4) OVER
        (
            PARTITION BY
                ProductID,
                MachineType,
                CASE
                    WHEN GoodItems > 0 THEN 1
                    ELSE 0
                END
            ORDER BY GoodItems
        ) AS [VolumeQuartile]

    FROM analytics.vw_OperationalPerformance op
)

SELECT
    *,

    CASE
        WHEN GoodItems <= 0 THEN 'No Output'
        WHEN VolumeQuartile = 1 THEN 'Low'
        WHEN VolumeQuartile = 2 THEN 'Medium'
        WHEN VolumeQuartile = 3 THEN 'High'
        WHEN VolumeQuartile = 4 THEN 'Very High'
    END AS [ProductionVolumeBand]

FROM VolumeRanking;

GO
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
SELECT
    ProductionVolumeBand,
    COUNT(*) AS [ContextCount],
    SUM(GoodItems) AS [GoodItems],
    SUM(TotalEnergyKWh) AS [TotalEnergyKWh]
FROM analytics.vw_ComparableOperatingContexts
GROUP BY ProductionVolumeBand
ORDER BY
    CASE ProductionVolumeBand
        WHEN 'No Output' THEN 1
        WHEN 'Low' THEN 2
        WHEN 'Medium' THEN 3
        WHEN 'High' THEN 4
        WHEN 'Very High' THEN 5
    END;

-- =============================================================
-- VOLUME-BAND VALIDATION
-- Reviews the distribution of comparable operating contexts.
-- =============================================================
-------------------------------------------------------------------------------
-- Benchmarking starts after operating contexts are segmented.
CREATE OR ALTER VIEW analytics.vw_ExpectedEnergyBenchmark
AS

WITH BenchmarkBase AS
(
    SELECT
        ProductID,
        MachineType,
        ShiftID,
        ProductionVolumeBand,
        TotalEnergyKWh,

        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY TotalEnergyKWh)
        OVER
        (
            PARTITION BY
                ProductID,
                MachineType,
                ShiftID,
                ProductionVolumeBand
        ) AS [ExpectedEnergyKWh],

        COUNT(*) OVER
        (
            PARTITION BY
                ProductID,
                MachineType,
                ShiftID,
                ProductionVolumeBand
        ) AS [BenchmarkContextCount]

    FROM analytics.vw_ComparableOperatingContexts

    WHERE
        GoodItems > 0
        AND ProductID IS NOT NULL
        AND ProductionVolumeBand <> 'No Output'
)

SELECT DISTINCT
    ProductID,
    MachineType,
    ShiftID,
    ProductionVolumeBand,
    CAST(ExpectedEnergyKWh AS DECIMAL(18,6))
        AS [ExpectedEnergyKWh],
    BenchmarkContextCount

FROM BenchmarkBase

WHERE BenchmarkContextCount >= 10;

GO

-------------------------------------------------------------------------------
SELECT
    COUNT(*) AS [BenchmarkGroupCount],
    MIN(BenchmarkContextCount) AS [MinContextCount],
    MAX(BenchmarkContextCount) AS [MaxContextCount],
    AVG(CAST(BenchmarkContextCount AS DECIMAL(18,2)))
        AS [AvgContextCount]
FROM analytics.vw_ExpectedEnergyBenchmark;


SELECT
    COUNT(*) AS [ProductiveContextCount],

    SUM(
        CASE
            WHEN b.ExpectedEnergyKWh IS NOT NULL
            THEN 1
            ELSE 0
        END
    ) AS [CoveredContextCount],

    SUM(
        CASE
            WHEN b.ExpectedEnergyKWh IS NULL
            THEN 1
            ELSE 0
        END
    ) AS [UncoveredContextCount],

    CAST(
        100.0 *
        SUM(
            CASE
                WHEN b.ExpectedEnergyKWh IS NOT NULL
                THEN 1
                ELSE 0
            END
        )
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS [CoveragePercent]

FROM analytics.vw_ComparableOperatingContexts c

LEFT JOIN analytics.vw_ExpectedEnergyBenchmark b
    ON c.ProductID = b.ProductID
    AND c.MachineType = b.MachineType
    AND c.ShiftID = b.ShiftID
    AND c.ProductionVolumeBand = b.ProductionVolumeBand

WHERE
    c.GoodItems > 0
    AND c.ProductID IS NOT NULL
    AND c.ProductionVolumeBand <> 'No Output';

-------------------------------------------------------------------------------
-- =============================================================
-- ENERGY EFFICIENCY GAP
-- Compares observed energy consumption with the expected benchmark
-- for each comparable operating context.
-- =============================================================
CREATE OR ALTER VIEW analytics.vw_EnergyEfficiencyGap
AS

SELECT
    c.*,

    b.ExpectedEnergyKWh,
    b.BenchmarkContextCount,

    CASE
        WHEN b.ExpectedEnergyKWh IS NOT NULL
        THEN c.TotalEnergyKWh - b.ExpectedEnergyKWh
        ELSE NULL
    END AS [EnergyGapKWh],

    CASE
        WHEN b.ExpectedEnergyKWh > 0
        THEN
            (c.TotalEnergyKWh - b.ExpectedEnergyKWh)
            / b.ExpectedEnergyKWh
        ELSE NULL
    END AS [EnergyGapPercent],

    CASE
        WHEN b.ExpectedEnergyKWh IS NULL
            THEN 'No Benchmark'

        WHEN c.TotalEnergyKWh > b.ExpectedEnergyKWh
            THEN 'Above Expected'

        WHEN c.TotalEnergyKWh < b.ExpectedEnergyKWh
            THEN 'Below Expected'

        ELSE 'As Expected'
    END AS [EfficiencyStatus]

FROM analytics.vw_ComparableOperatingContexts c

LEFT JOIN analytics.vw_ExpectedEnergyBenchmark b
    ON c.ProductID = b.ProductID
    AND c.MachineType = b.MachineType
    AND c.ShiftID = b.ShiftID
    AND c.ProductionVolumeBand = b.ProductionVolumeBand

WHERE c.GoodItems > 0;

GO

-------------------------------------------------------------------------------
SELECT
    EfficiencyStatus,
    COUNT(*) AS [ContextCount],
    CAST(AVG(EnergyGapKWh) AS DECIMAL(18,4))
        AS [AvgEnergyGapKWh],
    CAST(AVG(EnergyGapPercent) * 100 AS DECIMAL(18,2))
        AS [AvgEnergyGapPercent]
FROM analytics.vw_EnergyEfficiencyGap
GROUP BY EfficiencyStatus
ORDER BY [ContextCount] DESC;


SELECT
    COUNT(*) AS [InvalidGapRows]
FROM analytics.vw_EnergyEfficiencyGap
WHERE
    ExpectedEnergyKWh IS NOT NULL
    AND ABS(
        EnergyGapKWh -
        (TotalEnergyKWh - ExpectedEnergyKWh)
    ) > 0.0001;


-- =============================================================
-- ENERGY GAP THRESHOLDS
-- Establishes context-specific P75 thresholds for energy gaps.
-- =============================================================
-------------------------------------------------------------------------------
CREATE OR ALTER VIEW analytics.vw_EnergyGapThresholds
AS

WITH GapDistribution AS
(
    SELECT
        ProductID,
        MachineType,
        ShiftID,
        ProductionVolumeBand,

        PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY EnergyGapPercent)
        OVER
        (
            PARTITION BY
                ProductID,
                MachineType,
                ShiftID,
                ProductionVolumeBand
        ) AS [GapP75]

    FROM analytics.vw_EnergyEfficiencyGap

    WHERE ExpectedEnergyKWh IS NOT NULL
)

SELECT DISTINCT
    ProductID,
    MachineType,
    ShiftID,
    ProductionVolumeBand,
    CAST(GapP75 AS DECIMAL(18,6)) AS [GapP75]

FROM GapDistribution;

GO
-- =============================================================
-- MEANINGFUL ENERGY INEFFICIENCY
-- Flags contexts whose positive energy gap exceeds the context threshold.
-- =============================================================
-------------------------------------------------------------------------------
CREATE OR ALTER VIEW analytics.vw_MeaningfulEnergyInefficiency
AS

SELECT
    g.*,
    t.GapP75,

    CASE
        WHEN g.ExpectedEnergyKWh IS NOT NULL
             AND g.EnergyGapKWh > 0
             AND g.EnergyGapPercent > t.GapP75
        THEN 1
        ELSE 0
    END AS [IsMeaningfulInefficiency]

FROM analytics.vw_EnergyEfficiencyGap g

LEFT JOIN analytics.vw_EnergyGapThresholds t
    ON g.ProductID = t.ProductID
    AND g.MachineType = t.MachineType
    AND g.ShiftID = t.ShiftID
    AND g.ProductionVolumeBand = t.ProductionVolumeBand;

GO

-------------------------------------------------------------------------------
SELECT
    COUNT(*) AS [TotalContexts],

    SUM(IsMeaningfulInefficiency)
        AS [MeaningfulInefficiencyContexts],

    CAST(
        100.0 * SUM(IsMeaningfulInefficiency) / COUNT(*)
        AS DECIMAL(10,2)
    ) AS [MeaningfulInefficiencyPercent],

    CAST(
        SUM(
            CASE
                WHEN IsMeaningfulInefficiency = 1
                THEN EnergyGapKWh
                ELSE 0
            END
        )
        AS DECIMAL(18,2)
    ) AS [ExcessEnergyKWh]

FROM analytics.vw_MeaningfulEnergyInefficiency;


SELECT
    MIN(GapP75) AS [MinGapP75],
    AVG(GapP75) AS [AvgGapP75],
    MAX(GapP75) AS [MaxGapP75]
FROM analytics.vw_EnergyGapThresholds;
-------------------------------------------------------------------------------
-- =============================================================
-- RECURRING EFFICIENCY OPPORTUNITIES
-- Aggregates meaningful inefficiencies into actionable operating contexts.
-- =============================================================
CREATE OR ALTER VIEW analytics.vw_RecurringEfficiencyOpportunities
AS

SELECT
    PlantID,
    PlantName,

    LineID,
    LineName,

    MachineID,
    MachineName,
    MachineType,

    ProductID,
    ProductName,
    ProductFamily,

    ShiftID,
    ShiftName,

    COUNT(*) AS [ObservedContexts],

    SUM(IsMeaningfulInefficiency)
        AS [InefficientContexts],

    CAST(
        1.0 * SUM(IsMeaningfulInefficiency) / COUNT(*)
        AS DECIMAL(18,6)
    ) AS [RecurrenceRate],

    CAST(
        SUM(
            CASE
                WHEN IsMeaningfulInefficiency = 1
                THEN EnergyGapKWh
                ELSE 0
            END
        )
        AS DECIMAL(18,6)
    ) AS [TotalExcessEnergyKWh],

    CAST(
        AVG(
            CASE
                WHEN IsMeaningfulInefficiency = 1
                THEN EnergyGapPercent
            END
        )
        AS DECIMAL(18,6)
    ) AS [AvgExcessPercent],

    SUM(OperationalAnomalyCount)
        AS [OperationalAnomalyCount],

    SUM(UnplannedDowntimeMinutes)
        AS [UnplannedDowntimeMinutes],

    SUM(DowntimeEventCount)
        AS [DowntimeEventCount],

    MIN(ProductionDate) AS [FirstObservedDate],
    MAX(ProductionDate) AS [LastObservedDate]

FROM analytics.vw_MeaningfulEnergyInefficiency

GROUP BY
    PlantID,
    PlantName,
    LineID,
    LineName,
    MachineID,
    MachineName,
    MachineType,
    ProductID,
    ProductName,
    ProductFamily,
    ShiftID,
    ShiftName;

GO

-------------------------------------------------------------------------------
SELECT
    COUNT(*) AS [OpportunityCount],

    MIN(ObservedContexts) AS [MinObservedContexts],
    MAX(ObservedContexts) AS [MaxObservedContexts],

    CAST(MIN(RecurrenceRate) * 100 AS DECIMAL(10,2))
        AS [MinRecurrencePercent],

    CAST(AVG(RecurrenceRate) * 100 AS DECIMAL(10,2))
        AS [AvgRecurrencePercent],

    CAST(MAX(RecurrenceRate) * 100 AS DECIMAL(10,2))
        AS [MaxRecurrencePercent],

    CAST(SUM(TotalExcessEnergyKWh) AS DECIMAL(18,2))
        AS [TotalExcessEnergyKWh]

FROM analytics.vw_RecurringEfficiencyOpportunities;


SELECT TOP 10
    MachineID,
    MachineName,
    ProductID,
    ProductName,
    ShiftName,

    ObservedContexts,
    InefficientContexts,

    CAST(RecurrenceRate * 100 AS DECIMAL(10,2))
        AS [RecurrencePercent],

    TotalExcessEnergyKWh,

    CAST(AvgExcessPercent * 100 AS DECIMAL(10,2))
        AS [AvgExcessPercent],

    UnplannedDowntimeMinutes,
    OperationalAnomalyCount

FROM analytics.vw_RecurringEfficiencyOpportunities

WHERE InefficientContexts > 0

ORDER BY
    TotalExcessEnergyKWh DESC;


-- =============================================================
-- CONTEXT & SEGMENTATION VALIDATION
-- Checks context uniqueness and production-volume segmentation.
-- =============================================================
-------------------------------------------------------------------------------
SELECT
    COUNT(*) AS [TotalContexts],
    COUNT(DISTINCT CONCAT(
        CONVERT(VARCHAR(10), ProductionDate, 120), '|',
        PlantID, '|',
        LineID, '|',
        MachineID, '|',
        COALESCE(ProductID, 'NULL'), '|',
        ShiftID
    )) AS [UniqueContexts]
FROM analytics.vw_ComparableOperatingContexts;


SELECT
    ProductionVolumeBand,
    COUNT(*) AS [ContextCount]
FROM analytics.vw_ComparableOperatingContexts
GROUP BY ProductionVolumeBand
ORDER BY
    CASE ProductionVolumeBand
        WHEN 'No Output' THEN 1
        WHEN 'Low' THEN 2
        WHEN 'Medium' THEN 3
        WHEN 'High' THEN 4
        WHEN 'Very High' THEN 5
    END;

-------------------------------------------------------------------------------
-- =============================================================
-- OPPORTUNITY RECONCILIATION CHECKS
-- Compares source inefficiency totals with aggregated opportunity totals.
-- =============================================================
-- A. Current source total
SELECT
    COUNT(*) AS [SourceRows],
    SUM(IsMeaningfulInefficiency) AS [InefficientRows],
    CAST(
        SUM(
            CASE
                WHEN IsMeaningfulInefficiency = 1
                THEN EnergyGapKWh
                ELSE 0
            END
        ) AS DECIMAL(18,2)
    ) AS [SourceExcessEnergyKWh]
FROM analytics.vw_MeaningfulEnergyInefficiency;


-- B. Check inefficient rows with missing opportunity grouping keys
SELECT
    COUNT(*) AS [RowsWithMissingGroupingKeys],

    CAST(
        SUM(EnergyGapKWh)
        AS DECIMAL(18,2)
    ) AS [ExcessEnergyWithMissingGroupingKeys]

FROM analytics.vw_MeaningfulEnergyInefficiency
WHERE
    IsMeaningfulInefficiency = 1
    AND
    (
        PlantID IS NULL
        OR LineID IS NULL
        OR MachineID IS NULL
        OR ProductID IS NULL
        OR ShiftID IS NULL
    );


-- C. Current opportunity total
SELECT
    COUNT(*) AS [OpportunityRows],
    SUM(InefficientContexts) AS [AggregatedInefficientRows],

    CAST(
        SUM(TotalExcessEnergyKWh)
        AS DECIMAL(18,2)
    ) AS [OpportunityExcessEnergyKWh]

FROM analytics.vw_RecurringEfficiencyOpportunities;


-------------------------------------------------------------------------------
SELECT
    ProductID,
    MachineType,
    ShiftID,
    GoodItems,
    COUNT(*) AS [ContextCount],
    COUNT(DISTINCT ProductionVolumeBand) AS [DistinctVolumeBands]
FROM analytics.vw_ComparableOperatingContexts
WHERE GoodItems > 0
GROUP BY
    ProductID,
    MachineType,
    ShiftID,
    GoodItems
HAVING COUNT(DISTINCT ProductionVolumeBand) > 1
ORDER BY [ContextCount] DESC;


-------------------------------------------------------------------------------
-- =============================================================
-- BENCHMARK / INEFFICIENCY / OPPORTUNITY RECONCILIATION
-- Validates coverage and exact aggregation consistency.
-- =============================================================
-- 1. Benchmark coverage
SELECT
    COUNT(*) AS [ProductiveContexts],

    SUM(
        CASE
            WHEN ExpectedEnergyKWh IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS [CoveredContexts],

    SUM(
        CASE
            WHEN ExpectedEnergyKWh IS NULL THEN 1
            ELSE 0
        END
    ) AS [UncoveredContexts]

FROM analytics.vw_EnergyEfficiencyGap;


-- 2. Meaningful inefficiency source
SELECT
    COUNT(*) AS [SourceContexts],

    SUM(IsMeaningfulInefficiency)
        AS [MeaningfulInefficiencyContexts],

    CAST(
        SUM(
            CASE
                WHEN IsMeaningfulInefficiency = 1
                THEN EnergyGapKWh
                ELSE 0
            END
        )
        AS DECIMAL(18,2)
    ) AS [SourceExcessEnergyKWh]

FROM analytics.vw_MeaningfulEnergyInefficiency;


-- 3. Recurring opportunity aggregation
SELECT
    COUNT(*) AS [OpportunityCount],

    SUM(InefficientContexts)
        AS [AggregatedInefficientContexts],

    CAST(
        SUM(TotalExcessEnergyKWh)
        AS DECIMAL(18,2)
    ) AS [OpportunityExcessEnergyKWh]

FROM analytics.vw_RecurringEfficiencyOpportunities;


-- 4. Exact reconciliation
SELECT
    CAST(
        (
            SELECT SUM(TotalExcessEnergyKWh)
            FROM analytics.vw_RecurringEfficiencyOpportunities
        )
        -
        (
            SELECT SUM(
                CASE
                    WHEN IsMeaningfulInefficiency = 1
                    THEN EnergyGapKWh
                    ELSE 0
                END
            )
            FROM analytics.vw_MeaningfulEnergyInefficiency
        )
        AS DECIMAL(18,6)
    ) AS [AggregationDifference];

-------------------------------------------------------------------------------
-- =============================================================
-- COMPARABLE OPERATING CONTEXTS: PERCENTILE VERSION
-- Rebuilds volume bands using product/machine-type percentile boundaries.
-- =============================================================
CREATE OR ALTER VIEW analytics.vw_ComparableOperatingContexts
AS

WITH ProductiveDistribution AS
(
    SELECT
        ProductID,
        MachineType,
        GoodItems,

        PERCENTILE_CONT(0.25)
        WITHIN GROUP (ORDER BY GoodItems)
        OVER (
            PARTITION BY ProductID, MachineType
        ) AS [P25],

        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY GoodItems)
        OVER (
            PARTITION BY ProductID, MachineType
        ) AS [P50],

        PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY GoodItems)
        OVER (
            PARTITION BY ProductID, MachineType
        ) AS [P75]

    FROM analytics.vw_OperationalPerformance

    WHERE
        GoodItems > 0
        AND ProductID IS NOT NULL
),

PercentileBoundaries AS
(
    SELECT DISTINCT
        ProductID,
        MachineType,
        P25,
        P50,
        P75
    FROM ProductiveDistribution
)

SELECT
    op.*,

    CASE
        WHEN op.GoodItems <= 0
            THEN 'No Output'

        WHEN op.GoodItems <= b.P25
            THEN 'Low'

        WHEN op.GoodItems <= b.P50
            THEN 'Medium'

        WHEN op.GoodItems <= b.P75
            THEN 'High'

        ELSE 'Very High'
    END AS [ProductionVolumeBand]

FROM analytics.vw_OperationalPerformance op

LEFT JOIN PercentileBoundaries b
    ON op.ProductID = b.ProductID
    AND op.MachineType = b.MachineType;

GO

-- =============================================================
-- FINAL VOLUME-SEGMENTATION VALIDATION
-- Checks whether a single GoodItems value can fall into multiple bands.
-- =============================================================
-------------------------------------------------------------------------------
SELECT
    COUNT(*) AS [UnstableVolumeGroups]
FROM
(
    SELECT
        ProductID,
        MachineType,
        GoodItems
    FROM analytics.vw_ComparableOperatingContexts
    WHERE GoodItems > 0
    GROUP BY
        ProductID,
        MachineType,
        GoodItems
    HAVING COUNT(DISTINCT ProductionVolumeBand) > 1
) x;


SELECT
    ProductionVolumeBand,
    COUNT(*) AS [ContextCount]
FROM analytics.vw_ComparableOperatingContexts
GROUP BY ProductionVolumeBand
ORDER BY
    CASE ProductionVolumeBand
        WHEN 'No Output' THEN 1
        WHEN 'Low' THEN 2
        WHEN 'Medium' THEN 3
        WHEN 'High' THEN 4
        WHEN 'Very High' THEN 5
    END;
-------------------------------------------------------------------------------
-- =============================================================
-- VIEW REFRESH & FINAL OPPORTUNITY COUNTS
-- Refreshes dependent views and verifies resulting row counts.
-- =============================================================
EXEC sys.sp_refreshview 'analytics.vw_EnergyEfficiencyGap';

EXEC sys.sp_refreshview 'analytics.vw_EnergyGapThresholds';

EXEC sys.sp_refreshview 'analytics.vw_MeaningfulEnergyInefficiency';

EXEC sys.sp_refreshview 'analytics.vw_RecurringEfficiencyOpportunities';
-------------------------------------------------------------------------------
SELECT COUNT(*) AS [EnergyGapRows]
FROM analytics.vw_EnergyEfficiencyGap;

SELECT COUNT(*) AS [MeaningfulInefficiencyRows]
FROM analytics.vw_MeaningfulEnergyInefficiency;

SELECT COUNT(*) AS [OpportunityRows]
FROM analytics.vw_RecurringEfficiencyOpportunities;

-------------------------------------------------------------------------------
SELECT
    SUM(IsMeaningfulInefficiency)
        AS [SourceInefficientContexts],

    CAST(
        SUM(
            CASE
                WHEN IsMeaningfulInefficiency = 1
                THEN EnergyGapKWh
                ELSE 0
            END
        )
        AS DECIMAL(18,6)
    ) AS [SourceExcessEnergyKWh]
FROM analytics.vw_MeaningfulEnergyInefficiency;


SELECT
    SUM(InefficientContexts)
        AS [AggregatedInefficientContexts],

    CAST(
        SUM(TotalExcessEnergyKWh)
        AS DECIMAL(18,6)
    ) AS [AggregatedExcessEnergyKWh]
FROM analytics.vw_RecurringEfficiencyOpportunities;


SELECT
    CAST(
        (
            SELECT SUM(TotalExcessEnergyKWh)
            FROM analytics.vw_RecurringEfficiencyOpportunities
        )
        -
        (
            SELECT SUM(
                CASE
                    WHEN IsMeaningfulInefficiency = 1
                    THEN EnergyGapKWh
                    ELSE 0
                END
            )
            FROM analytics.vw_MeaningfulEnergyInefficiency
        )
        AS DECIMAL(18,6)
    ) AS [AggregationDifference];

-- =============================================================
-- OPPORTUNITY PRIORITIZATION THRESHOLD ANALYSIS
-- Calculates distribution thresholds used to categorize opportunities.
-- =============================================================
-------------------------------------------------------------------------------
SELECT
    COUNT(*) AS [OpportunityCount],

    CAST(
        PERCENTILE_CONT(0.25)
        WITHIN GROUP (ORDER BY RecurrenceRate)
        OVER ()
        AS DECIMAL(18,6)
    ) AS [RecurrenceP25],

    CAST(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY RecurrenceRate)
        OVER ()
        AS DECIMAL(18,6)
    ) AS [RecurrenceP50],

    CAST(
        PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY RecurrenceRate)
        OVER ()
        AS DECIMAL(18,6)
    ) AS [RecurrenceP75],

    CAST(
        PERCENTILE_CONT(0.25)
        WITHIN GROUP (ORDER BY TotalExcessEnergyKWh)
        OVER ()
        AS DECIMAL(18,6)
    ) AS [ExcessEnergyP25],

    CAST(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY TotalExcessEnergyKWh)
        OVER ()
        AS DECIMAL(18,6)
    ) AS [ExcessEnergyP50],

    CAST(
        PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY TotalExcessEnergyKWh)
        OVER ()
        AS DECIMAL(18,6)
    ) AS [ExcessEnergyP75]

FROM analytics.vw_RecurringEfficiencyOpportunities

WHERE InefficientContexts > 0

GROUP BY
    RecurrenceRate,
    TotalExcessEnergyKWh;

-------------------------------------------------------------------------------
WITH OpportunityDistribution AS
(
    SELECT
        PERCENTILE_CONT(0.25)
        WITHIN GROUP (ORDER BY RecurrenceRate)
        OVER () AS [RecurrenceP25],

        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY RecurrenceRate)
        OVER () AS [RecurrenceP50],

        PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY RecurrenceRate)
        OVER () AS [RecurrenceP75],

        PERCENTILE_CONT(0.25)
        WITHIN GROUP (ORDER BY TotalExcessEnergyKWh)
        OVER () AS [ExcessEnergyP25],

        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY TotalExcessEnergyKWh)
        OVER () AS [ExcessEnergyP50],

        PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY TotalExcessEnergyKWh)
        OVER () AS [ExcessEnergyP75]

    FROM analytics.vw_RecurringEfficiencyOpportunities
    WHERE InefficientContexts > 0
)

SELECT DISTINCT
    CAST(RecurrenceP25 * 100 AS DECIMAL(10,2))
        AS [RecurrenceP25Percent],

    CAST(RecurrenceP50 * 100 AS DECIMAL(10,2))
        AS [RecurrenceP50Percent],

    CAST(RecurrenceP75 * 100 AS DECIMAL(10,2))
        AS [RecurrenceP75Percent],

    CAST(ExcessEnergyP25 AS DECIMAL(18,2))
        AS [ExcessEnergyP25KWh],

    CAST(ExcessEnergyP50 AS DECIMAL(18,2))
        AS [ExcessEnergyP50KWh],

    CAST(ExcessEnergyP75 AS DECIMAL(18,2))
        AS [ExcessEnergyP75KWh]

FROM OpportunityDistribution;
-------------------------------------------------------------------------------
-- =============================================================
-- PRIORITIZED EFFICIENCY OPPORTUNITIES
-- Classifies opportunities by impact and recurrence for decision support.
-- =============================================================
CREATE OR ALTER VIEW analytics.vw_PrioritizedEfficiencyOpportunities
AS

SELECT
    *,

    CASE
        WHEN TotalExcessEnergyKWh >= 196.04
             AND RecurrenceRate >= 0.2500
            THEN 'Priority'

        WHEN TotalExcessEnergyKWh >= 196.04
             AND RecurrenceRate < 0.2500
            THEN 'High Impact / Less Frequent'

        WHEN TotalExcessEnergyKWh < 196.04
             AND RecurrenceRate >= 0.2500
            THEN 'Recurring / Lower Impact'

        ELSE 'Lower Priority'
    END AS [PriorityCategory]

FROM analytics.vw_RecurringEfficiencyOpportunities

WHERE InefficientContexts > 0;

GO
-------------------------------------------------------------------------------
SELECT
    PriorityCategory,

    COUNT(*) AS [OpportunityCount],

    CAST(
        AVG(RecurrenceRate) * 100
        AS DECIMAL(10,2)
    ) AS [AvgRecurrencePercent],

    CAST(
        SUM(TotalExcessEnergyKWh)
        AS DECIMAL(18,2)
    ) AS [TotalExcessEnergyKWh],

    CAST(
        100.0 * SUM(TotalExcessEnergyKWh)
        /
        SUM(SUM(TotalExcessEnergyKWh)) OVER ()
        AS DECIMAL(10,2)
    ) AS [ExcessEnergySharePercent]

FROM analytics.vw_PrioritizedEfficiencyOpportunities

GROUP BY PriorityCategory

ORDER BY [TotalExcessEnergyKWh] DESC;
-------------------------------------------------------------------------------
-- =============================================================
-- RANKED EFFICIENCY OPPORTUNITIES
-- Ranks opportunities within each priority category.
-- =============================================================
CREATE OR ALTER VIEW analytics.vw_RankedEfficiencyOpportunities
AS

SELECT
    *,

    ROW_NUMBER() OVER
    (
        PARTITION BY PriorityCategory
        ORDER BY
            TotalExcessEnergyKWh DESC,
            RecurrenceRate DESC,
            InefficientContexts DESC,
            MachineID,
            ProductID,
            ShiftID
    ) AS [PriorityRank]

FROM analytics.vw_PrioritizedEfficiencyOpportunities;

GO
-------------------------------------------------------------------------------
SELECT TOP 10
    PriorityRank,

    PlantName,
    LineName,

    MachineID,
    MachineName,

    ProductID,
    ProductName,

    ShiftName,

    ObservedContexts,
    InefficientContexts,

    CAST(
        RecurrenceRate * 100
        AS DECIMAL(10,2)
    ) AS [RecurrencePercent],

    CAST(
        TotalExcessEnergyKWh
        AS DECIMAL(18,2)
    ) AS [TotalExcessEnergyKWh],

    CAST(
        AvgExcessPercent * 100
        AS DECIMAL(10,2)
    ) AS [AvgExcessPercent],

    UnplannedDowntimeMinutes,
    OperationalAnomalyCount

FROM analytics.vw_RankedEfficiencyOpportunities

WHERE PriorityCategory = 'Priority'

ORDER BY PriorityRank;

-------------------------------------------------------------------------------
-- =============================================================
-- MONTHLY EFFICIENCY OPPORTUNITY TREND
-- Produces a time-series view of recurring inefficiency by operating context.
-- =============================================================
CREATE OR ALTER VIEW analytics.vw_MonthlyEfficiencyOpportunityTrend
AS

SELECT
    DATEFROMPARTS(
        YEAR(ProductionDate),
        MONTH(ProductionDate),
        1
    ) AS [MonthStart],

    PlantID,
    PlantName,

    LineID,
    LineName,

    MachineID,
    MachineName,
    MachineType,

    ProductID,
    ProductName,
    ProductFamily,

    ShiftID,
    ShiftName,

    COUNT(*) AS [ObservedContexts],

    SUM(IsMeaningfulInefficiency)
        AS [InefficientContexts],

    CAST(
        1.0 * SUM(IsMeaningfulInefficiency) / COUNT(*)
        AS DECIMAL(18,6)
    ) AS [MonthlyRecurrenceRate],

    CAST(
        SUM(
            CASE
                WHEN IsMeaningfulInefficiency = 1
                THEN EnergyGapKWh
                ELSE 0
            END
        )
        AS DECIMAL(18,6)
    ) AS [MonthlyExcessEnergyKWh]

FROM analytics.vw_MeaningfulEnergyInefficiency

GROUP BY
    DATEFROMPARTS(
        YEAR(ProductionDate),
        MONTH(ProductionDate),
        1
    ),

    PlantID,
    PlantName,
    LineID,
    LineName,
    MachineID,
    MachineName,
    MachineType,
    ProductID,
    ProductName,
    ProductFamily,
    ShiftID,
    ShiftName;

GO
-------------------------------------------------------------------------------
SELECT
    COLUMN_NAME AS [ColumnName]
FROM INFORMATION_SCHEMA.COLUMNS
WHERE
    TABLE_SCHEMA = 'analytics'
    AND TABLE_NAME = 'vw_MonthlyEfficiencyOpportunityTrend'
ORDER BY ORDINAL_POSITION;
-------------------------------------------------------------------------------
SELECT
    COUNT(*) AS [MonthlyTrendRows],
    MIN(MonthStart) AS [MinMonth],
    MAX(MonthStart) AS [MaxMonth],

    SUM(InefficientContexts)
        AS [InefficientContexts],

    CAST(
        SUM(MonthlyExcessEnergyKWh)
        AS DECIMAL(18,6)
    ) AS [MonthlyExcessEnergyKWh]

FROM analytics.vw_MonthlyEfficiencyOpportunityTrend;


SELECT
    CAST(
        SUM(MonthlyExcessEnergyKWh)
        -
        (
            SELECT SUM(
                CASE
                    WHEN IsMeaningfulInefficiency = 1
                    THEN EnergyGapKWh
                    ELSE 0
                END
            )
            FROM analytics.vw_MeaningfulEnergyInefficiency
        )
        AS DECIMAL(18,6)
    ) AS [AggregationDifference]

FROM analytics.vw_MonthlyEfficiencyOpportunityTrend;

-------------------------------------------------------------------------------
SELECT
    CAST(
        SUM(MonthlyExcessEnergyKWh)
        -
        (
            SELECT SUM(
                CASE
                    WHEN IsMeaningfulInefficiency = 1
                    THEN EnergyGapKWh
                    ELSE 0
                END
            )
            FROM analytics.vw_MeaningfulEnergyInefficiency
        )
        AS DECIMAL(18,6)
    ) AS [AggregationDifference]

FROM analytics.vw_MonthlyEfficiencyOpportunityTrend;
-------------------------------------------------------------------------------
-- =============================================================
-- EFFICIENCY OPPORTUNITY TREND CLASSIFICATION
-- Classifies opportunities as persistent, worsening, improving, or intermittent.
-- =============================================================
CREATE OR ALTER VIEW analytics.vw_EfficiencyOpportunityTrendClassification
AS

WITH MonthlyTrend AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY
                PlantID,
                LineID,
                MachineID,
                ProductID,
                ShiftID
            ORDER BY MonthStart
        ) AS [MonthOrder],

        COUNT(*) OVER
        (
            PARTITION BY
                PlantID,
                LineID,
                MachineID,
                ProductID,
                ShiftID
        ) AS [MonthCount]

    FROM analytics.vw_MonthlyEfficiencyOpportunityTrend
),

OpportunityTrend AS
(
    SELECT
        PlantID,
        PlantName,
        LineID,
        LineName,
        MachineID,
        MachineName,
        MachineType,
        ProductID,
        ProductName,
        ProductFamily,
        ShiftID,
        ShiftName,

        COUNT(*) AS [ObservedMonths],

        SUM(
            CASE
                WHEN InefficientContexts > 0
                THEN 1
                ELSE 0
            END
        ) AS [InefficientMonths],

        AVG(MonthlyRecurrenceRate)
            AS [AvgMonthlyRecurrenceRate],

        SUM(MonthlyExcessEnergyKWh)
            AS [TotalMonthlyExcessEnergyKWh],

        AVG(
            CASE
                WHEN MonthOrder <= 3
                THEN MonthlyRecurrenceRate
            END
        ) AS [EarlyPeriodRecurrenceRate],

        AVG(
            CASE
                WHEN MonthOrder > MonthCount - 3
                THEN MonthlyRecurrenceRate
            END
        ) AS [RecentPeriodRecurrenceRate]

    FROM MonthlyTrend

    GROUP BY
        PlantID,
        PlantName,
        LineID,
        LineName,
        MachineID,
        MachineName,
        MachineType,
        ProductID,
        ProductName,
        ProductFamily,
        ShiftID,
        ShiftName
)

SELECT
    *,

    CAST(
        1.0 * InefficientMonths / NULLIF(ObservedMonths, 0)
        AS DECIMAL(18,6)
    ) AS [MonthlyPersistenceRate],

    CAST(
        RecentPeriodRecurrenceRate - EarlyPeriodRecurrenceRate
        AS DECIMAL(18,6)
    ) AS [RecurrenceChange],

    CASE
        WHEN
            1.0 * InefficientMonths / NULLIF(ObservedMonths, 0) >= 0.75
            AND ABS(
                RecentPeriodRecurrenceRate - EarlyPeriodRecurrenceRate
            ) < 0.05
            THEN 'Persistent'

        WHEN
            RecentPeriodRecurrenceRate - EarlyPeriodRecurrenceRate >= 0.05
            THEN 'Worsening'

        WHEN
            RecentPeriodRecurrenceRate - EarlyPeriodRecurrenceRate <= -0.05
            THEN 'Improving'

        ELSE 'Intermittent'
    END AS [TrendClassification]

FROM OpportunityTrend;

GO
-------------------------------------------------------------------------------
SELECT
    TrendClassification,

    COUNT(*) AS [OpportunityCount],

    CAST(
        AVG(MonthlyPersistenceRate) * 100
        AS DECIMAL(10,2)
    ) AS [AvgPersistencePercent],

    CAST(
        AVG(RecurrenceChange) * 100
        AS DECIMAL(10,2)
    ) AS [AvgRecurrenceChangePercent],

    CAST(
        SUM(TotalMonthlyExcessEnergyKWh)
        AS DECIMAL(18,2)
    ) AS [TotalExcessEnergyKWh]

FROM analytics.vw_EfficiencyOpportunityTrendClassification

GROUP BY TrendClassification

ORDER BY [TotalExcessEnergyKWh] DESC;
-------------------------------------------------------------------------------
WITH ChangeDistribution AS
(
    SELECT
        PERCENTILE_CONT(0.25)
        WITHIN GROUP (ORDER BY RecurrenceChange)
        OVER () AS [ChangeP25],

        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY RecurrenceChange)
        OVER () AS [ChangeP50],

        PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY RecurrenceChange)
        OVER () AS [ChangeP75]

    FROM analytics.vw_EfficiencyOpportunityTrendClassification

    WHERE MonthlyPersistenceRate >= 0.75
)

SELECT DISTINCT
    CAST(ChangeP25 * 100 AS DECIMAL(10,2))
        AS [ChangeP25Percent],

    CAST(ChangeP50 * 100 AS DECIMAL(10,2))
        AS [ChangeP50Percent],

    CAST(ChangeP75 * 100 AS DECIMAL(10,2))
        AS [ChangeP75Percent]

FROM ChangeDistribution;
-------------------------------------------------------------------------------
-- =============================================================
-- EFFICIENCY OPPORTUNITY TIME PROFILE
-- Identifies whether an opportunity is currently active based on recent periods.
-- =============================================================
CREATE OR ALTER VIEW analytics.vw_EfficiencyOpportunityTimeProfile
AS

SELECT
    t.*,

    CASE
        WHEN t.RecentPeriodRecurrenceRate > 0
            THEN 'Recently Active'
        ELSE 'Not Recently Active'
    END AS [RecentActivityStatus]

FROM analytics.vw_EfficiencyOpportunityTrendClassification t;

GO

-------------------------------------------------------------------------------
CREATE OR ALTER VIEW analytics.vw_EfficiencyOpportunityTimeProfile
AS

SELECT
    t.*,

    CASE
        WHEN t.RecentPeriodRecurrenceRate > 0
            THEN 'Recently Active'
        ELSE 'Not Recently Active'
    END AS [RecentActivityStatus]

FROM analytics.vw_EfficiencyOpportunityTrendClassification t;

GO
-------------------------------------------------------------------------------
SELECT
    RecentActivityStatus,

    COUNT(*) AS [OpportunityCount],

    CAST(
        AVG(RecentPeriodRecurrenceRate) * 100
        AS DECIMAL(10,2)
    ) AS [AvgRecentRecurrencePercent],

    CAST(
        SUM(TotalMonthlyExcessEnergyKWh)
        AS DECIMAL(18,2)
    ) AS [TotalHistoricalExcessEnergyKWh]

FROM analytics.vw_EfficiencyOpportunityTimeProfile

GROUP BY RecentActivityStatus

ORDER BY [TotalHistoricalExcessEnergyKWh] DESC;
-------------------------------------------------------------------------------
SELECT
    TrendClassification,
    RecentActivityStatus,

    COUNT(*) AS [OpportunityCount],

    CAST(
        SUM(TotalMonthlyExcessEnergyKWh)
        AS DECIMAL(18,2)
    ) AS [TotalExcessEnergyKWh]

FROM analytics.vw_EfficiencyOpportunityTimeProfile

GROUP BY
    TrendClassification,
    RecentActivityStatus

ORDER BY
    TrendClassification,
    RecentActivityStatus;
	-------------------------------------------------------------------------------
SELECT
-- =============================================================
-- ML OUTPUT VALIDATION
-- Checks the available ML prediction table for flagged contexts and excess energy.
-- =============================================================
    COUNT(*) AS [TotalMLRows],

    SUM(
        CASE
            WHEN ML_MeaningfulExcessFlag = 1
            THEN 1
            ELSE 0
        END
    ) AS [FlaggedContexts],

    CAST(
        SUM(
            CASE
                WHEN ML_MeaningfulExcessFlag = 1
                THEN ML_EnergyGapKWh
                ELSE 0
            END
        )
        AS DECIMAL(18,2)
    ) AS [FlaggedExcessEnergyKWh]

FROM analytics.ML_EnergyPredictions;

-------------------------------------------------------------------------------
-- =============================================================
-- DATE DIMENSION
-- Creates and populates a calendar table covering the operational date range.
-- =============================================================
IF OBJECT_ID('dbo.Dim_Date', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Dim_Date
    (
        [Date]          DATE        NOT NULL,
        [Year]          INT         NOT NULL,
        [QuarterNumber] INT         NOT NULL,
        [Quarter]       VARCHAR(10) NOT NULL,
        [MonthNumber]   INT         NOT NULL,
        [MonthName]     VARCHAR(15) NOT NULL,
        [YearMonth]     CHAR(7)     NOT NULL,
        [DayOfMonth]    INT         NOT NULL,
        [DayOfWeek]     INT         NOT NULL,
        [DayName]       VARCHAR(15) NOT NULL,

        CONSTRAINT PK_Dim_Date
            PRIMARY KEY ([Date])
    );
END;
GO
-------------------------------------------------------------------------------
DECLARE @StartDate DATE;
DECLARE @EndDate   DATE;

SELECT
    @StartDate = MIN(ProductionDate),
    @EndDate   = MAX(ProductionDate)
FROM analytics.vw_OperationalPerformance;

;WITH DateSeries AS
(
    SELECT @StartDate AS [Date]

    UNION ALL

    SELECT DATEADD(DAY, 1, [Date])
    FROM DateSeries
    WHERE [Date] < @EndDate
)

INSERT INTO dbo.Dim_Date
(
    [Date],
    [Year],
    [QuarterNumber],
    [Quarter],
    [MonthNumber],
    [MonthName],
    [YearMonth],
    [DayOfMonth],
    [DayOfWeek],
    [DayName]
)
SELECT
    ds.[Date],
    YEAR(ds.[Date]),
    DATEPART(QUARTER, ds.[Date]),
    CONCAT('Q', DATEPART(QUARTER, ds.[Date])),
    MONTH(ds.[Date]),
    DATENAME(MONTH, ds.[Date]),
    CONVERT(CHAR(7), ds.[Date], 120),
    DAY(ds.[Date]),
    DATEPART(WEEKDAY, ds.[Date]),
    DATENAME(WEEKDAY, ds.[Date])
FROM DateSeries ds
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.Dim_Date d
    WHERE d.[Date] = ds.[Date]
)
OPTION (MAXRECURSION 0);
-------------------------------------------------------------------------------
SELECT
    COUNT(*) AS [DateRows],
    MIN([Date]) AS [MinDate],
    MAX([Date]) AS [MaxDate],
    COUNT(DISTINCT [Year]) AS [Years]
FROM dbo.Dim_Date;

-------------------------------------------------------------------------------
