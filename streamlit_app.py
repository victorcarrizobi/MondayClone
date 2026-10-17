"""
MondayClone -- Snowflake-Native Project Board
A monday.com-inspired work management board built entirely on Snowflake.
Hack the Experience track | Data in the D 2026 Hackathon
"""

import streamlit as st
import pandas as pd
import json

# ── Connection ──────────────────────────────────────────────
conn = st.connection("snowflake")

def run_query(sql, params=None):
    return conn.session().sql(sql).to_pandas()

def run_action(sql):
    conn.session().sql(sql).collect()

# ── Session State Init ──────────────────────────────────────
if "current_view" not in st.session_state:
    st.session_state["current_view"] = "Table"
if "selected_board" not in st.session_state:
    st.session_state["selected_board"] = "Fraud Investigation"
if "selected_item_id" not in st.session_state:
    st.session_state["selected_item_id"] = None
if "dark_mode" not in st.session_state:
    st.session_state["dark_mode"] = True

# ── Theme Colors ────────────────────────────────────────────
PRIORITY_COLORS = {
    "CRITICAL": "#E2445C", "HIGH": "#FDAB3D",
    "MEDIUM": "#579BFC", "LOW": "#00C875"
}
STATUS_COLORS = {
    "Open": "#579BFC", "Investigating": "#FDAB3D",
    "Confirmed Fraud": "#E2445C", "False Positive": "#C4C4C4",
    "Closed": "#00C875", "Filed": "#579BFC", "Under Review": "#FDAB3D",
    "Approved": "#00C875", "Denied": "#E2445C", "Settled": "#C4C4C4"
}

if st.session_state["dark_mode"]:
    BG = "#1A1A2E"; CARD_BG = "#16213E"; TEXT = "#E0E0E0"
    SIDEBAR_BG = "#0F3460"; ACCENT = "#533483"
else:
    BG = "#F6F7FB"; CARD_BG = "#FFFFFF"; TEXT = "#323338"
    SIDEBAR_BG = "#FFFFFF"; ACCENT = "#6C6CFF"

# ── Global CSS ──────────────────────────────────────────────
st.markdown(f"""
<style>
    .stApp {{ background-color: {BG}; color: {TEXT}; }}
    .board-header {{ font-size: 28px; font-weight: 700; margin-bottom: 4px; color: {TEXT}; }}
    .board-sub {{ font-size: 14px; color: {"#9CA3AF" if st.session_state["dark_mode"] else "#676879"}; margin-bottom: 20px; }}
    .kpi-card {{
        background: {CARD_BG}; border-radius: 8px; padding: 16px 20px;
        border-left: 4px solid {ACCENT}; margin-bottom: 8px;
    }}
    .kpi-value {{ font-size: 28px; font-weight: 700; color: {TEXT}; }}
    .kpi-label {{ font-size: 12px; color: {"#9CA3AF" if st.session_state["dark_mode"] else "#676879"}; text-transform: uppercase; letter-spacing: 1px; }}
    .status-pill {{
        display: inline-block; padding: 2px 10px; border-radius: 12px;
        font-size: 12px; font-weight: 600; color: white;
    }}
    .kanban-card {{
        background: {CARD_BG}; border-radius: 8px; padding: 12px;
        margin-bottom: 8px; border-left: 3px solid;
    }}
    .kanban-header {{
        padding: 8px 12px; border-radius: 8px 8px 0 0;
        font-weight: 700; font-size: 14px; color: white; text-align: center;
    }}
    .item-detail-header {{ font-size: 22px; font-weight: 700; color: {TEXT}; margin-bottom: 12px; }}
    .update-bubble {{
        background: {CARD_BG}; border-radius: 8px; padding: 12px;
        margin-bottom: 8px; border-left: 3px solid {ACCENT};
    }}
    .update-author {{ font-weight: 700; font-size: 13px; color: {TEXT}; }}
    .update-body {{ font-size: 13px; color: {"#CCC" if st.session_state["dark_mode"] else "#555"}; margin-top: 4px; }}
    div[data-testid="stSidebar"] {{ background-color: {SIDEBAR_BG}; }}
</style>
""", unsafe_allow_html=True)

