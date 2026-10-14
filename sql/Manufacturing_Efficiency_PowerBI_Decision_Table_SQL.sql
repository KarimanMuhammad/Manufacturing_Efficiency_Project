-- =============================================================
-- POWER BI OUTPUT TABLES
-- Materializes selected analytics views into physical tables for
-- efficient and direct consumption by the Power BI model.
-- =============================================================
USE ManufacturingEfficiencyDB;
GO

-- =============================================================
-- RANKED OPPORTUNITIES TABLE
-- Rebuilds the physical table from the ranked efficiency-opportunity view.
-- =============================================================
IF OBJECT_ID(
    'analytics.RankedEfficiencyOpportunities',
    'U'
) IS NOT NULL
    DROP TABLE analytics.RankedEfficiencyOpportunities;
GO

SELECT *
INTO analytics.RankedEfficiencyOpportunities
FROM analytics.vw_RankedEfficiencyOpportunities
OPTION (MAXDOP 1);
GO

-- Validate the number of rows materialized in the ranked-opportunities table.
SELECT COUNT(*) AS [RowCount]
FROM analytics.RankedEfficiencyOpportunities;

-- =============================================================
-- OPPORTUNITY TIME-PROFILE TABLE
-- Materializes the time-pattern and recent-activity profile for opportunities.
-- =============================================================
IF OBJECT_ID(
    'analytics.EfficiencyOpportunityTimeProfile',
    'U'
) IS NOT NULL
    DROP TABLE analytics.EfficiencyOpportunityTimeProfile;
GO

SELECT *
INTO analytics.EfficiencyOpportunityTimeProfile
FROM analytics.vw_EfficiencyOpportunityTimeProfile
OPTION (MAXDOP 1);
GO

-- Validate the number of rows materialized in the time-profile table.
SELECT COUNT(*) AS [RowCount]
FROM analytics.EfficiencyOpportunityTimeProfile;

-- =============================================================
-- FINAL POWER BI DECISION TABLE
-- Combines ranked opportunities with trend/activity evidence and derives
-- the final investigation priority used for decision support in Power BI.
-- =============================================================
-------------------------------------------------------------
-- 27.3 Create Final Power BI Decision Table
-- This table combines ranked efficiency opportunities with their
-- trend and recent-activity profile for direct Power BI consumption.

IF OBJECT_ID(
    'analytics.FinalEfficiencyInvestigationPriority_BI',
    'U'
) IS NOT NULL
    DROP TABLE analytics.FinalEfficiencyInvestigationPriority_BI;
GO

SELECT
    r.*,

    t.ObservedMonths,
    t.InefficientMonths,
    t.AvgMonthlyRecurrenceRate,
    t.MonthlyPersistenceRate,
    t.EarlyPeriodRecurrenceRate,
    t.RecentPeriodRecurrenceRate,
    t.RecurrenceChange,
    t.TrendClassification,
    t.RecentActivityStatus,

    CASE
        WHEN r.PriorityCategory = 'Priority'
             AND t.RecentActivityStatus = 'Recently Active'
             AND t.TrendClassification IN ('Worsening', 'Persistent')
            THEN 'Immediate Investigation'

        WHEN r.PriorityCategory IN (
            'Priority',
            'High Impact / Less Frequent'
        )
             AND t.RecentActivityStatus = 'Recently Active'
            THEN 'High Investigation Priority'

        WHEN r.PriorityCategory = 'Recurring / Lower Impact'
             AND t.RecentActivityStatus = 'Recently Active'
             AND t.TrendClassification IN ('Worsening', 'Persistent')
            THEN 'Monitor Closely'

        WHEN t.TrendClassification = 'Improving'
            THEN 'Improving / Monitor'

        WHEN t.RecentActivityStatus = 'Not Recently Active'
            THEN 'Historical / Review'

        ELSE 'Routine Monitoring'
    END AS [InvestigationPriority]

INTO analytics.FinalEfficiencyInvestigationPriority_BI
FROM analytics.RankedEfficiencyOpportunities AS r

LEFT JOIN analytics.EfficiencyOpportunityTimeProfile AS t
    ON r.PlantID = t.PlantID
    AND r.LineID = t.LineID
    AND r.MachineID = t.MachineID
    AND r.ProductID = t.ProductID
    AND r.ShiftID = t.ShiftID;
GO

-- =============================================================
-- FINAL POWER BI DECISION TABLE VALIDATION
-- Checks row completeness and the total excess-energy impact represented
-- in the final Power BI decision table.
-- =============================================================
-- 27.4 Validate Final Power BI Decision Table

SELECT
    COUNT(*) AS [RowCount],

    SUM(
        CASE
            WHEN TrendClassification IS NULL
              OR RecentActivityStatus IS NULL
              OR InvestigationPriority IS NULL
            THEN 1
            ELSE 0
        END
    ) AS [IncompleteRows],

    CAST(
        SUM(TotalExcessEnergyKWh)
        AS DECIMAL(18,2)
    ) AS [TotalExcessEnergyKWh]

FROM analytics.FinalEfficiencyInvestigationPriority_BI;