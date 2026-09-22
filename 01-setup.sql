-- ============================================================
-- Per-User AI Quotas — Tiered Architecture Setup
-- ============================================================
-- Three-tier model: TIER_1, TIER_2, TIER_3
-- All users default to TIER_1. Exempt users are never tagged.
-- Includes both NOTIFY and BLOCK enforcement.
-- ============================================================
-- RBAC Design:
--   SECURITYADMIN → Creates QUOTA_ADMIN and AI_USERS roles
--   SYSADMIN      → Creates database & schema
--   ACCOUNTADMIN  → Grants special privileges to both roles
--   QUOTA_ADMIN   → Creates and owns ALL schema objects (admin role)
--   AI_USERS      → End-user role with Cortex AI access (not PUBLIC)
-- ============================================================


-- ═══════════════════════════════════════════════════════════════
-- SECTION A: ROLE & GRANTS (run once by admins)
-- ═══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- A1: Create roles (SECURITYADMIN)
-- ─────────────────────────────────────────────────────────────
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS QUOTA_ADMIN;
GRANT ROLE QUOTA_ADMIN TO USER SUSKUMAR;  --your_admin_user   -- replace with your admin user if different
GRANT ROLE QUOTA_ADMIN TO ROLE SYSADMIN;         -- role hierarchy best practice

CREATE ROLE IF NOT EXISTS AI_USERS;              -- role for users who need Cortex AI access
GRANT ROLE AI_USERS TO ROLE SYSADMIN;            -- role hierarchy

-- ─────────────────────────────────────────────────────────────
-- A2: Create database & schema
-- ─────────────────────────────────────────────────────────────
USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS COST_MGMT_DB;
CREATE SCHEMA IF NOT EXISTS COST_MGMT_DB.QUOTA_SCHEMA;

-- ─────────────────────────────────────────────────────────────
-- A3: Grants to QUOTA_ADMIN role
-- Replace QUOTA_ADMIN with your role name if different.
-- Replace COST_MGMT_DB.QUOTA_SCHEMA with your db/schema.
-- Replace XSMALL_WH with your warehouse.
-- ─────────────────────────────────────────────────────────────
USE ROLE ACCOUNTADMIN;

-- [QUOTA_ADMIN] Database & schema access
GRANT USAGE ON DATABASE COST_MGMT_DB TO ROLE QUOTA_ADMIN;
GRANT ALL ON SCHEMA COST_MGMT_DB.QUOTA_SCHEMA TO ROLE QUOTA_ADMIN;

-- [QUOTA_ADMIN] Quota & budget creation
GRANT DATABASE ROLE SNOWFLAKE.QUOTA_CREATOR TO ROLE QUOTA_ADMIN;
GRANT DATABASE ROLE SNOWFLAKE.BUDGET_CREATOR TO ROLE QUOTA_ADMIN;
GRANT CREATE SNOWFLAKE.CORE.QUOTA ON SCHEMA COST_MGMT_DB.QUOTA_SCHEMA TO ROLE QUOTA_ADMIN;

-- [QUOTA_ADMIN] Access to SNOWFLAKE shared database (ACCOUNT_USAGE, telemetry, event table)
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE QUOTA_ADMIN;

-- [QUOTA_ADMIN] Tag management (required for ALTER USER ... SET TAG on any user)
GRANT APPLY TAG ON ACCOUNT TO ROLE QUOTA_ADMIN;

-- [QUOTA_ADMIN] Warehouse access (for queries, procedures, and tasks)
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE QUOTA_ADMIN;

-- ─────────────────────────────────────────────────────────────
-- A4: Grants to AI_USERS role (for users who need Cortex AI access)
-- In production, replace AI_USERS with your existing role that AI users have.
-- Do NOT grant to PUBLIC unless you want every user to have AI access.
-- ─────────────────────────────────────────────────────────────

-- [AI_USERS] Warehouse access
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE AI_USERS;

-- [AI_USERS] AI function access
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE AI_USERS;
GRANT DATABASE ROLE SNOWFLAKE.COPILOT_USER TO ROLE AI_USERS;


-- ═══════════════════════════════════════════════════════════════
-- SECTION B: DEMO USERS (optional — for testing only)
-- ═══════════════════════════════════════════════════════════════

-- Still as ACCOUNTADMIN (CREATE USER requires USERADMIN+)
CREATE USER IF NOT EXISTS DEMO_TIER1_USER
  PASSWORD = '< >'
  DEFAULT_ROLE = AI_USERS
  DEFAULT_WAREHOUSE = COMPUTE_WH
  EMAIL = 'admin@yourcompany.com'
  COMMENT = 'Demo — Tier 1 user';