# ── Sidebar ─────────────────────────────────────────────────
with st.sidebar:
    st.markdown("## MondayClone")
    st.markdown(f'<span style="font-size:12px;color:#9CA3AF;">Snowflake-Native Board</span>', unsafe_allow_html=True)
    st.markdown("---")

    boards = run_query("SELECT BOARD_ID, NAME FROM MC_BOARDS ORDER BY BOARD_ID")
    board_names = boards["NAME"].tolist()
    sel_board = st.selectbox("Board", board_names, key="sb_board")
    st.session_state["selected_board"] = sel_board

    st.markdown("---")
    views = ["Table", "Kanban", "Dashboard", "Item Detail"]
    for v in views:
        if st.button(v, key=f"nav_{v}", use_container_width=True):
            st.session_state["current_view"] = v

    st.markdown("---")
    st.toggle("Dark Mode", key="dark_mode")
    st.markdown("---")
    st.markdown(f'<span style="font-size:11px;color:#666;">Hack the Experience | Data in the D 2026</span>', unsafe_allow_html=True)

# ── Data Loading ────────────────────────────────────────────
board_id = int(boards[boards["NAME"] == st.session_state["selected_board"]]["BOARD_ID"].iloc[0])

@st.cache_data(ttl=120)
def load_items(bid):
    return run_query(f"""
        SELECT ITEM_ID, ITEM_NAME, STATUS, PRIORITY, ASSIGNEE, DUE_DATE, AMOUNT,
               CUSTOMER_NAME, CUSTOMER_TIER, CREDIT_SCORE, RISK_SCORE, CREDIT_RISK,
               AML_RISK, IS_URGENT, IS_OVERDUE, GROUP_NAME, GROUP_COLOR,
               SOURCE_TABLE, SOURCE_ID, CUSTOMER_ID, CUSTOMER_EMAIL, CREATED_AT, UPDATED_AT
        FROM MC_ITEM_DETAILS
        WHERE BOARD_ID = {bid}
        ORDER BY
            CASE PRIORITY WHEN 'CRITICAL' THEN 1 WHEN 'HIGH' THEN 2 WHEN 'MEDIUM' THEN 3 ELSE 4 END,
            DUE_DATE NULLS LAST
    """)

@st.cache_data(ttl=120)
def load_board_stats(bid):
    return run_query(f"SELECT * FROM MC_BOARD_STATS WHERE BOARD_ID = {bid}")

@st.cache_data(ttl=120)
def load_groups(bid):
    return run_query(f"SELECT GROUP_ID, NAME, POSITION, COLOR FROM MC_GROUPS WHERE BOARD_ID = {bid} ORDER BY POSITION")

items_df = load_items(board_id)
groups_df = load_groups(board_id)

# ── Helper: Priority & Status Pills ────────────────────────
def priority_pill(p):
    c = PRIORITY_COLORS.get(p, "#999")
    return f'<span class="status-pill" style="background:{c};">{p}</span>'

def status_pill(s):
    c = STATUS_COLORS.get(s, "#999")
    return f'<span class="status-pill" style="background:{c};">{s}</span>'

