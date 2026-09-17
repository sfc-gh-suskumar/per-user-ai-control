import streamlit as st
from snowflake.snowpark.context import get_active_session
import pandas as pd

st.set_page_config(page_title="AI Quota Admin", page_icon="shield", layout="wide")

# --- Connection (Snowsight active session) ---
# Deploy this app using the QUOTA_ADMIN role.
# QUOTA_ADMIN owns all quota objects and has full access.
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

# --- Custom CSS for Snowflake branding ---
st.markdown("""
<style>
    [data-testid="stSidebar"] { background-color: #F8F9FB; }
    [data-testid="stSidebar"] [data-testid="stMarkdownContainer"] p { color: #11567F; }
    .stMetric label { color: #11567F !important; font-weight: 600; }
    .stMetric [data-testid="stMetricValue"] { color: #29B5E8; }
    div[data-testid="stDataFrame"] { border: 1px solid #E8EDF3; border-radius: 8px; }
    h1, h2, h3 { color: #11567F; }
    .stTabs [data-baseweb="tab-list"] { gap: 8px; }
    .stTabs [data-baseweb="tab"] { 
        background-color: #F8F9FB; border-radius: 6px; padding: 8px 16px;
        color: #11567F; font-weight: 500;
    }
    .stTabs [aria-selected="true"] { background-color: #29B5E8 !important; color: white !important; }
    [data-testid="stCaptionContainer"] p { color: #4A5568 !important; font-size: 0.92rem !important; }
</style>
""", unsafe_allow_html=True)

# --- Constants ---
DB_SCHEMA = "COST_MGMT_DB.QUOTA_SCHEMA"

# Dynamically discover all quotas in the schema
@st.cache_data(ttl=300)
def get_quota_list():
    """Fetch all SNOWFLAKE.CORE.QUOTA objects in the schema."""
    result = session.sql(f"SHOW SNOWFLAKE.CORE.QUOTA IN SCHEMA {DB_SCHEMA}").collect()
    if result:
        return [row["name"] for row in result]
    return []

QUOTAS = get_quota_list()
TIER_LABELS = {q: q.replace("_", " ").title() for q in QUOTAS}

# --- Header ---
col_title, col_refresh = st.columns([8, 1])
with col_title:
    st.title("AI Quota Administration")
    st.caption("Per-user spending controls for Snowflake AI Services")
with col_refresh:
    st.write("")  # spacing
    if st.button("Refresh", key="global_refresh"):
        st.cache_data.clear()
        st.rerun()

# --- Navigation via Tabs ---
tabs = st.tabs([
    "Dashboard",
    "Quota Management",
    "Tag Management",
    "Block Status",
    "Real-Time Tag Lookup",
    "Exempt Users",
    "Untagged Users",
    "Execution Log"
])

