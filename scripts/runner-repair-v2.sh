#!/usr/bin/env bash
set -euxo pipefail

REGION="ca-central-1"
BUCKET="legend-customer360-ca-662151075184-ca-central-1-an"
DB_ID="legend-customer360-postgres"
SECRET_NAME="legend/customer360/salesforce"

mkdir -p /opt/customer360/{scripts,logs,data,venv}

# Install OS packages. Do NOT upgrade system pip on Amazon Linux; rpm-managed pip cannot be uninstalled cleanly.
dnf install -y python3 python3-pip postgresql15 git jq awscli

# Create an isolated venv so Python packages do not fight Amazon Linux rpm-managed pip.
python3 -m venv /opt/customer360/venv
/opt/customer360/venv/bin/python -m ensurepip --upgrade || true
/opt/customer360/venv/bin/python -m pip install --upgrade --ignore-installed pip setuptools wheel
/opt/customer360/venv/bin/python -m pip install boto3 pandas psycopg2-binary sqlalchemy simple-salesforce python-dotenv pyarrow

cat > /opt/customer360/scripts/healthcheck.py <<'PY'
import boto3, socket

region = "ca-central-1"
bucket = "legend-customer360-ca-662151075184-ca-central-1-an"
db_id = "legend-customer360-postgres"
secret_id = "legend/customer360/salesforce"

rds = boto3.client("rds", region_name=region)
s3 = boto3.client("s3", region_name=region)
secrets = boto3.client("secretsmanager", region_name=region)

db = rds.describe_db_instances(DBInstanceIdentifier=db_id)["DBInstances"][0]
endpoint = db["Endpoint"]["Address"]
port = db["Endpoint"]["Port"]

print("RDS endpoint:", endpoint)
print("RDS port:", port)

print("Testing TCP connection to RDS...")
sock = socket.create_connection((endpoint, port), timeout=10)
sock.close()
print("RDS TCP: OK")

print("Testing S3 bucket access...")
s3.head_bucket(Bucket=bucket)
print("S3 bucket: OK")

print("Testing Salesforce secret metadata access...")
secrets.describe_secret(SecretId=secret_id)
print("Secret metadata: OK")

print("Healthcheck complete.")
PY

cat > /opt/customer360/run-healthcheck.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
/opt/customer360/venv/bin/python /opt/customer360/scripts/healthcheck.py
SH
chmod +x /opt/customer360/run-healthcheck.sh
chown -R ec2-user:ec2-user /opt/customer360

/opt/customer360/run-healthcheck.sh
