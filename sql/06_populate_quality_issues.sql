TRUNCATE data_quality_issues;

INSERT INTO data_quality_issues (table_name, column_name, record_key, issue_type, severity, issue_message)
SELECT 'staging_mid_raw', 'name', 'ALL', 'MISSING_VALUES', 'CRITICAL', 'Brakujace wartosci w kolumnie Name: ' || COUNT(*) || ' rekordow'
FROM staging_mid_raw
WHERE name IS NULL OR TRIM(name) = ''
HAVING COUNT(*) > 0;

INSERT INTO data_quality_issues (table_name, column_name, record_key, issue_type, severity, issue_message)
SELECT 'staging_mid_raw', 'contains', 'ALL', 'MISSING_VALUES', 'MAJOR', 'Brakujace wartosci w kolumnie Contains: ' || COUNT(*) || ' rekordow'
FROM staging_mid_raw
WHERE contains IS NULL OR TRIM(contains) = ''
HAVING COUNT(*) > 0;

INSERT INTO data_quality_issues (table_name, column_name, record_key, issue_type, severity, issue_message)
SELECT 'staging_mid_raw', 'chemical_class', 'ALL', 'MISSING_VALUES', 'MAJOR', 'Brakujace wartosci w kolumnie Chemical_Class: ' || COUNT(*) || ' rekordow'
FROM staging_mid_raw
WHERE chemical_class IS NULL OR TRIM(chemical_class) = ''
HAVING COUNT(*) > 0;

INSERT INTO data_quality_issues (table_name, column_name, record_key, issue_type, severity, issue_message)
SELECT 'staging_mid_raw', 'action_class', 'ALL', 'MISSING_VALUES', 'MAJOR', 'Brakujace wartosci w kolumnie Action_Class: ' || COUNT(*) || ' rekordow'
FROM staging_mid_raw
WHERE action_class IS NULL OR TRIM(action_class) = ''
HAVING COUNT(*) > 0;

INSERT INTO data_quality_issues (table_name, column_name, record_key, issue_type, severity, issue_message)
SELECT
    'staging_mid_raw', 'habit_forming', COALESCE(habit_forming, 'NULL'), 'INVALID_DICTIONARY_VALUE', 'MAJOR',
    'Wartosc Habit_Forming spoza slownika Yes/No: ' || COALESCE(habit_forming, 'NULL') || ', liczba rekordow: ' || COUNT(*)
FROM staging_mid_raw
WHERE habit_forming IS NOT NULL AND TRIM(habit_forming) <> '' AND LOWER(TRIM(habit_forming)) NOT IN ('yes', 'no')
GROUP BY habit_forming;

INSERT INTO data_quality_issues (table_name, column_name, record_key, issue_type, severity, issue_message)
SELECT
    'staging_mid_raw', 'name', medication_name_std, 'DUPLICATE_VALUE', 'MAJOR',
    'Duplikat nazwy leku po standaryzacji: ' || medication_name_std || ', liczba wystapien: ' || COUNT(*)
FROM (
    SELECT LOWER(REGEXP_REPLACE(TRIM(name), '\s+', ' ', 'g')) AS medication_name_std
    FROM staging_mid_raw
    WHERE name IS NOT NULL AND TRIM(name) <> ''
) s
GROUP BY medication_name_std
HAVING COUNT(*) > 1;

INSERT INTO data_quality_issues (table_name, column_name, record_key, issue_type, severity, issue_message)
SELECT 'staging_mid_raw', 'link', 'ALL', 'INVALID_FORMAT', 'MAJOR', 'Niepoprawny format URL w kolumnie Link: ' || COUNT(*) || ' rekordow'
FROM staging_mid_raw
WHERE link IS NULL OR link !~ '^https?://'
HAVING COUNT(*) > 0;

INSERT INTO data_quality_issues (table_name, column_name, record_key, issue_type, severity, issue_message)
SELECT
    'staging_mid_raw', 'text_description_fields', 'ALL', 'UNCLEAN_TEXT', 'MINOR',
    'Rekordy z podejrzeniem HTML lub sladow scrapingu w polach opisowych: ' || COUNT(*) || ' rekordow'
FROM staging_mid_raw
WHERE COALESCE(product_introduction, '') || COALESCE(product_uses, '') || COALESCE(product_benefits, '') || COALESCE(side_effect, '') || COALESCE(how_to_use, '') || COALESCE(how_works, '') || COALESCE(quick_tips, '') || COALESCE(safety_advice, '') ~* '(<[^>]+>|span style|p dir=|ul "")'
HAVING COUNT(*) > 0;

INSERT INTO data_quality_issues (table_name, column_name, record_key, issue_type, severity, issue_message)
SELECT 'ct_images', 'ct_image_id', 'ALL', 'MISSING_CT_MAPPING', 'MAJOR', 'Brak zaladowanych rekordow CT w tabeli ct_images'
WHERE NOT EXISTS (SELECT 1 FROM ct_images);

INSERT INTO data_quality_issues (table_name, column_name, record_key, issue_type, severity, issue_message)
SELECT 'ct_images', 'artificial_mapping_flag', 'ALL', 'MISSING_ARTIFICIAL_MAPPING_FLAG', 'MAJOR', 'Rekordy CT bez artificial_mapping_flag = TRUE: ' || COUNT(*) || ' rekordow'
FROM ct_images
WHERE artificial_mapping_flag IS DISTINCT FROM TRUE
HAVING COUNT(*) > 0;
