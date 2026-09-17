-- ============================================================
-- Per-User AI Quotas — Create Tiered Quotas (Demo)
-- ============================================================
-- Three tiers with NOTIFY + BLOCK enforcement:
--   TIER_1: 1 credit/day, 10 credits/month
--   TIER_2: 2 credits/day, 20 credits/month
--   TIER_3: 3 credits/day, 30 credits/month
--
-- Notifications: 50%, 80%, 100% ACTUAL for both daily and monthly
-- Block: Enabled — user blocked when daily OR monthly limit exceeded
-- ============================================================

USE ROLE QUOTA_ADMIN;
USE SCHEMA COST_MGMT_DB.QUOTA_SCHEMA;

-- ═══════════════════════════════════════════════════════════════
-- TIER 1 — 1 credit/day, 10 credits/month
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE SNOWFLAKE.CORE.QUOTA tier1_quota();

-- Target: users with tag AI_COST_TIER = 'TIER_1'
CALL tier1_quota!SET_USER_TAGS(
  [
    [(SELECT SYSTEM$REFERENCE('TAG', 'COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER', 'SESSION', 'APPLYBUDGET')), 'TIER_1']
  ],
  'UNION'
);

-- All AI services covered
CALL tier1_quota!ADD_SHARED_RESOURCE('AI FUNCTION', 'AI_COMPLETE');
CALL tier1_quota!ADD_SHARED_RESOURCE('AI FUNCTION', 'AI_EXTRACT');
CALL tier1_quota!ADD_SHARED_RESOURCE('AI FUNCTION', 'AI_CLASSIFY');
CALL tier1_quota!ADD_SHARED_RESOURCE('AI FUNCTION', 'AI_SENTIMENT');
CALL tier1_quota!ADD_SHARED_RESOURCE('AI FUNCTION');
CALL tier1_quota!ADD_SHARED_RESOURCE('CORTEX AGENT');
CALL tier1_quota!ADD_SHARED_RESOURCE('SNOWFLAKE INTELLIGENCE');
CALL tier1_quota!ADD_SHARED_RESOURCE('CORTEX CODE');

-- Limits
CALL tier1_quota!SET_PER_USER_LIMIT(10);          -- 10 credits/month
CALL tier1_quota!SET_PER_USER_LIMIT(1, 'DAILY');  -- 1 credit/day

-- Notifications (monthly)
CALL tier1_quota!ADD_NOTIFICATION_THRESHOLD(50, 'ACTUAL', TRUE, 'MONTHLY');   -- 50% actual monthly
CALL tier1_quota!ADD_NOTIFICATION_THRESHOLD(80, 'ACTUAL', TRUE, 'MONTHLY');   -- 80% actual monthly
CALL tier1_quota!ADD_NOTIFICATION_THRESHOLD(100, 'ACTUAL', TRUE, 'MONTHLY');  -- 100% actual monthly

-- Notifications (daily)
CALL tier1_quota!ADD_NOTIFICATION_THRESHOLD(50, 'ACTUAL', TRUE, 'DAILY');    -- 50% actual daily
CALL tier1_quota!ADD_NOTIFICATION_THRESHOLD(80, 'ACTUAL', TRUE, 'DAILY');    -- 80% actual daily
CALL tier1_quota!ADD_NOTIFICATION_THRESHOLD(100, 'ACTUAL', TRUE, 'DAILY');   -- 100% actual daily

-- Admin email
CALL tier1_quota!SET_ADMIN_EMAILS('admin@yourcompany.com');

-- Block enforcement — blocks ALL AI services when limit exceeded
CALL tier1_quota!SET_BLOCK_ENFORCEMENT_ENABLED(TRUE);

-- Hourly evaluation
CALL tier1_quota!SET_REFRESH_TIER('TIER_1H');


-- ═══════════════════════════════════════════════════════════════
-- TIER 2 — 2 credits/day, 20 credits/month
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE SNOWFLAKE.CORE.QUOTA tier2_quota();

-- Target: users with tag AI_COST_TIER = 'TIER_2'
CALL tier2_quota!SET_USER_TAGS(
  [
    [(SELECT SYSTEM$REFERENCE('TAG', 'COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER', 'SESSION', 'APPLYBUDGET')), 'TIER_2']
  ],
  'UNION'
);

-- All AI services covered
CALL tier2_quota!ADD_SHARED_RESOURCE('AI FUNCTION', 'AI_COMPLETE');
CALL tier2_quota!ADD_SHARED_RESOURCE('AI FUNCTION', 'AI_EXTRACT');
CALL tier2_quota!ADD_SHARED_RESOURCE('AI FUNCTION', 'AI_CLASSIFY');
CALL tier2_quota!ADD_SHARED_RESOURCE('AI FUNCTION', 'AI_SENTIMENT');
CALL tier2_quota!ADD_SHARED_RESOURCE('AI FUNCTION');
CALL tier2_quota!ADD_SHARED_RESOURCE('CORTEX AGENT');
CALL tier2_quota!ADD_SHARED_RESOURCE('SNOWFLAKE INTELLIGENCE');
CALL tier2_quota!ADD_SHARED_RESOURCE('CORTEX CODE');

-- Limits
CALL tier2_quota!SET_PER_USER_LIMIT(20);          -- 20 credits/month
CALL tier2_quota!SET_PER_USER_LIMIT(2, 'DAILY');  -- 2 credits/day

