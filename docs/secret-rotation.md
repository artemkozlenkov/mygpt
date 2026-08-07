# Secret Rotation Runbook — myGPT

Step-by-step, copy-paste guide for rotating **every** credential that backs
`https://chat.softawebit.com`. Summary table and cadence live in the
[README](../README.md#secret-rotation-strategy); this file is the how-to.

Everything is an Azure resource or a value in one SOPS-encrypted file. The
two stores you touch:

| Store | Contents |
|---|---|
| `charts/mygpt/values.secrets.yaml` (SOPS, Azure KV `mygpt-sops/sops`) | every app secret |
| k8s Secret `azuredns-config` (namespace `cert-manager`) | the DNS service-principal secret for cert-manager DNS-01 |

## 0. Pre-flight

Confirm the operator identity has everything it needs before you start:

```bash
az account show --query "{sub:name, user:user.name}" -o tsv   # d597c780-…, artem.kozlenkov@softawebit.com
# operator needs "Key Vault Crypto Officer" on mygpt-sops (SOPS decrypt/encrypt)
az keyvault show -n mygpt-sops --query name -o tsv             # → mygpt-sops

kubectl cluster-info >/dev/null                                # k3s reachable
git -C /home/art/projects/mygpt status --short                 # clean before rotating
```

Take a plaintext snapshot of the current values so you can diff/revert:

```bash
sops --decrypt charts/mygpt/values.secrets.yaml > /tmp/secrets.plain.bak
```

Check decrypt works at all (if this fails, stop — fix access before anything):

```bash
sops --decrypt charts/mygpt/values.secrets.yaml > /dev/null && echo DECRYPT-OK
```

> ⚠ **Do not run `helm secrets decrypt` and expect it to edit the file.** On the
> current tooling (helm-secrets 4.7.7) it prints the plaintext to stdout and
> leaves the file untouched. The only flow that is known-good here is explicit
> `sops` input/output files, as shown below.

## 1. ⚠ Repair known drift FIRST (document parsing is currently broken)

The committed `values.secrets.yaml` nests six keys under `postgres:` instead of
`secrets.data:`. The chart only renders `secrets.data` into the runtime Secret
(`templates/secret.yaml`), so **`DOCUMENT_INTELLIGENCE_KEY` is empty in the
live deployment today** — Azure Document Intelligence cannot authenticate and
PDF/document parsing fails. The other five still work only because `values.yaml`
carries sensible defaults.

Move all six from under `postgres:` to under `secrets.data:` (delete the
`postgres:` duplicates). This is a requirement for step [B](#b-azure-document-intelligence),
and you should do it even if you are only rotating one secret — otherwise the
next `helm secrets upgrade` silently drops them:

```yaml
# BEFORE (broken) — under postgres:
postgres:
  user: llmproxy
  password: …
  CONTENT_EXTRACTION_ENGINE: document_intelligence
  DOCUMENT_INTELLIGENCE_ENDPOINT: https://mygpt-docintel.cognitiveservices.azure.com/
  DOCUMENT_INTELLIGENCE_KEY: <key>
  BYPASS_MODEL_ACCESS_CONTROL: "True"
  DEFAULT_LOCALE: en
  WEBUI_FAVICON_URL: https://chat.softawebit.com/static/logo.svg

# AFTER (correct) — under secrets.data, alongside the other ~50 keys:
secrets:
  data:
    …
    CONTENT_EXTRACTION_ENGINE: document_intelligence
    DOCUMENT_INTELLIGENCE_ENDPOINT: https://mygpt-docintel.cognitiveservices.azure.com/
    DOCUMENT_INTELLIGENCE_KEY: <key>
    BYPASS_MODEL_ACCESS_CONTROL: "True"
    DEFAULT_LOCALE: en
    WEBUI_FAVICON_URL: https://chat.softawebit.com/static/logo.svg
```

## 2. The rotate-any-value loop

Every rotation below is this loop with different inputs:

```bash
sops --decrypt charts/mygpt/values.secrets.yaml > /tmp/secrets.plain.yaml   # plaintext to a scratch file
# … edit /tmp/secrets.plain.yaml (e.g. the KEY you are rotating) …
cp /tmp/secrets.plain.yaml charts/mygpt/values.secrets.yaml                 # stage plaintext at the repo path
sops --encrypt --in-place charts/mygpt/values.secrets.yaml                  # encrypt back to ciphertext
sops --decrypt charts/mygpt/values.secrets.yaml > /dev/null                 # round-trip check
git diff --stat charts/mygpt/values.secrets.yaml                            # ciphertext should change
git add charts/mygpt/values.secrets.yaml && git commit -m "chore(secrets): rotate <what>"
helm secrets upgrade mygpt charts/mygpt \
  -f charts/mygpt/values.secrets.yaml --namespace mygpt
kubectl -n mygpt rollout status deploy/mygpt-openwebui   # slow start is normal (Whisper reloads)
kubectl -n mygpt get secret mygpt-secrets -o jsonpath='{.data.<KEY>}' | base64 -d | wc -c   # sanity
```

Only the encrypted file is committed — never a plaintext value. The `sops`
creation rule in `.sops.yaml` matches the *repo path* (`charts/mygpt/values.secrets.yaml`),
so encryption must run on a file at that path — never redirect `sops --encrypt
/tmp/… > charts/…` (it errors "no matching creation rules" and truncates the
target). The `cp` + `--in-place` pair above is the verified flow.

---

## A. Azure OpenAI key — `AZURE_AI_API_KEY` + `AUDIO_TTS_OPENAI_API_KEY`

One account, **one key, two values** (`AUDIO_TTS_OPENAI_API_KEY` is the same
key as `AZURE_AI_API_KEY` — keep them identical). Backs chat
(`gpt-5.6-luna`), RAG embeddings, and TTS.

**Rotate without downtime (staggered slot swap):** the account has `key1`/`key2`
slots. Put a fresh value from the *other* slot into SOPS first, deploy, then
rotate the one still in use.

```bash
az cognitiveservices account keys list -n mygpt-openai -g rg-mygpt-ai --query "{key1:key1, key2:key2}" -o tsv
# if the live key equals key1, regenerate key2 and use that; then flip key1 next time
az cognitiveservices account keys regenerate -n mygpt-openai -g rg-mygpt-ai --key-name key2
```

Set **both** `AZURE_AI_API_KEY` and `AUDIO_TTS_OPENAI_API_KEY` to the new value
(identical), then run the [loop](#2-the-rotate-any-value-loop).

Verify chat + embeddings through LiteLLM with the master key:

```bash
kubectl -n mygpt exec deploy/mygpt-litellm -- curl -s -X POST http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer <LITELLM_MASTER_KEY>" -H "Content-Type: application/json" \
  -d '{"model":"gpt-5.6-luna","messages":[{"role":"user","content":"ping"}]}'
```

Then flip the remaining slot (`key1` here) to a fresh value at your next rotation.

## B. Azure Document Intelligence — `DOCUMENT_INTELLIGENCE_KEY`

Account `mygpt-docintel`, RG `rg-mygpt-ai`. Requires the [step-1 repair](#1--repair-known-drift-first-document-parsing-is-currently-broken) —
the key only reaches the runtime once it sits under `secrets.data:`.

```bash
az cognitiveservices account keys list -n mygpt-docintel -g rg-mygpt-ai -o tsv   # which slot is live?
az cognitiveservices account keys regenerate -n mygpt-docintel -g rg-mygpt-ai --key-name key2
```

Set `DOCUMENT_INTELLIGENCE_KEY` (under `secrets.data:`) to the new value, then
the [loop](#2-the-rotate-any-value-loop). Verify a PDF upload parses in the UI
(no `Unexpected token '<', "<html>…"` error, RAG ingest completes).

## C. Dormant keys — `GEMINI_API_KEY`, `MOONSHOT_API_KEY`, `KW_SECRET_API_KEY`

`gpt-5.6-luna` and `text-embedding-3-large` are the only models wired into
LiteLLM (`files/litellm_config.yaml`); Kokoro TTS is unused (Azure OpenAI TTS is
live). These three keys are **not exercised at runtime** — rotating them is
pointless, removing them shrinks the attack surface. Delete the entries (and
their `values.yaml` defaults) or replace with `openssl rand -hex 32`. This is
safe to do in the same commit as any other rotation.

## D. LiteLLM master key — `LITELLM_MASTER_KEY` = `OPENAI_API_KEYS` = `RAG_OPENAI_API_KEY`

Three values that **must stay byte-identical** (they authenticate LiteLLM ↔
OpenWebUI ↔ RAG against the proxy's master key). Rotating invalidates existing
browser/UI sessions — users re-login, RAG re-authenticates; no data loss.

```bash
openssl rand -hex 32
```

Set all three to the new value, then the [loop](#2-the-rotate-any-value-loop).
After upgrade, confirm the UI still lists models and answers (login again).

## E. LiteLLM admin panel — `UI_USERNAME` / `UI_PASSWORD`

Credentials for the LiteLLM admin UI. Choose a strong pair
(`openssl rand -hex 16` for the password), then the
[loop](#2-the-rotate-any-value-loop).

## F. SearXNG — `SEARXNG_SECRET`

Local session-signing key for the self-hosted SearXNG instance. No cloud
credential involved.

```bash
openssl rand -hex 32
```

Set it, then the [loop](#2-the-rotate-any-value-loop). SearXNG restarts as part
of the upgrade; users' local search-session cookies are invalidated (minor).

## G. Microsoft SSO — `MICROSOFT_CLIENT_SECRET`

Entra app **`owui-sso`** (client id `80b4db32-…`). Prefer the **portal** so the
old secret stays valid until you're done:

> Azure portal → Microsoft Entra ID → App registrations → `owui-sso` →
> **Certificates & secrets** → **New client secret** → pick an expiry → copy the
> *value* now (only shown once).

Fast path via CLI (this *replaces* the current password immediately, so there is
a brief window where SSO sign-in fails until the upgrade lands — use only if the
short gap is acceptable):

```bash
az ad app credential reset --id 80b4db32-c03e-4a60-9593-05a694263337 --years 1
```

Set `MICROSOFT_CLIENT_SECRET` to the new value, then the
[loop](#2-the-rotate-any-value-loop). Existing SSO sessions end → users re-login.
Client id, tenant id, and redirect URI do **not** change. When confirmed working,
delete the old secret from the app registration.

## H. Postgres — `DATABASE_URL`, `OPENWEBUI_DATABASE_URL`, `postgres.password`

One role (`llmproxy`) used by both databases (`litellm`, `openwebui`). The
password is embedded in **two URLs** (`postgres://` and `postgresql://` schemes
— keep each scheme) and in `postgres.password`, which renders
`POSTGRES_PASSWORD` in the Secret. All three must agree.

**No data loss:** Postgres only applies `POSTGRES_PASSWORD` on first init, so
changing it in the Secret does nothing — you must rotate the role in-place, then
make the Secret match:

```bash
PW=$(openssl rand -hex 24)
kubectl -n mygpt exec statefulset/mygpt-db -- psql -U llmproxy -d postgres \
  -c "ALTER ROLE llmproxy WITH PASSWORD '$PW';"
```

Then set all three values to the new password:

```yaml
DATABASE_URL: postgres://llmproxy:<PW>@db:5432/litellm
OPENWEBUI_DATABASE_URL: postgresql://llmproxy:<PW>@db:5432/openwebui
postgres:
  password: <PW>
```

Then the [loop](#2-the-rotate-any-value-loop). Verify chat history still loads
and the DB is reachable. **Do not** "recreate the DB PVC to rotate" — that
destroys all chat history and RAG embeddings; only do it if you want a clean
reset.

## I. DNS service principal → cert-manager — `client-secret` in `azuredns-config`

SPN **`mygpt-caddy`** (`19c2b995-…`), role DNS Zone Contributor on
`softawebit.com`. Used by the ClusterIssuer `letsencrypt-azure-dns01` to write
`_acme-challenge` TXT records (DNS-01). **Not** in the SOPS file — it lives in
k8s Secret `azuredns-config` (namespace `cert-manager`). There is no `.env`
anymore (compose is retired).

```bash
# create a new credential for the SPN (prints the new secret once)
NEW=$(az ad sp credential reset --id 19c2b995-6762-4fbd-9b1f-01a006a295f6 --years 1 --query password -o tsv)

# push it into the ClusterIssuer's secret, then restart cert-manager
kubectl -n cert-manager create secret generic azuredns-config \
  --from-literal=client-secret="$NEW" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n cert-manager rollout restart deploy/cert-manager

# verify
kubectl get clusterissuer letsencrypt-azure-dns01 -o jsonpath='{.status.conditions[0].message}'
kubectl -n mygpt get certificate mygpt-tls        # Ready=True
```

`az ad sp credential reset` invalidates the previous password immediately; the
only consumer is cert-manager at TLS issuance/renewal, and the live cert is
valid for ~90 days — so this gap is harmless unless you rotate during a renewal.
Give the SPN credential an expiry and set a calendar reminder.

Optional force-reissue check (brief window without the TLS secret):
`kubectl -n mygpt delete secret mygpt-tls` → cert-manager reissues via DNS-01.

## J. SOPS encryption key — Azure KV `mygpt-sops/sops` (do this LAST)

The crown jewel. Rotating the KV key re-encrypts everything, so do it after all
other edits are committed, so there is only one re-encryption pass. Keep the old
key version alive until you've verified the re-encrypted file decrypts — if you
lose the key (or delete the old version too early), **all encrypted secrets are
unrecoverable**.

```bash
# 1. new version of key "sops" (old version stays)
NEWKID=$(az keyvault key create --vault-name mygpt-sops --name sops \
  --kty RSA --size 2048 --ops encrypt decrypt wrapKey unwrapKey \
  --query key.kid -o tsv)
echo "$NEWKID"   # e.g. https://mygpt-sops.vault.azure.net/keys/sops/<new-version>

# 2. decrypt current ciphertext with the still-pinned old key
sops --decrypt charts/mygpt/values.secrets.yaml > /tmp/secrets.plain.yaml

# 3. edit .sops.yaml → point azure_keyvault at $NEWKID

# 4. re-encrypt with the new key (must run on the repo path — see §2)
cp /tmp/secrets.plain.yaml charts/mygpt/values.secrets.yaml
sops --encrypt --in-place charts/mygpt/values.secrets.yaml

# 5. verify the new ciphertext decrypts
sops --decrypt charts/mygpt/values.secrets.yaml > /dev/null && echo RE-ENCRYPT-OK

# 6. commit, and only then retire the old version
git add charts/mygpt/values.secrets.yaml .sops.yaml && git commit -m "chore(secrets): rotate SOPS KV key"
az keyvault key delete --vault-name mygpt-sops --name sops \
  --id https://mygpt-sops.vault.azure.net/keys/sops/<old-version>   # f2e1735b-…
```

Notes:

- The URL in `.sops.yaml` **includes the key version** — that is what pins
  decryption. Update it every rotation.
- Do **not** enable Key Vault auto-rotation for this key: SOPS pins the version,
  so auto-rotation would strand the committed ciphertext.
- Old versions sit in soft-delete for 7 days (recoverable) — don't purge until
  the next rotation proves itself.

---

## 3. Full rotation — one pass

Doing every credential? Use this order so each section's dependency is ready and
there is a single re-encryption:

1. [§0 Pre-flight](#0-pre-flight) + snapshot
2. [§1 Repair drift](#1--repair-known-drift-first-document-parsing-is-currently-broken)
3. [A Azure OpenAI](#a-azure-openai-key--azure_ai_api_key--audio_tts_openai_api_key) (chat/embeddings/TTS)
4. [B Document Intelligence](#b-azure-document-intelligence--document_intelligence_key)
5. [C Dormant keys](#c-dormant-keys--gemini_api_key-moonshot_api_key-kw_secret_api_key) (remove)
6. [D LiteLLM master key](#d-litellm-master-key--litellm_master_key--openai_api_keys--rag_openai_api_key)
7. [E Admin UI](#e-litellm-admin-panel--ui_username--ui_password) + [F SearXNG](#f-searxng--searxng_secret)
8. [G SSO](#g-microsoft-sso--microsoft_client_secret)
9. [H Postgres](#h-postgres--database_url-openwebui_database_url-postgrespassword)
10. [I SPN → cert-manager](#i-dns-service-principal--cert-manager--client-secret-in-azuredns-config)
11. [J SOPS KV key](#j-sops-encryption-key--azure-kv-mygpt-sopssops-do-this-last) (last)
12. `helm secrets upgrade mygpt charts/mygpt -f charts/mygpt/values.secrets.yaml --namespace mygpt`
13. [Verification checklist](#verification-checklist)

You can batch all the `secrets.data:` edits (steps 3–9) in a **single**
decrypt → edit → encrypt → commit, but the SPN and KV-key steps still require
their own commands.

## Verification checklist

After any rotation:

```bash
kubectl -n mygpt get pods                                # all Running/Ready (db may restart once)
kubectl -n mygpt get ingress                             # chat.softawebit.com present
kubectl -n mygpt get secret mygpt-secrets -o jsonpath='{.data.DOCUMENT_INTELLIGENCE_KEY}' | base64 -d | wc -c   # >0
kubectl get clusterissuer letsencrypt-azure-dns01 -o jsonpath='{.status.conditions[0].status}'
kubectl -n mygpt get certificate mygpt-tls               # Ready=True
```

In the UI (`https://chat.softawebit.com`): sign in via SSO, send a chat message,
ask for a web search, upload a PDF and check RAG ingestion, and play a TTS
sample. Confirm chat history loaded (DB). Re-login if sessions were invalidated.

## Incident / rollback notes

- **Lost the SOPS key** → the committed ciphertext is unrecoverable. There is no
  backup; the vault is the crown jewel. Keep old key versions until a rotation
  is proven.
- **Rotated something that broke a service** → `git revert` the secrets commit
  (or restore `/tmp/secrets.plain.bak`, re-encrypt under the *current* key),
  then `helm secrets upgrade`. For Azure slots, flip back to the untouched
  `key1`/`key2` slot.
- **gitleaks pre-commit** (`core.hooksPath = .githooks`) blocks *new* staged
  leaks but never scrubs history — anything that ever touched a committed file
  is already burned; rotate it.
- **SSO and the DNS SPN are independent** — do not conflate them; both support
  expiry dates, set them.
