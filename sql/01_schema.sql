DROP TABLE IF EXISTS data_quality_issues CASCADE;
DROP TABLE IF EXISTS ct_images CASCADE;
DROP TABLE IF EXISTS exams CASCADE;
DROP TABLE IF EXISTS staging_ct_mapping CASCADE;
DROP TABLE IF EXISTS patient_medications CASCADE;
DROP TABLE IF EXISTS visits CASCADE;
DROP TABLE IF EXISTS patients CASCADE;
DROP TABLE IF EXISTS medication_substances CASCADE;
DROP TABLE IF EXISTS active_substances CASCADE;
DROP TABLE IF EXISTS medication_descriptions CASCADE;
DROP TABLE IF EXISTS medications CASCADE;
DROP TABLE IF EXISTS staging_mid_raw CASCADE;

CREATE TABLE staging_mid_raw (
    name TEXT,
    link TEXT,
    contains TEXT,
    product_introduction TEXT,
    product_uses TEXT,
    product_benefits TEXT,
    side_effect TEXT,
    how_to_use TEXT,
    how_works TEXT,
    quick_tips TEXT,
    safety_advice TEXT,
    chemical_class TEXT,
    habit_forming TEXT,
    therapeutic_class TEXT,
    action_class TEXT
);

CREATE TABLE medications (
    medication_id BIGSERIAL PRIMARY KEY,
    medication_name TEXT NOT NULL,
    medication_name_std TEXT NOT NULL UNIQUE,
    source_link TEXT,
    contains_raw TEXT,
    chemical_class TEXT,
    habit_forming TEXT NOT NULL DEFAULT 'UNKNOWN' CHECK (habit_forming IN ('YES', 'NO', 'UNKNOWN')),
    therapeutic_class TEXT,
    action_class TEXT,
    dosage_form TEXT,
    strength_text TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE medication_descriptions (
    description_id BIGSERIAL PRIMARY KEY,
    medication_id BIGINT NOT NULL UNIQUE REFERENCES medications(medication_id) ON DELETE CASCADE,
    product_introduction TEXT,
    product_uses TEXT,
    product_benefits TEXT,
    side_effect TEXT,
    how_to_use TEXT,
    how_works TEXT,
    quick_tips TEXT,
    safety_advice TEXT
);

CREATE TABLE active_substances (
    substance_id BIGSERIAL PRIMARY KEY,
    substance_name TEXT NOT NULL,
    substance_name_std TEXT NOT NULL UNIQUE
);

CREATE TABLE medication_substances (
    medication_id BIGINT NOT NULL REFERENCES medications(medication_id) ON DELETE CASCADE,
    substance_id BIGINT NOT NULL REFERENCES active_substances(substance_id) ON DELETE CASCADE,
    PRIMARY KEY (medication_id, substance_id)
);

CREATE TABLE patients (
    patient_id BIGSERIAL PRIMARY KEY,
    pseudo_patient_code TEXT NOT NULL UNIQUE,
    gender TEXT CHECK (gender IN ('M', 'F', 'OTHER', 'UNKNOWN')) DEFAULT 'UNKNOWN',
    age INTEGER CHECK (age BETWEEN 0 AND 120),
    artificial_record_flag BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE visits (
    visit_id BIGSERIAL PRIMARY KEY,
    patient_id BIGINT NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
    visit_date DATE NOT NULL,
    diagnosis TEXT,
    artificial_record_flag BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE patient_medications (
    patient_medication_id BIGSERIAL PRIMARY KEY,
    patient_id BIGINT NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
    visit_id BIGINT REFERENCES visits(visit_id) ON DELETE CASCADE,
    medication_id BIGINT NOT NULL REFERENCES medications(medication_id),
    start_date DATE,
    end_date DATE,
    artificial_record_flag BOOLEAN NOT NULL DEFAULT TRUE,
    CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

CREATE TABLE exams (
    exam_id BIGSERIAL PRIMARY KEY,
    patient_id BIGINT NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
    visit_id BIGINT REFERENCES visits(visit_id) ON DELETE SET NULL,
    exam_type TEXT NOT NULL,
    exam_date DATE NOT NULL,
    result_summary TEXT,
    artificial_record_flag BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE staging_ct_mapping (
    patient_id BIGINT,
    file_name TEXT,
    local_file_path TEXT,
    storage_uri TEXT,
    modality TEXT,
    body_part TEXT,
    artificial_mapping_flag BOOLEAN
);

CREATE TABLE ct_images (
    ct_image_id BIGSERIAL PRIMARY KEY,
    exam_id BIGINT NOT NULL REFERENCES exams(exam_id) ON DELETE CASCADE,
    patient_id BIGINT NOT NULL REFERENCES patients(patient_id) ON DELETE CASCADE,
    file_name TEXT NOT NULL,
    local_file_path TEXT,
    storage_uri TEXT NOT NULL,
    modality TEXT DEFAULT 'CT',
    body_part TEXT DEFAULT 'UNKNOWN',
    artificial_mapping_flag BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE data_quality_issues (
    issue_id BIGSERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    column_name TEXT,
    record_key TEXT,
    issue_type TEXT NOT NULL,
    severity TEXT CHECK (severity IN ('CRITICAL', 'MAJOR', 'MINOR')),
    issue_message TEXT,
    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_medications_name_std ON medications(medication_name_std);
CREATE INDEX idx_substances_name_std ON active_substances(substance_name_std);
CREATE INDEX idx_patient_medications_patient ON patient_medications(patient_id);
CREATE INDEX idx_patient_medications_medication ON patient_medications(medication_id);
CREATE INDEX idx_exams_patient ON exams(patient_id);
CREATE INDEX idx_ct_images_patient ON ct_images(patient_id);
CREATE INDEX idx_ct_images_exam ON ct_images(exam_id);
