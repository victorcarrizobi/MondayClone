-- ============================================================
-- 04_dynamic_tables.sql  --  Live dashboard aggregates
-- ============================================================
-- CRITICAL: No CURRENT_TIMESTAMP() in DT definitions.
-- CRITICAL: FINSERV_DW grants (01_grants.sql) must be applied first.

USE DATABASE DEFAULT_DATABASE;
USE SCHEMA PUBLIC;

-- -----------------------------------------------
-- MC_BOARD_STATS: per-board aggregate metrics
-- -----------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE MC_BOARD_STATS
    TARGET_LAG = '1 hour'
    WAREHOUSE  = DEFAULT_WH
AS
SELECT
    b.BOARD_ID,
    b.NAME                                                  AS BOARD_NAME,
    COUNT(i.ITEM_ID)                                        AS TOTAL_ITEMS,
    COUNT_IF(i.STATUS IN ('Open', 'Filed'))                 AS ITEMS_NEW,
    COUNT_IF(i.STATUS IN ('Investigating', 'Under Review')) AS ITEMS_IN_PROGRESS,
    COUNT_IF(i.STATUS IN ('Confirmed Fraud', 'Approved'))   AS ITEMS_RESOLVED,
    COUNT_IF(i.STATUS IN ('Closed', 'Settled', 'Denied', 'False Positive')) AS ITEMS_CLOSED,
    COUNT_IF(i.PRIORITY = 'CRITICAL')                       AS PRIORITY_CRITICAL,
    COUNT_IF(i.PRIORITY = 'HIGH')                           AS PRIORITY_HIGH,
    COUNT_IF(i.PRIORITY = 'MEDIUM')                         AS PRIORITY_MEDIUM,
    COUNT_IF(i.PRIORITY = 'LOW')                            AS PRIORITY_LOW,
    ROUND(AVG(DATEDIFF(DAY, i.CREATED_AT, i.UPDATED_AT)), 1) AS AVG_AGE_DAYS,
    SUM(i.AMOUNT)                                           AS TOTAL_AMOUNT,
    ROUND(AVG(i.AMOUNT), 2)                                 AS AVG_AMOUNT
FROM MC_BOARDS b
LEFT JOIN MC_ITEMS i ON b.BOARD_ID = i.BOARD_ID
GROUP BY b.BOARD_ID, b.NAME;

-- -----------------------------------------------
-- MC_ITEM_DETAILS: enriched items with customer + risk data
-- -----------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE MC_ITEM_DETAILS
    TARGET_LAG = '1 hour'
    WAREHOUSE  = DEFAULT_WH
AS
SELECT
    i.ITEM_ID,
    i.BOARD_ID,
    b.NAME                                              AS BOARD_NAME,
    i.GROUP_ID,
    g.NAME                                              AS GROUP_NAME,
    g.COLOR                                             AS GROUP_COLOR,
    i.NAME                                              AS ITEM_NAME,
    i.STATUS,
    i.PRIORITY,
    i.ASSIGNEE,
    i.DUE_DATE,
    i.AMOUNT,
    i.SOURCE_TABLE,
    i.SOURCE_ID,
    i.CUSTOMER_ID,
    i.CREATED_AT,
    i.UPDATED_AT,
    -- Customer enrichment
    c.FIRST_NAME || ' ' || c.LAST_NAME                 AS CUSTOMER_NAME,
    c.CUSTOMER_TIER,
    c.CREDIT_SCORE,
    c.EMAIL                                             AS CUSTOMER_EMAIL,
    -- Risk enrichment
    r.RISK_SCORE,
    r.CREDIT_RISK,
    r.AML_RISK,
    -- Computed flags
    CASE
        WHEN i.PRIORITY IN ('CRITICAL', 'HIGH')
         AND i.STATUS IN ('Open', 'Filed', 'Investigating', 'Under Review')
        THEN TRUE ELSE FALSE
    END                                                 AS IS_URGENT,
    CASE
        WHEN i.DUE_DATE < CURRENT_DATE()
         AND i.STATUS NOT IN ('Closed', 'Settled', 'Denied', 'False Positive')
        THEN TRUE ELSE FALSE
    END                                                 AS IS_OVERDUE
FROM MC_ITEMS i
JOIN MC_BOARDS b  ON i.BOARD_ID  = b.BOARD_ID
JOIN MC_GROUPS g  ON i.GROUP_ID  = g.GROUP_ID
LEFT JOIN FINSERV_DW.CORE.CUSTOMERS c         ON i.CUSTOMER_ID = c.CUSTOMER_ID
LEFT JOIN FINSERV_DW.RISK.RISK_ASSESSMENTS r  ON i.CUSTOMER_ID = r.CUSTOMER_ID;
