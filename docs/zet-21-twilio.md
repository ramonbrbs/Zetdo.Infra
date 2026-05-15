# Zet-21 — Twilio Messaging Runbook

last_rotated_on: 2026-05-14 (initial provisioning — no rotation yet)

This runbook covers the manual Twilio console steps that the Zetdo `Infra/`
Terraform tree cannot automate (no first-class Terraform provider for Twilio
Messaging Services or WhatsApp sender registration). All Azure-side wiring
(Service Bus namespace + queue, Key Vault secrets, Function App, Container App
env vars, Cosmos `MessagingDB`/`MessageDeliveries`) is codified in Terraform
and applied automatically by the GitHub Actions workflows.

Owner: infrastructure team / on-call for the Zet-21 release. Update
`last_rotated_on` at the top of this file every time any Twilio credential
(`AccountSid`, `AuthToken`, `MessagingServiceSid`) is rotated.

---

## 1. Per-environment matrix

| Environment | Web API hostname        | Twilio status-callback URL                                  | Cosmos DB | Service Bus namespace          | Function App                            |
|-------------|-------------------------|-------------------------------------------------------------|-----------|--------------------------------|-----------------------------------------|
| dev         | `api-dev.zetdo.com`     | `https://api-dev.zetdo.com/api/v1/webhooks/twilio/status`   | `cosmos-zetdo-dev-weu`  | `sb-zetdo-dev-weu`  | `func-zetdo-reminders-dev-weu`  |
| sit         | `api-sit.zetdo.com`     | `https://api-sit.zetdo.com/api/v1/webhooks/twilio/status`   | `cosmos-zetdo-sit-weu`  | `sb-zetdo-sit-weu`  | `func-zetdo-reminders-sit-weu`  |
| prod        | `api.zetdo.com`         | `https://api.zetdo.com/api/v1/webhooks/twilio/status`       | `cosmos-zetdo-prod-weu` | `sb-zetdo-prod-weu` | `func-zetdo-reminders-prod-weu` |

DNS: webhooks hit the existing Container App ingress (`api*.zetdo.com`). No new
public IP or DNS record is required (CON-303).

---

## 2. One-time Twilio account setup (per environment)

Each environment needs its **own** Twilio account/subaccount so credentials,
audit trail, and billing are isolated. Repeat steps 2.1 → 2.6 for `dev`, `sit`,
and `prod`.

### 2.1. Create the Twilio account (or subaccount)

1. Sign in to `https://console.twilio.com` with the Zetdo infra owner account.
2. For **dev** and **sit**: use a Twilio subaccount under the main Zetdo account
   (Console → Account → Subaccounts → **Create subaccount** → name
   `zetdo-<env>`).
3. For **prod**: use a dedicated **main account** if compliance requires (A2P
   10DLC and WhatsApp registration cannot share with a sandbox subaccount).
4. Record the **Account SID** (`ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`) and the
   **Auth Token** from the Console home page.

> **Sandbox vs production**: dev SHOULD start on the Twilio sandbox (free,
> instant). The sandbox uses well-known sender `+14155238886`, requires the
> recipient to opt in by texting a join code, and is rate-limited. sit/prod
> require a **production WhatsApp Business sender** (see §2.4) and **A2P 10DLC
> brand+campaign** registration for SMS (see §2.5).

### 2.2. Create the Messaging Service

1. Console → Messaging → Services → **Create Messaging Service**.
2. Name: `zetdo-appointment-reminders-<env>`.
3. Use case: `Notifications, 2-Way`.
4. Click **Create**.
5. On the next screen, **do NOT** add a sender yet — you will add the WhatsApp
   sender once it is approved (§2.4).
6. Set the **Status Callback URL** to the per-environment value in the matrix
   above. This makes Twilio post delivery status updates to the Web API, not
   the Function App.
7. Record the **Messaging Service SID** (`MGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`).

### 2.3. Submit and approve Content Templates

The Function App sends WhatsApp template messages by SID rather than free-form
text, so the templates must be pre-approved by Meta via Twilio.

For each environment, submit two templates (`en-US` and `pt-BR`) named
`appointment-reminder`:

1. Console → Messaging → Content Template Builder → **Create new template**.
2. Friendly name: `appointment-reminder-en-US` (or `appointment-reminder-pt-BR`).
3. Language: `en` (or `pt_BR`).
4. Category: `UTILITY` (appointment reminders qualify as utility messages —
   marketing category is more expensive and harder to approve).