CREATE USER IF NOT EXISTS DEMO_TIER2_USER
  PASSWORD = '< >'
  DEFAULT_ROLE = AI_USERS
  DEFAULT_WAREHOUSE = COMPUTE_WH
  EMAIL = 'admin@yourcompany.com'
  COMMENT = 'Demo — Tier 2 user';

CREATE USER IF NOT EXISTS DEMO_TIER3_USER
  PASSWORD = '< >'
  DEFAULT_ROLE = AI_USERS
  DEFAULT_WAREHOUSE = COMPUTE_WH
  EMAIL = 'admin@yourcompany.com'
  COMMENT = 'Demo — Tier 3 user';

CREATE USER IF NOT EXISTS DEMO_NOEMAIL_USER
  PASSWORD = 'DemoNoEmail_2026!'
  DEFAULT_ROLE = AI_USERS
  DEFAULT_WAREHOUSE = COMPUTE_WH
  COMMENT = 'Demo — No email user (Tier 1). Notifications go to admin email only.';

-- Grant AI_USERS role to demo users (gives them Cortex AI access)
GRANT ROLE AI_USERS TO USER DEMO_TIER1_USER;
GRANT ROLE AI_USERS TO USER DEMO_TIER2_USER;
GRANT ROLE AI_USERS TO USER DEMO_TIER3_USER;
GRANT ROLE AI_USERS TO USER DEMO_NOEMAIL_USER;


-- ═══════════════════════════════════════════════════════════════
-- SECTION C: SCHEMA OBJECTS (run as QUOTA_ADMIN — owns everything)
-- ═══════════════════════════════════════════════════════════════

USE ROLE QUOTA_ADMIN;
USE SCHEMA COST_MGMT_DB.QUOTA_SCHEMA;

-- ─────────────────────────────────────────────────────────────
-- C1: Tag for tier routing
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE TAG AI_COST_TIER
  ALLOWED_VALUES 'TIER_1', 'TIER_2', 'TIER_3', 'EXEMPT'
  COMMENT = 'Per-user AI quota tier: TIER_1, TIER_2, TIER_3, EXEMPT=No quota';

-- [QUOTA_ADMIN] APPLYBUDGET on tag (required for SET_USER_TAGS on quotas)
GRANT APPLYBUDGET ON TAG COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER TO ROLE QUOTA_ADMIN;

-- ─────────────────────────────────────────────────────────────
-- C2: Tag demo users to their tiers
-- ─────────────────────────────────────────────────────────────
ALTER USER DEMO_TIER1_USER SET TAG COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER = 'TIER_1';
ALTER USER DEMO_TIER2_USER SET TAG COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER = 'TIER_2';
ALTER USER DEMO_TIER3_USER SET TAG COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER = 'TIER_3';
ALTER USER DEMO_NOEMAIL_USER SET TAG COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER = 'TIER_1';