# ═══════════════════════════════════════════════════════════════
# TAB: Dashboard
# ═══════════════════════════════════════════════════════════════
with tabs[0]:
    # Quota summary table
    st.subheader("Quota Overview")
    quota_rows = []
    for quota in QUOTAS:
        try:
            config = cached_query(session, f"CALL {DB_SCHEMA}.{quota}!GET_CONFIG()")
            if not config.empty:
                quota_rows.append({
                    "Quota Name": quota,
                    "Daily Limit (Credits)": config["PER_USER_LIMIT_DAILY"].iloc[0],
                    "Monthly Limit (Credits)": config["PER_USER_LIMIT"].iloc[0]
                })
            else:
                quota_rows.append({"Quota Name": quota, "Daily Limit (Credits)": None, "Monthly Limit (Credits)": None})
        except Exception:
            quota_rows.append({"Quota Name": quota, "Daily Limit (Credits)": "Error", "Monthly Limit (Credits)": "Error"})
    if quota_rows:
        st.dataframe(pd.DataFrame(quota_rows), use_container_width=True, hide_index=True)

    st.divider()

    # Usage preview (reads from pre-computed cache table — instant load)
    st.subheader("Per-User Usage (Current Month)")
    st.caption("Credit consumption per user per AI service from the 1st of this month through today. Use this to identify users approaching their quota limits.")
    tier_options = [""] + QUOTAS
    tier_format = lambda x: "-- Select a Quota --" if x == "" else TIER_LABELS[x]
    selected_tier = st.selectbox("Select Quota", tier_options, format_func=tier_format, key="dash_tier")

    if selected_tier == "":
        st.info("Select a quota above to view per-user usage data.")
    else:
        usage = cached_query(session, f"""
            SELECT USER_NAME, SERVICE_TYPE, USER_ID, CREDITS_SPEND, REFRESHED_AT
            FROM {DB_SCHEMA}.QUOTA_USAGE_CACHE
            WHERE QUOTA_NAME = '{selected_tier}'
            ORDER BY CREDITS_SPEND DESC
        """)
        if not usage.empty:
            last_refresh = usage['REFRESHED_AT'].iloc[0] if 'REFRESHED_AT' in usage.columns else None
            if last_refresh:
                st.caption(f"Last refreshed: {last_refresh}")
            display_cols = [c for c in usage.columns if c != 'REFRESHED_AT']
            st.dataframe(usage[display_cols], use_container_width=True, hide_index=True)
        else:
            st.info("No usage data for the current month. The cache may not have been refreshed yet.")

# ═══════════════════════════════════════════════════════════════
# TAB: Quota Management
# ═══════════════════════════════════════════════════════════════
with tabs[1]:
    st.subheader("Quota Management")
    st.caption("View and set per-user daily/monthly credit limits and notification thresholds for each tier.")

    for quota in QUOTAS:
        with st.expander(f"{TIER_LABELS[quota]} — {quota}", expanded=False):
            try:
                config = cached_query(session, f"CALL {DB_SCHEMA}.{quota}!GET_CONFIG()")
                if not config.empty:
                    col1, col2 = st.columns(2)
                    col1.metric("Daily Limit", f"{config['PER_USER_LIMIT_DAILY'].iloc[0]} credits")
                    col2.metric("Monthly Limit", f"{config['PER_USER_LIMIT'].iloc[0]} credits")
                else:
                    st.info("No config found.")
            except Exception as e:
                st.error(f"Error loading config: {e}")

            with st.form(f"set_limits_{quota}", clear_on_submit=False):
                col1, col2 = st.columns(2)
                with col1:
                    new_daily = st.number_input("New Daily Limit (credits)", min_value=0.0, step=0.5, key=f"daily_{quota}")
                with col2:
                    new_monthly = st.number_input("New Monthly Limit (credits)", min_value=0.0, step=1.0, key=f"monthly_{quota}")
                submitted = st.form_submit_button("Update Limits", type="primary")
                if submitted:
                    try:
                        if new_daily > 0:
                            session.sql(f"CALL {DB_SCHEMA}.{quota}!SET_PER_USER_LIMIT({new_daily}, 'DAILY')").collect()
                        if new_monthly > 0:
                            session.sql(f"CALL {DB_SCHEMA}.{quota}!SET_PER_USER_LIMIT({new_monthly})").collect()
                        if new_daily > 0 or new_monthly > 0:
                            st.success(f"{TIER_LABELS[quota]} limits updated!")
                        else:
                            st.warning("Enter at least one limit value greater than 0.")
                    except Exception as e:
                        st.error(friendly_error(e))

            st.markdown("**Notification Thresholds** _(monthly only)_")
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
                    pct = st.number_input("Threshold %", min_value=1, max_value=100, value=50, step=10, key=f"thr_pct_{quota}")
                    add_thr = st.form_submit_button("Add Threshold")
                    if add_thr:
                        try:
                            session.sql(f"CALL {DB_SCHEMA}.{quota}!ADD_NOTIFICATION_THRESHOLD({pct}, 'ACTUAL', TRUE)").collect()
                            st.success(f"Added {pct}% threshold.")
                        except Exception as e:
                            st.error(friendly_error(e))
            with col_remove:
                with st.form(f"remove_threshold_{quota}", clear_on_submit=True):
                    pct_rm = st.number_input("Threshold % to remove", min_value=1, max_value=100, value=100, step=10, key=f"thr_rm_{quota}")
                    rm_thr = st.form_submit_button("Remove Threshold")
                    if rm_thr:
                        try:
                            session.sql(f"CALL {DB_SCHEMA}.{quota}!REMOVE_NOTIFICATION_THRESHOLD({pct_rm}, 'ACTUAL')").collect()
                            st.success(f"Removed {pct_rm}% threshold.")
                        except Exception as e:
                            st.error(friendly_error(e))