-- Notifications (monthly)
CALL tier2_quota!ADD_NOTIFICATION_THRESHOLD(50, 'ACTUAL', TRUE, 'MONTHLY');   -- 50% actual monthly
CALL tier2_quota!ADD_NOTIFICATION_THRESHOLD(80, 'ACTUAL', TRUE, 'MONTHLY');   -- 80% actual monthly
CALL tier2_quota!ADD_NOTIFICATION_THRESHOLD(100, 'ACTUAL', TRUE, 'MONTHLY');  -- 100% actual monthly

-- Notifications (daily)
CALL tier2_quota!ADD_NOTIFICATION_THRESHOLD(50, 'ACTUAL', TRUE, 'DAILY');    -- 50% actual daily
CALL tier2_quota!ADD_NOTIFICATION_THRESHOLD(80, 'ACTUAL', TRUE, 'DAILY');    -- 80% actual daily
CALL tier2_quota!ADD_NOTIFICATION_THRESHOLD(100, 'ACTUAL', TRUE, 'DAILY');   -- 100% actual daily

-- Admin email
CALL tier2_quota!SET_ADMIN_EMAILS('admin@yourcompany.com');

-- Block enforcement
CALL tier2_quota!SET_BLOCK_ENFORCEMENT_ENABLED(TRUE);

-- Hourly evaluation
CALL tier2_quota!SET_REFRESH_TIER('TIER_1H');


-- ═══════════════════════════════════════════════════════════════
-- TIER 3 — 3 credits/day, 30 credits/month
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE SNOWFLAKE.CORE.QUOTA tier3_quota();

-- Target: users with tag AI_COST_TIER = 'TIER_3'
CALL tier3_quota!SET_USER_TAGS(
  [
    [(SELECT SYSTEM$REFERENCE('TAG', 'COST_MGMT_DB.QUOTA_SCHEMA.AI_COST_TIER', 'SESSION', 'APPLYBUDGET')), 'TIER_3']
  ],
  'UNION'
);

-- All AI services covered
CALL tier3_quota!ADD_SHARED_RESOURCE('AI FUNCTION', 'AI_COMPLETE');
CALL tier3_quota!ADD_SHARED_RESOURCE('AI FUNCTION', 'AI_EXTRACT');
CALL tier3_quota!ADD_SHARED_RESOURCE('AI FUNCTION', 'AI_CLASSIFY');
CALL tier3_quota!ADD_SHARED_RESOURCE('AI FUNCTION', 'AI_SENTIMENT');
CALL tier3_quota!ADD_SHARED_RESOURCE('AI FUNCTION');
CALL tier3_quota!ADD_SHARED_RESOURCE('CORTEX AGENT');
CALL tier3_quota!ADD_SHARED_RESOURCE('SNOWFLAKE INTELLIGENCE');
CALL tier3_quota!ADD_SHARED_RESOURCE('CORTEX CODE');

-- Limits
CALL tier3_quota!SET_PER_USER_LIMIT(30);          -- 30 credits/month
CALL tier3_quota!SET_PER_USER_LIMIT(3, 'DAILY');  -- 3 credits/day

-- Notifications (monthly)
CALL tier3_quota!ADD_NOTIFICATION_THRESHOLD(50, 'ACTUAL', TRUE, 'MONTHLY');   -- 50% actual monthly
CALL tier3_quota!ADD_NOTIFICATION_THRESHOLD(80, 'ACTUAL', TRUE, 'MONTHLY');   -- 80% actual monthly
CALL tier3_quota!ADD_NOTIFICATION_THRESHOLD(100, 'ACTUAL', TRUE, 'MONTHLY');  -- 100% actual monthly

-- Notifications (daily)
CALL tier3_quota!ADD_NOTIFICATION_THRESHOLD(50, 'ACTUAL', TRUE, 'DAILY');    -- 50% actual daily
CALL tier3_quota!ADD_NOTIFICATION_THRESHOLD(80, 'ACTUAL', TRUE, 'DAILY');    -- 80% actual daily
CALL tier3_quota!ADD_NOTIFICATION_THRESHOLD(100, 'ACTUAL', TRUE, 'DAILY');   -- 100% actual daily

-- Admin email
CALL tier3_quota!SET_ADMIN_EMAILS('admin@yourcompany.com');

-- Block enforcement
CALL tier3_quota!SET_BLOCK_ENFORCEMENT_ENABLED(TRUE);

-- Hourly evaluation
CALL tier3_quota!SET_REFRESH_TIER('TIER_1H');


-- ═══════════════════════════════════════════════════════════════
-- VERIFY ALL QUOTAS
-- ═══════════════════════════════════════════════════════════════

-- Check configuration
CALL tier1_quota!GET_CONFIG();
CALL tier2_quota!GET_CONFIG();
CALL tier3_quota!GET_CONFIG();

-- Check user scope (should show tag-based targeting, not ALL_USERS)
CALL tier1_quota!GET_QUOTA_SCOPE();
CALL tier2_quota!GET_QUOTA_SCOPE();
CALL tier3_quota!GET_QUOTA_SCOPE();

-- Check which users are in each quota
CALL tier1_quota!GET_USERS();
CALL tier2_quota!GET_USERS();
CALL tier3_quota!GET_USERS();