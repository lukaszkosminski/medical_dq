\echo 'Raport 1: Liczba rekordow w tabelach'
SELECT 'staging_mid_raw' AS table_name, COUNT(*) AS record_count FROM staging_mid_raw
UNION ALL SELECT 'medications', COUNT(*) FROM medications
UNION ALL SELECT 'active_substances', COUNT(*) FROM active_substances
UNION ALL SELECT 'medication_substances', COUNT(*) FROM medication_substances
UNION ALL SELECT 'patients', COUNT(*) FROM patients
UNION ALL SELECT 'visits', COUNT(*) FROM visits
UNION ALL SELECT 'patient_medications', COUNT(*) FROM patient_medications
UNION ALL SELECT 'exams', COUNT(*) FROM exams
UNION ALL SELECT 'ct_images', COUNT(*) FROM ct_images
UNION ALL SELECT 'data_quality_issues', COUNT(*) FROM data_quality_issues;

\echo 'Raport 2: Braki danych w MID.xlsx / staging_mid_raw'
SELECT * FROM (
    SELECT 'name' AS column_name, COUNT(*) AS total_records, SUM(CASE WHEN name IS NULL OR TRIM(name) = '' THEN 1 ELSE 0 END) AS missing_records, ROUND(100.0 * SUM(CASE WHEN name IS NULL OR TRIM(name) = '' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS missing_pct FROM staging_mid_raw
    UNION ALL SELECT 'contains', COUNT(*), SUM(CASE WHEN contains IS NULL OR TRIM(contains) = '' THEN 1 ELSE 0 END), ROUND(100.0 * SUM(CASE WHEN contains IS NULL OR TRIM(contains) = '' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) FROM staging_mid_raw
    UNION ALL SELECT 'chemical_class', COUNT(*), SUM(CASE WHEN chemical_class IS NULL OR TRIM(chemical_class) = '' THEN 1 ELSE 0 END), ROUND(100.0 * SUM(CASE WHEN chemical_class IS NULL OR TRIM(chemical_class) = '' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) FROM staging_mid_raw
    UNION ALL SELECT 'action_class', COUNT(*), SUM(CASE WHEN action_class IS NULL OR TRIM(action_class) = '' THEN 1 ELSE 0 END), ROUND(100.0 * SUM(CASE WHEN action_class IS NULL OR TRIM(action_class) = '' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) FROM staging_mid_raw
) x ORDER BY missing_pct DESC;

\echo 'Raport 3: Rozklad klas terapeutycznych'
SELECT therapeutic_class, COUNT(*) AS records_count
FROM medications
GROUP BY therapeutic_class
ORDER BY records_count DESC NULLS LAST
LIMIT 20;

\echo 'Raport 4: Powiazania pacjentow testowych z CT'
SELECT
    COUNT(DISTINCT p.patient_id) AS total_test_patients,
    COUNT(DISTINCT c.patient_id) AS patients_with_ct,
    COUNT(c.ct_image_id) AS total_ct_images,
    ROUND(100.0 * COUNT(DISTINCT c.patient_id) / NULLIF(COUNT(DISTINCT p.patient_id), 0), 2) AS patients_with_ct_pct
FROM patients p
LEFT JOIN ct_images c ON c.patient_id = p.patient_id;

\echo 'Raport 5: Przykladowe powiazania lek - pacjent testowy - CT'
SELECT
    p.pseudo_patient_code,
    m.medication_name,
    e.exam_type,
    c.file_name,
    c.storage_uri,
    c.artificial_mapping_flag
FROM patients p
JOIN patient_medications pm ON pm.patient_id = p.patient_id
JOIN medications m ON m.medication_id = pm.medication_id
LEFT JOIN exams e ON e.patient_id = p.patient_id AND e.exam_type = 'CT'
LEFT JOIN ct_images c ON c.exam_id = e.exam_id
ORDER BY p.patient_id
LIMIT 20;
