-- ============================================================
-- restore.sql -- Restore MondayClone from backup CSVs
-- ============================================================
-- Usage:
--   1. Upload backup/*.csv.gz files to a stage:
--      CREATE STAGE MC_RESTORE_STAGE;
--      PUT 'file:///path/to/backup/mc_*.csv.gz' @MC_RESTORE_STAGE/;
--   2. Run sql/02_schema.sql first to create tables
--   3. Then run this file to load data

USE DATABASE DEFAULT_DATABASE;
USE SCHEMA PUBLIC;
USE WAREHOUSE DEFAULT_WH;

-- Load in dependency order (boards -> groups -> items -> rest)
COPY INTO MC_BOARDS FROM @MC_RESTORE_STAGE/mc_boards.csv.gz
    FILE_FORMAT=(TYPE=CSV COMPRESSION=GZIP SKIP_HEADER=1 FIELD_OPTIONALLY_ENCLOSED_BY='"');

COPY INTO MC_GROUPS FROM @MC_RESTORE_STAGE/mc_groups.csv.gz
    FILE_FORMAT=(TYPE=CSV COMPRESSION=GZIP SKIP_HEADER=1 FIELD_OPTIONALLY_ENCLOSED_BY='"');

COPY INTO MC_USERS FROM @MC_RESTORE_STAGE/mc_users.csv.gz
    FILE_FORMAT=(TYPE=CSV COMPRESSION=GZIP SKIP_HEADER=1 FIELD_OPTIONALLY_ENCLOSED_BY='"');

COPY INTO MC_ITEMS FROM @MC_RESTORE_STAGE/mc_items.csv.gz
    FILE_FORMAT=(TYPE=CSV COMPRESSION=GZIP SKIP_HEADER=1 FIELD_OPTIONALLY_ENCLOSED_BY='"');

COPY INTO MC_UPDATES FROM @MC_RESTORE_STAGE/mc_updates.csv.gz
    FILE_FORMAT=(TYPE=CSV COMPRESSION=GZIP SKIP_HEADER=1 FIELD_OPTIONALLY_ENCLOSED_BY='"');

COPY INTO MC_AI_INSIGHTS FROM @MC_RESTORE_STAGE/mc_ai_insights.csv.gz
    FILE_FORMAT=(TYPE=CSV COMPRESSION=GZIP SKIP_HEADER=1 FIELD_OPTIONALLY_ENCLOSED_BY='"');

-- Activity log may be empty, skip errors
COPY INTO MC_ACTIVITY_LOG FROM @MC_RESTORE_STAGE/mc_activity_log.csv.gz
    FILE_FORMAT=(TYPE=CSV COMPRESSION=GZIP SKIP_HEADER=1 FIELD_OPTIONALLY_ENCLOSED_BY='"')
    ON_ERROR=CONTINUE;
