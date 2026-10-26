import streamlit as st
from snowflake.snowpark.context import get_active_session
import pandas as pd

st.set_page_config(page_title="AI Quota Admin", page_icon="shield", layout="wide")

# --- Connection (Snowsight active session) ---
session = get_active_session()

def run_query(sql):
    """Run SQL and return pandas DataFrame (no cache — for writes and one-off calls)."""
    result = session.sql(sql).collect()
    if result:
        return pd.DataFrame([row.as_dict() for row in result])
    return pd.DataFrame()

@st.cache_data(ttl=60, show_spinner=False)
def cached_query(_session, sql):
    """Cached read query — results persist for 60 seconds across rerenders."""
    result = _session.sql(sql).collect()
    if result:
        return pd.DataFrame([row.as_dict() for row in result])
    return pd.DataFrame()

def friendly_error(e):
    """Convert SQL exceptions to user-friendly messages."""
    msg = str(e)
    if "does not exist or not authorized" in msg:
        if "User" in msg:
            return "User not found. Check the username and try again."
        return "Object not found or you don't have permission to access it."
    if "already exists" in msg:
        return "This entry already exists."
    if "too many arguments" in msg or "not enough arguments" in msg:
        return "Operation failed due to an internal configuration issue. Contact your admin."
    if "Insufficient privileges" in msg:
        return "Insufficient privileges. Ensure the app is running with the QUOTA_ADMIN role."
    return f"Operation failed: {msg.split(':')[-1].strip()}"

def refresh_after_write():
    """Clear cache and rerun so updated data shows immediately."""
    st.cache_data.clear()
    st.rerun()

def get_current_user():
    """Get the logged-in user in SiS (not the app owner)."""
    try:
        return st.user.user_name or "UNKNOWN"
    except Exception:
        try:
            return st.context.user_name or "UNKNOWN"
        except Exception:
            return "UNKNOWN"

def audit_log(operation, details, ticket):
    """Insert an audit entry for a write operation. Non-blocking — errors are silently ignored."""
    try:
        user = get_current_user().replace("'", "''")
        safe_details = (details or "").replace("'", "''")
        safe_ticket = (ticket or "").replace("'", "''")
        session.sql(f"""
            INSERT INTO {DB_SCHEMA}.ADMIN_AUDIT_LOG (PERFORMED_BY, OPERATION, DETAILS, SNOW_TICKET)
            SELECT '{user}', '{operation}', '{safe_details}', '{safe_ticket}'
        """).collect()
    except Exception:
        pass

# --- Constants ---
DB_SCHEMA = "COST_MGMT_DB.QUOTA_SCHEMA"

@st.cache_data(ttl=300)
def get_quota_list():
    """Fetch all SNOWFLAKE.CORE.QUOTA objects in the schema."""
    result = session.sql(f"SHOW SNOWFLAKE.CORE.QUOTA IN SCHEMA {DB_SCHEMA}").collect()
    if result:
        return [row["name"] for row in result]
    return []

QUOTAS = get_quota_list()
TIER_LABELS = {q: q.replace("_", " ").title() for q in QUOTAS}

# --- Sidebar Navigation ---
st.sidebar.title("AI Quota Admin")
st.sidebar.caption("Per-user spending controls")

with st.sidebar.expander("📖 Page Guide", expanded=False):
    st.markdown("""
**Quota Management** — View/edit daily, weekly & monthly limits, notification thresholds, and block enforcement per quota.

**Tag Management** — View tier assignments and move users between tiers (TIER_1 / TIER_2 / TIER_3 / EXEMPT).

**Block Status** — See which users are currently blocked and perform tier upgrades to unblock them.

**Tier Lookup** — Look up the current tier tag for any individual user (real-time, no latency).

**Exempt Users** — Manage the exemption list (users excluded from quota enforcement).

**Untagged Users** — Find users without a tier tag and bulk-assign them to TIER_1.

**Execution Log** — View automated procedure run history (TAG_NEW_USERS, REFRESH_USAGE_CACHE).

**Audit Log** — All manual write operations performed via this app with timestamps and ServiceNow tickets.
""")

PAGES = [
    "Quota Management",
    "Tag Management",
    "Block Status",
    "Tier Lookup",
    "Exempt Users",
    "Untagged Users",
    "Execution Log",
    "Audit Log"
]
page = st.sidebar.radio("Navigate", PAGES, key="nav_page")

