#!/usr/bin/env python3
import json
import getpass
import subprocess
import tempfile
import os
import sys

secret_id = "legend/customer360/salesforce"
sf_username = "aipulse@legendboats.com"

print("Customer360 Salesforce secret updater")
print("Username is fixed to:", sf_username)
print("Stores credentials in AWS Secrets Manager:", secret_id)
print("Do NOT paste password/token into Slack.")
print()

sf_password = getpass.getpass("Salesforce password: ")
if not sf_password:
    print("ERROR: password is required", file=sys.stderr)
    sys.exit(1)

sf_security_token = getpass.getpass("Salesforce security token [required unless trusted IP is configured; press Enter if none]: ")

while True:
    sf_domain = input("Salesforce domain: type 'test' for sandbox or 'login' for production: ").strip().lower()
    if sf_domain in {"test", "login"}:
        break
    print("Please type exactly: test or login")

payload = {
    "sf_username": sf_username,
    "sf_password": sf_password,
    "sf_security_token": sf_security_token,
    "sf_domain": sf_domain,
}

fd, path = tempfile.mkstemp(prefix="sf-secret-", suffix=".json")
try:
    with os.fdopen(fd, "w") as f:
        json.dump(payload, f)
    subprocess.run([
        "aws", "secretsmanager", "put-secret-value",
        "--secret-id", secret_id,
        "--secret-string", f"file://{path}",
    ], check=True)
    print()
    print("Salesforce secret updated successfully.")
    print("Stored username:", sf_username)
    print("Stored domain:", sf_domain)
    print("Security token stored:", "yes" if sf_security_token else "no / blank")
finally:
    try:
        os.remove(path)
    except FileNotFoundError:
        pass
