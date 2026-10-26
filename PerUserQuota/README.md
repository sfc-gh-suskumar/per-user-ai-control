# Per-User AI Cost Control & Guardrails

Per-user spending quotas for Snowflake AI Services with tiered limits, automatic blocking, daily/monthly notifications, and a Streamlit admin app.

> Per-User Quotas is a **Generally Available (GA)** feature in Snowflake.

---

## Quick Start — Deployment Order

| Step | File | Run As | Purpose |
|------|------|--------|---------|
| 1 | `01-setup.sql` | SECURITYADMIN → SYSADMIN → ACCOUNTADMIN → QUOTA_ADMIN | Creates role, grants, database, schema, tables, procedures, tasks |
| 2 | `02-create-quota.sql` | QUOTA_ADMIN | Creates the 3 quota objects with limits, notifications, block enforcement |
| 3 | Deploy Streamlit app | QUOTA_ADMIN | See `quota-admin-app/deployment-instructions.md` |

These two SQL files (`01-setup.sql` and `02-create-quota.sql`) are the **primary deployment artifacts**. Everything else is supplementary.

---

## File Reference

### SQL Scripts

| File | Purpose |
|------|---------|
| `01-setup.sql` | **Main setup** — Creates QUOTA_ADMIN and AI_USERS roles, grants all privileges, creates database/schema, tables (EXEMPT_USERS, PROCEDURE_EXECUTION_LOG, ADMIN_AUDIT_LOG, QUOTA_USAGE_CACHE), procedures (TAG_NEW_USERS, REFRESH_USAGE_CACHE), scheduled tasks, and the AI_COST_TIER tag. |
| `02-create-quota.sql` | **Quota creation** — Creates TIER1_QUOTA, TIER2_QUOTA, TIER3_QUOTA with per-user limits, notification thresholds (50%/80%/100% daily & monthly), block enforcement, and admin email. |
| `03-generate-usage.sql` | Helper script to generate test AI usage as demo users (for validating quota enforcement). |
| `04-monitor-verify.sql` | Monitoring queries — check active blocks, usage, notification thresholds, enforcement history. |
| `05-cleanup.sql` | Tear-down script — suspends tasks, drops all objects. Use to reset the environment. |

### Streamlit Admin App (`quota-admin-app/`)

| File | Purpose |
|------|---------|
| `streamlit_app_sidebar.py` | **Primary app file** — deploy this to Streamlit-in-Snowflake |
| `deployment-instructions.md` | Step-by-step guide to deploy the app in Snowsight |
| `.streamlit/config.toml` | Streamlit configuration (static serving enabled) |
| `static/*.ttf` | Inter & JetBrains Mono font files for UI |

### Documentation

| File | Purpose |
|------|---------|
| `SUMMARY.md` | Full solution design — tier structure, limits, enforcement, notifications, constraints |
| `TEST-RESULTS.md` | Test evidence — block enforcement, email delivery, tier upgrade unblock, in-progress kill |
| `action_items_v1.0.md` | Customer Q&A — answers to common questions with test results |
| `architecture.svg` | Architecture diagram — app → cache → tasks → quotas → users |

---

## Architecture

```
┌─────────────────────────────────────────────┐
│         Streamlit Admin App                  │
│  (Quota Mgmt | Tag Mgmt | Block Status |    │
│   Tier Lookup | Per-User Usage | Audit Log) │
└──────────────────────┬──────────────────────┘
                       │ reads (instant)
                       ▼
         ┌─────────────────────────┐
         │   QUOTA_USAGE_CACHE     │
         │  (pre-computed usage)   │
         └─────────────┬───────────┘
                       │ refreshed hourly
                       ▼
         ┌─────────────────────────┐
         │  REFRESH_USAGE_CACHE    │◄── Scheduled Task (60 min)
         │  TAG_NEW_USERS          │◄── Scheduled Task (daily 2 PM ET)
         └─────────────┬───────────┘
                       │ calls quota methods
                       ▼
    ┌──────────┬──────────────┬──────────────┐
    │TIER1_QUOTA│ TIER2_QUOTA  │ TIER3_QUOTA  │
    │ 1cr/day  │  2cr/day     │  3cr/day     │
    │ 10cr/mo  │  20cr/mo     │  30cr/mo     │
    └────┬─────┴──────┬───────┴──────┬───────┘
         │            │              │
         ▼            ▼              ▼
    Users tagged    Users tagged    Users tagged
    TIER_1          TIER_2          TIER_3
```

---

## App Pages

| Page | Functionality |
|------|--------------|
| **Quota Management** | View/edit daily & monthly limits, notification thresholds, and block enforcement per quota |
| **Tag Management** | View tier assignments and move users between tiers |
| **Block Status** | See blocked users and perform tier upgrades to unblock |
| **Tier Lookup** | Real-time tier lookup for any individual user |
| **Exempt Users** | Manage the exemption list (users excluded from enforcement) |
| **Untagged Users** | Find users without a tier tag and bulk-assign to TIER_1 |
| **Per-User Usage** | Top 20 users by credit spend and per-user service breakdown |
| **Execution Log** | Automated procedure run history with skipped user details |
| **Audit Log** | All manual write operations with timestamps and ServiceNow tickets |

---

## Key Design Decisions

- **Two roles**: `QUOTA_ADMIN` owns all quota objects (admin); `AI_USERS` grants Cortex AI access to end users (no PUBLIC grants)
- **Tag-based user routing** — `AI_COST_TIER` tag determines which quota applies to each user
- **Usage cache table** — avoids slow quota API calls; refreshed hourly by background task
- **Audit logging** — every write operation in the app is logged with the operator's username and ServiceNow ticket
- **Daily + Monthly notifications** — 50%, 80%, 100% ACTUAL thresholds for both cycles
- **Block enforcement** — automatic blocking when daily OR monthly limit is exceeded

---

## Customizing for Your Environment

In `01-setup.sql` Section A1/A3/A4, replace these values:

| Placeholder | Replace With |
|-------------|-------------|
| `QUOTA_ADMIN` | Your admin role name |
| `AI_USERS` | Your existing role that end users have (for Cortex AI access) |
| `COST_MGMT_DB.QUOTA_SCHEMA` | Your database and schema |
| `XSMALL_WH` | Your warehouse |
| `YOUR_ADMIN_USER` | Your admin username |

In `02-create-quota.sql`, adjust:
- Tier limits (daily/monthly credits)
- Notification thresholds (percentages)
- Admin email address
- Shared resources (AI services to track)
