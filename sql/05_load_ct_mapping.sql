DELETE FROM ct_images;
DELETE FROM exams WHERE exam_type = 'CT';

INSERT INTO exams (patient_id, visit_id, exam_type, exam_date, result_summary, artificial_record_flag)
SELECT DISTINCT
    m.patient_id,
    v.visit_id,
    'CT',
    CURRENT_DATE,
    'Artificial CT exam generated only for technical data integration test',
    TRUE
FROM staging_ct_mapping m
LEFT JOIN visits v ON v.patient_id = m.patient_id
WHERE m.patient_id IS NOT NULL;

INSERT INTO ct_images (
    exam_id,
    patient_id,
    file_name,
    local_file_path,
    storage_uri,
    modality,
    body_part,
    artificial_mapping_flag
)
SELECT
    e.exam_id,
    m.patient_id,
    m.file_name,
    m.local_file_path,
    m.storage_uri,
    COALESCE(NULLIF(m.modality, ''), 'CT'),
    COALESCE(NULLIF(m.body_part, ''), 'UNKNOWN'),
    TRUE
FROM staging_ct_mapping m
JOIN LATERAL (
    SELECT exam_id
    FROM exams e
    WHERE e.patient_id = m.patient_id AND e.exam_type = 'CT'
    ORDER BY e.exam_id
    LIMIT 1
) e ON TRUE
WHERE m.file_name IS NOT NULL AND TRIM(m.file_name) <> '';
