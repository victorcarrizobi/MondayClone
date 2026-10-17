-- ============================================================
-- 02_schema.sql  --  MondayClone core tables
-- ============================================================

USE DATABASE DEFAULT_DATABASE;
USE SCHEMA PUBLIC;
USE WAREHOUSE DEFAULT_WH;

-- Sequences for auto-increment IDs
CREATE OR REPLACE SEQUENCE MC_BOARD_SEQ   START = 1 INCREMENT = 1;
CREATE OR REPLACE SEQUENCE MC_GROUP_SEQ   START = 1 INCREMENT = 1;
CREATE OR REPLACE SEQUENCE MC_ITEM_SEQ    START = 1 INCREMENT = 1;
CREATE OR REPLACE SEQUENCE MC_UPDATE_SEQ  START = 1 INCREMENT = 1;
CREATE OR REPLACE SEQUENCE MC_USER_SEQ    START = 1 INCREMENT = 1;
CREATE OR REPLACE SEQUENCE MC_LOG_SEQ     START = 1 INCREMENT = 1;

-- -----------------------------------------------
-- MC_BOARDS: top-level project boards
-- -----------------------------------------------
CREATE OR REPLACE TABLE MC_BOARDS (
    BOARD_ID    INT DEFAULT MC_BOARD_SEQ.NEXTVAL,
    NAME        VARCHAR(200)  NOT NULL,
    DESCRIPTION VARCHAR(1000),
    CREATED_AT  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (BOARD_ID)
);

-- -----------------------------------------------
-- MC_GROUPS: status groups within a board
-- -----------------------------------------------
CREATE OR REPLACE TABLE MC_GROUPS (
    GROUP_ID    INT DEFAULT MC_GROUP_SEQ.NEXTVAL,
    BOARD_ID    INT NOT NULL,
    NAME        VARCHAR(200) NOT NULL,
    POSITION    INT DEFAULT 0,
    COLOR       VARCHAR(20) DEFAULT '#579BFC',
    PRIMARY KEY (GROUP_ID),
    FOREIGN KEY (BOARD_ID) REFERENCES MC_BOARDS(BOARD_ID)
);

-- -----------------------------------------------
-- MC_ITEMS: individual work items (cards)
-- -----------------------------------------------
CREATE OR REPLACE TABLE MC_ITEMS (
    ITEM_ID       INT DEFAULT MC_ITEM_SEQ.NEXTVAL,
    GROUP_ID      INT NOT NULL,
    BOARD_ID      INT NOT NULL,
    NAME          VARCHAR(500) NOT NULL,
    STATUS        VARCHAR(50)  DEFAULT 'OPEN',
    PRIORITY      VARCHAR(20)  DEFAULT 'MEDIUM',
    ASSIGNEE      VARCHAR(100),
    DUE_DATE      DATE,
    AMOUNT        NUMBER(18,2),
    SOURCE_TABLE  VARCHAR(100),
    SOURCE_ID     INT,
    CUSTOMER_ID   INT,
    CREATED_AT    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (ITEM_ID),
    FOREIGN KEY (GROUP_ID) REFERENCES MC_GROUPS(GROUP_ID),
    FOREIGN KEY (BOARD_ID) REFERENCES MC_BOARDS(BOARD_ID)
);

-- -----------------------------------------------
-- MC_UPDATES: comments / activity on items
-- -----------------------------------------------
CREATE OR REPLACE TABLE MC_UPDATES (
    UPDATE_ID       INT DEFAULT MC_UPDATE_SEQ.NEXTVAL,
    ITEM_ID         INT NOT NULL,
    AUTHOR          VARCHAR(100) NOT NULL,
    BODY            VARCHAR(4000),
    CREATED_AT      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    SENTIMENT_SCORE FLOAT,
    PRIMARY KEY (UPDATE_ID),
    FOREIGN KEY (ITEM_ID) REFERENCES MC_ITEMS(ITEM_ID)
);

-- -----------------------------------------------
-- MC_USERS: mock user directory
-- -----------------------------------------------
CREATE OR REPLACE TABLE MC_USERS (
    USER_ID      INT DEFAULT MC_USER_SEQ.NEXTVAL,
    NAME         VARCHAR(100) NOT NULL,
    ROLE         VARCHAR(50)  NOT NULL,
    AVATAR_COLOR VARCHAR(20)  DEFAULT '#579BFC',
    PRIMARY KEY (USER_ID)
);

-- -----------------------------------------------
-- MC_ACTIVITY_LOG: audit trail of changes
-- -----------------------------------------------
CREATE OR REPLACE TABLE MC_ACTIVITY_LOG (
    LOG_ID     INT DEFAULT MC_LOG_SEQ.NEXTVAL,
    ITEM_ID    INT,
    USER_ID    INT,
    ACTION     VARCHAR(50)   NOT NULL,
    DETAIL     VARCHAR(2000),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (LOG_ID)
);

-- -----------------------------------------------
-- MC_AI_INSIGHTS: AI-generated enrichment
-- -----------------------------------------------
CREATE OR REPLACE TABLE MC_AI_INSIGHTS (
    ITEM_ID          INT NOT NULL,
    AI_SUMMARY       VARCHAR(2000),
    SUGGESTED_ACTIONS VARCHAR(2000),
    AUTO_PRIORITY    VARCHAR(20),
    GENERATED_AT     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (ITEM_ID),
    FOREIGN KEY (ITEM_ID) REFERENCES MC_ITEMS(ITEM_ID)
);
