import argparse
import json
from pathlib import Path
import pandas as pd


def main() -> None:
    parser = argparse.ArgumentParser(description="Profile MID CSV exported from MID.xlsx.")
    parser.add_argument("--csv", default="data/processed/mid_raw.csv")
    parser.add_argument("--limit", type=int, default=10000, help="Rows to profile. 0 means full file.")
    parser.add_argument("--delimiter", default=None)
    parser.add_argument("--output", default="reports/mid_profile.json")
    args = parser.parse_args()

    csv_path = Path(args.csv)
    if not csv_path.exists():
        raise FileNotFoundError(csv_path)

    nrows = None if args.limit == 0 else args.limit
    df = pd.read_csv(csv_path, sep=args.delimiter, nrows=nrows, dtype=str, engine="python")

    profile = {
        "source": str(csv_path),
        "profiled_rows": int(len(df)),
        "columns": list(df.columns),
        "column_count": int(len(df.columns)),
        "missing": {},
        "unique": {},
    }
    for col in df.columns:
        profile["missing"][col] = {
            "count": int(df[col].isna().sum() + (df[col].fillna("").astype(str).str.strip() == "").sum()),
            "pct": round(float(((df[col].isna()) | (df[col].fillna("").astype(str).str.strip() == "")).mean() * 100), 2),
        }
        profile["unique"][col] = int(df[col].nunique(dropna=True))

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(profile, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(profile, ensure_ascii=False, indent=2))
    print(f"[OK] profile saved to {out}")


if __name__ == "__main__":
    main()
