import csv
import os
import random
from pathlib import Path
from db_utils import connect

CT_EXTENSIONS = {".dcm", ".tif", ".tiff", ".png", ".jpg", ".jpeg"}


def get_patient_ids() -> list[int]:
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT patient_id FROM patients ORDER BY patient_id;")
            return [row[0] for row in cur.fetchall()]


def main() -> None:
    ct_root = Path(os.getenv("CT_ROOT", "data/raw/ct"))
    out_path = Path(os.getenv("CT_MAPPING_OUTPUT", "data/processed/ct_patient_mapping.csv"))
    bucket = os.getenv("MINIO_BUCKET", "medical-lakehouse")

    if not ct_root.exists():
        raise FileNotFoundError(f"CT folder does not exist: {ct_root}")

    files = sorted([p for p in ct_root.rglob("*") if p.is_file() and p.suffix.lower() in CT_EXTENSIONS])
    if not files:
        raise RuntimeError(f"No CT image files found under {ct_root}. Expected extensions: {sorted(CT_EXTENSIONS)}")

    patient_ids = get_patient_ids()
    if not patient_ids:
        raise RuntimeError("No patients found. Run sql/02_load_from_staging.sql first.")

    random.seed(42)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    with out_path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["patient_id", "file_name", "local_file_path", "storage_uri", "modality", "body_part", "artificial_mapping_flag"],
        )
        writer.writeheader()
        for file_path in files:
            patient_id = random.choice(patient_ids)
            relative_name = file_path.name
            modality_folder = "dicom" if file_path.suffix.lower() == ".dcm" else "other"
            storage_uri = f"s3://{bucket}/bronze/ct/{modality_folder}/{relative_name}"
            writer.writerow({
                "patient_id": patient_id,
                "file_name": relative_name,
                "local_file_path": str(file_path),
                "storage_uri": storage_uri,
                "modality": "CT",
                "body_part": "UNKNOWN",
                "artificial_mapping_flag": "true",
            })

    print(f"[OK] wrote {len(files)} artificial CT mappings to {out_path}")
    print("[INFO] Mapping is artificial and must not be interpreted clinically.")


if __name__ == "__main__":
    main()
