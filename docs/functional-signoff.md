# myGPT — Functional Signoff Checklist

Feature-by-feature acceptance checklist for signing off that
`https://chat.softawebit.com` works end-to-end. Every item names a feature, the
**expected behavior**, and **how to verify** it — CLI checks run from the
operator machine, UI checks run in the browser. Nothing is "working" until each
row's Pass criteria is met. This complements the [secret rotation
runbook](secret-rotation.md) and the deployment docs in
[README](../README.md).

## How to use this checklist

- Work top to bottom. CLI checks are fast; UI checks are the real proof.
- A row passes only when the **Expected** column holds.
- If a row fails, fix before signing off — do not carry a known-broken feature.
- Run the CLI checks after any upgrade/rotation to confirm nothing regressed.

## Preconditions

```bash
kubectl cluster-info >/dev/null
kubectl -n mygpt get pods                       # all Running / Ready
curl -sI https://chat.softawebit.com | head -1  # HTTP/2 200
```

## Feature checklist

| # | Feature | Expected behavior | Verify |
|---|---------|-------------------|--------|
| F1 | Chat (`gpt-5.6-luna`) | A message returns a real model answer | CLI (litellm) + UI |
| F2 | RAG embeddings | Documents are chunked & embedded (`text-embedding-3-large`) | CLI (litellm) + UI |
| F3 | Web search (SearXNG) | Search toggle returns live results with sources | UI |
| F4 | TTS (`tts-1`) | A message can be read aloud (audio plays) | CLI (Azure) + UI |
| F5 | Document parsing (Azure DocIntelligence) | A PDF upload is parsed into the knowledge base | UI |
| F6 | SSO (Microsoft Entra) | Sign-in via the Microsoft account works | UI |
| F7 | Postgres persistence | Chat history & model config survive a pod restart | UI + CLI |
| F8 | Redis | Caching / sessions work | CLI |
| F9 | TLS + ingress | Valid LE cert, DNS-01, `chat.softawebit.com` over HTTPS | CLI |
| F10 | LiteLLM admin | Admin panel reachable with `UI_USERNAME`/`UI_PASSWORD` | UI |
| F11 | Model visibility | All verified users see the models (no empty list) | UI |
| F12 | Branding / locale | Custom theme, logo favicon, default locale apply | UI |
| F13 | Rate-limit resilience | No 429 surfaces to the UI under normal use | CLI + observe |

---

### F1 — Chat

**Expected:** a user message to `gpt-5.6-luna` returns a fluent model answer.

CLI (exercises litellm → Azure OpenAI directly):

```bash
kubectl -n mygpt exec deploy/mygpt-litellm -- python3 -c "
import os, urllib.request, json
body=json.dumps({'model':'gpt-5.6-luna','messages':[{'role':'user','content':'Reply with exactly: PONG'}],'max_tokens':20}).encode()
req=urllib.request.Request('http://localhost:4000/v1/chat/completions', data=body,
  headers={'Authorization':'Bearer '+os.environ['LITELLM_MASTER_KEY'],'Content-Type':'application/json'})
d=json.load(urllib.request.urlopen(req, timeout=90))
print('content:', d['choices'][0]['message']['content'])
"
```

**Pass:** output is `content: PONG`. UI: send a chat message in a conversation.

### F2 — RAG embeddings

**Expected:** the embedding model returns vectors of dimension 3072.

```bash
kubectl -n mygpt exec deploy/mygpt-litellm -- python3 -c "
import os, urllib.request, json
body=json.dumps({'model':'text-embedding-3-large','input':'mygpt functional test'}).encode()
req=urllib.request.Request('http://localhost:4000/v1/embeddings', data=body,
  headers={'Authorization':'Bearer '+os.environ['LITELLM_MASTER_KEY'],'Content-Type':'application/json'})
d=json.load(urllib.request.urlopen(req, timeout=90))
print('dims:', len(d['data'][0]['embedding']))
"
```

**Pass:** `dims: 3072`. UI: upload a document to a knowledge base and ask a
question referencing it; the answer cites the uploaded content.

### F3 — Web search (SearXNG)

**Expected:** with Web search toggled on, the assistant retrieves live results.

