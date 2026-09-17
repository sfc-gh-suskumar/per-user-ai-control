# Deployment Instructions — AI Quota Admin App

## Prerequisites

- `QUOTA_ADMIN` role configured with all privileges (from `01-setup.sql` Section A)
- Database and schema exist: `COST_MGMT_DB.QUOTA_SCHEMA`
- All quota objects from `01-setup.sql` and `02-create-quota.sql` are deployed
- The `QUOTA_USAGE_CACHE` table and `REFRESH_USAGE_CACHE_TASK` task are created and running (from `01-setup.sql` Section C7/C8)
- Run `CALL REFRESH_USAGE_CACHE()` once after initial setup to seed the cache

## RBAC Note

**Deploy this app using the QUOTA_ADMIN role.** Since QUOTA_ADMIN owns all quota objects (tag, tables, procedure, quotas), the Streamlit app — when created by QUOTA_ADMIN — inherits full access. No additional privilege grants are needed.

## Architecture

The app reads per-user usage data from the `QUOTA_USAGE_CACHE` table (not from live quota calls), ensuring instant page loads. A background task (`REFRESH_USAGE_CACHE_TASK`) refreshes this cache on a configurable schedule (default: every 1 hour). See `architecture.svg` for the full flow diagram.

## Deploy via Snowsight UI

### Step 1: Switch to QUOTA_ADMIN Role

1. Log in to Snowsight
2. Click your profile (bottom-left) → **Switch Role** → select `QUOTA_ADMIN`

### Step 2: Create the Streamlit App

1. Navigate to **Projects > Streamlit**
2. Click **+ Streamlit App**
3. Configure:
   - **App name**: `QUOTA_ADMIN_APP`
   - **Database**: `COST_MGMT_DB`
   - **Schema**: `QUOTA_SCHEMA`
   - **Warehouse**: `XSMALL_WH`
4. Click **Create**

### Step 3: Upload App Code

1. In the Streamlit editor, replace the default code with the contents of `streamlit_app_sidebar.py`
2. Click **Run** to verify it loads without errors

### Step 4: Upload Static Files (Fonts)

1. In the Streamlit editor, click the **Packages & Files** panel (left sidebar)
2. Under **Stage files**, upload:
   - `.streamlit/config.toml` → upload to `.streamlit/` directory
   - All `.ttf` files from `static/` → upload to `static/` directory

The font files are:
- `Inter-Regular.ttf`
- `Inter-Medium.ttf`
- `Inter-SemiBold.ttf`
- `Inter-Bold.ttf`
- `JetBrainsMono-Regular.ttf`
- `JetBrainsMono-Medium.ttf`

### Step 5: Grant Access to Other Roles (Optional)

If other roles need to view the app:

```sql
-- Grant usage to other roles (run as QUOTA_ADMIN since it owns the app)
GRANT USAGE ON STREAMLIT COST_MGMT_DB.QUOTA_SCHEMA.QUOTA_ADMIN_APP TO ROLE ACCOUNTADMIN;
```

### Step 6: Verify

1. Ensure active role is `QUOTA_ADMIN`
2. Navigate to **Projects > Streamlit**
3. Open `QUOTA_ADMIN_APP`
4. Verify all pages load correctly:
   - Quota Management shows config (limits, thresholds, block enforcement)
   - Tag Management shows tagged users and Tier Change form
   - Block Status shows active blocks with Update Tier option
   - Tier Lookup performs real-time tag check
   - Exempt Users manages exemption list
   - Untagged Users lists users without tags
   - Per-User Usage shows top 20 users by credit spend
   - Execution Log shows procedure run history
   - Audit Log shows write operation history

## Why QUOTA_ADMIN Must Deploy

The Streamlit app runs with the **owner role** (the role that created it). Since QUOTA_ADMIN owns:
- All quota objects (`TIER1_QUOTA`, `TIER2_QUOTA`, `TIER3_QUOTA`)
- The tag (`AI_COST_TIER`)
- All tables (`EXEMPT_USERS`, `PROCEDURE_EXECUTION_LOG`, `QUOTA_USAGE_CACHE`, `ADMIN_AUDIT_LOG`)
- The procedures (`TAG_NEW_USERS`, `REFRESH_USAGE_CACHE`)
- The tasks (`DAILY_TAG_NEW_USERS`, `REFRESH_USAGE_CACHE_TASK`)

...the app has full access to call quota methods, query tables, and manage tags without any additional grants.

If you deploy as ACCOUNTADMIN instead, quota methods will fail because ACCOUNTADMIN is not the owner of the quota objects.

## Updating the App

To update after code changes:
1. Open the Streamlit app in Snowsight editor (as QUOTA_ADMIN)
2. Replace the code with the updated `streamlit_app_sidebar.py`
3. Click **Run** to verify
4. Changes are live immediately — no redeploy needed

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Unknown function TIER1_QUOTA!GET_CONFIG" | App not deployed as QUOTA_ADMIN. Redeploy using QUOTA_ADMIN role |
| "No active session" error | App must be deployed in Snowsight, not run locally |
| "Unsupported statement type USE" | Remove any `USE ROLE/SCHEMA` calls from the app code |
| TAG_REFERENCES shows stale data | Normal — up to ~2 hour lag. Use spot-check buttons |
| Usage data not showing | Run `CALL REFRESH_USAGE_CACHE()` to seed the cache. Verify the task is running: `SHOW TASKS LIKE 'REFRESH_USAGE_CACHE_TASK' IN SCHEMA COST_MGMT_DB.QUOTA_SCHEMA;` |
| Fonts not loading | Verify `static/*.ttf` files uploaded and `config.toml` has `enableStaticServing = true` |

## Configuring the Refresh Schedule

The usage cache refreshes every 1 hour by default. To change:

```sql
-- Example: refresh every 30 minutes
ALTER TASK COST_MGMT_DB.QUOTA_SCHEMA.REFRESH_USAGE_CACHE_TASK
  SET SCHEDULE = '30 MINUTE';
```