if st.sidebar.button("Refresh Data"):
    st.cache_data.clear()
    st.rerun()

st.sidebar.divider()

# --- Custom CSS ---
st.markdown("""
<style>
    [data-testid="stSidebar"] { background-color: #F8F9FB; }
    [data-testid="stSidebar"] [data-testid="stMarkdownContainer"] p { color: #11567F; }
    .stMetric label { color: #11567F !important; font-weight: 600; }
    .stMetric [data-testid="stMetricValue"] { color: #29B5E8; }
    div[data-testid="stDataFrame"] { border: 1px solid #E8EDF3; border-radius: 8px; }
    h1, h2, h3 { color: #11567F; }
    [data-testid="stCaptionContainer"] p { color: #4A5568 !important; font-size: 0.92rem !important; }
</style>
""", unsafe_allow_html=True)


# ═══════════════════════════════════════════════════════════════
# PAGE: Quota Management
# ═══════════════════════════════════════════════════════════════
if page == "Quota Management":
    st.header("Quota Management")
    st.caption("View and set per-user daily/weekly/monthly credit limits and notification thresholds.")

    selected_quota = st.selectbox("Select Quota", QUOTAS, format_func=lambda x: f"{TIER_LABELS[x]} — {x}", key="mgmt_quota")

    if selected_quota:
        quota = selected_quota
        try:
            config = cached_query(session, f"CALL {DB_SCHEMA}.{quota}!GET_CONFIG()")
            if not config.empty:
                col1, col2, col3, col4 = st.columns(4)
                col1.metric("Daily Limit", f"{config['PER_USER_LIMIT_DAILY'].iloc[0]} credits")
                col2.metric("Weekly Limit", f"{config['PER_USER_LIMIT_WEEKLY'].iloc[0]} credits")
                col3.metric("Monthly Limit", f"{config['PER_USER_LIMIT'].iloc[0]} credits")
                block_enabled = config['BLOCK_ENFORCEMENT_ENABLED'].iloc[0]
                col4.metric("Block Enforcement", "Enabled" if block_enabled else "Disabled")
            else:
                st.info("No config found.")
                block_enabled = False
        except Exception as e:
            st.error(f"Error loading config: {e}")
            block_enabled = False

        # Block Enforcement Toggle
        with st.form(f"block_toggle_{quota}", clear_on_submit=True):
            new_block = st.selectbox("Block Enforcement", [True, False], format_func=lambda x: "Enabled" if x else "Disabled", index=0 if block_enabled else 1, key=f"block_{quota}")
            ticket_block = st.text_input("ServiceNow Ticket / Justification", placeholder="e.g. INC0012345", key=f"ticket_block_{quota}")
            block_submitted = st.form_submit_button("Update Block Enforcement", type="primary")
            if block_submitted:
                if not ticket_block or not ticket_block.strip():
                    st.warning("A ServiceNow ticket is required to proceed.")
                else:
                    try:
                        session.sql(f"CALL {DB_SCHEMA}.{quota}!SET_BLOCK_ENFORCEMENT_ENABLED({str(new_block).upper()})").collect()
                        audit_log("UPDATE_BLOCK_ENFORCEMENT", f"Quota={quota}, BlockEnabled={new_block}", ticket_block.strip())
                        refresh_after_write()
                    except Exception as e:
                        st.error(friendly_error(e))

        with st.form(f"set_limits_{quota}", clear_on_submit=True):
            col1, col2, col3 = st.columns(3)
            with col1:
                new_daily = st.number_input("Daily Limit (credits)", min_value=0, value=None, step=1, key=f"daily_{quota}", placeholder="e.g. 5")
            with col2:
                new_weekly = st.number_input("Weekly Limit (credits)", min_value=0, value=None, step=1, key=f"weekly_{quota}", placeholder="e.g. 15")
            with col3:
                new_monthly = st.number_input("Monthly Limit (credits)", min_value=0, value=None, step=1, key=f"monthly_{quota}", placeholder="e.g. 20")
            ticket_limits = st.text_input("ServiceNow Ticket / Justification", placeholder="e.g. INC0012345", key=f"ticket_limits_{quota}")
            submitted = st.form_submit_button("Update Limits", type="primary")
            if submitted:
                if not ticket_limits or not ticket_limits.strip():
                    st.warning("A ServiceNow ticket is required to proceed.")
                elif not new_daily and not new_weekly and not new_monthly:
                    st.warning("Enter at least one limit value greater than 0.")
                else:
                    try:
                        changes = []
                        if new_daily and new_daily > 0:
                            session.sql(f"CALL {DB_SCHEMA}.{quota}!SET_PER_USER_LIMIT({int(new_daily)}, 'DAILY')").collect()
                            changes.append(f"Daily={int(new_daily)}")
                        if new_weekly and new_weekly > 0:
                            session.sql(f"CALL {DB_SCHEMA}.{quota}!SET_PER_USER_LIMIT({int(new_weekly)}, 'WEEKLY')").collect()
                            changes.append(f"Weekly={int(new_weekly)}")
                        if new_monthly and new_monthly > 0:
                            session.sql(f"CALL {DB_SCHEMA}.{quota}!SET_PER_USER_LIMIT({int(new_monthly)})").collect()
                            changes.append(f"Monthly={int(new_monthly)}")
                        if changes:
                            audit_log("UPDATE_LIMITS", f"Quota={quota}, {', '.join(changes)}", ticket_limits.strip())
                            refresh_after_write()
                    except Exception as e:
                        st.error(friendly_error(e))

        st.divider()
        st.markdown("**Notification Thresholds**")
        try:
            thresholds = cached_query(session, f"CALL {DB_SCHEMA}.{quota}!GET_NOTIFICATION_THRESHOLDS()")
            if not thresholds.empty:
                st.dataframe(thresholds, use_container_width=True, hide_index=True)
            else:
                st.caption("No notification thresholds configured.")
        except Exception as e:
            st.error(f"Error loading thresholds: {e}")

        col_add, col_remove = st.columns(2)
        with col_add:
            with st.form(f"add_threshold_{quota}", clear_on_submit=True):
                pct = st.number_input("Threshold %", min_value=1, max_value=100, value=None, step=10, key=f"thr_pct_{quota}", placeholder="e.g. 80")
                thr_strategy = st.selectbox("Strategy", ["ACTUAL", "PROJECTED"], key=f"thr_strategy_{quota}")
                thr_cycle = st.selectbox("Cycle", ["DAILY", "WEEKLY", "MONTHLY"], key=f"thr_cycle_{quota}")
                ticket_add_thr = st.text_input("ServiceNow Ticket / Justification", placeholder="e.g. INC0012345", key=f"ticket_add_thr_{quota}")
                add_thr = st.form_submit_button("Add Threshold", type="primary")
                if add_thr:
                    if not ticket_add_thr or not ticket_add_thr.strip():
                        st.warning("A ServiceNow ticket is required.")
                    elif pct:
                        try:
                            session.sql(f"CALL {DB_SCHEMA}.{quota}!ADD_NOTIFICATION_THRESHOLD({pct}, '{thr_strategy}', TRUE, '{thr_cycle}')").collect()
                            audit_log("ADD_THRESHOLD", f"Quota={quota}, Threshold={pct}%, Strategy={thr_strategy}, Cycle={thr_cycle}", ticket_add_thr.strip())
                            refresh_after_write()
                        except Exception as e:
                            st.error(friendly_error(e))
                    else:
                        st.warning("Enter a threshold percentage.")
        with col_remove:
            with st.form(f"remove_threshold_{quota}", clear_on_submit=True):
                pct_rm = st.number_input("Threshold % to remove", min_value=1, max_value=100, value=None, step=10, key=f"thr_rm_{quota}", placeholder="e.g. 80")
                thr_strategy_rm = st.selectbox("Strategy", ["ACTUAL", "PROJECTED"], key=f"thr_strategy_rm_{quota}")
                thr_cycle_rm = st.selectbox("Cycle", ["DAILY", "WEEKLY", "MONTHLY"], key=f"thr_cycle_rm_{quota}")
                ticket_rm_thr = st.text_input("ServiceNow Ticket / Justification", placeholder="e.g. INC0012345", key=f"ticket_rm_thr_{quota}")
                rm_thr = st.form_submit_button("Remove Threshold", type="primary")
                if rm_thr:
                    if not ticket_rm_thr or not ticket_rm_thr.strip():
                        st.warning("A ServiceNow ticket is required.")
                    elif pct_rm:
                        try:
                            session.sql(f"CALL {DB_SCHEMA}.{quota}!REMOVE_NOTIFICATION_THRESHOLD({pct_rm}, '{thr_strategy_rm}', '{thr_cycle_rm}')").collect()
                            audit_log("REMOVE_THRESHOLD", f"Quota={quota}, Threshold={pct_rm}%, Strategy={thr_strategy_rm}, Cycle={thr_cycle_rm}", ticket_rm_thr.strip())
                            refresh_after_write()
                        except Exception as e:
                            st.error(friendly_error(e))
                    else:
                        st.warning("Enter a threshold percentage.")


