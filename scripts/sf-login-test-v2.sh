#!/usr/bin/env bash
set -euo pipefail

INSTANCE_ID="${INSTANCE_ID:-i-0e99060efb1c9f03c}"
REGION="ca-central-1"
aws configure set region "$REGION" >/dev/null

cat > /tmp/customer360-sf-login-test-remote-v2.sh <<'REMOTE'
#!/usr/bin/env bash
set -euo pipefail

mkdir -p /opt/customer360/{scripts,logs,data,venv}
if [ ! -x /opt/customer360/venv/bin/python ]; then
  dnf install -y python3 python3-pip postgresql15 git jq awscli
  python3 -m venv /opt/customer360/venv
  /opt/customer360/venv/bin/python -m ensurepip --upgrade || true
fi
/opt/customer360/venv/bin/python -m pip install -q boto3 simple-salesforce

cat > /opt/customer360/scripts/sf_login_test.py <<'PY'
import json
import re
import sys
import boto3
from simple_salesforce import Salesforce
from simple_salesforce.exceptions import SalesforceAuthenticationFailed

REGION = "ca-central-1"
SECRET_ID = "legend/customer360/salesforce"

EMAIL_RE = re.compile(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}")

def clean_username(value):
    value = (value or "").strip()
    emails = EMAIL_RE.findall(value)
    # Prefer exact aipulse address if Slack added mailto junk.
    for email in emails:
        if email.lower() == "aipulse@legendboats.com":
            return email
    return emails[0] if emails else value

secret = json.loads(boto3.client("secretsmanager", region_name=REGION).get_secret_value(SecretId=SECRET_ID)["SecretString"])
username_raw = secret.get("sf_username")
username = clean_username(username_raw)
password = secret.get("sf_password", "")
security_token = secret.get("sf_security_token", "") or ""
domain = secret.get("sf_domain", "login") or "login"

print("Testing Salesforce login")
print("Username raw:", username_raw)
print("Username used:", username)
print("Domain:", domain)
print("Security token present:", bool(security_token))
print()

try:
    sf = Salesforce(username=username, password=password, security_token=security_token, domain=domain)
except SalesforceAuthenticationFailed as e:
    print("Salesforce login: FAILED")
    print(str(e))
    print()
    print("If code is LOGIN_MUST_USE_SECURITY_TOKEN, reset/get the security token for aipulse@legendboats.com or add the AWS runner IP to Salesforce trusted networks.")
    sys.exit(1)

print("Salesforce login: OK")
print("Instance:", sf.sf_instance)
org = sf.query("SELECT Id, Name, OrganizationType, InstanceName FROM Organization LIMIT 1")
if org["records"]:
    rec = org["records"][0]
    print("Org:", rec.get("Name"))
    print("Org type:", rec.get("OrganizationType"))
    print("Instance name:", rec.get("InstanceName"))

describe = sf.describe()
objects = {o["name"]: o for o in describe["sobjects"]}
targets = ["Account","Contact","Asset","Product2","Case","Opportunity","AcctSeed__Project__c","AcctSeed__Transaction__c","AcctSeed__Billing__c","AcctSeed__Billing_Line__c","AcctSeedERP__Material__c","AcctSeedERP__Sales_Order__c","AcctSeedERP__Sales_Order_Line__c"]
print("Key object availability:")
for name in targets:
    obj = objects.get(name)
    print(f"  {('QUERYABLE' if obj and obj.get('queryable') else 'MISSING/NOQUERY'):<16} {name}")
print("Total objects visible:", len(objects))
print("Read-only login/metadata test complete.")
PY

/opt/customer360/venv/bin/python /opt/customer360/scripts/sf_login_test.py
REMOTE

python3 - <<'PY'
import json, pathlib
script = pathlib.Path('/tmp/customer360-sf-login-test-remote-v2.sh').read_text()
cmd = "cat > /tmp/customer360-sf-login-test-remote-v2.sh <<'REMOTE'\n" + script + "\nREMOTE\nchmod +x /tmp/customer360-sf-login-test-remote-v2.sh\nsudo /tmp/customer360-sf-login-test-remote-v2.sh"
pathlib.Path('/tmp/customer360-sf-login-test-v2-ssm.json').write_text(json.dumps({'commands': [cmd]}))
PY

COMMAND_ID="$(aws ssm send-command --instance-ids "$INSTANCE_ID" --document-name "AWS-RunShellScript" --comment "Customer360 Salesforce read-only login test v2" --parameters file:///tmp/customer360-sf-login-test-v2-ssm.json --query "Command.CommandId" --output text)"
echo "Command ID: $COMMAND_ID"
aws ssm wait command-executed --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" || true
aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" --query '{Status:Status,Output:StandardOutputContent,Error:StandardErrorContent}' --output json
