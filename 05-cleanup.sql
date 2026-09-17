-- ============================================================
-- Per-User AI Quotas — Cleanup (Demo)
-- ============================================================
-- Reverse order of creation. Objects dropped by their owner role.
-- ============================================================

-- ═══════════════════════════════════════════════════════════════
-- 1. DROP SCHEMA OBJECTS (as QUOTA_ADMIN — owner of all objects)
-- ═══════════════════════════════════════════════════════════════
USE ROLE QUOTA_ADMIN;
USE SCHEMA COST_MGMT_DB.QUOTA_SCHEMA;

-- Quotas
DROP SNOWFLAKE.CORE.QUOTA IF EXISTS TIER1_QUOTA;
DROP SNOWFLAKE.CORE.QUOTA IF EXISTS TIER2_QUOTA;
DROP SNOWFLAKE.CORE.QUOTA IF EXISTS TIER3_QUOTA;

-- Task (suspend first)
ALTER TASK IF EXISTS REFRESH_USAGE_CACHE_TASK SUSPEND;
DROP TASK IF EXISTS REFRESH_USAGE_CACHE_TASK;
ALTER TASK IF EXISTS DAILY_TAG_NEW_USERS SUSPEND;
DROP TASK IF EXISTS DAILY_TAG_NEW_USERS;

-- Procedures
DROP PROCEDURE IF EXISTS TAG_NEW_USERS();
DROP PROCEDURE IF EXISTS REFRESH_USAGE_CACHE();

-- Tables
DROP TABLE IF EXISTS QUOTA_USAGE_CACHE;
DROP TABLE IF EXISTS QUOTA_USAGE_CACHE_STAGING;
DROP TABLE IF EXISTS EXEMPT_USERS;
DROP TABLE IF EXISTS PROCEDURE_EXECUTION_LOG;

-- Tag (must untag users first or drop will cascade)
DROP TAG IF EXISTS AI_COST_TIER;

-- ═══════════════════════════════════════════════════════════════
-- 2. DROP DEMO USERS (requires ACCOUNTADMIN/USERADMIN)
-- ═══════════════════════════════════════════════════════════════
USE ROLE ACCOUNTADMIN;

DROP USER IF EXISTS DEMO_TIER1_USER;
DROP USER IF EXISTS DEMO_TIER2_USER;
DROP USER IF EXISTS DEMO_TIER3_USER;
DROP USER IF EXISTS DEMO_NOEMAIL_USER;

-- ═══════════════════════════════════════════════════════════════
-- 3. DROP SCHEMA & DATABASE (optional — uncomment if needed)
-- ═══════════════════════════════════════════════════════════════
-- DROP SCHEMA IF EXISTS COST_MGMT_DB.QUOTA_SCHEMA;
-- DROP DATABASE IF EXISTS COST_MGMT_DB;

-- ═══════════════════════════════════════════════════════════════
-- 4. DROP ROLE (optional — uncomment if decommissioning entirely)
-- ═══════════════════════════════════════════════════════════════
-- USE ROLE SECURITYADMIN;
-- DROP ROLE IF EXISTS QUOTA_ADMIN;
