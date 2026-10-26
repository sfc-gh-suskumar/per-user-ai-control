-- ============================================================
-- Per-User AI Quotas — Monitor & Verify (Demo)
-- ============================================================
-- Run these queries as QUOTA_ADMIN to check quota status,
-- active blocks, usage previews, and notification history.
-- ============================================================

USE ROLE QUOTA_ADMIN;
USE SCHEMA COST_MGMT_DB.QUOTA_SCHEMA;

-- ═══════════════════════════════════════════════════════════════
-- 1. QUOTA CONFIGURATION
-- ═══════════════════════════════════════════════════════════════

-- Full configuration for each tier
CALL tier1_quota!GET_CONFIG();
CALL tier2_quota!GET_CONFIG();
CALL tier3_quota!GET_CONFIG();

-- ═══════════════════════════════════════════════════════════════
-- 2. USER SCOPE — Who is in each quota?
-- ═══════════════════════════════════════════════════════════════

CALL tier1_quota!GET_QUOTA_SCOPE();
CALL tier2_quota!GET_QUOTA_SCOPE();
CALL tier3_quota!GET_QUOTA_SCOPE();

-- List users governed by each quota
CALL tier1_quota!GET_USERS();
CALL tier2_quota!GET_USERS();
CALL tier3_quota!GET_USERS();

-- ═══════════════════════════════════════════════════════════════
-- 3. ACTIVE BLOCKS — Who is currently blocked?
-- ═══════════════════════════════════════════════════════════════

CALL tier1_quota!GET_ACTIVE_BLOCKS();
CALL tier2_quota!GET_ACTIVE_BLOCKS();
CALL tier3_quota!GET_ACTIVE_BLOCKS();

-- ═══════════════════════════════════════════════════════════════
-- 4. PER-USER USAGE PREVIEW — Current spend per user
-- Requires date range: ('<start_date>', '<end_date>')
-- ═══════════════════════════════════════════════════════════════

CALL tier1_quota!GET_PER_USER_USAGE_PREVIEW(DATE_TRUNC('month', CURRENT_DATE())::VARCHAR, CURRENT_DATE()::VARCHAR);
CALL tier2_quota!GET_PER_USER_USAGE_PREVIEW(DATE_TRUNC('month', CURRENT_DATE())::VARCHAR, CURRENT_DATE()::VARCHAR);
CALL tier3_quota!GET_PER_USER_USAGE_PREVIEW(DATE_TRUNC('month', CURRENT_DATE())::VARCHAR, CURRENT_DATE()::VARCHAR);

-- ═══════════════════════════════════════════════════════════════
-- 5. NOTIFICATION THRESHOLDS & EVENT HISTORY
-- ═══════════════════════════════════════════════════════════════

-- View configured thresholds
CALL tier1_quota!GET_NOTIFICATION_THRESHOLDS();
CALL tier2_quota!GET_NOTIFICATION_THRESHOLDS();
CALL tier3_quota!GET_NOTIFICATION_THRESHOLDS();

-- Query the event table for quota notification events
-- NOTE: Replace with your account's event table if different from default
-- Check with: SHOW PARAMETERS LIKE 'EVENT_TABLE' IN ACCOUNT;
SELECT
    RECORD:name::STRING   AS event_name,
    VALUE:message::STRING AS message,
    TIMESTAMP
FROM snowflake.telemetry.events
WHERE SCOPE['name'] = 'snow.cost.quota'
  AND TIMESTAMP > DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY TIMESTAMP DESC;

-- ═══════════════════════════════════════════════════════════════
-- 6. CROSS-REFERENCE WITH ACCOUNT_USAGE
-- ═══════════════════════════════════════════════════════════════

-- Total AI Function credits per user (last 24h)
SELECT 
    u.NAME AS user_name,
    SUM(a.TOKEN_CREDITS) AS total_ai_function_credits,
    COUNT(*) AS total_calls
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY a
JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON a.USER_ID = u.USER_ID
WHERE u.NAME IN ('DEMO_TIER1_USER', 'DEMO_TIER2_USER', 'DEMO_TIER3_USER', 'DEMO_NOEMAIL_USER')
  AND a.USAGE_TIME >= DATEADD(hour, -24, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY 1;

-- Daily usage trend per user (last 7 days)
SELECT 
    u.NAME AS user_name,
    DATE(a.USAGE_TIME) AS usage_date,
    SUM(a.TOKEN_CREDITS) AS daily_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY a
JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON a.USER_ID = u.USER_ID
WHERE u.NAME IN ('DEMO_TIER1_USER', 'DEMO_TIER2_USER', 'DEMO_TIER3_USER', 'DEMO_NOEMAIL_USER')
  AND a.USAGE_TIME >= DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY 1, 2;

-- ═══════════════════════════════════════════════════════════════
-- 7. TIER MOVEMENT — Upgrade/Downgrade a user
-- ═══════════════════════════════════════════════════════════════

-- Example: Upgrade DEMO_TIER1_USER to TIER_2 (unblocks if blocked)
-- ALTER USER DEMO_TIER1_USER SET TAG COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER = 'TIER_2';

-- Example: Exempt a user from all quotas
-- ALTER USER DEMO_TIER1_USER SET TAG COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER = 'EXEMPT';

-- Example: Remove tag entirely (also exempts)
-- ALTER USER DEMO_TIER1_USER UNSET TAG COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER;

-- ═══════════════════════════════════════════════════════════════
-- 8. VERIFY TAG ASSIGNMENTS (real-time spot check)
-- SYSTEM$GET_TAG is real-time but requires literal user names.
-- TAG_REFERENCES view has ~2 hour lag.
-- ═══════════════════════════════════════════════════════════════

-- Spot check demo users
SELECT SYSTEM$GET_TAG('COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER', 'DEMO_TIER1_USER', 'USER') AS tier1_tag;
SELECT SYSTEM$GET_TAG('COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER', 'DEMO_TIER2_USER', 'USER') AS tier2_tag;
SELECT SYSTEM$GET_TAG('COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER', 'DEMO_TIER3_USER', 'USER') AS tier3_tag;
SELECT SYSTEM$GET_TAG('COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER', 'DEMO_NOEMAIL_USER', 'USER') AS noemail_tag;

-- Spot check auto-tagged users (add any user name to verify)
SELECT SYSTEM$GET_TAG('COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER', 'ALICE', 'USER') AS alice_tag;
SELECT SYSTEM$GET_TAG('COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER', 'BOB', 'USER') AS bob_tag;

-- Verify exempt user is NOT tagged (should return NULL)
SELECT SYSTEM$GET_TAG('COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER', 'YOUR_ADMIN_USER', 'USER') AS admin_tag;

-- Bulk check via TAG_REFERENCES (has ~2 hour lag)
SELECT OBJECT_NAME AS USER_NAME, TAG_VALUE
FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES
WHERE TAG_NAME = 'AI_COST_TIER'
  AND DOMAIN = 'USER'
ORDER BY TAG_VALUE, OBJECT_NAME;

-- Check execution log for last tagging run
SELECT * FROM COST_MGMT_DB.QUOTA_SCHEMA.PROCEDURE_EXECUTION_LOG ORDER BY EXECUTION_TIMESTAMP DESC LIMIT 5;

-- ═══════════════════════════════════════════════════════════════
-- 9. SNOWSIGHT MONITORING PATH
-- ═══════════════════════════════════════════════════════════════
-- Navigate to: Admin → Cost Management → Quotas
-- Each quota shows: usage graph, notification history, active blocks
-- Users can see their own quota status at: Profile → Quota Status
