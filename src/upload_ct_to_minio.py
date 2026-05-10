import os
from pathlib import Path
import boto3
from botocore.client import Config

CT_EXTENSIONS = {".dcm", ".tif", ".tiff", ".png", ".jpg", ".jpeg"}


def main() -> None:
    endpoint = os.getenv("MINIO_ENDPOINT", "http://localhost:9000")
    access_key = os.getenv("MINIO_ACCESS_KEY", "minioadmin")
    secret_key = os.getenv("MINIO_SECRET_KEY", "minioadmin")
    bucket = os.getenv("MINIO_BUCKET", "medical-lakehouse")
    ct_root = Path(os.getenv("CT_ROOT", "data/raw/ct"))
    limit = int(os.getenv("UPLOAD_LIMIT", "200"))

    if not ct_root.exists():
        raise FileNotFoundError(ct_root)

    client = boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(signature_version="s3v4"),
        region_name="us-east-1",
    )

    existing = [b["Name"] for b in client.list_buckets().get("Buckets", [])]
    if bucket not in existing:
        client.create_bucket(Bucket=bucket)
        print(f"[OK] created bucket: {bucket}")

    files = sorted([p for p in ct_root.rglob("*") if p.is_file() and p.suffix.lower() in CT_EXTENSIONS])[:limit]
    for file_path in files:
        modality_folder = "dicom" if file_path.suffix.lower() == ".dcm" else "other"
        key = f"bronze/ct/{modality_folder}/{file_path.name}"
        client.upload_file(str(file_path), bucket, key)
        print(f"[OK] uploaded s3://{bucket}/{key}")
    print(f"[DONE] uploaded {len(files)} files to MinIO. Limit={limit}")


if __name__ == "__main__":
    main()
