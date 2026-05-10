TRUNCATE medication_substances, active_substances, medication_descriptions, patient_medications, visits, patients, exams, ct_images, medications RESTART IDENTITY CASCADE;

INSERT INTO medications (
    medication_name,
    medication_name_std,
    source_link,
    contains_raw,
    chemical_class,
    habit_forming,
    therapeutic_class,
    action_class,
    dosage_form,
    strength_text
)
SELECT DISTINCT ON (LOWER(REGEXP_REPLACE(TRIM(name), '\s+', ' ', 'g')))
    REGEXP_REPLACE(TRIM(name), '\s+', ' ', 'g') AS medication_name,
    LOWER(REGEXP_REPLACE(TRIM(name), '\s+', ' ', 'g')) AS medication_name_std,
    NULLIF(TRIM(link), '') AS source_link,
    NULLIF(TRIM(contains), '') AS contains_raw,
    NULLIF(REGEXP_REPLACE(TRIM(chemical_class), '\s+', ' ', 'g'), '') AS chemical_class,
    CASE
        WHEN LOWER(TRIM(habit_forming)) = 'yes' THEN 'YES'
        WHEN LOWER(TRIM(habit_forming)) = 'no' THEN 'NO'
        ELSE 'UNKNOWN'
    END AS habit_forming,
    CASE
        WHEN UPPER(TRIM(therapeutic_class)) = 'CARDIA' THEN 'CARDIAC'
        WHEN UPPER(TRIM(therapeutic_class)) = 'RESPIRATOR' THEN 'RESPIRATORY'
        WHEN UPPER(TRIM(therapeutic_class)) = 'ANTI INFECTIVE' THEN 'ANTI INFECTIVES'
        WHEN UPPER(TRIM(therapeutic_class)) = 'NEURO CN' THEN 'NEURO CNS'
        ELSE NULLIF(UPPER(REGEXP_REPLACE(TRIM(therapeutic_class), '\s+', ' ', 'g')), '')
    END AS therapeutic_class,
    NULLIF(UPPER(REGEXP_REPLACE(TRIM(action_class), '\s+', ' ', 'g')), '') AS action_class,
    NULL AS dosage_form,
    (regexp_match(name, '([0-9]+(\.[0-9]+)?\s?(mg|ml|mcg|g|iu|%)?)', 'i'))[1] AS strength_text
FROM staging_mid_raw
WHERE name IS NOT NULL AND TRIM(name) <> ''
ORDER BY LOWER(REGEXP_REPLACE(TRIM(name), '\s+', ' ', 'g')), link NULLS LAST;

INSERT INTO medication_descriptions (
    medication_id,
    product_introduction,
    product_uses,
    product_benefits,
    side_effect,
    how_to_use,
    how_works,
    quick_tips,
    safety_advice
)
SELECT
    m.medication_id,
    NULLIF(REGEXP_REPLACE(TRIM(s.product_introduction), '\s+', ' ', 'g'), ''),
    NULLIF(REGEXP_REPLACE(TRIM(s.product_uses), '\s+', ' ', 'g'), ''),
    NULLIF(REGEXP_REPLACE(TRIM(s.product_benefits), '\s+', ' ', 'g'), ''),
    NULLIF(REGEXP_REPLACE(TRIM(s.side_effect), '\s+', ' ', 'g'), ''),
    NULLIF(REGEXP_REPLACE(TRIM(s.how_to_use), '\s+', ' ', 'g'), ''),
    NULLIF(REGEXP_REPLACE(TRIM(s.how_works), '\s+', ' ', 'g'), ''),
    NULLIF(REGEXP_REPLACE(TRIM(s.quick_tips), '\s+', ' ', 'g'), ''),
    NULLIF(REGEXP_REPLACE(TRIM(s.safety_advice), '\s+', ' ', 'g'), '')
FROM medications m
JOIN LATERAL (
    SELECT *
    FROM staging_mid_raw s
    WHERE LOWER(REGEXP_REPLACE(TRIM(s.name), '\s+', ' ', 'g')) = m.medication_name_std
    LIMIT 1
) s ON TRUE;

WITH split_substances AS (
    SELECT DISTINCT
        m.medication_id,
        REGEXP_REPLACE(TRIM(part), '\s+', ' ', 'g') AS substance_name,
        LOWER(REGEXP_REPLACE(TRIM(part), '\s+', ' ', 'g')) AS substance_name_std
    FROM medications m,
    LATERAL regexp_split_to_table(COALESCE(m.contains_raw, ''), '\s*(\+|,|/|;)\s*') AS part
    WHERE TRIM(part) <> ''
)
INSERT INTO active_substances (substance_name, substance_name_std)
SELECT DISTINCT ON (substance_name_std)
    substance_name,
    substance_name_std
FROM split_substances
WHERE substance_name_std <> ''
ON CONFLICT (substance_name_std) DO NOTHING;

WITH split_substances AS (
    SELECT DISTINCT
        m.medication_id,
        LOWER(REGEXP_REPLACE(TRIM(part), '\s+', ' ', 'g')) AS substance_name_std
    FROM medications m,
    LATERAL regexp_split_to_table(COALESCE(m.contains_raw, ''), '\s*(\+|,|/|;)\s*') AS part
    WHERE TRIM(part) <> ''
)
INSERT INTO medication_substances (medication_id, substance_id)
SELECT DISTINCT
    ss.medication_id,
    a.substance_id
FROM split_substances ss
JOIN active_substances a ON a.substance_name_std = ss.substance_name_std
ON CONFLICT DO NOTHING;

-- Dane testowe wymagane przez zadanie: pacjenci, wizyty i przypisania lekow.
INSERT INTO patients (pseudo_patient_code, gender, age, artificial_record_flag)
SELECT
    'P' || LPAD(gs::text, 6, '0') AS pseudo_patient_code,
    CASE WHEN gs % 3 = 0 THEN 'F' WHEN gs % 3 = 1 THEN 'M' ELSE 'UNKNOWN' END AS gender,
    18 + (gs % 73) AS age,
    TRUE
FROM generate_series(1, 500) AS gs;

INSERT INTO visits (patient_id, visit_date, diagnosis, artificial_record_flag)
SELECT
    patient_id,
    DATE '2024-01-01' + ((patient_id % 365)::int) AS visit_date,
    'Artificial test visit generated for relational model',
    TRUE
FROM patients;

INSERT INTO patient_medications (patient_id, visit_id, medication_id, start_date, end_date, artificial_record_flag)
SELECT
    p.patient_id,
    v.visit_id,
    m.medication_id,
    v.visit_date,
    NULL,
    TRUE
FROM patients p
JOIN visits v ON v.patient_id = p.patient_id
JOIN LATERAL (
    SELECT medication_id
    FROM medications
    ORDER BY medication_id
    OFFSET ((p.patient_id - 1) % GREATEST((SELECT COUNT(*) FROM medications), 1))
    LIMIT 1
) m ON TRUE;