# ── VIEW: TABLE ─────────────────────────────────────────────
def render_table_view():
    st.markdown(f'<div class="board-header">{st.session_state["selected_board"]}</div>', unsafe_allow_html=True)
    st.markdown(f'<div class="board-sub">{len(items_df)} items | Table View</div>', unsafe_allow_html=True)

    # Filters
    col1, col2, col3, col4 = st.columns(4)
    with col1:
        statuses = ["All"] + sorted(items_df["STATUS"].dropna().unique().tolist())
        f_status = st.selectbox("Status", statuses, key="tbl_status")
    with col2:
        priorities = ["All"] + sorted(items_df["PRIORITY"].dropna().unique().tolist())
        f_priority = st.selectbox("Priority", priorities, key="tbl_priority")
    with col3:
        assignees = ["All"] + sorted(items_df["ASSIGNEE"].dropna().unique().tolist())
        f_assignee = st.selectbox("Assignee", assignees, key="tbl_assignee")
    with col4:
        search = st.text_input("Search items", key="tbl_search")

    filtered = items_df.copy()
    if f_status != "All":
        filtered = filtered[filtered["STATUS"] == f_status]
    if f_priority != "All":
        filtered = filtered[filtered["PRIORITY"] == f_priority]
    if f_assignee != "All":
        filtered = filtered[filtered["ASSIGNEE"] == f_assignee]
    if search:
        filtered = filtered[filtered["ITEM_NAME"].str.contains(search, case=False, na=False)]

    # KPI row
    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Total Items", len(filtered))
    c2.metric("Critical", len(filtered[filtered["PRIORITY"] == "CRITICAL"]))
    c3.metric("Overdue", int(filtered["IS_OVERDUE"].sum()) if "IS_OVERDUE" in filtered.columns else 0)
    total_amt = filtered["AMOUNT"].sum() if len(filtered) > 0 else 0
    c4.metric("Total Exposure", f"${total_amt:,.0f}")

    # Table
    display_cols = ["ITEM_NAME", "STATUS", "PRIORITY", "ASSIGNEE", "DUE_DATE", "AMOUNT", "CUSTOMER_NAME", "CUSTOMER_TIER"]
    display_df = filtered[display_cols].copy()
    display_df.columns = ["Item", "Status", "Priority", "Assignee", "Due Date", "Amount", "Customer", "Tier"]
    display_df["Amount"] = display_df["Amount"].apply(lambda x: f"${x:,.2f}" if pd.notna(x) else "")

    st.dataframe(display_df, use_container_width=True, height=500)

    # Click to detail
    st.markdown("---")
    st.markdown("**Quick Action: Open Item Detail**")
    item_ids = filtered["ITEM_ID"].tolist()
    item_labels = filtered["ITEM_NAME"].tolist()
    if item_labels:
        sel = st.selectbox("Select item", range(len(item_labels)), format_func=lambda i: item_labels[i], key="tbl_item_select")
        if st.button("Open Detail", key="tbl_open_detail"):
            st.session_state["selected_item_id"] = int(item_ids[sel])
            st.session_state["current_view"] = "Item Detail"
            st.experimental_rerun()


# ── VIEW: KANBAN ────────────────────────────────────────────
def render_kanban_view():
    st.markdown(f'<div class="board-header">{st.session_state["selected_board"]}</div>', unsafe_allow_html=True)
    st.markdown(f'<div class="board-sub">{len(items_df)} items | Kanban View</div>', unsafe_allow_html=True)

    # Priority filter
    priorities = ["All"] + sorted(items_df["PRIORITY"].dropna().unique().tolist())
    f_priority = st.selectbox("Filter by Priority", priorities, key="kan_priority")
    filtered = items_df if f_priority == "All" else items_df[items_df["PRIORITY"] == f_priority]

    # Kanban columns
    cols = st.columns(len(groups_df))
    for idx, (_, grp) in enumerate(groups_df.iterrows()):
        grp_name = grp["NAME"]
        grp_color = grp["COLOR"]
        grp_items = filtered[filtered["GROUP_NAME"] == grp_name].head(20)

        with cols[idx]:
            st.markdown(f'<div class="kanban-header" style="background:{grp_color};">{grp_name} ({len(grp_items)})</div>', unsafe_allow_html=True)

            for _, item in grp_items.iterrows():
                p_color = PRIORITY_COLORS.get(item["PRIORITY"], "#999")
                overdue_badge = ' <span style="color:#E2445C;font-size:10px;">OVERDUE</span>' if item.get("IS_OVERDUE") else ""
                urgent_badge = ' <span style="color:#FDAB3D;font-size:10px;">URGENT</span>' if item.get("IS_URGENT") else ""

                card_html = f"""
                <div class="kanban-card" style="border-left-color:{p_color};">
                    <div style="font-size:12px;font-weight:600;color:{TEXT};margin-bottom:4px;">
                        {item["ITEM_NAME"][:50]}{"..." if len(str(item["ITEM_NAME"])) > 50 else ""}
                    </div>
                    <div style="font-size:11px;color:#9CA3AF;">
                        {priority_pill(item["PRIORITY"])} {overdue_badge}{urgent_badge}
                    </div>
                    <div style="font-size:11px;color:#9CA3AF;margin-top:4px;">
                        {"Assigned: " + str(item["ASSIGNEE"]) if pd.notna(item["ASSIGNEE"]) else "Unassigned"}
                    </div>
                    <div style="font-size:11px;color:#9CA3AF;">
                        ${item["AMOUNT"]:,.0f}
                    </div>
                </div>
                """
                st.markdown(card_html, unsafe_allow_html=True)