# ═══════════════════════════════════════════════════════════════
# PAGE: Tag Management
# ═══════════════════════════════════════════════════════════════
elif page == "Tag Management":
    st.header("Tag Management")
    st.info("Data sourced from ACCOUNT_USAGE.TAG_REFERENCES (up to **2 hours** latency).")
    try:
        tags = cached_query(session, """
            SELECT OBJECT_NAME AS USER_NAME, TAG_VALUE AS TIER
            FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES
            WHERE TAG_NAME = 'AI_COST_TIER' AND DOMAIN = 'USER'
            ORDER BY TAG_VALUE, OBJECT_NAME
        """)
        if not tags.empty:
            tier_counts = tags.groupby("TIER").size().reset_index(name="COUNT")
            cols = st.columns(len(tier_counts))
            for i, row in tier_counts.iterrows():
                cols[i].metric(row["TIER"], row["COUNT"])
            st.dataframe(tags, use_container_width=True, hide_index=True)
        else:
            st.info("No tagged users found.")
    except Exception as e:
        st.error(f"Error: {e}")

    st.divider()
    st.subheader("Tier Change")
    st.caption("Tag changes take effect immediately for quota enforcement, but may take up to 2 hours to appear above.")
    
    with st.form("move_tier_form", clear_on_submit=True):
        col1, col2 = st.columns(2)
        with col1:
            user_to_move = st.text_input("User Name", placeholder="e.g. ALICE", key="tag_user")
        with col2:
            new_tier = st.selectbox("New Tier", ["TIER_1", "TIER_2", "TIER_3", "EXEMPT"], key="tag_tier")
        ticket_move = st.text_input("ServiceNow Ticket / Justification", placeholder="e.g. INC0012345", key="ticket_move")
        submitted = st.form_submit_button("Apply Change", type="primary")
        if submitted:
            if not ticket_move.strip():
                st.warning("A ServiceNow ticket is required to proceed.")
            elif user_to_move.strip():
                try:
                    session.sql(f"ALTER USER {user_to_move.strip()} SET TAG {DB_SCHEMA}.AI_COST_TIER = '{new_tier}'").collect()
                    audit_log("MOVE_TIER", f"User={user_to_move.strip()}, NewTier={new_tier}", ticket_move.strip())
                    st.success(f"Done! {user_to_move.strip()} moved to {new_tier}")
                except Exception as e:
                    st.error(friendly_error(e))
            else:
                st.warning("Enter a user name.")


