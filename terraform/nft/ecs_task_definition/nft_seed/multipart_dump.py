import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile


PART_SIZE = 5 * 1024 * 1024 * 1024
READ_SIZE = 8 * 1024 * 1024


def valid_version(value):
    return (isinstance(value, str) and len(value) <= 1024
            and re.fullmatch(r"[A-Za-z0-9._/+=-]+", value) is not None
            and value.lower() not in ("null", "none"))


def validate_certificate(run_id, key, version):
    if not re.fullmatch(r"[1-9][0-9]*-[1-9][0-9]*", run_id or ""):
        raise RuntimeError("Invalid seed run identity")
    if key != f"seeding/certificate-references/{run_id}.png" or not valid_version(version):
        raise RuntimeError("Invalid certificate identity")


def upload_dump(stream, aws, dump_succeeded, part_size=PART_SIZE):
    upload_id = None
    completion_attempted = False
    digest = hashlib.sha256()
    total = 0
    parts = []
    try:
        upload_id = aws("create-multipart-upload").get("UploadId")
        if not isinstance(upload_id, str) or not upload_id:
            raise RuntimeError("Multipart upload identity is missing")

        with tempfile.TemporaryDirectory(prefix="nft-dump-") as directory:
            part_path = directory + "/part"
            while True:
                size = 0
                with open(part_path, "wb") as part:
                    while size < part_size:
                        chunk = stream.read(min(READ_SIZE, part_size - size))
                        if not chunk:
                            break
                        part.write(chunk)
                        digest.update(chunk)
                        size += len(chunk)
                        total += len(chunk)
                if not size:
                    break
                if len(parts) >= 10000:
                    raise RuntimeError("Dump exceeds S3 multipart capacity")
                number = len(parts) + 1
                etag = aws("upload-part", upload_id=upload_id, part_number=number, body=part_path).get("ETag")
                if not isinstance(etag, str) or not etag:
                    raise RuntimeError("Multipart part identity is missing")
                parts.append({"ETag": etag, "PartNumber": number})
                if size < part_size:
                    break

        if not parts or not dump_succeeded():
            raise RuntimeError("Database dump failed or was empty")
        completion_attempted = True
        version = aws("complete-multipart-upload", upload_id=upload_id, parts=parts).get("VersionId")
        if not valid_version(version):
            raise RuntimeError("Completed dump has no immutable version")
        return {"version": version, "bytes": total, "sha256": digest.hexdigest()}
    finally:
        if upload_id and not completion_attempted:
            try:
                aws("abort-multipart-upload", upload_id=upload_id)
            except Exception:
                print("Multipart cleanup failed; operator inspection is required.", file=sys.stderr)


def publish_manifest(aws, run_id, certificate_key, certificate_version, dump):
    validate_certificate(run_id, certificate_key, certificate_version)
    if (not valid_version(dump.get("version")) or not isinstance(dump.get("bytes"), int)
            or isinstance(dump["bytes"], bool) or dump["bytes"] <= 0
            or not re.fullmatch(r"[a-f0-9]{64}", dump.get("sha256", ""))):
        raise RuntimeError("Invalid dump identity")
    key = f"seed-manifests/{run_id}.json"
    manifest = {
        "runId": run_id,
        "dump": {"key": "seed-data.dump", **dump},
        "certificate": {"key": certificate_key, "version": certificate_version},
    }
    version = aws("put-object", key=key, manifest=manifest).get("VersionId")
    if not valid_version(version):
        raise RuntimeError("Manifest has no immutable version")
    return {"key": key, "version": version}


def aws_cli(operation, **kwargs):
    bucket = "prsdb-seed-data-nft"
    key = kwargs.get("key", "seed-data.dump")
    command = ["aws", "s3api", operation, "--bucket", bucket, "--key", key,
               "--region", "eu-west-2", "--output", "json", "--no-cli-pager"]
    if "upload_id" in kwargs:
        command.extend(["--upload-id", kwargs["upload_id"]])
    if operation == "upload-part":
        command.extend(["--part-number", str(kwargs["part_number"]), "--body", kwargs["body"]])
    with tempfile.TemporaryDirectory(prefix="nft-dump-request-") as directory:
        if operation in ("complete-multipart-upload", "put-object"):
            document = {"Parts": kwargs["parts"]} if operation == "complete-multipart-upload" else kwargs["manifest"]
            path = directory + "/request.json"
            with open(path, "w", encoding="utf-8") as file:
                json.dump(document, file, separators=(",", ":"))
            if operation == "complete-multipart-upload":
                command.extend(["--multipart-upload", "file://" + path])
            else:
                command.extend(["--body", path, "--if-none-match", "*", "--content-type", "application/json"])
        result = subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return json.loads(result.stdout or b"{}")


def main():
    process = None
    try:
        run_id = os.environ.get("NFT_SEED_RUN_ID")
        certificate_key = os.environ.get("NFT_SEED_CERTIFICATE_OBJECT_KEY")
        certificate_version = os.environ.get("NFT_SEED_CERTIFICATE_VERSION_ID")
        validate_certificate(run_id, certificate_key, certificate_version)
        with tempfile.TemporaryFile() as errors:
            process = subprocess.Popen(
                ["pg_dump", "--format=custom", "--no-owner", "--no-acl"],
                stdout=subprocess.PIPE, stderr=errors,
            )
            try:
                dump = upload_dump(process.stdout, aws_cli, lambda: process.wait() == 0)
            finally:
                process.stdout.close()
                if process.poll() is None:
                    process.terminate()
                    process.wait()
        manifest = publish_manifest(aws_cli, run_id, certificate_key, certificate_version, dump)
        print("NFT_SEED_MANIFEST_VERSION=" + manifest["version"], flush=True)
    except Exception:
        print("Seed dump or immutable manifest publication failed; operator inspection is required.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