5. Content type: `Twilio/Text` (start with text-only; rich content is a
   follow-up release).
6. Body — see `Backend/CLAUDE.md` for the canonical copy. Use `{{1}}`/`{{2}}`
   variables for `customerFirstName`, `appointmentLocalTime`, etc.
7. Submit for WhatsApp approval. Meta approval typically takes 1–24 hours; SMS
   approval is instant.
8. Once approved, record the **Content SID** (`HXxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`)
   per locale. These go into the Terraform variables
   `twilio_content_template_en` and `twilio_content_template_ptbr`.

### 2.4. Provision the WhatsApp sender (sit / prod only)

> The dev environment can stay on the Twilio sandbox (`+14155238886`). For sit
> and prod, complete the production WhatsApp Business sender flow.

1. Ensure the Zetdo Meta Business Account is verified
   (`https://business.facebook.com` → Settings → Business Info → Verify).
2. Console → Messaging → Senders → **WhatsApp** → **Add Sender**.
3. Choose the previously-created Messaging Service.
4. Provide the WhatsApp display name (`Zetdo`) and phone number to be used.
   The number must NOT already be in use for personal WhatsApp.
5. Complete the Meta Embedded Signup flow (Facebook OAuth → select WABA →
   accept terms).
6. Wait for Meta approval (1–7 days). Twilio emails the infra owner when the
   sender is active.
7. Add the approved sender to the Messaging Service: Service → Senders →
   **Add Senders** → WhatsApp → select the new sender.
8. Record the E.164 number — this is the value for the Terraform variable
   `twilio_whatsapp_sender_e164`.

### 2.5. Register the A2P 10DLC brand/campaign (prod SMS only)

If SMS is enabled as a fallback for prod, register a brand+campaign per
Twilio's A2P 10DLC flow:

1. Console → Messaging → Regulatory Compliance → US A2P 10DLC.
2. Create a **Brand** (Zetdo company info) — $44 one-time, instant approval.
3. Create a **Campaign** with use case `Mixed` or `Account Notification` — $10
   one-time + $1.50/mo.
4. Attach the campaign to the Messaging Service.

This step is NOT required for WhatsApp-only deployments. dev/sit do not need
A2P 10DLC.

### 2.6. Configure the status-callback URL

The Messaging Service Status Callback URL was set in §2.2. Verify per env:

```bash
# Replace <MG-SID> with the Messaging Service SID and use the env's Auth Token.
curl -X GET "https://messaging.twilio.com/v1/Services/<MG-SID>" \
  -u "<AccountSid>:<AuthToken>" | jq .status_callback
```

Expected response per environment matches the URL in the per-environment
matrix above.

The Web API verifies the `X-Twilio-Signature` header on every incoming
status-callback request — see backend spec REQ-403. If the URL is wrong,
Twilio sends to the wrong host and signature verification will not even fire.

---

## 3. Wire Twilio credentials into Azure (via CI)

Set the following secrets in each environment's GitHub Actions environment
(Settings → Environments → `<env>` → Add secret). The Infra workflow reads
them via `TF_VAR_*` and writes them to Key Vault on `terraform apply`.

| GitHub Secret                      | Key Vault secret name             | Terraform variable             |
|------------------------------------|-----------------------------------|--------------------------------|
| `TF_VAR_twilio_account_sid`        | `twilio-account-sid`              | `twilio_account_sid`           |
| `TF_VAR_twilio_auth_token`         | `twilio-auth-token`               | `twilio_auth_token`            |
| `TF_VAR_twilio_messaging_service_sid` | `twilio-messaging-service-sid` | `twilio_messaging_service_sid` |

Non-sensitive values are committed to `terraform.tfvars` per env:

```hcl
twilio_whatsapp_sender_e164  = "+15551234567"            # E.164 sender
twilio_content_template_en   = "HXxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
twilio_content_template_ptbr = "HXyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy"
```

The Container App pulls Twilio credentials from Key Vault via Container App
Secrets that reference the versionless secret IDs (Zet-19 pattern). The
Function App pulls them via Key Vault references (`@Microsoft.KeyVault(...)`)
in app settings. Both pick up the latest version on revision restart / app
settings refresh (AC-308).

---

## 4. Rotating Twilio credentials

The three secrets have very different rotation cadences (CON-310):

- **AuthToken** — most likely to rotate (regularly, or on suspected leak).
- **MessagingServiceSid** — rotates only if the Messaging Service is rebuilt.
- **AccountSid** — effectively immutable; rotating means creating a new
  account.