# ═══════════════════════════════════════════════════════════════
# TAB: Tag Management
# ═══════════════════════════════════════════════════════════════
with tabs[2]:
    st.subheader("Current Tag Assignments")
    st.info("Data sourced from ACCOUNT_USAGE.TAG_REFERENCES which has up to **2 hours** of latency. Recent tag changes may not appear immediately.")
    try:
        tags = cached_query(session, """            SELECT OBJECT_NAME AS USER_NAME, TAG_VALUE AS TIER
            FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES
            WHERE TAG_NAME = 'AI_COST_TIER' AND DOMAIN = 'USER'
            ORDER BY TAG_VALUE, OBJECT_NAME
        """)
        if not tags.empty:
            # Summary metrics
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
    st.subheader("Move User to a Different Tier")
    st.caption("Tag changes take effect immediately for quota enforcement, but may take up to 2 hours to appear in the table above.")
    
    with st.form("move_tier_form", clear_on_submit=True):
        col1, col2 = st.columns(2)
        with col1:
            user_to_move = st.text_input("User Name", placeholder="e.g. ALICE", key="tag_user")
        with col2:
            new_tier = st.selectbox("New Tier", ["TIER_1", "TIER_2", "TIER_3", "EXEMPT"], key="tag_tier")
        submitted = st.form_submit_button("Apply Change", type="primary")
        if submitted:
            if user_to_move.strip():
                try:
                    session.sql(f"ALTER USER {user_to_move.strip()} SET TAG {DB_SCHEMA}.AI_COST_TIER = '{new_tier}'").collect()
                    st.success(f"Done! {user_to_move.strip()} moved to {new_tier}")
                except Exception as e:
                    st.error(friendly_error(e))
            else:
                st.warning("Enter a user name.")

# ═══════════════════════════════════════════════════════════════
# TAB: Block Status
# ═══════════════════════════════════════════════════════════════
with tabs[3]:
    st.subheader("Currently Blocked Users")
    
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
    st.subheader("Unblock via Tier Upgrade")
    st.caption("Moving a user to a higher tier clears the block within ~15 minutes.")
    
    with st.form("unblock_form", clear_on_submit=True):
        col1, col2 = st.columns(2)
        with col1:
            blocked_user = st.text_input("Blocked User", key="unblock_user")
        with col2:
            upgrade_tier = st.selectbox("Upgrade to", ["TIER_2", "TIER_3"], key="unblock_tier")
        submitted = st.form_submit_button("Upgrade & Unblock", type="primary")
        if submitted:
            if blocked_user.strip():
                try:
                    session.sql(f"ALTER USER {blocked_user.strip()} SET TAG {DB_SCHEMA}.AI_COST_TIER = '{upgrade_tier}'").collect()
                    st.success(f"Done! {blocked_user.strip()} upgraded to {upgrade_tier}. Block clears within ~15 min.")
                except Exception as e:
                    st.error(friendly_error(e))
            else:
                st.warning("Enter a user name.")