# ═══════════════════════════════════════════════════════════════
# PAGE: Block Status
# ═══════════════════════════════════════════════════════════════
elif page == "Block Status":
    st.header("Block Status")
    
    all_blocks = pd.DataFrame()
    for quota in QUOTAS:
        try:
            blocks = cached_query(session, f"CALL {DB_SCHEMA}.{quota}!GET_ACTIVE_BLOCKS()")
            if not blocks.empty:
                blocks["QUOTA"] = TIER_LABELS[quota]
                all_blocks = pd.concat([all_blocks, blocks], ignore_index=True)
        except Exception:
            pass
    
    if not all_blocks.empty:
        st.warning(f"{len(all_blocks)} active block(s)")
        st.dataframe(all_blocks, use_container_width=True, hide_index=True)
    else:
        st.success("No users currently blocked across any tier.")

    st.divider()
    st.subheader("Update Tier")
    st.caption("Moving a user to a different tier clears any active block within ~15 minutes.")
    
    with st.form("unblock_form", clear_on_submit=True):
        col1, col2 = st.columns(2)
        with col1:
            blocked_user = st.text_input("User Name", key="unblock_user")
        with col2:
            upgrade_tier = st.selectbox("Change To", ["TIER_1", "TIER_2", "TIER_3"], key="unblock_tier")
        ticket_unblock = st.text_input("ServiceNow Ticket / Justification", placeholder="e.g. INC0012345", key="ticket_unblock")
        submitted = st.form_submit_button("Update Tier", type="primary")
        if submitted:
            if not ticket_unblock.strip():
                st.warning("A ServiceNow ticket is required to proceed.")
            elif blocked_user.strip():
                try:
                    session.sql(f"ALTER USER {blocked_user.strip()} SET TAG {DB_SCHEMA}.AI_COST_TIER = '{upgrade_tier}'").collect()
                    audit_log("UPDATE_TIER", f"User={blocked_user.strip()}, ChangedTo={upgrade_tier}", ticket_unblock.strip())
                    st.success(f"Done! {blocked_user.strip()} changed to {upgrade_tier}. Block clears within ~15 min.")
                except Exception as e:
                    st.error(friendly_error(e))
            else:
                st.warning("Enter a user name.")


