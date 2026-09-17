-- ============================================================
-- Per-User AI Quotas — Generate Usage (Demo)
-- ============================================================
-- IMPORTANT: EXECUTE AS USER does NOT attribute AI credits to
-- the impersonated user. You must log in as each demo user
-- directly (separate Snowsight tab or SnowSQL session).
--
-- Login credentials:
--   DEMO_TIER1_USER / DemoTier1_2026!
--   DEMO_TIER2_USER / DemoTier2_2026!
--   DEMO_TIER3_USER / DemoTier3_2026!
--   DEMO_NOEMAIL_USER / DemoNoEmail_2026!  (no email — notifications go to admin only)
--
-- Quota limits:
--   TIER 1: 1 credit/day,  10 credits/month → BLOCK at limit
--   TIER 2: 2 credits/day, 20 credits/month → BLOCK at limit
--   TIER 3: 3 credits/day, 30 credits/month → BLOCK at limit
--
-- After ~2 hours, usage appears in ACCOUNT_USAGE views.
-- After ~1 hour more, quota evaluation runs (TIER_1H).
-- ============================================================


-- ═══════════════════════════════════════════════════════════════
-- RUN AS DEMO_TIER1_USER (separate session)
-- ═══════════════════════════════════════════════════════════════
-- Log in: snowsql -a <account> -u DEMO_TIER1_USER
-- Or open a new Snowsight tab → sign in as DEMO_TIER1_USER
-- Password: DemoTier1_2026!
--
-- Goal: Generate enough usage to approach/exceed 1 credit daily limit
-- to demonstrate BLOCK enforcement

USE WAREHOUSE XSMALL_WH;

-- AI_COMPLETE usage (~0.01-0.02 credits per call with large model)
SELECT AI_COMPLETE('mistral-large2', 'Summarize Q2 2024 portfolio performance for fixed income.');
SELECT AI_COMPLETE('mistral-large2', 'Draft compliance report for SEC filing requirements.');
SELECT AI_COMPLETE('mistral-large2', 'Analyze risk factor: ' || SEQ4()::VARCHAR)
FROM TABLE(GENERATOR(ROWCOUNT => 20));

-- AI_EXTRACT usage (~0.001 credits per call)
SELECT AI_EXTRACT(
  'Invoice #' || SEQ4()::VARCHAR || ': Vendor Acme Corp, Amount $125,000, Due 2025-06-15, Fund: FUND-2024-EQ',
  ['vendor', 'amount', 'due_date', 'fund']
)
FROM TABLE(GENERATOR(ROWCOUNT => 100));

-- AI_CLASSIFY usage (~0.0003 credits per call)
SELECT AI_CLASSIFY(
  'Inquiry #' || SEQ4()::VARCHAR || ': Client wants to rebalance portfolio toward ESG funds',
  ['Portfolio Management', 'New Investment', 'Withdrawal', 'Compliance']
)
FROM TABLE(GENERATOR(ROWCOUNT => 200));

-- AI_SENTIMENT usage (~0.0002 credits per call)
SELECT AI_SENTIMENT('Client feedback #' || SEQ4()::VARCHAR || ': Very satisfied with the quarterly returns.')
FROM TABLE(GENERATOR(ROWCOUNT => 200));

-- CORTEX AGENT / COWORK / COCO:
--   Open Snowsight → CoCo right panel → ask questions
--   e.g., "What is the total revenue?"
--   Or open CoWork and ask analytical questions


-- ═══════════════════════════════════════════════════════════════
-- RUN AS DEMO_TIER2_USER (separate session)
-- ═══════════════════════════════════════════════════════════════
-- Log in: snowsql -a <account> -u DEMO_TIER2_USER
-- Or open a new Snowsight tab → sign in as DEMO_TIER2_USER
-- Password: DemoTier2_2026!
--
-- Goal: Generate moderate usage within 2 credit daily limit

USE WAREHOUSE XSMALL_WH;

-- AI_COMPLETE usage
SELECT AI_COMPLETE('mistral-large2', 'Explain the impact of rising rates on bond portfolios.');
SELECT AI_COMPLETE('mistral-large2', 'Draft a market outlook for emerging markets Q3 2025.');
SELECT AI_COMPLETE('mistral-large2', 'Generate investment thesis: ' || SEQ4()::VARCHAR)
FROM TABLE(GENERATOR(ROWCOUNT => 30));

-- AI_EXTRACT usage
SELECT AI_EXTRACT(
  'Trade #' || SEQ4()::VARCHAR || ': Buy 10,000 shares AAPL at $185.50, Account: INST-4421, Broker: GS',
  ['action', 'quantity', 'ticker', 'price', 'account', 'broker']
)
FROM TABLE(GENERATOR(ROWCOUNT => 150));

-- AI_CLASSIFY usage
SELECT AI_CLASSIFY(
  'Document #' || SEQ4()::VARCHAR || ': Annual financial statement with auditor notes',
  ['Regulatory Filing', 'Client Report', 'Internal Memo', 'Research Note']
)
FROM TABLE(GENERATOR(ROWCOUNT => 300));