# ── VIEW: DASHBOARD ─────────────────────────────────────────
def render_dashboard_view():
    st.markdown(f'<div class="board-header">{st.session_state["selected_board"]} -- Dashboard</div>', unsafe_allow_html=True)

    stats = load_board_stats(board_id)
    if len(stats) == 0:
        st.warning("Board stats not yet available. Dynamic table may still be refreshing.")
        return

    row = stats.iloc[0]

    # KPI cards
    k1, k2, k3, k4 = st.columns(4)
    k1.markdown(f"""<div class="kpi-card">
        <div class="kpi-label">Total Items</div>
        <div class="kpi-value">{int(row["TOTAL_ITEMS"]):,}</div>
    </div>""", unsafe_allow_html=True)
    k2.markdown(f"""<div class="kpi-card">
        <div class="kpi-label">In Progress</div>
        <div class="kpi-value">{int(row["ITEMS_IN_PROGRESS"]):,}</div>
    </div>""", unsafe_allow_html=True)
    k3.markdown(f"""<div class="kpi-card">
        <div class="kpi-label">Critical Priority</div>
        <div class="kpi-value" style="color:#E2445C;">{int(row["PRIORITY_CRITICAL"]):,}</div>
    </div>""", unsafe_allow_html=True)
    k4.markdown(f"""<div class="kpi-card">
        <div class="kpi-label">Total Exposure</div>
        <div class="kpi-value">${float(row['TOTAL_AMOUNT']):,.0f}</div>
    </div>""", unsafe_allow_html=True)

    st.markdown("<br>", unsafe_allow_html=True)

    # Charts row
    ch1, ch2 = st.columns(2)

    with ch1:
        st.markdown("**Status Distribution**")
        status_data = items_df.groupby("STATUS").size().reset_index(name="count")
        colors = [STATUS_COLORS.get(s, "#999") for s in status_data["STATUS"]]
        st.vega_lite_chart(status_data, {
            "mark": {"type": "bar", "cornerRadiusTopLeft": 4, "cornerRadiusTopRight": 4},
            "encoding": {
                "x": {"field": "STATUS", "type": "nominal", "sort": "-y", "axis": {"labelAngle": -45, "labelColor": TEXT, "titleColor": TEXT}},
                "y": {"field": "count", "type": "quantitative", "axis": {"labelColor": TEXT, "titleColor": TEXT}},
                "color": {"field": "STATUS", "type": "nominal", "scale": {"domain": status_data["STATUS"].tolist(), "range": colors}, "legend": None}
            },
            "background": "transparent",
            "width": "container",
            "height": 300
        }, use_container_width=True)

    with ch2:
        st.markdown("**Priority Breakdown**")
        priority_data = items_df.groupby("PRIORITY").size().reset_index(name="count")
        p_order = ["CRITICAL", "HIGH", "MEDIUM", "LOW"]
        p_colors = [PRIORITY_COLORS.get(p, "#999") for p in p_order if p in priority_data["PRIORITY"].values]
        p_domain = [p for p in p_order if p in priority_data["PRIORITY"].values]
        st.vega_lite_chart(priority_data, {
            "mark": {"type": "arc", "innerRadius": 50},
            "encoding": {
                "theta": {"field": "count", "type": "quantitative"},
                "color": {"field": "PRIORITY", "type": "nominal", "scale": {"domain": p_domain, "range": p_colors}, "legend": {"labelColor": TEXT, "titleColor": TEXT}}
            },
            "background": "transparent",
            "width": "container",
            "height": 300
        }, use_container_width=True)

    # Amount exposure by status
    st.markdown("**Exposure by Status**")
    amt_data = items_df.groupby("STATUS")["AMOUNT"].sum().reset_index()
    amt_data.columns = ["STATUS", "TOTAL_AMOUNT"]
    amt_colors = [STATUS_COLORS.get(s, "#999") for s in amt_data["STATUS"]]
    st.vega_lite_chart(amt_data, {
        "mark": {"type": "bar", "cornerRadiusTopLeft": 4, "cornerRadiusTopRight": 4},
        "encoding": {
            "x": {"field": "STATUS", "type": "nominal", "sort": "-y", "axis": {"labelAngle": -45, "labelColor": TEXT, "titleColor": TEXT}},
            "y": {"field": "TOTAL_AMOUNT", "type": "quantitative", "axis": {"format": "$,.0f", "labelColor": TEXT, "titleColor": TEXT}, "title": "Total Amount ($)"},
            "color": {"field": "STATUS", "type": "nominal", "scale": {"domain": amt_data["STATUS"].tolist(), "range": amt_colors}, "legend": None}
        },
        "background": "transparent",
        "width": "container",
        "height": 300
    }, use_container_width=True)

    # Customer tier distribution
    st.markdown("**Items by Customer Tier**")
    tier_data = items_df.groupby("CUSTOMER_TIER").size().reset_index(name="count")
    tier_colors = {"VIP": "#A25DDC", "PREMIUM": "#FDAB3D", "STANDARD": "#579BFC", "BASIC": "#C4C4C4"}
    t_dom = [t for t in ["VIP", "PREMIUM", "STANDARD", "BASIC"] if t in tier_data["CUSTOMER_TIER"].values]
    t_col = [tier_colors.get(t, "#999") for t in t_dom]
    st.vega_lite_chart(tier_data, {
        "mark": {"type": "bar", "cornerRadiusTopLeft": 4, "cornerRadiusTopRight": 4},
        "encoding": {
            "x": {"field": "CUSTOMER_TIER", "type": "nominal", "sort": t_dom, "axis": {"labelColor": TEXT, "titleColor": TEXT}},
            "y": {"field": "count", "type": "quantitative", "axis": {"labelColor": TEXT, "titleColor": TEXT}},
            "color": {"field": "CUSTOMER_TIER", "type": "nominal", "scale": {"domain": t_dom, "range": t_col}, "legend": None}
        },
        "background": "transparent",
        "width": "container",
        "height": 250
    }, use_container_width=True)