# ═══════════════════════════════════════════════════════════════
# PAGE: Tier Lookup
# ═══════════════════════════════════════════════════════════════
elif page == "Tier Lookup":
    st.header("Tier Lookup")
    st.caption("Bypasses the 2-hour ACCOUNT_USAGE lag.")

    with st.form("realtime_tag_form"):
        lookup_user = st.text_input("User Name", placeholder="e.g. ALICE", key="realtime_user")
        submitted = st.form_submit_button("Check Tag", type="primary")
        if submitted:
            if lookup_user.strip():
                try:
                    result = run_query(f"SELECT SYSTEM$GET_TAG('{DB_SCHEMA}.AI_COST_TIER', '{lookup_user.strip()}', 'USER') AS TAG_VALUE")
                    if not result.empty and result["TAG_VALUE"].iloc[0]:
                        tag_val = result["TAG_VALUE"].iloc[0]
                        st.success(f"**{lookup_user.strip()}** is currently tagged: **{tag_val}**")
                    else:
                        st.warning(f"**{lookup_user.strip()}** has no AI_COST_TIER tag assigned.")
                except Exception as e:
                    st.error(friendly_error(e))
            else:
                st.warning("Enter a user name.")

    st.divider()
    st.subheader("Bulk Lookup")
    st.caption("Check tags for multiple users at once (comma-separated).")

    with st.form("bulk_tag_form"):
        bulk_users = st.text_input("User Names (comma-separated)", placeholder="e.g. ALICE, BOB, CHARLIE", key="bulk_users")
        submitted = st.form_submit_button("Check All", type="primary")
        if submitted:
            if bulk_users.strip():
                users = [u.strip() for u in bulk_users.split(",") if u.strip()]
                rows = []
                for u in users:
                    try:
                        result = run_query(f"SELECT SYSTEM$GET_TAG('{DB_SCHEMA}.AI_COST_TIER', '{u}', 'USER') AS TAG_VALUE")
                        tag_val = result["TAG_VALUE"].iloc[0] if not result.empty and result["TAG_VALUE"].iloc[0] else "NOT TAGGED"
                        rows.append({"USER_NAME": u, "CURRENT_TIER": tag_val})
                    except Exception as e:
                        rows.append({"USER_NAME": u, "CURRENT_TIER": "USER NOT FOUND"})
                st.dataframe(pd.DataFrame(rows), use_container_width=True, hide_index=True)
            else:
                st.warning("Enter at least one user name.")


