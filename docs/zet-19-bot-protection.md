# Zet-19 — Bot Protection Runbook (reCAPTCHA v3 + Firebase App Check)

last_rotated_on: 2026-05-10 (initial provisioning — no rotation yet)

This runbook covers the **manual** Google Cloud / Firebase steps that the Zetdo `Infra/` Terraform tree cannot automate (no Terraform provider exists for reCAPTCHA Admin or Firebase App Check). All Azure-side wiring (Key Vault secret, Container App env-var binding, Static Web App CSP) is codified in Terraform and applied automatically by the GitHub Actions workflows.

Owner: infrastructure team / on-call for the Zet-19 release. Update `last_rotated_on` at the top of this file every time any reCAPTCHA site or secret key is rotated (per `infra.md` GUD-001 of the development considerations).

---

## 1. Per-environment matrix

| Environment | SPA hostname(s) | Firebase project | GitHub Actions Environment |
|---|---|---|---|
| dev | `dev.zetdo.com`, `localhost` (engineer laptop) | `zetdo-dev` | `dev` |
| sit | `sit.zetdo.com` | `zetdo-sit` | `sit` |
| prod | `app.zetdo.com` | `zetdo-prod` | `prod` |

Hostnames above are illustrative — confirm the actual production allowlist with the deployment owner before promoting `enforce` mode.

---

## 2. One-time setup per environment

Repeat steps 2.1 → 2.6 once per environment (dev, sit, prod). Each environment needs its **own** site/secret key pair (see `infra.md` CON-002 — keys must not be shared across environments).

### 2.1. Create the reCAPTCHA v3 key pair

1. Open `https://www.google.com/recaptcha/admin/create` while signed in with the Google account that owns the Zetdo project.
2. **Label**: `zetdo-<env>` (e.g. `zetdo-dev`).
3. **reCAPTCHA type**: select **reCAPTCHA v3** (not v2, not Enterprise).
4. **Domains**: add the SPA hostnames listed in the per-environment matrix above. For `dev`, also add `localhost` so engineer laptops can run end-to-end tests.
   - Do **not** check "Allow this key to work from any domain (not recommended)" — see `infra.md` GUD-001.
5. **Owners**: at least two people from the infra team.
6. Accept the reCAPTCHA Terms of Service.
7. **Submit** — the next page shows the **Site Key** (public) and **Secret Key** (confidential). Copy both immediately into a password manager — the Secret Key is shown only once in cleartext.

> **GUD-002 — Google v3 test keys**: the well-known Google test keys (site `6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI` / secret `6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe`) always score 0.9 and accept any hostname. They are acceptable for engineer-laptop manual testing in `dev` only. The shared `dev` environment must use a real key bound to `dev.zetdo.com`.

### 2.2. Record the Site Key (frontend)

The Site Key is **public** and lives in the frontend environment files:

```
Front/src/app/environments/environment.ts          # local dev / engineer laptop
Front/src/app/environments/environment.dev.ts      # shared dev
Front/src/app/environments/environment.sit.ts      # sit
Front/src/app/environments/environment.prod.ts     # prod
```

Add (or update) the property `recaptchaSiteKey: '<site-key>'` in the matching environment file. The Mobile app uses the same key per environment via `Mobile/.env` → `EXPO_PUBLIC_RECAPTCHA_SITE_KEY` (see `mobile.md`).

Commit the change on the same branch that targets the environment (`dev` for dev, `master` for sit, `release-*` tag for prod).

### 2.3. Record the Secret Key (backend, via GitHub Actions)

The Secret Key is **confidential** and is consumed only by the backend's reCAPTCHA verification call. It is stored in **Azure Key Vault** as `BotProtection--RecaptchaSecret` and surfaced to the Container App as the env var `BotProtection__RecaptchaSecret`.

Set the value once per environment in **GitHub Actions repository secrets** (Settings → Environments → `<env>` → Add secret):