-- AI_SENTIMENT usage
SELECT AI_SENTIMENT('Analyst note #' || SEQ4()::VARCHAR || ': Strong buy signal despite market volatility.')
FROM TABLE(GENERATOR(ROWCOUNT => 300));


-- ═══════════════════════════════════════════════════════════════
-- RUN AS DEMO_TIER3_USER (separate session)
-- ═══════════════════════════════════════════════════════════════
-- Log in: snowsql -a <account> -u DEMO_TIER3_USER
-- Or open a new Snowsight tab → sign in as DEMO_TIER3_USER
-- Password: DemoTier3_2026!
--
-- Goal: Generate higher usage within 3 credit daily limit

USE WAREHOUSE XSMALL_WH;

-- AI_COMPLETE usage (heavier usage — power user)
SELECT AI_COMPLETE('mistral-large2', 'Create a comprehensive risk model for multi-asset portfolio.');
SELECT AI_COMPLETE('mistral-large2', 'Analyze macro trends affecting global equities in 2025.');
SELECT AI_COMPLETE('mistral-large2', 'Generate deep analysis item: ' || SEQ4()::VARCHAR)
FROM TABLE(GENERATOR(ROWCOUNT => 50));

-- AI_EXTRACT usage
SELECT AI_EXTRACT(
  'Contract #' || SEQ4()::VARCHAR || ': Counterparty JP Morgan, Notional $50M, Maturity 2027-12-31, Type: IRS',
  ['counterparty', 'notional', 'maturity', 'type']
)
FROM TABLE(GENERATOR(ROWCOUNT => 200));

-- AI_CLASSIFY usage
SELECT AI_CLASSIFY(
  'Alert #' || SEQ4()::VARCHAR || ': Unusual trading volume detected in derivatives book',
  ['Market Risk', 'Operational Risk', 'Compliance', 'Fraud Detection']
)
FROM TABLE(GENERATOR(ROWCOUNT => 500));

-- AI_SENTIMENT usage
SELECT AI_SENTIMENT('Market commentary #' || SEQ4()::VARCHAR || ': Bearish outlook persists amid rate uncertainty.')
FROM TABLE(GENERATOR(ROWCOUNT => 500));


-- ═══════════════════════════════════════════════════════════════
-- RUN AS DEMO_NOEMAIL_USER (separate session)
-- ═══════════════════════════════════════════════════════════════
-- Log in: snowsql -a <account> -u DEMO_NOEMAIL_USER
-- Or open a new Snowsight tab → sign in as DEMO_NOEMAIL_USER
-- Password: DemoNoEmail_2026!
--
-- This user has NO EMAIL configured.
-- Notifications will only go to the admin email (admin@yourcompany.com).
-- Tagged as TIER_1 → same limits as DEMO_TIER1_USER (1 credit/day, 10/month)

USE WAREHOUSE XSMALL_WH;

-- AI_COMPLETE usage
SELECT AI_COMPLETE('mistral-large2', 'Summarize compliance requirements for FINRA Rule 4512.');
SELECT AI_COMPLETE('mistral-large2', 'Draft client onboarding checklist for institutional accounts.');
SELECT AI_COMPLETE('mistral-large2', 'Analyze regulatory scenario: ' || SEQ4()::VARCHAR)
FROM TABLE(GENERATOR(ROWCOUNT => 20));

-- AI_EXTRACT usage
SELECT AI_EXTRACT(
  'Statement #' || SEQ4()::VARCHAR || ': Account INST-9901, Balance $2.4M, YTD Return 8.3%, Advisor: Smith',
  ['account', 'balance', 'ytd_return', 'advisor']
)
FROM TABLE(GENERATOR(ROWCOUNT => 100));

-- AI_CLASSIFY usage
SELECT AI_CLASSIFY(
  'Request #' || SEQ4()::VARCHAR || ': Transfer $50,000 from money market to equity fund',
  ['Fund Transfer', 'Account Inquiry', 'New Account', 'Complaint']
)
FROM TABLE(GENERATOR(ROWCOUNT => 200));

-- AI_SENTIMENT usage
SELECT AI_SENTIMENT('Service review #' || SEQ4()::VARCHAR || ': Advisor was responsive but fees seem high.')
FROM TABLE(GENERATOR(ROWCOUNT => 200));


-- ═══════════════════════════════════════════════════════════════
-- CORTEX AGENT / COWORK / COCO (Manual — all users)
-- ═══════════════════════════════════════════════════════════════
-- For each demo user, log in to Snowsight and:
--
-- CORTEX AGENT:
--   Open CoCo right panel → select an available agent
--   Ask: "What is the total revenue?"
--   Ask: "Show me top customers by transaction volume."
--
-- SNOWFLAKE COWORK (Intelligence):
--   Click CoWork icon → ask questions about your data
--   e.g., "Show me top performers this quarter"
--
-- CORTEX CODE (CoCo):
--   Open CoCo assistant in Snowsight
--   Ask: "Write a query to find duplicate records"
--   Ask: "Explain this table's schema"
--
-- All services are tracked under the user's tier quota.