# ═══════════════════════════════════════════════════════════════
# TAB: Real-Time Tag Lookup
# ═══════════════════════════════════════════════════════════════
with tabs[4]:
    st.subheader("Real-Time Tag Lookup")
    st.caption("Check a user's current AI_COST_TIER tag value in real time (bypasses the 2-hour ACCOUNT_USAGE lag).")

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
# TAB: Exempt Users
# ═══════════════════════════════════════════════════════════════
with tabs[5]:
    st.subheader("Exempt Users")
    st.caption("Users excluded from auto-tagging and all quotas.")
    
    try:
        exempt = cached_query(session, f"SELECT * FROM {DB_SCHEMA}.EXEMPT_USERS ORDER BY USER_NAME")
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
            submitted = st.form_submit_button("Add", type="primary")
            if submitted:
                if add_user.strip():
                    try:
                        session.sql(f"INSERT INTO {DB_SCHEMA}.EXEMPT_USERS (USER_NAME, REASON) VALUES ('{add_user.strip()}', '{add_reason}')").collect()
                        st.success(f"Done! {add_user.strip()} exempted.")
                    except Exception as e:
                        st.error(friendly_error(e))
                else:
                    st.warning("Enter a user name.")
    
    with col2:
        st.subheader("Remove Exempt User")
        with st.form("remove_exempt_form", clear_on_submit=True):
            remove_user = st.text_input("User Name", key="exempt_remove")
            submitted = st.form_submit_button("Remove")
            if submitted:
                if remove_user.strip():
                    try:
                        session.sql(f"DELETE FROM {DB_SCHEMA}.EXEMPT_USERS WHERE USER_NAME = '{remove_user.strip()}'").collect()
                        st.success(f"Done! {remove_user.strip()} removed from exempt list.")
                    except Exception as e:
                        st.error(friendly_error(e))
                else:
                    st.warning("Enter a user name.")


# ═══════════════════════════════════════════════════════════════
# TAB: Untagged Users
# ═══════════════════════════════════════════════════════════════
with tabs[6]:
    st.subheader("Untagged Users")
    st.caption("Users not yet assigned to any tier. Auto-tagged to TIER_1 on next daily task run. This list uses TAG_REFERENCES (up to 2 hours latency) — recently tagged users may still appear here temporarily.")
    
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
            
            if st.button("Tag All to TIER_1 Now", type="primary", key="tag_all_btn"):
                with st.spinner("Tagging users to TIER_1..."):
                    try:
                        result = run_query(f"CALL {DB_SCHEMA}.TAG_NEW_USERS()")
                        st.success(f"Done! {result.iloc[0, 0]}")
                    except Exception as e:
                        st.error(friendly_error(e))
        else:
            st.success("All users are tagged.")
    except Exception as e:
        st.error(f"Error: {e}")

# ═══════════════════════════════════════════════════════════════
# TAB: Execution Log
# ═══════════════════════════════════════════════════════════════
with tabs[7]:
    st.subheader("Procedure Execution Log")
    
    try:
        logs = cached_query(session, f"""
            SELECT EXECUTION_ID, PROCEDURE_NAME, EXECUTION_TIMESTAMP, STATUS,
                   USERS_TAGGED, USERS_SKIPPED, ERROR_CODE, ERROR_DESCRIPTION
            FROM {DB_SCHEMA}.PROCEDURE_EXECUTION_LOG
            ORDER BY EXECUTION_TIMESTAMP DESC
            LIMIT 20
        """)
        if not logs.empty:
            # Summary
            success_count = len(logs[logs["STATUS"] == "SUCCESS"])
            fail_count = len(logs[logs["STATUS"] == "FAILURE"])
            col1, col2 = st.columns(2)
            col1.metric("Successful Runs", success_count)
            col2.metric("Failed Runs", fail_count)
            
            st.dataframe(logs, use_container_width=True, hide_index=True)
        else:
            st.info("No executions logged yet.")
    except Exception as e:
        st.error(f"Error: {e}")

