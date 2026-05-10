import os
import pandas as pd
import streamlit as st
from sqlalchemy import create_engine, text

DB_URL = os.getenv("DB_URL", "postgresql+psycopg2://postgres:postgres@localhost:5432/medical_dq")

st.set_page_config(page_title="Medical Data Quality Dashboard", layout="wide")
st.title("Medical Data Quality Dashboard")
st.caption("MID.xlsx + PostgreSQL + MinIO + Streamlit. CT mapping is artificial for technical testing only.")

@st.cache_resource
def get_engine():
    return create_engine(DB_URL)

engine = get_engine()


def read_sql(query: str, params: dict | None = None) -> pd.DataFrame:
    try:
        return pd.read_sql(text(query), engine, params=params or {})
    except Exception as exc:
        st.error(f"Database query failed: {exc}")
        return pd.DataFrame()

record_counts = read_sql("""
SELECT 'staging_mid_raw' AS table_name, COUNT(*) AS record_count FROM staging_mid_raw
UNION ALL SELECT 'medications', COUNT(*) FROM medications
UNION ALL SELECT 'active_substances', COUNT(*) FROM active_substances
UNION ALL SELECT 'patients', COUNT(*) FROM patients
UNION ALL SELECT 'visits', COUNT(*) FROM visits
UNION ALL SELECT 'patient_medications', COUNT(*) FROM patient_medications
UNION ALL SELECT 'exams', COUNT(*) FROM exams
UNION ALL SELECT 'ct_images', COUNT(*) FROM ct_images
UNION ALL SELECT 'data_quality_issues', COUNT(*) FROM data_quality_issues
ORDER BY table_name;
""")

st.subheader("1. Liczba rekordów")
st.dataframe(record_counts, use_container_width=True)

metrics = read_sql("""
SELECT
    COUNT(*) AS total_records,
    ROUND(100.0 * COUNT(name) / NULLIF(COUNT(*), 0), 2) AS name_completeness_pct,
    ROUND(100.0 * COUNT(contains) / NULLIF(COUNT(*), 0), 2) AS contains_completeness_pct,
    ROUND(100.0 * COUNT(chemical_class) / NULLIF(COUNT(*), 0), 2) AS chemical_class_completeness_pct,
    ROUND(100.0 * COUNT(action_class) / NULLIF(COUNT(*), 0), 2) AS action_class_completeness_pct
FROM staging_mid_raw;
""")
st.subheader("2. Kompletność danych źródłowych")
st.dataframe(metrics, use_container_width=True)

consistency = read_sql("""
SELECT
    COUNT(*) AS total_records,
    SUM(CASE WHEN habit_forming IN ('YES', 'NO', 'UNKNOWN') THEN 1 ELSE 0 END) AS valid_records,
    ROUND(100.0 * SUM(CASE WHEN habit_forming IN ('YES', 'NO', 'UNKNOWN') THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS habit_forming_consistency_pct
FROM medications;
""")
uniqueness = read_sql("""
SELECT
    COUNT(*) AS total_medication_records,
    COUNT(DISTINCT medication_name_std) AS unique_medication_names,
    ROUND(100.0 * COUNT(DISTINCT medication_name_std) / NULLIF(COUNT(*), 0), 2) AS medication_name_uniqueness_pct
FROM medications;
""")
col1, col2 = st.columns(2)
with col1:
    st.subheader("3. Spójność")
    st.dataframe(consistency, use_container_width=True)
with col2:
    st.subheader("4. Unikalność")
    st.dataframe(uniqueness, use_container_width=True)

missing = read_sql("""
SELECT * FROM (
    SELECT 'name' AS column_name, COUNT(*) AS total_records, SUM(CASE WHEN name IS NULL OR TRIM(name) = '' THEN 1 ELSE 0 END) AS missing_records, ROUND(100.0 * SUM(CASE WHEN name IS NULL OR TRIM(name) = '' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS missing_pct FROM staging_mid_raw
    UNION ALL SELECT 'contains', COUNT(*), SUM(CASE WHEN contains IS NULL OR TRIM(contains) = '' THEN 1 ELSE 0 END), ROUND(100.0 * SUM(CASE WHEN contains IS NULL OR TRIM(contains) = '' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) FROM staging_mid_raw
    UNION ALL SELECT 'chemical_class', COUNT(*), SUM(CASE WHEN chemical_class IS NULL OR TRIM(chemical_class) = '' THEN 1 ELSE 0 END), ROUND(100.0 * SUM(CASE WHEN chemical_class IS NULL OR TRIM(chemical_class) = '' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) FROM staging_mid_raw
    UNION ALL SELECT 'action_class', COUNT(*), SUM(CASE WHEN action_class IS NULL OR TRIM(action_class) = '' THEN 1 ELSE 0 END), ROUND(100.0 * SUM(CASE WHEN action_class IS NULL OR TRIM(action_class) = '' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) FROM staging_mid_raw
) x ORDER BY missing_pct DESC;
""")
st.subheader("5. Rozkład braków danych")
st.dataframe(missing, use_container_width=True)

ct = read_sql("""
SELECT
    COUNT(DISTINCT p.patient_id) AS total_test_patients,
    COUNT(DISTINCT c.patient_id) AS patients_with_ct,
    COUNT(c.ct_image_id) AS total_ct_images,
    ROUND(100.0 * COUNT(DISTINCT c.patient_id) / NULLIF(COUNT(DISTINCT p.patient_id), 0), 2) AS patients_with_ct_pct
FROM patients p
LEFT JOIN ct_images c ON c.patient_id = p.patient_id;
""")
st.subheader("6. Powiązania pacjentów testowych z CT")
st.dataframe(ct, use_container_width=True)

issues = read_sql("""
SELECT severity, issue_type, COUNT(*) AS issues_count
FROM data_quality_issues
GROUP BY severity, issue_type
ORDER BY severity, issue_type;
""")
st.subheader("7. Zmaterializowane problemy jakości danych")
st.dataframe(issues, use_container_width=True)

st.subheader("8. Wyszukiwanie CT po leku")
term = st.text_input("Fragment nazwy leku", value="")
if term.strip():
    result = read_sql("""
    SELECT
        p.patient_id,
        p.pseudo_patient_code,
        m.medication_name,
        e.exam_id,
        e.exam_date,
        c.ct_image_id,
        c.storage_uri,
        c.artificial_mapping_flag
    FROM patients p
    JOIN patient_medications pm ON pm.patient_id = p.patient_id
    JOIN medications m ON m.medication_id = pm.medication_id
    JOIN exams e ON e.patient_id = p.patient_id AND e.exam_type = 'CT'
    JOIN ct_images c ON c.exam_id = e.exam_id
    WHERE m.medication_name_std LIKE LOWER(:term)
    LIMIT 100;
    """, {"term": f"%{term}%"})
    st.dataframe(result, use_container_width=True)
    st.warning("Wynik pokazuje tylko techniczne, sztuczne powiązanie. Nie wolno interpretować go klinicznie.")