# ── VIEW: ITEM DETAIL ───────────────────────────────────────
def render_item_detail_view():
    st.markdown(f'<div class="board-header">Item Detail</div>', unsafe_allow_html=True)

    if st.session_state["selected_item_id"] is None:
        # Let user pick an item
        st.info("Select an item to view details.")
        item_ids = items_df["ITEM_ID"].tolist()
        item_labels = items_df["ITEM_NAME"].tolist()
        if item_labels:
            sel = st.selectbox("Choose item", range(len(item_labels)), format_func=lambda i: item_labels[i], key="det_item_select")
            if st.button("View Detail", key="det_open"):
                st.session_state["selected_item_id"] = int(item_ids[sel])
                st.experimental_rerun()
        return

    iid = st.session_state["selected_item_id"]
    item_row = items_df[items_df["ITEM_ID"] == iid]
    if len(item_row) == 0:
        st.error("Item not found.")
        if st.button("Back to Table"):
            st.session_state["selected_item_id"] = None
            st.session_state["current_view"] = "Table"
            st.experimental_rerun()
        return

    item = item_row.iloc[0]

    # Back button
    if st.button("Back to Board"):
        st.session_state["selected_item_id"] = None
        st.session_state["current_view"] = "Table"
        st.experimental_rerun()

    # Header
    st.markdown(f'<div class="item-detail-header">{item["ITEM_NAME"]}</div>', unsafe_allow_html=True)
    st.markdown(f'{status_pill(item["STATUS"])} &nbsp; {priority_pill(item["PRIORITY"])}', unsafe_allow_html=True)

    st.markdown("<br>", unsafe_allow_html=True)

    # Two-column detail
    left, right = st.columns(2)

    with left:
        st.markdown("**Item Properties**")
        st.markdown(f"""
| Property | Value |
|---|---|
| **Status** | {item["STATUS"]} |
| **Priority** | {item["PRIORITY"]} |
| **Assignee** | {item["ASSIGNEE"] if pd.notna(item["ASSIGNEE"]) else "Unassigned"} |
| **Due Date** | {item["DUE_DATE"]} |
| **Amount** | ${item["AMOUNT"]:,.2f} |
| **Source** | {item["SOURCE_TABLE"]} #{item["SOURCE_ID"]} |
| **Created** | {item["CREATED_AT"]} |
| **Updated** | {item["UPDATED_AT"]} |
""")

    with right:
        st.markdown("**Customer Profile**")
        st.markdown(f"""
| Field | Value |
|---|---|
| **Name** | {item["CUSTOMER_NAME"] if pd.notna(item.get("CUSTOMER_NAME")) else "N/A"} |
| **Tier** | {item["CUSTOMER_TIER"] if pd.notna(item.get("CUSTOMER_TIER")) else "N/A"} |
| **Credit Score** | {int(item["CREDIT_SCORE"]) if pd.notna(item.get("CREDIT_SCORE")) else "N/A"} |
| **Risk Score** | {int(item["RISK_SCORE"]) if pd.notna(item.get("RISK_SCORE")) else "N/A"} |
| **Credit Risk** | {item["CREDIT_RISK"] if pd.notna(item.get("CREDIT_RISK")) else "N/A"} |
| **AML Risk** | {item["AML_RISK"] if pd.notna(item.get("AML_RISK")) else "N/A"} |
| **Email** | {item["CUSTOMER_EMAIL"] if pd.notna(item.get("CUSTOMER_EMAIL")) else "N/A"} |
""")

    # AI Insights
    st.markdown("---")
    st.markdown("**AI Insights**")
    ai_data = run_query(f"SELECT * FROM MC_AI_INSIGHTS WHERE ITEM_ID = {iid}")
    if len(ai_data) > 0:
        ai = ai_data.iloc[0]
        st.markdown(f'**Summary:** {ai["AI_SUMMARY"]}')
        st.markdown(f'**Suggested Actions:** {ai["SUGGESTED_ACTIONS"]}')
        st.markdown(f'**AI Priority:** {priority_pill(ai["AUTO_PRIORITY"])}', unsafe_allow_html=True)
    else:
        st.info("No AI insights generated yet. Run AI enrichment to analyze this item.")
        if st.button("Generate AI Insight", key="gen_ai"):
            with st.spinner("Generating AI insight..."):
                try:
                    run_action(f"""
                        INSERT INTO MC_AI_INSIGHTS (ITEM_ID, AI_SUMMARY, SUGGESTED_ACTIONS, AUTO_PRIORITY)
                        SELECT
                            {iid},
                            SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b',
                                'You are a financial operations analyst. Summarize this work item in 2-3 sentences for a manager review. '
                                || 'Item: ' || '{item["ITEM_NAME"].replace("'", "''")}'
                                || ', Status: ' || '{item["STATUS"]}'
                                || ', Priority: ' || '{item["PRIORITY"]}'
                                || ', Amount: $' || '{item["AMOUNT"]:,.2f}'
                                || ', Customer Tier: ' || '{item.get("CUSTOMER_TIER", "N/A")}'
                                || ', Risk Score: ' || '{item.get("RISK_SCORE", "N/A")}'
                            ),
                            SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b',
                                'You are a financial operations analyst. Given this work item, suggest 3 concrete next steps as a numbered list. Be specific and actionable. '
                                || 'Item: ' || '{item["ITEM_NAME"].replace("'", "''")}'
                                || ', Status: ' || '{item["STATUS"]}'
                                || ', Priority: ' || '{item["PRIORITY"]}'
                                || ', Amount: $' || '{item["AMOUNT"]:,.2f}'
                            ),
                            '{item["PRIORITY"]}'
                    """)
                    st.success("AI insight generated!")
                    st.experimental_rerun()
                except Exception as e:
                    st.error(f"AI generation failed: {e}")

    # Updates / Comments
    st.markdown("---")
    st.markdown("**Updates & Comments**")
    updates = run_query(f"SELECT AUTHOR, BODY, CREATED_AT, SENTIMENT_SCORE FROM MC_UPDATES WHERE ITEM_ID = {iid} ORDER BY CREATED_AT DESC")
    if len(updates) > 0:
        for _, upd in updates.iterrows():
            sent_badge = ""
            if pd.notna(upd.get("SENTIMENT_SCORE")):
                s = float(upd["SENTIMENT_SCORE"])
                sent_color = "#00C875" if s > 0.3 else "#E2445C" if s < -0.3 else "#FDAB3D"
                sent_badge = f' <span style="font-size:10px;color:{sent_color};">sentiment: {s:.2f}</span>'
            st.markdown(f"""
            <div class="update-bubble">
                <div class="update-author">{upd["AUTHOR"]}{sent_badge}</div>
                <div class="update-body">{upd["BODY"]}</div>
                <div style="font-size:10px;color:#666;margin-top:4px;">{upd["CREATED_AT"]}</div>
            </div>
            """, unsafe_allow_html=True)
    else:
        st.info("No updates yet.")

    # Add comment
    st.markdown("**Add Comment**")
    users = run_query("SELECT NAME FROM MC_USERS ORDER BY NAME")
    user_names = users["NAME"].tolist()
    comment_user = st.selectbox("As", user_names, key="det_comment_user")
    comment_body = st.text_area("Comment", key="det_comment_body")
    if st.button("Post Comment", key="det_post"):
        if comment_body.strip():
            safe_user = comment_user.replace("'", "''")
            safe_body = comment_body.replace("\\", "\\\\").replace("'", "''")
            run_action(f"CALL MC_ADD_UPDATE({iid}, '{safe_user}', '{safe_body}')")
            st.success("Comment posted!")
            st.experimental_rerun()

    # Quick actions
    st.markdown("---")
    st.markdown("**Quick Actions**")
    act1, act2 = st.columns(2)
    with act1:
        grp_names = groups_df["NAME"].tolist()
        new_status = st.selectbox("Change Status", grp_names, key="det_new_status")
        if st.button("Update Status", key="det_update_status"):
            run_action(f"CALL MC_UPDATE_ITEM_STATUS({iid}, '{new_status}', 1)")
            st.success(f"Status changed to {new_status}")
            st.cache_data.clear()
            st.experimental_rerun()
    with act2:
        new_assignee = st.selectbox("Assign To", user_names, key="det_assign")
        if st.button("Assign", key="det_do_assign"):
            run_action(f"CALL MC_ASSIGN_ITEM({iid}, '{new_assignee}', 1)")
            st.success(f"Assigned to {new_assignee}")
            st.cache_data.clear()
            st.experimental_rerun()


# ── MAIN ROUTER ─────────────────────────────────────────────
view = st.session_state["current_view"]
if view == "Table":
    render_table_view()
elif view == "Kanban":
    render_kanban_view()
elif view == "Dashboard":
    render_dashboard_view()
elif view == "Item Detail":
    render_item_detail_view()
