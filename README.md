# Legend Customer 360 Tools

Small AWS CloudShell/SSM helper scripts for the Legend Customer 360 prototype.

## Current setup

- AWS region: `ca-central-1`
- S3 bucket: `legend-customer360-ca-662151075184-ca-central-1-an`
- RDS identifier: `legend-customer360-postgres`
- EC2 runner: `i-0e99060efb1c9f03c`
- Salesforce secret: `legend/customer360/salesforce`

## Quick commands from AWS CloudShell

Update Salesforce secret with fixed clean username:

```bash
curl -fL https://raw.githubusercontent.com/OWNER/REPO/main/scripts/update-sf-secret-fixed-user.py -o update-sf-secret-fixed-user.py
python3 update-sf-secret-fixed-user.py
```

Run read-only Salesforce login/object metadata test:

```bash
curl -fL https://raw.githubusercontent.com/OWNER/REPO/main/scripts/sf-login-test-v2.sh -o sf-login-test-v2.sh
chmod +x sf-login-test-v2.sh
./sf-login-test-v2.sh
```

## Safety

These scripts are intended to be read-only against Salesforce. The login test authenticates and reads metadata only. It does not insert, update, upsert, delete, or deploy anything in Salesforce.
