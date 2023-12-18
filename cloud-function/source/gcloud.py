from typing import Union

import google_crc32c  # type: ignore
from google.cloud import secretmanager, storage


def access_secret_version(
    project_id: str, secret_id: str, version_id: str = "latest"
) -> str:
    """Access the payload for the given secret version if one exists. The version
    can be a version number as a string (e.g. "5") or an alias (e.g. "latest").

    Args:
        project_id (str): The ID of your Google Cloud project.
        secret_id (str): The ID of your secret in Secret Manager.
        version_id (str, optional): The version ID of secret to access.
         Defaults to "latest".

    Returns:
        str: Secret value.
    """

    # Create the Secret Manager client.
    client = secretmanager.SecretManagerServiceClient()

    # Build the resource name of the secret version.
    name = f"projects/{project_id}/secrets/{secret_id}/versions/{version_id}"

    # Access the secret version.
    response = client.access_secret_version(request={"name": name})

    # Verify payload checksum.
    crc32c = google_crc32c.Checksum()
    crc32c.update(response.payload.data)
    if response.payload.data_crc32c != int(crc32c.hexdigest(), 16):
        print("Data corruption detected.")
        return response

    # Return the secret payload.
    payload = response.payload.data.decode("UTF-8")
    return payload


def upload_blob_from_memory(
    bucket_name: str, contents: str, destination_blob_name: str
) -> None:
    """Uploads a file to the bucket.

    Args:
        bucket_name (str): The ID of your GCS bucket.
        contents (str): The contents to upload to the file.
        destination_blob_name (str): The ID of your GCS object.
    """

    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(destination_blob_name)

    blob.upload_from_string(contents)


def read_text_file_from_gcs(
    bucket_name: str, destination_blob_name: str
) -> Union[str, None]:
    """Reads the content of a text file stored in Google Cloud Storage (GCS)
     and returns it as a string.

    Args:
        bucket_name (str): The ID of your GCS bucket.
        destination_blob_name (str): The ID of your GCS object.

    Returns:
        Union[str, None]: The content of the text file as a string if it exists,
         or None if not found.
    """

    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(destination_blob_name)

    # Check if file exists
    if blob.exists():
        content = blob.download_as_text()
    else:
        content = None

    return content
