# Medical Data Quality Project - kompletne rozwiązanie

Projekt realizuje zadanie dotyczące zarządzania jakością danych medycznych z użyciem narzędzi open source.


## Architektura kontenerów

```text
Kontener 1: PostgreSQL - relacyjna baza danych
Kontener 2: MinIO - storage obiektowy dla plików CT / Data Lakehouse
Kontener 3: App - Python, ETL, preprocessing, mapowanie CT, dashboard Streamlit
```

## Ważne założenie

`MID.xlsx` zawiera jedną tabelę z informacjami o lekach. Nie zawiera prawdziwych pacjentów, wizyt ani badań CT.

Dlatego:

- dane leków pochodzą z `MID.xlsx`,
- pacjenci, wizyty i przypisania leków do pacjentów są sztuczne,
- mapowanie CT do pacjentów jest sztuczne,
- wyników zapytania lek - pacjent - CT nie wolno interpretować klinicznie.

## Narzędzia open source

- PostgreSQL
- MinIO
- Python
- Streamlit
- Docker Compose
- OpenOffice / LibreOffice do konwersji XLSX -> CSV
- SQL

DuckDB nie jest wymagany, jeśli plik `MID.xlsx` został już przekonwertowany do CSV w OpenOffice/LibreOffice.

## Struktura projektu

```text
.
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
├── README.md
├── data/
│   ├── raw/
│   │   └── ct/
│   └── processed/
├── dashboard/
│   └── streamlit_app.py
├── reports/
│   ├── completeness_metrics.csv
│   ├── ct_mapping_summary.csv
│   ├── data_quality_issues_summary.csv
│   ├── html_like_text_issues.csv
│   ├── record_counts.csv
│   └── streamlit_report.pdf
├── sql/
│   ├── 01_schema.sql
│   ├── 02_load_from_staging.sql
│   ├── 03_quality_checks.sql
│   ├── 04_reports.sql
│   ├── 05_load_ct_mapping.sql
│   └── 06_populate_quality_issues.sql
└── src/
    ├── db_utils.py
    ├── load_mid_csv.py
    ├── profile_mid_csv.py
    ├── create_ct_mapping.py
    ├── load_ct_mapping.py
    ├── upload_ct_to_minio.py
    └── run_pipeline.py
```

## Przygotowanie danych

### 1. MID.xlsx

Przekonwertuj `MID.xlsx` do CSV w OpenOffice/LibreOffice i zapisz jako:

```text
data/processed/mid_raw.csv
```

Zalecane opcje eksportu CSV:

```text
Character set: UTF-8
Field delimiter: , albo ;
Text delimiter: "
```

Skrypt `src/load_mid_csv.py` próbuje automatycznie wykryć separator CSV.

### 2. Obrazy CT

Rozpakuj dodatkowy zbiór CT do:

```text
data/raw/ct/
```

Podkatalogi są poprawne, np.:

```text
data/raw/ct/ct_medical_images/dicom_dir/*.dcm
```

## Uruchomienie

### 1. Start kontenerów

```bash
docker compose up -d --build
```

### 2. Pełny pipeline

```bash
docker exec medical_dq_app python src/run_pipeline.py
```

Pipeline wykonuje:

1. utworzenie schematu bazy,
2. załadowanie CSV do `staging_mid_raw`,
3. transformacje do tabel relacyjnych,
4. mapowanie CT, jeżeli pliki są w `data/raw/ct/`,
5. materializację problemów jakości w `data_quality_issues`.

### 3. Opcjonalny upload CT do MinIO

```bash
docker exec medical_dq_app python src/upload_ct_to_minio.py
```

Domyślnie skrypt wysyła maksymalnie 200 plików CT. Limit można zmienić zmienną środowiskową `UPLOAD_LIMIT`.

### 4. Dashboard

Otwórz:

```text
http://localhost:8501
```

### 5. MinIO

Panel MinIO:

```text
http://localhost:9001
```

Dane logowania:

```text
login: minioadmin
hasło: minioadmin
```

## Raporty SQL

Możesz uruchomić raporty przez kontener PostgreSQL:

```bash
docker cp sql/03_quality_checks.sql medical_dq_postgres:/tmp/03_quality_checks.sql
docker exec medical_dq_postgres psql -U postgres -d medical_dq -f /tmp/03_quality_checks.sql
```

```bash
docker cp sql/04_reports.sql medical_dq_postgres:/tmp/04_reports.sql
docker exec medical_dq_postgres psql -U postgres -d medical_dq -f /tmp/04_reports.sql
```

## Zapytanie końcowe: lek -> CT

Przykładowe zapytanie znajduje się w pliku z odpowiedziami w folderze `Doc` i dashboardzie. Logika:

```text
patients -> patient_medications -> medications -> exams -> ct_images
```

Wynik pokazuje wyłącznie techniczne, sztuczne powiązanie.
