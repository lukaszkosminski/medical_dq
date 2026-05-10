\echo '1. Kompletność danych zrodlowych MID'
SELECT
    COUNT(*) AS total_records,
    ROUND(100.0 * COUNT(name) / NULLIF(COUNT(*), 0), 2) AS name_completeness_pct,
    ROUND(100.0 * COUNT(link) / NULLIF(COUNT(*), 0), 2) AS link_completeness_pct,
    ROUND(100.0 * COUNT(contains) / NULLIF(COUNT(*), 0), 2) AS contains_completeness_pct,
    ROUND(100.0 * COUNT(chemical_class) / NULLIF(COUNT(*), 0), 2) AS chemical_class_completeness_pct,
    ROUND(100.0 * COUNT(action_class) / NULLIF(COUNT(*), 0), 2) AS action_class_completeness_pct
FROM staging_mid_raw;

\echo '2. Braki danych w wybranych kolumnach'
SELECT * FROM (
    SELECT 'name' AS column_name, COUNT(*) AS total_records, SUM(CASE WHEN name IS NULL OR TRIM(name) = '' THEN 1 ELSE 0 END) AS missing_records FROM staging_mid_raw
    UNION ALL SELECT 'contains', COUNT(*), SUM(CASE WHEN contains IS NULL OR TRIM(contains) = '' THEN 1 ELSE 0 END) FROM staging_mid_raw
    UNION ALL SELECT 'chemical_class', COUNT(*), SUM(CASE WHEN chemical_class IS NULL OR TRIM(chemical_class) = '' THEN 1 ELSE 0 END) FROM staging_mid_raw
    UNION ALL SELECT 'action_class', COUNT(*), SUM(CASE WHEN action_class IS NULL OR TRIM(action_class) = '' THEN 1 ELSE 0 END) FROM staging_mid_raw
) x
ORDER BY missing_records DESC;

\echo '3. Spojnosc Habit_Forming po standaryzacji'
SELECT
    COUNT(*) AS total_records,
    SUM(CASE WHEN habit_forming IN ('YES', 'NO', 'UNKNOWN') THEN 1 ELSE 0 END) AS valid_records,
    ROUND(100.0 * SUM(CASE WHEN habit_forming IN ('YES', 'NO', 'UNKNOWN') THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS habit_forming_consistency_pct
FROM medications;

\echo '4. Rozklad Habit_Forming'
SELECT habit_forming, COUNT(*) AS records_count
FROM medications
GROUP BY habit_forming
ORDER BY records_count DESC;

\echo '5. Unikalnosc nazw lekow po standaryzacji'
SELECT
    COUNT(*) AS total_medication_records,
    COUNT(DISTINCT medication_name_std) AS unique_medication_names,
    ROUND(100.0 * COUNT(DISTINCT medication_name_std) / NULLIF(COUNT(*), 0), 2) AS medication_name_uniqueness_pct
FROM medications;

\echo '6. Duplikaty logiczne nazw lekow w danych surowych'
SELECT
    LOWER(REGEXP_REPLACE(TRIM(name), '\s+', ' ', 'g')) AS medication_name_std,
    COUNT(*) AS duplicate_count
FROM staging_mid_raw
WHERE name IS NOT NULL AND TRIM(name) <> ''
GROUP BY LOWER(REGEXP_REPLACE(TRIM(name), '\s+', ' ', 'g'))
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 20;

\echo '7. Linki o niepoprawnym formacie'
SELECT
    COUNT(*) AS total_records,
    SUM(CASE WHEN link ~ '^https?://' THEN 1 ELSE 0 END) AS valid_links,
    SUM(CASE WHEN link IS NULL OR link !~ '^https?://' THEN 1 ELSE 0 END) AS invalid_links,
    ROUND(100.0 * SUM(CASE WHEN link ~ '^https?://' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 2) AS link_consistency_pct
FROM staging_mid_raw;

\echo '8. Obrazy CT i flaga sztucznego mapowania'
SELECT
    COUNT(*) AS ct_records,
    SUM(CASE WHEN artificial_mapping_flag IS TRUE THEN 1 ELSE 0 END) AS artificial_mappings,
    SUM(CASE WHEN artificial_mapping_flag IS DISTINCT FROM TRUE THEN 1 ELSE 0 END) AS non_artificial_or_missing_flags
FROM ct_images;