CLI (SearXNG is reachable from the openwebui pod):

```bash
kubectl -n mygpt exec deploy/mygpt-openwebui -- python3 -c "
import urllib.request, json
req=urllib.request.Request('http://searxng:8080/search?q=mygpt+test&format=json', headers={'Accept':'application/json'})
d=json.load(urllib.request.urlopen(req, timeout=30))
print('results:', len(d.get('results',[])))
"
```

**Pass:** `results:` > 0. UI: enable Web search on a chat and ask a current-events
question; answer includes sources.

### F4 — TTS (`tts-1`)

**Expected:** a chat message can be read aloud (voice `nova`, Azure OpenAI TTS).

```bash
KEY=$(kubectl -n mygpt get secret mygpt-secrets -o jsonpath='{.data.AUDIO_TTS_OPENAI_API_KEY}' | base64 -d)
curl -s -m 30 -X POST "https://mygpt-openai.openai.azure.com/openai/v1/audio/speech" \
  -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
  -d '{"model":"tts-1","voice":"nova","input":"mygpt functional test"}' -o /tmp/tts.mp3 -w "http: %{http_code}\n"
file /tmp/tts.mp3
```

**Pass:** `http: 200` and the file is an MP3. UI: click the speaker icon on a
message and hear it.

### F5 — Document parsing (Azure Document Intelligence)

**Expected:** uploading a PDF parses it into text for RAG (no
`Unexpected token '<', "<html>…` error).

CLI (key is valid and matches the account):

```bash
SEC=$(kubectl -n mygpt get secret mygpt-secrets -o jsonpath='{.data.DOCUMENT_INTELLIGENCE_KEY}' | base64 -d)
AZ=$(az cognitiveservices account keys list -n mygpt-docintel -g rg-mygpt-ai --query key1 -o tsv)
[ "$SEC" = "$AZ" ] && echo "DocIntelligence key valid"
kubectl -n mygpt exec deploy/mygpt-openwebui -- sh -c \
  'echo "DOC_INTEL_KEY len: $(printenv DOCUMENT_INTELLIGENCE_KEY | wc -c)"; echo "engine: $(printenv CONTENT_EXTRACTION_ENGINE)"'
```

