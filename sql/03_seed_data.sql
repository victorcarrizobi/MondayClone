-- ============================================================
-- 03_seed_data.sql  --  Populate MondayClone from FINSERV_DW
-- ============================================================

USE DATABASE DEFAULT_DATABASE;
USE SCHEMA PUBLIC;
USE WAREHOUSE DEFAULT_WH;

-- -----------------------------------------------
-- 1. Create boards
-- -----------------------------------------------
INSERT INTO MC_BOARDS (NAME, DESCRIPTION)
VALUES
    ('Fraud Investigation', 'Track and investigate fraud alerts from the financial services data warehouse. Source: FINSERV_DW.RISK.FRAUD_ALERTS'),
    ('Claims Processing',   'Manage insurance claims lifecycle from filing to settlement. Source: FINSERV_DW.INSURANCE.CLAIMS');

-- -----------------------------------------------
-- 2. Create groups for Fraud Investigation board
--    Statuses: OPEN, INVESTIGATING, CONFIRMED_FRAUD, FALSE_POSITIVE, CLOSED
-- -----------------------------------------------
INSERT INTO MC_GROUPS (BOARD_ID, NAME, POSITION, COLOR)
SELECT b.BOARD_ID, g.NAME, g.POS, g.COLOR
FROM MC_BOARDS b,
     (SELECT 'Open'            AS NAME, 1 AS POS, '#579BFC' AS COLOR UNION ALL
      SELECT 'Investigating',          2,         '#FDAB3D' UNION ALL
      SELECT 'Confirmed Fraud',        3,         '#E2445C' UNION ALL
      SELECT 'False Positive',         4,         '#C4C4C4' UNION ALL
      SELECT 'Closed',                 5,         '#00C875') g
WHERE b.NAME = 'Fraud Investigation';

-- -----------------------------------------------
-- 3. Create groups for Claims Processing board
--    Statuses: FILED, UNDER_REVIEW, APPROVED, DENIED, SETTLED
-- -----------------------------------------------
INSERT INTO MC_GROUPS (BOARD_ID, NAME, POSITION, COLOR)
SELECT b.BOARD_ID, g.NAME, g.POS, g.COLOR
FROM MC_BOARDS b,
     (SELECT 'Filed'        AS NAME, 1 AS POS, '#579BFC' AS COLOR UNION ALL
      SELECT 'Under Review',        2,         '#FDAB3D' UNION ALL
      SELECT 'Approved',            3,         '#00C875' UNION ALL
      SELECT 'Denied',              4,         '#E2445C' UNION ALL
      SELECT 'Settled',             5,         '#C4C4C4') g
WHERE b.NAME = 'Claims Processing';

-- -----------------------------------------------
-- 4. Seed items from FRAUD_ALERTS into Fraud board
--    Map: ALERT_TYPE -> name, SEVERITY -> priority, STATUS -> status
-- -----------------------------------------------
INSERT INTO MC_ITEMS (GROUP_ID, BOARD_ID, NAME, STATUS, PRIORITY, DUE_DATE, AMOUNT, SOURCE_TABLE, SOURCE_ID, CUSTOMER_ID)
SELECT
    grp.GROUP_ID,
    grp.BOARD_ID,
    fa.ALERT_TYPE || ' - Alert #' || fa.ALERT_ID                       AS NAME,
    CASE fa.STATUS
        WHEN 'OPEN'            THEN 'Open'
        WHEN 'INVESTIGATING'   THEN 'Investigating'
        WHEN 'CONFIRMED_FRAUD' THEN 'Confirmed Fraud'
        WHEN 'FALSE_POSITIVE'  THEN 'False Positive'
        WHEN 'CLOSED'          THEN 'Closed'
    END                                                                AS STATUS,
    CASE fa.SEVERITY
        WHEN 'CRITICAL' THEN 'CRITICAL'
        WHEN 'HIGH'     THEN 'HIGH'
        WHEN 'MEDIUM'   THEN 'MEDIUM'
        WHEN 'LOW'      THEN 'LOW'
        ELSE 'MEDIUM'
    END                                                                AS PRIORITY,
    COALESCE(fa.RESOLUTION_DATE::DATE, DATEADD(DAY, 14, fa.ALERT_DATE::DATE)) AS DUE_DATE,
    fa.FLAGGED_AMOUNT                                                  AS AMOUNT,
    'FRAUD_ALERTS'                                                     AS SOURCE_TABLE,
    fa.ALERT_ID                                                        AS SOURCE_ID,
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
    END;

-- -----------------------------------------------
-- 5. Seed items from CLAIMS into Claims board
--    Map: CLAIM_TYPE + CLAIM_NUMBER -> name
--    Priority derived from claim amount thresholds
-- -----------------------------------------------
INSERT INTO MC_ITEMS (GROUP_ID, BOARD_ID, NAME, STATUS, PRIORITY, ASSIGNEE, DUE_DATE, AMOUNT, SOURCE_TABLE, SOURCE_ID, CUSTOMER_ID)
SELECT
    grp.GROUP_ID,
    grp.BOARD_ID,
    cl.CLAIM_TYPE || ' - ' || cl.CLAIM_NUMBER                         AS NAME,
    CASE cl.STATUS
        WHEN 'FILED'        THEN 'Filed'
        WHEN 'UNDER_REVIEW' THEN 'Under Review'
        WHEN 'APPROVED'     THEN 'Approved'
        WHEN 'DENIED'       THEN 'Denied'
        WHEN 'SETTLED'      THEN 'Settled'
    END                                                                AS STATUS,
    CASE
        WHEN cl.CLAIM_AMOUNT >= 500000 THEN 'CRITICAL'
        WHEN cl.CLAIM_AMOUNT >= 100000 THEN 'HIGH'
        WHEN cl.CLAIM_AMOUNT >= 10000  THEN 'MEDIUM'
        ELSE 'LOW'
    END                                                                AS PRIORITY,
    cl.ADJUSTER_NAME                                                   AS ASSIGNEE,
    DATEADD(DAY, 30, cl.REPORTED_DATE)                                 AS DUE_DATE,
    cl.CLAIM_AMOUNT                                                    AS AMOUNT,
    'CLAIMS'                                                           AS SOURCE_TABLE,
    cl.CLAIM_ID                                                        AS SOURCE_ID,
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
    END;

