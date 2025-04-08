from flask import Flask, request, render_template
import psycopg2
import os
import boto3
from botocore.exceptions import ClientError

app = Flask(__name__)

# Environment variables
DB_HOST = os.environ.get("DB_HOST")
DB_USER = os.environ.get("DB_USER")
DB_PASS = os.environ.get("DB_PASS")
DB_NAME = os.environ.get("DB_NAME", "postgres")
S3_BUCKET = os.environ.get("S3_BUCKET")

@app.route("/")
def home():
    return "Hello from Flask running on EC2 behind ALB!"

@app.route("/db")
def db_check():
    if not all([DB_HOST, DB_USER, DB_PASS]):
        return "Database configuration is missing."

    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASS
        )
        cur = conn.cursor()
        cur.execute("SELECT version();")
        version = cur.fetchone()
        cur.close()
        conn.close()
        return f"Connected to PostgreSQL DB! Version: {version[0]}"
    except Exception as e:
        return f"Failed to connect to DB: {str(e)}"

@app.route("/upload", methods=["GET", "POST"])
def upload_file():
    if request.method == "POST":
        file = request.files.get("file")
        if not file:
            return "No file provided."

        if not S3_BUCKET:
            return "S3 bucket not configured."

        # Optional: Validate file type & size
        allowed_extensions = ('.txt', '.pdf', '.jpg', '.png')
        if not file.filename.endswith(allowed_extensions):
            return "File type not allowed."

        file.seek(0, os.SEEK_END)
        if file.tell() > 5 * 1024 * 1024:
            return "File too large (max 5MB)."
        file.seek(0)

        s3 = boto3.client("s3")
        try:
            s3.upload_fileobj(file, S3_BUCKET, file.filename)
            return f"Uploaded {file.filename} to S3 bucket '{S3_BUCKET}'"
        except ClientError as e:
            return f"Upload failed: {str(e)}"

    return render_template("upload.html")