# ═══════════════════════════════════════════════════════════════
# PAGE: Exempt Users
# ═══════════════════════════════════════════════════════════════
elif page == "Exempt Users":
    st.header("Exempt Users")
    st.caption("Users excluded from auto-tagging and all quotas.")
    
    try:
        exempt = cached_query(session, f"""
            SELECT USER_NAME, REASON,
                   TO_VARCHAR(CONVERT_TIMEZONE('America/Chicago', EXEMPT_DATE), 'YYYY-MM-DD HH24:MI') || ' CST' AS EXEMPT_DATE
            FROM {DB_SCHEMA}.EXEMPT_USERS ORDER BY USER_NAME
        """)
        if not exempt.empty:
            st.dataframe(exempt, use_container_width=True, hide_index=True)
        else:
            st.info("No exempt users.")
    except Exception as e:
        st.error(f"Error: {e}")

    st.divider()
    col1, col2 = st.columns(2)
    with col1:
        st.subheader("Add Exempt User")
        with st.form("add_exempt_form", clear_on_submit=True):
            add_user = st.text_input("User Name", key="exempt_add")
            add_reason = st.text_input("Reason", value="Service account", key="exempt_reason")
            ticket_add_exempt = st.text_input("ServiceNow Ticket / Justification", placeholder="e.g. INC0012345", key="ticket_add_exempt")
            submitted = st.form_submit_button("Add", type="primary")
            if submitted:
                if not ticket_add_exempt.strip():
                    st.warning("A ServiceNow ticket is required.")
                elif add_user.strip():
                    try:
                        session.sql(f"INSERT INTO {DB_SCHEMA}.EXEMPT_USERS (USER_NAME, REASON) VALUES ('{add_user.strip()}', '{add_reason}')").collect()
                        audit_log("ADD_EXEMPT_USER", f"User={add_user.strip()}, Reason={add_reason}", ticket_add_exempt.strip())
                        st.success(f"Done! {add_user.strip()} exempted.")
                        refresh_after_write()
                    except Exception as e:
                        st.error(friendly_error(e))
                else:
                    st.warning("Enter a user name.")
    
    with col2:
        st.subheader("Remove Exempt User")
        with st.form("remove_exempt_form", clear_on_submit=True):
            remove_user = st.text_input("User Name", key="exempt_remove")
            ticket_rm_exempt = st.text_input("ServiceNow Ticket / Justification", placeholder="e.g. INC0012345", key="ticket_rm_exempt")
            submitted = st.form_submit_button("Remove", type="primary")
            if submitted:
                if not ticket_rm_exempt.strip():
                    st.warning("A ServiceNow ticket is required.")
                elif remove_user.strip():
                    try:
                        session.sql(f"DELETE FROM {DB_SCHEMA}.EXEMPT_USERS WHERE USER_NAME = '{remove_user.strip()}'").collect()
                        audit_log("REMOVE_EXEMPT_USER", f"User={remove_user.strip()}", ticket_rm_exempt.strip())
                        st.success(f"Done! {remove_user.strip()} removed from exempt list.")
                        refresh_after_write()
                    except Exception as e:
                        st.error(friendly_error(e))
                else:
                    st.warning("Enter a user name.")


# ═══════════════════════════════════════════════════════════════
# PAGE: Untagged Users
# ═══════════════════════════════════════════════════════════════
elif page == "Untagged Users":
    st.header("Untagged Users")
    st.caption("Users not yet assigned to any tier. Auto-tagged to TIER_1 on next daily task run.")
    
    # Show last auto-tag execution time
    try:
        last_run = cached_query(session, f"""
            SELECT TO_VARCHAR(CONVERT_TIMEZONE('America/Chicago', EXECUTION_TIMESTAMP), 'YYYY-MM-DD HH24:MI') AS LAST_RUN_CST
            FROM {DB_SCHEMA}.PROCEDURE_EXECUTION_LOG
            WHERE PROCEDURE_NAME = 'TAG_NEW_USERS'
            ORDER BY EXECUTION_TIMESTAMP DESC
            LIMIT 1
        """)
        if not last_run.empty:
            last_ts = last_run['LAST_RUN_CST'].iloc[0]
            st.info(f"Last auto-tag run: **{last_ts} CST**")
        else:
            st.info("Auto-tag has not run yet.")
    except Exception:
        pass
    
    try:
        untagged = cached_query(session, """
            SELECT u.NAME AS USER_NAME, u.TYPE,
                   TO_VARCHAR(CONVERT_TIMEZONE('America/Chicago', u.CREATED_ON), 'YYYY-MM-DD HH24:MI') || ' CST' AS CREATED_ON
            FROM SNOWFLAKE.ACCOUNT_USAGE.USERS u
            WHERE u.DELETED_ON IS NULL
              AND u.TYPE != 'SNOWFLAKE_SERVICE'
              AND u.NAME NOT IN (SELECT USER_NAME FROM COST_MGMT_DB.QUOTA_SCHEMA.EXEMPT_USERS)
              AND u.NAME NOT IN (
                SELECT OBJECT_NAME
                FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES
                WHERE TAG_NAME = 'AI_COST_TIER' AND DOMAIN = 'USER'
              )
            ORDER BY u.CREATED_ON DESC
        """)
        if not untagged.empty:
            st.warning(f"{len(untagged)} user(s) not yet tagged.")
            st.dataframe(untagged, use_container_width=True, hide_index=True)
        else:
            st.success("All users are tagged.")
    except Exception as e:
        st.error(f"Error: {e}")

    st.divider()
    st.caption("Manually run the tagging procedure (Account Usage Tag References has upto 2 hours of latency).")
    if st.button("Run Tag New Users Now", type="primary", key="manual_tag_btn"):
        with st.spinner("Running Tag New Users..."):
            try:
                result = run_query(f"CALL {DB_SCHEMA}.TAG_NEW_USERS()")
                st.success(f"Done! {result.iloc[0, 0]}")
                refresh_after_write()
            except Exception as e:
                st.error(friendly_error(e))
    st.caption("Safe to re-run: this only tags untagged users. It will not change the tier of already tagged users or exempted users.")



