-- ============================================================
-- 06_tasks_alerts.sql  --  Scheduled tasks and alerts
-- ============================================================

USE DATABASE DEFAULT_DATABASE;
USE SCHEMA PUBLIC;
USE WAREHOUSE DEFAULT_WH;

-- -----------------------------------------------
-- Task: Detect new fraud alerts and auto-insert as items
-- Runs every 15 minutes. Picks up any FRAUD_ALERTS rows
-- that don't yet have a corresponding MC_ITEMS entry.
-- -----------------------------------------------
CREATE OR REPLACE TASK MC_SYNC_FRAUD_ALERTS
    WAREHOUSE = DEFAULT_WH
    SCHEDULE  = '15 MINUTE'
AS
INSERT INTO MC_ITEMS (GROUP_ID, BOARD_ID, NAME, STATUS, PRIORITY, DUE_DATE, AMOUNT, SOURCE_TABLE, SOURCE_ID, CUSTOMER_ID)
SELECT
    grp.GROUP_ID,
    grp.BOARD_ID,
    fa.ALERT_TYPE || ' - Alert #' || fa.ALERT_ID,
    CASE fa.STATUS
        WHEN 'OPEN'            THEN 'Open'
        WHEN 'INVESTIGATING'   THEN 'Investigating'
        WHEN 'CONFIRMED_FRAUD' THEN 'Confirmed Fraud'
        WHEN 'FALSE_POSITIVE'  THEN 'False Positive'
        WHEN 'CLOSED'          THEN 'Closed'
    END,
    CASE fa.SEVERITY
        WHEN 'CRITICAL' THEN 'CRITICAL'
        WHEN 'HIGH'     THEN 'HIGH'
        WHEN 'MEDIUM'   THEN 'MEDIUM'
        WHEN 'LOW'      THEN 'LOW'
        ELSE 'MEDIUM'
    END,
    COALESCE(fa.RESOLUTION_DATE::DATE, DATEADD(DAY, 14, fa.ALERT_DATE::DATE)),
    fa.FLAGGED_AMOUNT,
    'FRAUD_ALERTS',
    fa.ALERT_ID,
    fa.CUSTOMER_ID
FROM FINSERV_DW.RISK.FRAUD_ALERTS fa
JOIN MC_GROUPS grp
    ON grp.BOARD_ID = (SELECT BOARD_ID FROM MC_BOARDS WHERE NAME = 'Fraud Investigation')
   AND grp.NAME = CASE fa.STATUS
        WHEN 'OPEN'            THEN 'Open'
        WHEN 'INVESTIGATING'   THEN 'Investigating'
        WHEN 'CONFIRMED_FRAUD' THEN 'Confirmed Fraud'
        WHEN 'FALSE_POSITIVE'  THEN 'False Positive'
        WHEN 'CLOSED'          THEN 'Closed'
    END
WHERE NOT EXISTS (
    SELECT 1 FROM MC_ITEMS i
    WHERE i.SOURCE_TABLE = 'FRAUD_ALERTS'
      AND i.SOURCE_ID = fa.ALERT_ID
);

-- -----------------------------------------------
-- Task: Detect new claims and auto-insert as items
-- Runs every 15 minutes.
-- -----------------------------------------------
CREATE OR REPLACE TASK MC_SYNC_CLAIMS
    WAREHOUSE = DEFAULT_WH
    SCHEDULE  = '15 MINUTE'
AS
INSERT INTO MC_ITEMS (GROUP_ID, BOARD_ID, NAME, STATUS, PRIORITY, ASSIGNEE, DUE_DATE, AMOUNT, SOURCE_TABLE, SOURCE_ID, CUSTOMER_ID)
SELECT
    grp.GROUP_ID,
    grp.BOARD_ID,
    cl.CLAIM_TYPE || ' - ' || cl.CLAIM_NUMBER,
    CASE cl.STATUS
        WHEN 'FILED'        THEN 'Filed'
        WHEN 'UNDER_REVIEW' THEN 'Under Review'
        WHEN 'APPROVED'     THEN 'Approved'
        WHEN 'DENIED'       THEN 'Denied'
        WHEN 'SETTLED'      THEN 'Settled'
    END,
    CASE
        WHEN cl.CLAIM_AMOUNT >= 500000 THEN 'CRITICAL'
        WHEN cl.CLAIM_AMOUNT >= 100000 THEN 'HIGH'
        WHEN cl.CLAIM_AMOUNT >= 10000  THEN 'MEDIUM'
        ELSE 'LOW'
    END,
    cl.ADJUSTER_NAME,
    DATEADD(DAY, 30, cl.REPORTED_DATE),
    cl.CLAIM_AMOUNT,
    'CLAIMS',
    cl.CLAIM_ID,
    cl.CUSTOMER_ID
FROM FINSERV_DW.INSURANCE.CLAIMS cl
JOIN MC_GROUPS grp
    ON grp.BOARD_ID = (SELECT BOARD_ID FROM MC_BOARDS WHERE NAME = 'Claims Processing')
   AND grp.NAME = CASE cl.STATUS
        WHEN 'FILED'        THEN 'Filed'
        WHEN 'UNDER_REVIEW' THEN 'Under Review'
        WHEN 'APPROVED'     THEN 'Approved'
        WHEN 'DENIED'       THEN 'Denied'
        WHEN 'SETTLED'      THEN 'Settled'
    END
WHERE NOT EXISTS (
    SELECT 1 FROM MC_ITEMS i
    WHERE i.SOURCE_TABLE = 'CLAIMS'
      AND i.SOURCE_ID = cl.CLAIM_ID
);

-- -----------------------------------------------
-- Alert: Notify when critical fraud items are overdue
-- Checks every hour for CRITICAL priority fraud items
-- past their due date that are still open/investigating.
-- -----------------------------------------------
CREATE OR REPLACE ALERT MC_CRITICAL_OVERDUE_ALERT
    WAREHOUSE = DEFAULT_WH
    SCHEDULE  = '60 MINUTE'
IF (EXISTS (
    SELECT 1
    FROM MC_ITEMS
    WHERE SOURCE_TABLE = 'FRAUD_ALERTS'
      AND PRIORITY = 'CRITICAL'
      AND STATUS IN ('Open', 'Investigating')
      AND DUE_DATE < CURRENT_DATE()
))
THEN
    INSERT INTO MC_ACTIVITY_LOG (ITEM_ID, USER_ID, ACTION, DETAIL)
    SELECT
        i.ITEM_ID,
        NULL,
        'OVERDUE_ALERT',
        'CRITICAL fraud item overdue: ' || i.NAME || ' (due ' || i.DUE_DATE || ')'
    FROM MC_ITEMS i
    WHERE i.SOURCE_TABLE = 'FRAUD_ALERTS'
      AND i.PRIORITY = 'CRITICAL'
      AND i.STATUS IN ('Open', 'Investigating')
      AND i.DUE_DATE < CURRENT_DATE();

-- -----------------------------------------------
-- NOTE: Tasks are created in SUSPENDED state.
-- Run these to activate:
--   ALTER TASK MC_SYNC_FRAUD_ALERTS RESUME;
--   ALTER TASK MC_SYNC_CLAIMS RESUME;
--   ALTER ALERT MC_CRITICAL_OVERDUE_ALERT RESUME;
-- -----------------------------------------------