### 4.1. Rotate the Auth Token (most common case)

1. Console → Account → Auth Tokens & API Keys → **Generate new auth token**.
2. The Console keeps both the current and previous tokens valid for ~24h, so
   you can rotate without immediate downtime.
3. Update the GitHub Actions environment secret
   `TF_VAR_twilio_auth_token` with the new value.
4. Trigger the Infra workflow (or wait for the next push). Terraform updates
   the Key Vault secret value (new version).
5. Within ~5 min, both the Container App and the Function App pick up the new
   version (AC-308) — no code deploy required.
6. **Verify**: send a test message via `POST /api/v1/messaging/test` (Web API,
   dev only) and confirm Twilio status callback arrives signed correctly.
7. Once verified, **revoke the previous token** in the Twilio Console.
8. Update `last_rotated_on` at the top of this file.

### 4.2. Rotate the Messaging Service

1. Console → Messaging → Services → **Create new Messaging Service** with a
   `-v2` suffix in the name.
2. Re-attach the approved WhatsApp sender and Content Templates (they can
   live in multiple services).
3. Update `TF_VAR_twilio_messaging_service_sid` and re-run Infra apply.
4. Once the new service is live, **delete the old service** in Twilio.

### 4.3. Rotate the AccountSid

This is effectively a full re-onboarding (new Twilio account → new
WhatsApp/A2P registration). Avoid unless forced by Twilio terms of service.

---

## 5. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Function App invocation throws `Unauthorized` when calling Twilio | Stale `AuthToken` in Key Vault | Re-apply Terraform; restart Function App; verify the Key Vault reference is on the **latest** version. |
| Web API returns `403` on `/api/v1/webhooks/twilio/status` | `X-Twilio-Signature` mismatch — wrong `AuthToken` used to compute HMAC | Ensure the Web API and the Function App use the **same** Twilio account (i.e. share `twilio-auth-token` per env). |
| Status-callback URL in Twilio shows `https://api-dev.zetdo.com/...` for sit | Wrong Messaging Service Sid in Key Vault | Update `TF_VAR_twilio_messaging_service_sid` for the affected env. |
| Function App scales to 0 and never wakes up | Service Bus role assignment missing or wrong principal | Verify `module.service_bus.consumer_principal_id == module.function_app_messaging.principal_id`; re-apply Terraform. |
| `MessageDeliveries` queries timeout / exceed 1k RU/min | Cross-partition lookup without composite index | Confirm composite index on `providerMessageSid` exists in `MessagingDB.MessageDeliveries` (Cosmos Data Explorer → Settings). |
| Twilio webhook arrives at `func-zetdo-reminders-*` instead of the Container App | Status Callback URL misconfigured in the Messaging Service | Re-run §2.6 to fix. |

---

## 6. Rollback

To stop sending reminders without removing the infrastructure:

1. **Soft kill switch**: Set the Function App's `AzureWebJobs.DispatchReminders.Disabled`
   app setting to `1` via Azure CLI:
   ```bash
   az functionapp config appsettings set \
     --name "func-zetdo-reminders-<env>-weu" \
     --resource-group "rg-zetdo-<env>-weu" \
     --settings "AzureWebJobs.DispatchReminders.Disabled=1"
   ```
   The function stops processing the queue; messages accumulate (lock-renewed
   by Service Bus' 30-day TTL — see CON-305).

2. **Full rollback**: revert the Terraform PR. The Function App, Service Bus
   namespace, and Key Vault secrets are recreated/destroyed atomically by the
   Infra apply. Cosmos `MessagingDB` and `MessageDeliveries` should be
   retained — they hold delivery history — so reverting is selective:
   ```bash
   terraform destroy -target=module.function_app_messaging \
                     -target=module.service_bus \
                     -var-file=terraform.tfvars
   ```
   Existing reminder messages in the queue are preserved for 30 days and can
   be re-played by re-applying.

---

## 7. References

- Infra spec: `spec/spec-zet-21-20260514-architecture-twilio-messaging/infra.md`
- Backend spec: `spec/spec-zet-21-20260514-architecture-twilio-messaging/backend.md`
- Twilio Messaging API: https://www.twilio.com/docs/messaging
- Twilio Content Templates: https://www.twilio.com/docs/content
- Azure Service Bus identity-based connection:
  https://learn.microsoft.com/azure/azure-functions/functions-reference?tabs=blob#common-properties-for-identity-based-connections