# ═══════════════════════════════════════════════════════════════
# PAGE: Execution Log
# ═══════════════════════════════════════════════════════════════
elif page == "Execution Log":
    st.header("Execution Log")
    
    try:
        logs = cached_query(session, f"""
            SELECT EXECUTION_ID, PROCEDURE_NAME,
                   TO_VARCHAR(CONVERT_TIMEZONE('America/Chicago', EXECUTION_TIMESTAMP), 'YYYY-MM-DD HH24:MI:SS') || ' CST' AS EXECUTION_TIMESTAMP,
                   STATUS, USERS_TAGGED, USERS_SKIPPED, ERROR_CODE, ERROR_DESCRIPTION
            FROM {DB_SCHEMA}.PROCEDURE_EXECUTION_LOG
            ORDER BY EXECUTION_TIMESTAMP DESC
            LIMIT 20
        """)
        if not logs.empty:
            success_count = len(logs[logs["STATUS"] == "SUCCESS"])
            fail_count = len(logs[logs["STATUS"] == "FAILURE"])
            col1, col2 = st.columns(2)
            col1.metric("Successful Runs", success_count)
            col2.metric("Failed Runs", fail_count)
            st.dataframe(logs, use_container_width=True, hide_index=True)
            
            # Show skipped user details for runs with skipped > 0
            skipped_runs = logs[logs["USERS_SKIPPED"] > 0]
            if not skipped_runs.empty:
                st.divider()
                st.subheader("Skipped User Details")
                st.caption("Users that could not be tagged and the reason why. Expand each run to see details.")
                for _, row in skipped_runs.iterrows():
                    exec_id = row["EXECUTION_ID"]
                    run_ts = row["EXECUTION_TIMESTAMP"]
                    skipped_n = row["USERS_SKIPPED"]
                    with st.expander(f"Run #{exec_id} — {run_ts} ({skipped_n} skipped)"):
                        try:
                            details = cached_query(session, f"""
                                SELECT f.value:user::STRING AS USER_NAME,
                                       f.value:reason::STRING AS REASON
                                FROM {DB_SCHEMA}.PROCEDURE_EXECUTION_LOG,
                                     LATERAL FLATTEN(input => SKIPPED_USER_DETAILS) f
                                WHERE EXECUTION_ID = {exec_id}
                                ORDER BY f.value:user::STRING
                            """)
                            if not details.empty:
                                st.dataframe(details, use_container_width=True, hide_index=True)
                            else:
                                st.info("No detail captured (older run without SKIPPED_USER_DETAILS).")
                        except Exception:
                            st.info("No detail captured (older run without SKIPPED_USER_DETAILS).")
        else:
            st.info("No executions logged yet.")
    except Exception as e:
        st.error(f"Error: {e}")


# ═══════════════════════════════════════════════════════════════
# PAGE: Audit Log
# ═══════════════════════════════════════════════════════════════
elif page == "Audit Log":
    st.header("Audit Log")
    st.caption("All write operations performed via this app (latest 100 entries).")
    
    try:
        audit = cached_query(session, f"""
            SELECT AUDIT_ID, PERFORMED_BY, OPERATION, DETAILS, SNOW_TICKET,
                   TO_VARCHAR(CONVERT_TIMEZONE('America/Chicago', PERFORMED_AT), 'YYYY-MM-DD HH24:MI:SS') || ' CST' AS PERFORMED_AT
            FROM {DB_SCHEMA}.ADMIN_AUDIT_LOG
            ORDER BY AUDIT_ID DESC
            LIMIT 100
        """)
        if not audit.empty:
            st.dataframe(audit, use_container_width=True, hide_index=True)
        else:
            st.info("No audit entries yet.")
    except Exception as e:
        st.error(f"Error: {e}")