-- ─────────────────────────────────────────────────────────────
-- C3: Exempt users table
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE EXEMPT_USERS (
  USER_NAME VARCHAR NOT NULL,
  REASON VARCHAR,
  EXEMPT_DATE TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO EXEMPT_USERS (USER_NAME, REASON)
VALUES
  ('suskumar', 'Account admin — must never be blocked'),
  ('SNOWFLAKE', 'System user'); --YOUR_ADMIN_USER

-- ─────────────────────────────────────────────────────────────
-- C4: Procedure execution log table
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE PROCEDURE_EXECUTION_LOG (
  EXECUTION_ID NUMBER AUTOINCREMENT,
  PROCEDURE_NAME VARCHAR NOT NULL,
  EXECUTION_TIMESTAMP TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
  STATUS VARCHAR NOT NULL,
  USERS_TAGGED INT DEFAULT 0,
  USERS_SKIPPED INT DEFAULT 0,
  TAGGED_USER_NAMES ARRAY,
  SKIPPED_USER_DETAILS ARRAY,
  ERROR_CODE VARCHAR,
  ERROR_DESCRIPTION VARCHAR
);

-- ─────────────────────────────────────────────────────────────
-- C5: Admin audit log table (tracks all write operations from the app)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE TABLE ADMIN_AUDIT_LOG (
  AUDIT_ID NUMBER AUTOINCREMENT,
  PERFORMED_BY VARCHAR NOT NULL DEFAULT CURRENT_USER(),
  OPERATION VARCHAR NOT NULL,
  DETAILS VARCHAR,
  SNOW_TICKET VARCHAR,
  PERFORMED_AT TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP()
);

-- ─────────────────────────────────────────────────────────────
-- C6: Auto-tagging procedure (with execution logging)
-- Tags new users to TIER_1, excluding exempt users and SNOWFLAKE_SERVICE
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE PROCEDURE TAG_NEW_USERS()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
AS
BEGIN
  LET tagged_count INT := 0;
  LET skipped_count INT := 0;
  LET tagged_names ARRAY := ARRAY_CONSTRUCT();
  LET skipped_details ARRAY := ARRAY_CONSTRUCT();
  LET user_cursor CURSOR FOR
    SELECT u.NAME
    FROM SNOWFLAKE.ACCOUNT_USAGE.USERS u
    WHERE u.DELETED_ON IS NULL
      AND u.TYPE != 'SNOWFLAKE_SERVICE'
      AND u.NAME NOT IN (SELECT USER_NAME FROM COST_MGMT_DB.QUOTA_SCHEMA.EXEMPT_USERS)
      AND u.NAME NOT IN (
        SELECT OBJECT_NAME 
        FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES 
        WHERE TAG_NAME = 'AI_COST_TIER' 
          AND DOMAIN = 'USER'
      );
  
  BEGIN
    FOR user_rec IN user_cursor DO
      BEGIN
        EXECUTE IMMEDIATE 'ALTER USER "' || user_rec.NAME || '" SET TAG COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER = ''TIER_1''';
        tagged_count := tagged_count + 1;
        tagged_names := ARRAY_APPEND(tagged_names, user_rec.NAME);
      EXCEPTION
        WHEN OTHER THEN
          skipped_count := skipped_count + 1;
          skipped_details := ARRAY_APPEND(skipped_details, 
            OBJECT_CONSTRUCT('user', user_rec.NAME, 'error_code', SQLCODE::VARCHAR, 'reason', SQLERRM));
      END;
    END FOR;

    INSERT INTO COST_MGMT_DB.QUOTA_SCHEMA.PROCEDURE_EXECUTION_LOG 
      (PROCEDURE_NAME, STATUS, USERS_TAGGED, USERS_SKIPPED, TAGGED_USER_NAMES, SKIPPED_USER_DETAILS)
    SELECT 'TAG_NEW_USERS', 'SUCCESS', :tagged_count, :skipped_count, :tagged_names, :skipped_details;
    
    RETURN 'SUCCESS: Tagged ' || tagged_count::VARCHAR || ' users to TIER_1. Skipped ' || skipped_count::VARCHAR || '.';

  EXCEPTION
    WHEN OTHER THEN
      LET err_code VARCHAR := SQLCODE::VARCHAR;
      LET err_msg VARCHAR := SQLERRM;

      INSERT INTO COST_MGMT_DB.QUOTA_SCHEMA.PROCEDURE_EXECUTION_LOG 
        (PROCEDURE_NAME, STATUS, USERS_TAGGED, USERS_SKIPPED, TAGGED_USER_NAMES, SKIPPED_USER_DETAILS, ERROR_CODE, ERROR_DESCRIPTION)
      SELECT 'TAG_NEW_USERS', 'FAILURE', :tagged_count, :skipped_count, :tagged_names, :skipped_details, :err_code, :err_msg;
      
      RETURN 'FAILURE: ' || err_msg;
  END;
END;

-- ─────────────────────────────────────────────────────────────
-- C7: Usage cache table (for fast Streamlit reads)
-- NOTE: Commented out — Per-User Usage page removed from Streamlit app.
-- This section uses GET_PER_USER_USAGE_PREVIEW() which is removed at GA.
-- Will be replaced with GET_SPENDING_DETAILS_BY_USERS() in a future version.
-- ─────────────────────────────────────────────────────────────
/*
CREATE OR REPLACE TABLE QUOTA_USAGE_CACHE (
  QUOTA_NAME VARCHAR NOT NULL,
  USER_NAME VARCHAR,
  SERVICE_TYPE VARCHAR,
  USER_ID NUMBER,
  USAGE_DATE DATE,
  CREDITS_SPEND FLOAT,
  REFRESHED_AT TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE PROCEDURE REFRESH_USAGE_CACHE()
  RETURNS VARCHAR
  LANGUAGE SQL
  EXECUTE AS CALLER
AS
DECLARE
  quota_name VARCHAR;
  quota_count INTEGER DEFAULT 0;
  c1 CURSOR FOR
    SELECT "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
BEGIN
  CREATE OR REPLACE TABLE COST_MGMT_DB.QUOTA_SCHEMA.QUOTA_USAGE_CACHE_STAGING (
    QUOTA_NAME VARCHAR NOT NULL,
    USER_NAME VARCHAR,
    SERVICE_TYPE VARCHAR,
    USER_ID NUMBER,
    USAGE_DATE DATE,
    CREDITS_SPEND FLOAT,
    REFRESHED_AT TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP()
  );

  SHOW SNOWFLAKE.CORE.QUOTA IN SCHEMA COST_MGMT_DB.QUOTA_SCHEMA;

  OPEN c1;
  FOR rec IN c1 DO
    quota_name := rec."name";
    quota_count := quota_count + 1;

    EXECUTE IMMEDIATE 'CALL COST_MGMT_DB.QUOTA_SCHEMA.' || :quota_name || '!GET_PER_USER_USAGE_PREVIEW(
      DATE_TRUNC(''month'', CURRENT_DATE())::VARCHAR, CURRENT_DATE()::VARCHAR
    )';
    INSERT INTO COST_MGMT_DB.QUOTA_SCHEMA.QUOTA_USAGE_CACHE_STAGING (QUOTA_NAME, USER_NAME, SERVICE_TYPE, USER_ID, USAGE_DATE, CREDITS_SPEND)
    SELECT :quota_name, "USER_NAME", "SERVICE_TYPE", "USER_ID", "USAGE_HOUR"::DATE, SUM("CREDITS_SPEND")
    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
    GROUP BY :quota_name, "USER_NAME", "SERVICE_TYPE", "USER_ID", "USAGE_HOUR"::DATE;

  END FOR;
  CLOSE c1;

  ALTER TABLE COST_MGMT_DB.QUOTA_SCHEMA.QUOTA_USAGE_CACHE
    SWAP WITH COST_MGMT_DB.QUOTA_SCHEMA.QUOTA_USAGE_CACHE_STAGING;

  DROP TABLE IF EXISTS COST_MGMT_DB.QUOTA_SCHEMA.QUOTA_USAGE_CACHE_STAGING;

  RETURN 'Cache refreshed at ' || CURRENT_TIMESTAMP()::VARCHAR || ' — ' || quota_count::VARCHAR || ' quotas processed';
END;
*/

-- ─────────────────────────────────────────────────────────────
-- C8: Scheduled tasks
-- ─────────────────────────────────────────────────────────────

-- Hourly: refresh usage cache (commented out — Per-User Usage page removed)
/*
CREATE OR REPLACE TASK REFRESH_USAGE_CACHE_TASK
  WAREHOUSE = XSMALL_WH
  SCHEDULE = '60 MINUTE'
  COMMENT = 'Refreshes the QUOTA_USAGE_CACHE table hourly for fast Streamlit reads'
AS
  CALL COST_MGMT_DB.QUOTA_SCHEMA.REFRESH_USAGE_CACHE();

ALTER TASK REFRESH_USAGE_CACHE_TASK RESUME;
*/

-- Daily 2 PM ET: auto-tag new users to TIER_1
CREATE OR REPLACE TASK DAILY_TAG_NEW_USERS
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = 'USING CRON 0 14 * * * America/New_York'
  COMMENT = 'Tags new users to TIER_1 daily at 2 PM ET, excluding exempt users'
AS
  CALL COST_MGMT_DB.QUOTA_SCHEMA.TAG_NEW_USERS();

ALTER TASK DAILY_TAG_NEW_USERS RESUME;

-- Seed the usage cache on first setup (commented out — Per-User Usage page removed)
-- CALL REFRESH_USAGE_CACHE();


-- ═══════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════

-- Confirm current role
SELECT CURRENT_ROLE();

-- Check tags applied
SELECT SYSTEM$GET_TAG('COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER', 'DEMO_TIER1_USER', 'USER');
SELECT SYSTEM$GET_TAG('COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER', 'DEMO_TIER2_USER', 'USER');
SELECT SYSTEM$GET_TAG('COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER', 'DEMO_TIER3_USER', 'USER');
SELECT SYSTEM$GET_TAG('COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER', 'DEMO_NOEMAIL_USER', 'USER');

-- Verify DEMO_NOEMAIL_USER has no email
SELECT NAME, EMAIL FROM SNOWFLAKE.ACCOUNT_USAGE.USERS WHERE NAME = 'DEMO_NOEMAIL_USER';

-- Check exempt users
SELECT * FROM COST_MGMT_DB.QUOTA_SCHEMA.EXEMPT_USERS;

-- Check task status
SHOW TASKS IN SCHEMA COST_MGMT_DB.QUOTA_SCHEMA;
