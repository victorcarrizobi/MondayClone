# MondayClone -- Gotcha File

> Inherited gotchas from Project 1 (SupplyChainMonitor) are pre-loaded. Project-specific gotchas will be added below.

---

## Inherited: SiS Compatibility Rules

- Use `st.experimental_rerun()` not `st.rerun()`
- Use `st.vega_lite_chart` not `st.bar_chart(color=)`
- No `st.download_button` in SiS
- No `default=` on widgets when using session state
- Use `style.map()` not `style.applymap()`
- Create stage before CREATE STREAMLIT; use AUTO_COMPRESS=FALSE
- AI_COMPLETE model: `llama3.1-8b` only
- Grant ATTENDEE_ROLE direct access before creating DTs/Tasks/Alerts
- No CURRENT_TIMESTAMP() in Dynamic Table definitions

---

## Project-Specific Gotchas

(none yet)
