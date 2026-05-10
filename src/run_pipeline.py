from pathlib import Path
from db_utils import run_sql_file
import subprocess
import sys


def run(cmd: list[str]) -> None:
    print("[RUN]", " ".join(cmd))
    subprocess.check_call(cmd)


def main() -> None:
    csv_path = Path("data/processed/mid_raw.csv")
    if not csv_path.exists():
        raise FileNotFoundError("Missing data/processed/mid_raw.csv. Export MID.xlsx to CSV first and place it there.")

    run_sql_file("sql/01_schema.sql")
    run([sys.executable, "src/load_mid_csv.py", "--csv", str(csv_path)])
    run_sql_file("sql/02_load_from_staging.sql")

    ct_root = Path("data/raw/ct")
    has_ct = ct_root.exists() and any(p.is_file() for p in ct_root.rglob("*"))
    if has_ct:
        run([sys.executable, "src/create_ct_mapping.py"])
        run([sys.executable, "src/load_ct_mapping.py"])
        run_sql_file("sql/05_load_ct_mapping.sql")
    else:
        print("[WARN] No CT files found under data/raw/ct. Skipping CT mapping.")

    run_sql_file("sql/06_populate_quality_issues.sql")
    print("[DONE] pipeline completed")


if __name__ == "__main__":
    main()
