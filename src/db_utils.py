import os
import time
from pathlib import Path
import psycopg2
from psycopg2 import sql

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": int(os.getenv("DB_PORT", "5432")),
    "dbname": os.getenv("DB_NAME", "medical_dq"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD", "postgres"),
}


def connect(retries: int = 30, delay: float = 2.0):
    last_error = None
    for _ in range(retries):
        try:
            return psycopg2.connect(**DB_CONFIG)
        except Exception as exc:
            last_error = exc
            time.sleep(delay)
    raise RuntimeError(f"Could not connect to PostgreSQL: {last_error}")


def run_sql_file(path: str | Path) -> None:
    path = Path(path)
    with connect() as conn:
        conn.autocommit = True
        with conn.cursor() as cur:
            cur.execute(path.read_text(encoding="utf-8"))
    print(f"[OK] executed {path}")