-- ═══════════════════════════════════════════════════════════════
-- VERIFY USAGE (run as ACCOUNTADMIN, after 2+ hours)
-- ═══════════════════════════════════════════════════════════════

USE ROLE ACCOUNTADMIN;

-- AI Functions usage by user
SELECT 
    u.NAME AS user_name,
    a.FUNCTION_NAME AS ai_function,
    SUM(a.TOKEN_CREDITS) AS credits,
    COUNT(*) AS calls
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY a
JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON a.USER_ID = u.USER_ID
WHERE u.NAME IN ('DEMO_TIER1_USER', 'DEMO_TIER2_USER', 'DEMO_TIER3_USER', 'DEMO_NOEMAIL_USER')
  AND a.USAGE_TIME >= DATEADD(hour, -24, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY user_name, credits DESC;

-- Cortex Agent usage
SELECT 
    USER_NAME,
    AGENT_NAME,
    SUM(TOKEN_CREDITS) AS credits,
    COUNT(*) AS calls
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
WHERE USER_NAME IN ('DEMO_TIER1_USER', 'DEMO_TIER2_USER', 'DEMO_TIER3_USER', 'DEMO_NOEMAIL_USER')
  AND START_TIME >= DATEADD(hour, -24, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY USER_NAME;

-- CoCo usage (Desktop + Snowsight)
SELECT 
    USER_NAME,
    'CORTEX_CODE_DESKTOP' AS service,
    SUM(TOKEN_CREDITS) AS credits,
    COUNT(*) AS calls
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_DESKTOP_USAGE_HISTORY
WHERE USER_NAME IN ('DEMO_TIER1_USER', 'DEMO_TIER2_USER', 'DEMO_TIER3_USER', 'DEMO_NOEMAIL_USER')
  AND USAGE_TIME >= DATEADD(hour, -24, CURRENT_TIMESTAMP())
GROUP BY 1, 2

UNION ALL

SELECT 
    USER_NAME,
    'CORTEX_CODE_SNOWSIGHT' AS service,
    SUM(TOKEN_CREDITS) AS credits,
    COUNT(*) AS calls
FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY
WHERE USER_NAME IN ('DEMO_TIER1_USER', 'DEMO_TIER2_USER', 'DEMO_TIER3_USER', 'DEMO_NOEMAIL_USER')
  AND USAGE_TIME >= DATEADD(hour, -24, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY USER_NAME, service;

-- CoWork (Snowflake Intelligence) usage
SELECT 
    USER_NAME,
    SUM(TOKEN_CREDITS) AS credits,
    COUNT(*) AS calls
FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY
WHERE USER_NAME IN ('DEMO_TIER1_USER', 'DEMO_TIER2_USER', 'DEMO_TIER3_USER', 'DEMO_NOEMAIL_USER')
  AND START_TIME >= DATEADD(hour, -24, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY USER_NAME;

-- Total credits per user (all AI services combined)
SELECT 
    user_name,
    SUM(credits) AS total_credits
FROM (
    SELECT u.NAME AS user_name, SUM(a.TOKEN_CREDITS) AS credits
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AISQL_USAGE_HISTORY a
    JOIN SNOWFLAKE.ACCOUNT_USAGE.USERS u ON a.USER_ID = u.USER_ID
    WHERE u.NAME IN ('DEMO_TIER1_USER', 'DEMO_TIER2_USER', 'DEMO_TIER3_USER', 'DEMO_NOEMAIL_USER')
      AND a.USAGE_TIME >= DATEADD(hour, -24, CURRENT_TIMESTAMP())
    GROUP BY 1
    
    UNION ALL
    
    SELECT USER_NAME, SUM(TOKEN_CREDITS)
    FROM SNOWFLAKE.ACCOUNT_USAGE.CORTEX_AGENT_USAGE_HISTORY
    WHERE USER_NAME IN ('DEMO_TIER1_USER', 'DEMO_TIER2_USER', 'DEMO_TIER3_USER', 'DEMO_NOEMAIL_USER')
      AND START_TIME >= DATEADD(hour, -24, CURRENT_TIMESTAMP())
    GROUP BY 1
    
    UNION ALL
    
    SELECT USER_NAME, SUM(TOKEN_CREDITS)
    FROM SNOWFLAKE.ACCOUNT_USAGE.SNOWFLAKE_INTELLIGENCE_USAGE_HISTORY
    WHERE USER_NAME IN ('DEMO_TIER1_USER', 'DEMO_TIER2_USER', 'DEMO_TIER3_USER', 'DEMO_NOEMAIL_USER')
      AND START_TIME >= DATEADD(hour, -24, CURRENT_TIMESTAMP())
    GROUP BY 1
) combined
GROUP BY 1
ORDER BY 1;