-- -----------------------------------------------
-- 6. Create mock users
-- -----------------------------------------------
INSERT INTO MC_USERS (NAME, ROLE, AVATAR_COLOR) VALUES
    ('Sarah Chen',       'Senior Investigator', '#E2445C'),
    ('James Rodriguez',  'Fraud Analyst',       '#FDAB3D'),
    ('Priya Patel',      'Claims Manager',      '#00C875'),
    ('Mike Thompson',    'Claims Adjuster',     '#579BFC'),
    ('Lisa Wang',        'Risk Analyst',        '#A25DDC'),
    ('David Kim',        'Compliance Officer',  '#FF642E'),
    ('Rachel Foster',    'Team Lead',           '#CAB641'),
    ('Alex Nguyen',      'Junior Analyst',      '#66CCFF');

-- -----------------------------------------------
-- 7. Seed sample updates (comments) for Fraud board
-- -----------------------------------------------
INSERT INTO MC_UPDATES (ITEM_ID, AUTHOR, BODY)
SELECT
    i.ITEM_ID,
    u.AUTHOR,
    u.BODY
FROM (
    SELECT ITEM_ID, ROW_NUMBER() OVER (ORDER BY ITEM_ID) AS RN
    FROM MC_ITEMS
    WHERE SOURCE_TABLE = 'FRAUD_ALERTS'
    LIMIT 10
) i
JOIN (
    SELECT 1 AS RN, 'Sarah Chen'      AS AUTHOR, 'Initial review complete. Transaction pattern suggests organized ring activity. Escalating to senior team.' AS BODY UNION ALL
    SELECT 2,       'James Rodriguez',            'Cross-referenced with known fraud patterns database. Match found on 3 indicators.' UNION ALL
    SELECT 3,       'David Kim',                  'Compliance review initiated. Customer account flagged for enhanced due diligence.' UNION ALL
    SELECT 4,       'Sarah Chen',                 'Contacted customer for verification. Awaiting callback within 48 hours.' UNION ALL
    SELECT 5,       'Lisa Wang',                  'Risk score updated based on new transaction data. Recommend immediate hold on account.' UNION ALL
    SELECT 6,       'Rachel Foster',              'Team standup: this alert is top priority this sprint. Assigning additional resources.' UNION ALL
    SELECT 7,       'Alex Nguyen',                'Gathered supporting documentation from partner bank. Evidence package being compiled.' UNION ALL
    SELECT 8,       'James Rodriguez',            'Geographic analysis complete. Transaction origin inconsistent with customer profile.' UNION ALL
    SELECT 9,       'David Kim',                  'SAR filing prepared and under review. Target submission within 24 hours.' UNION ALL
    SELECT 10,      'Sarah Chen',                 'Case closed after thorough investigation. All findings documented in case management system.'
) u ON i.RN = u.RN;

-- -----------------------------------------------
-- 8. Seed sample updates (comments) for Claims board
-- -----------------------------------------------
INSERT INTO MC_UPDATES (ITEM_ID, AUTHOR, BODY)
SELECT
    i.ITEM_ID,
    u.AUTHOR,
    u.BODY
FROM (
    SELECT ITEM_ID, ROW_NUMBER() OVER (ORDER BY ITEM_ID) AS RN
    FROM MC_ITEMS
    WHERE SOURCE_TABLE = 'CLAIMS'
    LIMIT 10
) i
JOIN (
    SELECT 1 AS RN, 'Priya Patel'    AS AUTHOR, 'Claim received and initial documentation review complete. All required forms present.' AS BODY UNION ALL
    SELECT 2,       'Mike Thompson',             'On-site inspection scheduled for next week. Coordinating with policyholder.' UNION ALL
    SELECT 3,       'Priya Patel',               'Claim amount exceeds authority level. Escalating to regional manager for approval.' UNION ALL
    SELECT 4,       'Mike Thompson',             'Adjuster notes indicate straightforward case. Recommending fast-track processing.' UNION ALL
    SELECT 5,       'Rachel Foster',             'Quality audit on this claim: all procedures followed correctly. Good work team.' UNION ALL
    SELECT 6,       'Alex Nguyen',               'Additional documentation requested from policyholder. Follow-up email sent.' UNION ALL
    SELECT 7,       'Priya Patel',               'Settlement offer prepared. Sending to policyholder for review and acceptance.' UNION ALL
    SELECT 8,       'Mike Thompson',             'Subrogation opportunity identified. Initiating recovery process against third party.' UNION ALL
    SELECT 9,       'Lisa Wang',                 'Risk assessment for this policy updated based on claims history. Premium adjustment recommended.' UNION ALL
    SELECT 10,      'Rachel Foster',             'Monthly claims review: this batch is tracking well within SLA targets.'
) u ON i.RN = u.RN;
