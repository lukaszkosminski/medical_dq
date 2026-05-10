from pathlib import Path
from db_utils import connect


def main() -> None:
    csv_path = Path("data/processed/ct_patient_mapping.csv")
    if not csv_path.exists():
        raise FileNotFoundError(csv_path)
    with connect() as conn:
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute("TRUNCATE staging_ct_mapping;")
            with csv_path.open("r", encoding="utf-8", newline="") as f:
                cur.copy_expert("COPY staging_ct_mapping FROM STDIN WITH (FORMAT csv, HEADER true)", f)
            cur.execute("SELECT COUNT(*) FROM staging_ct_mapping;")
            count = cur.fetchone()[0]
    print(f"[OK] loaded {count} rows into staging_ct_mapping")


if __name__ == "__main__":
    main()