**Pass:** key valid, `DOC_INTEL_KEY len` > 0, `engine: document_intelligence`.
UI (manual): upload a multi-page PDF to a knowledge base; after ingestion, ask
a question and confirm the answer references the PDF's content. If a PDF throws
`Unexpected token '<'`, the upload exceeded the ingress `proxyBodySize`
(default 50m) — see [README troubleshooting](../README.md#troubleshooting).

### F6 — SSO (Microsoft Entra)

**Expected:** signing in with the Microsoft account (`@softawebit.com`) creates
a session; the app is branded "MyGPT".

CLI (wiring is present):

```bash
kubectl -n mygpt exec deploy/mygpt-openwebui -- sh -c \
  'echo "client: $MICROSOFT_CLIENT_ID"; echo "redirect: $MICROSOFT_REDIRECT_URI"; echo "secret len: $(echo -n "$MICROSOFT_CLIENT_SECRET" | wc -c)"'
az ad app show --id 80b4db32-c03e-4a60-9593-05a694263337 --query "web.redirectUris[]" -o tsv
```

**Pass:** client id `80b4db32-…`, redirect
`https://chat.softawebit.com/oauth/microsoft/callback`, secret len > 0, and that
redirect is in the app's registered URIs. UI (manual): open the app in a private
window → **Sign in** → Microsoft login → redirected back as a verified user;
admin can see the account in **Settings → Users**.

### F7 — Postgres persistence

**Expected:** chat history, model personas, and RAG knowledge survive pod restarts.

```bash
kubectl -n mygpt exec statefulset/mygpt-db -- pg_isready -U llmproxy
# spot check the two databases exist
kubectl -n mygpt exec statefulset/mygpt-db -- psql -U llmproxy -d postgres -Atc \
  "SELECT datname FROM pg_database WHERE datname IN ('litellm','openwebui');"
```

**Pass:** `accepting connections`, both databases listed. UI (manual): send a
message, `kubectl -n mygpt rollout restart deploy/mygpt-openwebui`, then confirm
the conversation is still there after it comes back.

### F8 — Redis

**Expected:** cache/session backend is up.

```bash
kubectl -n mygpt exec deploy/mygpt-redis -- redis-cli ping
```

**Pass:** `PONG`.

### F9 — TLS + ingress

**Expected:** valid Let's Encrypt cert (DNS-01 over Azure), served by
ingress-nginx on 80/443.

```bash
kubectl -n mygpt get ingress                          # chat.softawebit.com, 80+443
kubectl -n mygpt get certificate mygpt-tls            # Ready=True
curl -sI https://chat.softawebit.com | head -1        # HTTP/2 200
```

**Pass:** ingress present, `Ready=True`, `HTTP/2 200` with a valid cert. Renewal
is automatic (~30 days before expiry via cert-manager).

### F10 — LiteLLM admin

**Expected:** the LiteLLM admin UI is reachable with the configured
`UI_USERNAME`/`UI_PASSWORD`.

CLI (admin credentials are set):

```bash
kubectl -n mygpt get secret mygpt-secrets -o jsonpath='UI: {.data.UI_USERNAME}' | base64 -d 2>/dev/null; echo
```

UI (manual): log in to the LiteLLM admin panel and confirm the model list shows
`gpt-5.6-luna` and `text-embedding-3-large`. **Note:** if `UI_USERNAME` /
`UI_PASSWORD` are empty, the admin panel has no auth — set them and redeploy
(see [secret rotation runbook §E](secret-rotation.md#e-litellm-admin-panel--ui_username--ui_password)).

### F11 — Model visibility

**Expected:** a `user`-role account sees all models (no empty model list).

```bash
kubectl -n mygpt exec deploy/mygpt-openwebui -- sh -c 'echo "BYPASS_MODEL_ACCESS_CONTROL: $BYPASS_MODEL_ACCESS_CONTROL"'
```

**Pass:** `BYPASS_MODEL_ACCESS_CONTROL: True` (required because the LiteLLM
models carry no access grants). UI: log in as a non-admin user and confirm the
model selector is populated.

### F12 — Branding / locale

**Expected:** custom logo favicon, theme, default locale, and app name "MyGPT".

```bash
kubectl -n mygpt exec deploy/mygpt-openwebui -- sh -c \
  'echo "name: $WEBUI_NAME"; echo "locale: $DEFAULT_LOCALE"; echo "favicon: $WEBUI_FAVICON_URL"'
curl -sI https://chat.softawebit.com/static/logo.svg | head -1
```

**Pass:** `name: MyGPT`, `locale: en`, favicon URL serves the logo (`200`). UI:
tab shows the logo, theme and persona config apply.

### F13 — Rate-limit resilience

**Expected:** no Azure `RateLimitError` surfaces to the UI during normal use.

```bash
az cognitiveservices account deployment show -n mygpt-openai -g rg-mygpt-ai \
  --deployment-name gpt-5.6-luna --query "{capacity:sku.capacity, limits:properties.rateLimits}" -o json
# retry config is live in litellm
kubectl -n mygpt exec deploy/mygpt-litellm -- sh -c 'grep -A6 router_settings /app/config.yaml | head'
```

**Pass:** capacity ≥ 10 (≈10 RPM / 10k TPM) and `router_settings` with
`RateLimitErrorRetries` present. If 429s still appear, raise capacity in
`infra/azure/variables.tf` (`model_deployments.gpt-5.6-luna.capacity`) and
`terraform apply`, then repeat F1.

---

## Signoff

| Feature | Pass (✓/✗) | Verified by | Date |
|---------|-----------|-------------|------|
| F1 Chat | | | |
| F2 RAG embeddings | | | |
| F3 Web search | | | |
| F4 TTS | | | |
| F5 Document parsing | | | |
| F6 SSO | | | |
| F7 Postgres persistence | | | |
| F8 Redis | | | |
| F9 TLS + ingress | | | |
| F10 LiteLLM admin | | | |
| F11 Model visibility | | | |
| F12 Branding / locale | | | |
| F13 Rate-limit resilience | | | |

All rows pass → the deployment is signed off for release to users.