| GitHub Actions Secret | Used by |
|---|---|
| `RECAPTCHA_SECRET` (in env `dev`) | `infra` workflow → `TF_VAR_recaptcha_secret` → `module.key_vault.recaptcha_secret` |
| `RECAPTCHA_SECRET` (in env `sit`) | same, sit |
| `RECAPTCHA_SECRET` (in env `prod`) | same, prod |

> The existing repo follows the **GitHub Actions Environments** model — `FIREBASE_CREDENTIAL_JSON` and `PASSWORD_HASH` are already environment-scoped under the same key name. We follow that convention. If you instead prefer suffix-named repo secrets (`RECAPTCHA_SECRET_DEV`, etc.), update the workflow's `env:` block accordingly.

Once the secret is set, push the Terraform branch — the next `terraform apply` will create / update the Key Vault secret. The Container App picks up the new value on its next revision restart (CON-003).

### 2.4. Enable the Play Integrity API (Android attestation)

1. Open `https://console.cloud.google.com/`.
2. Switch to the Google Cloud project linked to the Firebase project for this environment (see matrix above).
3. **APIs & Services → Library** → search **Play Integrity API** → **Enable**.

Repeat for each environment's Cloud project.

### 2.5. Register Android SHA-256 fingerprints

App Check / Play Integrity rejects calls that come from APKs whose signing certificate isn't registered against the Firebase project. For each environment:

1. Open `https://console.firebase.google.com/` → select the project → **Project Settings (gear)** → **Your apps**.
2. Pick the Android app (or **Add app** if the environment is brand new).
3. Under **SHA certificate fingerprints**, click **Add fingerprint** and paste the SHA-256 for:
   - The **debug** keystore used by `expo run:android` (`~/.android/debug.keystore`, password `android`).
   - The **release** keystore managed by EAS Build (`eas credentials → Android → Keystore → SHA-256`).
4. Click **Save**. Allow up to 10 minutes for the new fingerprint to propagate to the Play Integrity verification path.

> Without this step, Play Integrity attestation calls return a generic "untrusted" verdict and App Check enforcement (when promoted) will block all Android traffic.

### 2.6. Configure Firebase App Check enforcement

For each of the three Firebase apps registered to the project (Web, Android, iOS):

1. Open `https://console.firebase.google.com/` → select the project → **Build → App Check → Apps**.
2. Click the app → **Register / Manage**.
3. Provider:
   - **Web** → reCAPTCHA v3 → paste the **Site Key** from step 2.1.
   - **Android** → Play Integrity (no extra config; relies on step 2.5 fingerprints).
   - **iOS** → App Attest (production builds). Optional: enable DeviceCheck as a fallback for iOS &lt; 14 devices.
4. **Token TTL**: leave at the default (1 hour). See GUD-003 below — this is the worst-case latency between an enforcement / provider change and the observed traffic shift.
5. **Enforcement**: under each App Check-protected service (Cloud Firestore, Realtime Database, Cloud Functions, Storage, Authentication, etc.) and at the **App Check → APIs** screen, set the mode for this environment.
   - **Initial setting: `monitor`** — emits metrics but does not block. Hold for 7 days.
   - **Promotion**: only after `App Check → Metrics` for all three apps shows ≥ 99 % verified-request rate over the 7-day window (see CON-004 — this is a manual decision, never scripted).

> **GUD-003 — App Check token TTL**: clients cache an App Check token for ~1 hour. After flipping a provider setting in the console, expect ~1 hour before old clients re-attest. After flipping enforcement from `monitor` → `enforce`, fresh clients are blocked immediately, but already-attested clients continue silently for the remainder of their token TTL.

---

## 3. Validation (post-deploy)

Run these per environment after the first deployment that wires the new secret:

