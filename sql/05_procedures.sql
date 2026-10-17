-- ============================================================
-- 05_procedures.sql  --  MondayClone stored procedures
-- ============================================================

USE DATABASE DEFAULT_DATABASE;
USE SCHEMA PUBLIC;
USE WAREHOUSE DEFAULT_WH;

-- -----------------------------------------------
-- MC_UPDATE_ITEM_STATUS: change item status + log
-- -----------------------------------------------
CREATE OR REPLACE PROCEDURE MC_UPDATE_ITEM_STATUS(
    P_ITEM_ID    INT,
    P_NEW_STATUS VARCHAR,
    P_USER_ID    INT
)
RETURNS VARCHAR
LANGUAGE SQL
AS
DECLARE
    V_OLD_STATUS VARCHAR;
    V_USER_NAME  VARCHAR;
    V_GROUP_ID   INT;
BEGIN
    -- Get current status
    SELECT STATUS INTO :V_OLD_STATUS
    FROM MC_ITEMS
    WHERE ITEM_ID = :P_ITEM_ID;

    -- Get user name
    SELECT NAME INTO :V_USER_NAME
    FROM MC_USERS
    WHERE USER_ID = :P_USER_ID;

    -- Find target group for this status on the same board
    SELECT g.GROUP_ID INTO :V_GROUP_ID
    FROM MC_GROUPS g
    JOIN MC_ITEMS i ON i.BOARD_ID = g.BOARD_ID
    WHERE i.ITEM_ID = :P_ITEM_ID
      AND g.NAME = :P_NEW_STATUS;

    -- Update item
    UPDATE MC_ITEMS
    SET STATUS     = :P_NEW_STATUS,
        GROUP_ID   = :V_GROUP_ID,
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE ITEM_ID = :P_ITEM_ID;

    -- Log the change
    INSERT INTO MC_ACTIVITY_LOG (ITEM_ID, USER_ID, ACTION, DETAIL)
    VALUES (
        :P_ITEM_ID,
        :P_USER_ID,
        'STATUS_CHANGE',
        :V_USER_NAME || ' changed status from ' || :V_OLD_STATUS || ' to ' || :P_NEW_STATUS
    );

    RETURN 'Status updated: ' || V_OLD_STATUS || ' -> ' || P_NEW_STATUS;
END;

-- -----------------------------------------------
-- MC_ADD_UPDATE: add a comment to an item
-- -----------------------------------------------
CREATE OR REPLACE PROCEDURE MC_ADD_UPDATE(
    P_ITEM_ID INT,
    P_AUTHOR  VARCHAR,
    P_BODY    VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    INSERT INTO MC_UPDATES (ITEM_ID, AUTHOR, BODY)
    VALUES (:P_ITEM_ID, :P_AUTHOR, :P_BODY);

    -- Touch the item's updated_at
    UPDATE MC_ITEMS
    SET UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE ITEM_ID = :P_ITEM_ID;

    RETURN 'Update added to item ' || P_ITEM_ID;
END;

-- -----------------------------------------------
-- MC_ASSIGN_ITEM: assign an item + log
-- -----------------------------------------------
CREATE OR REPLACE PROCEDURE MC_ASSIGN_ITEM(
    P_ITEM_ID   INT,
    P_ASSIGNEE  VARCHAR,
    P_USER_ID   INT
)
RETURNS VARCHAR
LANGUAGE SQL
AS
DECLARE
    V_OLD_ASSIGNEE VARCHAR;
    V_USER_NAME    VARCHAR;
BEGIN
    -- Get current assignee
    SELECT COALESCE(ASSIGNEE, 'Unassigned') INTO :V_OLD_ASSIGNEE
    FROM MC_ITEMS
    WHERE ITEM_ID = :P_ITEM_ID;

    -- Get user name
    SELECT NAME INTO :V_USER_NAME
    FROM MC_USERS
    WHERE USER_ID = :P_USER_ID;

    -- Update assignee
    UPDATE MC_ITEMS
    SET ASSIGNEE   = :P_ASSIGNEE,
        UPDATED_AT = CURRENT_TIMESTAMP()
    WHERE ITEM_ID = :P_ITEM_ID;

    -- Log the change
    INSERT INTO MC_ACTIVITY_LOG (ITEM_ID, USER_ID, ACTION, DETAIL)
    VALUES (
        :P_ITEM_ID,
        :P_USER_ID,
        'ASSIGNMENT',
        :V_USER_NAME || ' assigned item from ' || :V_OLD_ASSIGNEE || ' to ' || :P_ASSIGNEE
    );

    RETURN 'Item ' || P_ITEM_ID || ' assigned to ' || P_ASSIGNEE;
END;
