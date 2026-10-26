# Version History

## v1.0.1 — August 2026

### Username Double-Quote Fix (01-setup.sql, streamlit_app_sidebar.py)

**Problem:** The `TAG_NEW_USERS` procedure and Streamlit app failed when usernames contained special characters (spaces, `@`, dots) because `ALTER USER` and other DDL statements treated unquoted names as invalid identifiers.

**Fix:** All dynamic SQL that references usernames now wraps them in double quotes:

```sql
-- Before (broke on "john.doe@company.com" or "First Last")
EXECUTE IMMEDIATE 'ALTER USER ' || user_rec.NAME || ' SET TAG ...';

-- After
EXECUTE IMMEDIATE 'ALTER USER "' || user_rec.NAME || '" SET TAG ...';
```

Applied in:
- `01-setup.sql` — `TAG_NEW_USERS` procedure (`ALTER USER`, `SET TAG`)
- `streamlit_app_sidebar.py` — all `ALTER USER` calls in Tag Management, Exempt Users, and Tier Lookup pages

---

### Remove Threshold Cycle Selector (streamlit_app_sidebar.py)

**Problem:** The Remove Threshold form only passed two arguments to `REMOVE_NOTIFICATION_THRESHOLD(pct, strategy)`, which defaults to removing the **MONTHLY** threshold. Admins had no way to remove a DAILY threshold from the UI.

**Fix:** Added a **Cycle** selector (`DAILY` / `MONTHLY`) to the Remove Threshold form and now passes it as the 3rd parameter:

```sql
-- Before (always removed MONTHLY)
CALL quota!REMOVE_NOTIFICATION_THRESHOLD(50, 'ACTUAL');

-- After (admin chooses which cycle to remove)
CALL quota!REMOVE_NOTIFICATION_THRESHOLD(50, 'ACTUAL', 'DAILY');
```

This aligns with the GA API signature: `REMOVE_NOTIFICATION_THRESHOLD(pct, strategy [, cycle])`.

---

### Per-User Usage Page Removed (streamlit_app_sidebar.py, 01-setup.sql)

**Reason:** The per-user cost calculations are being reworked as a separate effort. The underlying API (`GET_PER_USER_USAGE_PREVIEW`) was also removed at GA and needs to be replaced with `GET_SPENDING_DETAILS_BY_USERS()`.

**Changes:**
- `streamlit_app_sidebar.py` — Removed "Per-User Usage" from navigation, Page Guide, and page body
- `01-setup.sql` — Commented out `QUOTA_USAGE_CACHE` table, `REFRESH_USAGE_CACHE()` procedure, `REFRESH_USAGE_CACHE_TASK` task, and seed call

These will be re-introduced in a future version using the GA API.
