import argparse
import csv
from pathlib import Path
from db_utils import connect

EXPECTED_COLUMNS = [
    "Name", "Link", "Contains", "ProductIntroduction", "ProductUses",
    "ProductBenefits", "SideEffect", "HowToUse", "HowWorks", "QuickTips",
    "SafetyAdvice", "Chemical_Class", "Habit_Forming", "Therapeutic_Class", "Action_Class"
]


def sniff_delimiter(csv_path: Path) -> str:
    sample = csv_path.read_text(encoding="utf-8", errors="ignore")[:8192]
    try:
        dialect = csv.Sniffer().sniff(sample, delimiters=[",", ";", "\t", "|"])
        return dialect.delimiter
    except Exception:
        return ","


def main() -> None:
    parser = argparse.ArgumentParser(description="Load MID CSV into PostgreSQL staging_mid_raw.")
    parser.add_argument("--csv", default="data/processed/mid_raw.csv", help="Path to CSV exported from MID.xlsx")
    parser.add_argument("--delimiter", default=None, help="CSV delimiter. If not set, script will try to detect it.")
    args = parser.parse_args()

    csv_path = Path(args.csv)
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV not found: {csv_path}")

    delimiter = args.delimiter or sniff_delimiter(csv_path)
    print(f"[INFO] CSV path: {csv_path}")
    print(f"[INFO] Detected delimiter: {repr(delimiter)}")

    with csv_path.open("r", encoding="utf-8", errors="replace", newline="") as f:
        reader = csv.reader(f, delimiter=delimiter)
        header = next(reader)
    print(f"[INFO] CSV columns: {header}")
    if len(header) != 15:
        print("[WARN] CSV should have 15 columns. Check delimiter and export options from OpenOffice/LibreOffice.")

    with connect() as conn:
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute("TRUNCATE staging_mid_raw;")
            with csv_path.open("r", encoding="utf-8", errors="replace", newline="") as f:
                copy_sql = f"COPY staging_mid_raw FROM STDIN WITH (FORMAT csv, HEADER true, DELIMITER '{delimiter}', QUOTE '\"', ESCAPE '\"')"
                cur.copy_expert(copy_sql, f)
            cur.execute("SELECT COUNT(*) FROM staging_mid_raw;")
            count = cur.fetchone()[0]
    print(f"[OK] loaded {count} rows into staging_mid_raw")


if __name__ == "__main__":
    main()
