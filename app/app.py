"""
Flask web application for Part II of the Cloud and DevOps Engineering project.

Two pages:
  - Web Page 1 ("/")       : lists all blobs in the storage container, each with
                             a direct download link, plus a link to Web Page 2.
  - Web Page 2 ("/upload") : a form to upload a new file/image to the container.

Authentication to Azure Storage uses DefaultAzureCredential, which means:
  - When running on Azure App Service: it automatically uses the Web App's
    System-Assigned Managed Identity. No secret, key, or connection string
    is ever read or stored by this application.
  - When running locally (for development/testing): it falls back to your
    own `az login` session, so you can test without any Azure credentials
    in code or in a .env file.

Configuration (read from environment variables, set as App Settings in
Terraform - see modules/appservice/main.tf):
  - AZURE_STORAGE_ACCOUNT_NAME : name of the Storage Account
  - AZURE_STORAGE_CONTAINER_NAME : name of the Blob Container (default: images)
  - KEY_VAULT_URI : URI of the Key Vault (not required for storage access,
    kept here only if the app is later extended to read additional secrets)
"""

import os
import logging
from datetime import datetime, timedelta, timezone

from flask import Flask, render_template, request, redirect, url_for, flash
from werkzeug.utils import secure_filename

from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient, generate_blob_sas, BlobSasPermissions
from azure.core.exceptions import ResourceNotFoundError, HttpResponseError

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
# Used only to flash form-validation messages between requests; not a secret.
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "dev-secret-key-not-for-production")

# ── Configuration ────────────────────────────────────────────────────────
STORAGE_ACCOUNT_NAME = os.environ.get("AZURE_STORAGE_ACCOUNT_NAME")
CONTAINER_NAME = os.environ.get("AZURE_STORAGE_CONTAINER_NAME", "images")
MAX_CONTENT_LENGTH_MB = int(os.environ.get("MAX_UPLOAD_MB", "20"))

ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "gif", "webp", "bmp", "txt", "pdf"}

app.config["MAX_CONTENT_LENGTH"] = MAX_CONTENT_LENGTH_MB * 1024 * 1024


def get_blob_service_client() -> BlobServiceClient:
    """
    Build a BlobServiceClient authenticated via Managed Identity (on Azure)
    or the developer's `az login` session (locally). No account key or
    connection string is used anywhere in this application.
    """
    if not STORAGE_ACCOUNT_NAME:
        raise RuntimeError(
            "AZURE_STORAGE_ACCOUNT_NAME is not set. "
            "This must be configured as an App Setting (see Terraform appservice module)."
        )
    account_url = f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net"
    credential = DefaultAzureCredential()
    return BlobServiceClient(account_url=account_url, credential=credential)


def allowed_file(filename: str) -> bool:
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


def human_readable_size(num_bytes: int) -> str:
    """Convert a byte count into a human-readable string (KB/MB/GB)."""
    size = float(num_bytes)
    for unit in ["B", "KB", "MB", "GB"]:
        if size < 1024:
            return f"{size:.1f} {unit}"
        size /= 1024
    return f"{size:.1f} TB"


# ── Web Page 1: list all blobs with download links ──────────────────────
@app.route("/")
def index():
    try:
        service_client = get_blob_service_client()
        container_client = service_client.get_container_client(CONTAINER_NAME)

        files = []
        for blob in container_client.list_blobs():
            files.append(
                {
                    "name": blob.name,
                    "size": human_readable_size(blob.size or 0),
                    "last_modified": blob.last_modified.strftime("%Y-%m-%d %H:%M")
                    if blob.last_modified
                    else "-",
                    "url": container_client.get_blob_client(blob.name).url,
                }
            )
        files.sort(key=lambda f: f["name"].lower())

        return render_template("index.html", files=files, error=None)

    except Exception as exc:  # noqa: BLE001 - surfaced to the page for diagnostics
        logger.exception("Failed to list blobs")
        return render_template("index.html", files=[], error=str(exc))


# ── Web Page 2: upload form ──────────────────────────────────────────────
@app.route("/upload", methods=["GET", "POST"])
def upload():
    if request.method == "GET":
        return render_template("upload.html")

    # POST: handle the actual upload
    if "file" not in request.files:
        flash("No file part in the request.", "error")
        return redirect(url_for("upload"))

    file = request.files["file"]

    if file.filename == "":
        flash("No file selected.", "error")
        return redirect(url_for("upload"))

    if not allowed_file(file.filename):
        flash(
            f"File type not allowed. Allowed types: {', '.join(sorted(ALLOWED_EXTENSIONS))}",
            "error",
        )
        return redirect(url_for("upload"))

    filename = secure_filename(file.filename)

    try:
        service_client = get_blob_service_client()
        container_client = service_client.get_container_client(CONTAINER_NAME)
        blob_client = container_client.get_blob_client(filename)

        blob_client.upload_blob(
            file.stream,
            overwrite=True,
            content_settings=None,
        )

        flash(f'File "{filename}" uploaded successfully.', "success")
        return redirect(url_for("index"))

    except Exception as exc:  # noqa: BLE001
        logger.exception("Failed to upload blob")
        flash(f"Upload failed: {exc}", "error")
        return redirect(url_for("upload"))


# ── Health check (useful for App Service / pipeline smoke tests) ────────
@app.route("/healthz")
def healthz():
    return {"status": "ok"}, 200


if __name__ == "__main__":
    # Local development only. On App Service, gunicorn (see startup command)
    # serves the app instead of Flask's built-in dev server.
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8000)), debug=True)
