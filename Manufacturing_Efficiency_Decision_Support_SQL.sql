
-- =============================================================
-- DECISION-SUPPORT ANALYTICS LAYER
-- Builds a consolidated decision base by combining efficiency opportunity,
-- priority, and time-pattern evidence for each operating context.
-- =============================================================
USE ManufacturingEfficiencyDB;
GO
CREATE OR ALTER VIEW analytics.vw_EfficiencyOpportunityDecisionBase
AS

SELECT
    r.PlantID,
    r.PlantName,

    r.LineID,
    r.LineName,

    r.MachineID,
    r.MachineName,
    r.MachineType,

    r.ProductID,
    r.ProductName,
    r.ProductFamily,

    r.ShiftID,
    r.ShiftName,

    -- Impact and recurrence
    r.ObservedContexts,
    r.InefficientContexts,
    r.RecurrenceRate,
    r.TotalExcessEnergyKWh,
    r.AvgExcessPercent,

    -- Supporting operational evidence
    r.OperationalAnomalyCount,
    r.UnplannedDowntimeMinutes,
    r.DowntimeEventCount,

    r.FirstObservedDate,
    r.LastObservedDate,

    -- Existing impact × recurrence classification
    r.PriorityCategory,
    r.PriorityRank,

    -- Time-pattern evidence
    t.ObservedMonths,
    t.InefficientMonths,
    t.AvgMonthlyRecurrenceRate,
    t.MonthlyPersistenceRate,
    t.EarlyPeriodRecurrenceRate,
    t.RecentPeriodRecurrenceRate,
    t.RecurrenceChange,
    t.TrendClassification,
    t.RecentActivityStatus

FROM analytics.vw_RankedEfficiencyOpportunities r

LEFT JOIN analytics.vw_EfficiencyOpportunityTimeProfile t
    ON r.PlantID = t.PlantID
    AND r.LineID = t.LineID
    AND r.MachineID = t.MachineID
    AND r.ProductID = t.ProductID
    AND r.ShiftID = t.ShiftID;
GO
-- =============================================================
-- DECISION BASE VALIDATION
-- Checks row coverage and identifies missing trend/activity evidence.
-- =============================================================
SELECT
    COUNT(*) AS [DecisionBaseRows],

    SUM(
        CASE
            WHEN TrendClassification IS NULL
            THEN 1
            ELSE 0
        END
    ) AS [MissingTrendProfiles],

    SUM(
        CASE
            WHEN RecentActivityStatus IS NULL
            THEN 1
            ELSE 0
        END
    ) AS [MissingRecentActivity]

FROM analytics.vw_EfficiencyOpportunityDecisionBase;

-- =============================================================
-- DECISION BASE DUPLICATE CHECK
-- Verifies that each Plant/Line/Machine/Product/Shift context is unique.
-- =============================================================
SELECT
    PlantID,
    LineID,
    MachineID,
    ProductID,
    ShiftID,
    COUNT(*) AS [RowCount]

FROM analytics.vw_EfficiencyOpportunityDecisionBase

GROUP BY
    PlantID,
    LineID,
    MachineID,
    ProductID,
    ShiftID

HAVING COUNT(*) > 1;
-- =============================================================
-- FINAL INVESTIGATION PRIORITY
-- Converts impact, recurrence, recent activity, and trend evidence
-- into an actionable investigation-priority category.
-- =============================================================
--------------------------------------------------------
CREATE OR ALTER VIEW analytics.vw_FinalEfficiencyInvestigationPriority
AS

SELECT
    *,

    CASE
        -- Highest attention:
        -- already high impact + recurring, still active, and worsening/persistent
        WHEN PriorityCategory = 'Priority'
             AND RecentActivityStatus = 'Recently Active'
             AND TrendClassification IN ('Worsening', 'Persistent')
            THEN 'Immediate Investigation'

        -- Important issue, but not all urgency signals are present
        WHEN PriorityCategory IN
             (
                 'Priority',
                 'High Impact / Less Frequent'
             )
             AND RecentActivityStatus = 'Recently Active'
            THEN 'High Investigation Priority'

        -- Recurring issue that is currently active
        WHEN PriorityCategory = 'Recurring / Lower Impact'
             AND RecentActivityStatus = 'Recently Active'
             AND TrendClassification IN ('Worsening', 'Persistent')
            THEN 'Monitor Closely'

        -- Historical issue showing improvement
        WHEN TrendClassification = 'Improving'
            THEN 'Improving / Monitor'

        -- Not currently active
        WHEN RecentActivityStatus = 'Not Recently Active'
            THEN 'Historical / Review'

        ELSE 'Routine Monitoring'
    END AS [InvestigationPriority]

FROM analytics.vw_EfficiencyOpportunityDecisionBase;
GO

-- =============================================================
-- INVESTIGATION PRIORITY SUMMARY
-- Summarizes the number and energy impact of opportunities by priority.
-- =============================================================
SELECT
    InvestigationPriority,
    COUNT(*) AS [OpportunityCount],
    CAST(
        SUM(TotalExcessEnergyKWh)
        AS DECIMAL(18,2)
    ) AS [TotalExcessEnergyKWh]

FROM analytics.vw_FinalEfficiencyInvestigationPriority

GROUP BY InvestigationPriority

ORDER BY
    CASE InvestigationPriority
        WHEN 'Immediate Investigation' THEN 1
        WHEN 'High Investigation Priority' THEN 2
        WHEN 'Monitor Closely' THEN 3
        WHEN 'Improving / Monitor' THEN 4
        WHEN 'Historical / Review' THEN 5
        ELSE 6
    END;
-- =============================================================
-- FINAL DECISION-SUPPORT VALIDATION
-- Checks total opportunities, unique operating contexts, missing decision
-- attributes, and total excess energy represented in the final output.
-- =============================================================
	--------------------------------------------------
	SELECT
    COUNT(*) AS [TotalOpportunities],
    COUNT(DISTINCT CONCAT(
        PlantID, '|',
        LineID, '|',
        MachineID, '|',
        ProductID, '|',
        ShiftID
    )) AS [UniqueOpportunities],

    SUM(
        CASE
            WHEN InvestigationPriority IS NULL
              OR TrendClassification IS NULL
              OR RecentActivityStatus IS NULL
            THEN 1
            ELSE 0
        END
    ) AS [IncompleteDecisionRows],

    CAST(
        SUM(TotalExcessEnergyKWh)
        AS DECIMAL(18,2)
    ) AS [TotalExcessEnergyKWh]

FROM analytics.vw_FinalEfficiencyInvestigationPriority;