1. **Key Vault secret exists**: `az keyvault secret show --vault-name kv-zetdo-<env>-weu --name BotProtection--RecaptchaSecret --query name -o tsv` → returns `BotProtection--RecaptchaSecret`.
2. **Container App env var bound**: `az containerapp show -n ca-zetdo-<env>-weu -g rg-zetdo-<env>-weu --query "properties.template.containers[0].env[?name=='BotProtection__RecaptchaSecret']" -o table` → the `secretRef` column shows `botprotection--recaptchasecret`. The value itself is masked.
3. **CSP zero-violations** (`AC-006`): open the deployed SPA in a private window, DevTools → Console, navigate `/register` then `/book/<seed-slug>`, confirm no `Refused to load … because it violates the following Content Security Policy directive` messages.
4. **Backend bot protection round-trip** (`AC-004` / `AC-005`):
   - With a valid `X-Recaptcha-Token`: `POST /api/v1/Users` returns `200`.
   - Without: `POST /api/v1/Users` returns `403 BOT_PROTECTION_TOKEN_MISSING`.
5. **Firebase App Check metrics** (`AC-007`): 24 h after deploy, open `Firebase Console → App Check → Metrics` for each of the three apps and confirm ≥ 1 verified request and zero unverified-error spikes.

---

## 4. Rotation procedure

Triggered by: scheduled rotation (annual minimum), suspected key leak, or change of hostname allowlist.

1. Generate a new key pair in `https://www.google.com/recaptcha/admin/create` (same label suffixed with `-rotated-YYYYMMDD`, same hostnames).
2. Update **GitHub Actions secret** `RECAPTCHA_SECRET` for the target environment with the new Secret Key.
3. Update the `Front/src/app/environments/environment.<env>.ts` file with the new Site Key, commit, and push to the target branch (the Static Web App build picks it up on the next deploy).
4. Trigger the Terraform workflow for that environment — `terraform apply` updates the Key Vault secret value to the new Secret Key.
5. Restart the Container App revision so it pulls the new secret value: `az containerapp revision restart -n ca-zetdo-<env>-weu -g rg-zetdo-<env>-weu --revision <latest>`.
6. **Verification** — run section 3 against the rotated environment, end-to-end (browser DevTools + curl with and without token).
7. After 24 h of clean metrics, **disable the old key** in the reCAPTCHA admin console.
8. **Update the `last_rotated_on` line at the top of this file** with the new date (per GUD-001).

---

## 5. Rollback procedure (REQ-031)

If App Check enforcement after promotion (`monitor` → `enforce`) starts blocking legitimate traffic (look for spikes in Firebase Console → App Check → Metrics → "Unverified" column, or user reports of silent failures):

1. Open `https://console.firebase.google.com/` → select the project → **Build → App Check**.
2. For each app (Web, Android, iOS) and each enforced service, switch the enforcement mode back from **enforce** → **monitor**.
3. **No code change, no Terraform apply, no Container App restart is required** — the change is server-side at Firebase and propagates within minutes (worst case: bounded by the token TTL, ~1 hour, for already-attested clients).
4. File a follow-up to investigate the metrics spike before re-attempting promotion.

If instead the issue is the **reCAPTCHA Secret Key** (e.g. backend returning `403 BOT_PROTECTION_TOKEN_MISSING` for legitimate callers because the secret was misconfigured):

1. Re-run the Terraform workflow with the previous valid Secret Key value (revert the GitHub Actions secret to the previous version, then re-apply).
2. `az containerapp revision restart` to pick up the rolled-back secret.
3. Run section 3 validation.

---

## 6. Cost note

reCAPTCHA v3 free tier is **1M assessments / month / site key**. Each registration + booking attempt counts as one assessment. Current Zetdo traffic is well under this ceiling and no billing impact is expected at sit / prod for the next 12 months. Firebase App Check + Play Integrity are also free at current scale. Re-evaluate if traffic exceeds 500 k registration attempts / month / environment.

---

## 7. References

- Spec: `spec/spec-zet-19-20260510-architecture-recaptcha-bot-protection/infra.md`
- Backend wiring: `Backend/CLAUDE.md` (BotProtection module)
- Frontend wiring: `Front/CLAUDE.md`, `Front/src/app/environments/`
- Mobile wiring: `Mobile/CLAUDE.md`
- Google reCAPTCHA Admin: https://www.google.com/recaptcha/admin
- Firebase App Check overview: https://firebase.google.com/docs/app-check
- Play Integrity API: https://developer.android.com/google/play/integrity
- Firebase App Check console (per project): https://console.firebase.google.com/project/_/appcheck
