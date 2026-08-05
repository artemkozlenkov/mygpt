# myGPT — Hybrid AI Chat Application

Personal hybrid AI chat app: **OpenWebUI** frontend, **LiteLLM** proxy over
Azure AI Foundry & xAI, with **pgvector Postgres**, **Redis**, **SearxNG**
search, and local **Kokoro TTS**. Runs on a single-node **k3s** cluster via the
`charts/mygpt` Helm chart, served at **https://chat.softawebit.com**
(tailnet-only).

## Architecture

```
tailnet device ──> https://chat.softawebit.com
                    ├── ingress-nginx (host 80/443, LoadBalancer)
                    ├── cert-manager (Let's Encrypt, Azure DNS-01 challenge)
                    └── openwebui (chat UI)
                         ├── litellm ──> Azure AI Foundry (gpt-5.6-luna) / xAI (grok-4.5)
                         ├── db (pgvector Postgres 18)  — chat history, config, RAG embeddings
                         ├── redis (cache)
                         ├── searxng (web search / RAG)
                         └── kokoro-web (local TTS)
```

The host is behind **CGNAT**, so TLS uses the **DNS-01** challenge:
cert-manager writes a TXT record to Azure DNS to prove domain ownership — no
inbound ports needed. Only tailnet devices can reach the host IP.

## Deploying

Requirements on the operator machine: `kubectl`, `helm`, `sops`, the
`helm-secrets` plugin, and `az` (authenticated, with the deploying identity
holding **Key Vault Crypto Officer** on `mygpt-sops`).

### Secrets (SOPS + Azure Key Vault)

`charts/mygpt/values.secrets.yaml` is **SOPS-encrypted** with Azure Key Vault
key `mygpt-sops/sops` (see `.sops.yaml`) and committed. Edit → encrypt → commit:

```bash
helm secrets decrypt charts/mygpt/values.secrets.yaml   # plaintext for editing
# ...edit...
helm secrets encrypt charts/mygpt/values.secrets.yaml   # back to ciphertext
git add charts/mygpt/values.secrets.yaml && git commit  # commit encrypted only
```

Deploy / upgrade (decrypts on the fly):

```bash
helm secrets upgrade mygpt charts/mygpt \
  -f charts/mygpt/values.secrets.yaml --namespace mygpt
```

### First-time cluster bootstrap

A new host needs cert-manager + the `letsencrypt-azure-dns01` ClusterIssuer and
ingress-nginx. The exact sequence used for this deployment is in
`docs/k8s-migration.md` (Phase 0).

## Daily operations

```bash
helm secrets upgrade mygpt charts/mygpt -f charts/mygpt/values.secrets.yaml --namespace mygpt
kubectl -n mygpt get pods
kubectl -n mygpt logs deploy/mygpt-openwebui
kubectl -n mygpt port-forward svc/openwebui 8000:8080   # local UI access
k9s                                                      # terminal UI (pods, logs, shells)
```

## Configuration

| What | Where |
|---|---|
| App env / secrets | `charts/mygpt/values.secrets.yaml` (SOPS) + `values.yaml` defaults |
| Models (LiteLLM) | `charts/mygpt/files/litellm_config.yaml` |
| Postgres init | `charts/mygpt/files/initdb.sql` |
| SearXNG | `charts/mygpt/files/searxng/` |
| Ingress / TLS | `charts/mygpt/templates/ingress.yaml` + ClusterIssuer `letsencrypt-azure-dns01` |

## Adding a new service with its own domain

The certificate pipeline and LoadBalancer are already in place — a new service
just needs three things: an **A record**, a **Deployment + Service**, and an
**Ingress** with a cert-manager annotation.

**1. DNS** — create an A record in the `softawebit.com` Azure zone pointing the
new hostname at the host's tailnet IP (`100.123.171.13`):

```bash
az network dns record-set a add-record -g rg-dns-prod -z softawebit.com \
  -n <subdomain> -a 100.123.171.13
```

The `_acme-challenge` TXT record for the certificate is created and removed
automatically by cert-manager — no manual TXT handling.

**2. Deploy the service** (example, `apps` namespace):

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: myservice, namespace: apps }
spec:
  selector: { matchLabels: { app: myservice } }
  template:
    metadata: { labels: { app: myservice } }
    spec:
      containers:
        - name: app
          image: <image>
          ports: [{ containerPort: 3000 }]
---
apiVersion: v1
kind: Service
metadata: { name: myservice, namespace: apps }
spec:
  selector: { app: myservice }
  ports: [{ port: 80, targetPort: 3000 }]
```

**3. Ingress** — the annotation makes cert-manager issue a Let's Encrypt cert
for the new domain automatically (DNS-01):

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myservice
  namespace: apps
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-azure-dns01
spec:
  ingressClassName: nginx
  tls:
    - hosts: [<subdomain>.softawebit.com]
      secretName: myservice-tls
  rules:
    - host: <subdomain>.softawebit.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service: { name: myservice, port: { number: 80 } }
```

Apply all three (`kubectl apply -f -`), then verify:

```bash
curl -sI https://<subdomain>.softawebit.com   # 200 + valid cert
kubectl -n apps get certificate               # Ready=True
```

**If the service belongs in this stack** (not standalone): add a Deployment +
Service template to `charts/mygpt/templates/`, a rule to `ingress.yaml`, and any
env in `values.secrets.yaml`, then `helm secrets upgrade mygpt …`.

**Notes**
- The domain must be in a zone the ClusterIssuer can write TXT to
  (`softawebit.com`, or a delegated subzone backed by its own
  `DNS Zone Contributor` service principal).
- New domains behind CGNAT work exactly like `chat.softawebit.com` — DNS-01
  needs no inbound ports, so nothing else to configure.
- Standalone services manage their own secrets (a normal k8s `Secret`); chart
  services reuse `values.secrets.yaml`.

## Secret rotation strategy

Secrets live in **one store** now: `charts/mygpt/values.secrets.yaml`
(SOPS-encrypted, committed). Rotate → `helm secrets decrypt` → change →
`helm secrets encrypt` → commit → `helm secrets upgrade mygpt …`.

**Cadence:** rotate cloud keys quarterly; immediately on personnel change,
suspected leak, or when a value appears in a committed file/log (the gitleaks
hook blocks *new* leaks but never scrubs history).

| Credential | Lives in | Rotate by | Blast radius |
|-----------|----------|-----------|--------------|
| `AZURE_AI_API_KEY` (Foundry) | SOPS | Regenerate in the Foundry project / key vault | LLM + embeddings |
| `XAI_API_KEY` (Grok) | SOPS | Regenerate at https://console.x.ai | LLM calls |
| `GEMINI_API_KEY` | SOPS | Regenerate at https://aistudio.google.com | LLM calls |
| `MICROSOFT_CLIENT_SECRET` (SSO) | SOPS | Azure → App registrations → **Certificates & secrets** → new secret | Sign-in |
| `AZURE_CLIENT_SECRET` (SPN `mygpt-caddy`, DNS-01) | SOPS | `az ad sp credential reset --id 19c2b995-6762-4fbd-9b1f-01a006a295f6` | TLS issue/renew |
| SOPS key `mygpt-sops/sops` (Azure KV) | Azure (URL in `.sops.yaml`) | New KV key version → update `.sops.yaml` → re-encrypt | All encrypted secrets |
| `LITELLM_MASTER_KEY` (== `OPENAI_API_KEYS` == `RAG_OPENAI_API_KEY`) | SOPS | Generate a new key; **keep all three values identical** | All LLM traffic |
| Postgres password | SOPS (`DATABASE_URL`, `POSTGRES_PASSWORD`) | Same value in both; recreate the DB PVC on change | All data |
| `SEARXNG_SECRET` | SOPS | `openssl rand -hex 32` | Web search |
| `KW_SECRET_API_KEY` (Kokoro TTS) | SOPS | `openssl rand -hex 24` | TTS |
| `UI_USERNAME` / `UI_PASSWORD` (LiteLLM admin) | SOPS | Choose a strong pair | Proxy admin |
| `MOONSHOT_API_KEY` | SOPS | Remove the placeholder if unused | LLM calls |

Notes:

* The **gitleaks pre-commit hook** (`git config core.hooksPath .githooks`) blocks
  *new* staged secrets but does **not** scrub history — rotate anything that ever
  touched a committed file.
* The SSO app secret and the Caddy/DNS SPN secret are **independent** — rotate
  separately; give SPN secrets expiry dates.
* If the **SOPS KV key** is lost, all encrypted secrets are unrecoverable — treat
  the vault as the crown jewel of the backup story.

## Troubleshooting

* **Cert won't issue for a domain** → `kubectl -n <ns> describe certificate <name>`;
  check the ClusterIssuer is `Ready` and the SPN can write TXT to the zone
  (`az role assignment list --assignee <appId>`).
* **Domain unreachable** → A record must point to `100.123.171.13`; confirm the
  ingress-nginx LoadBalancer owns host 80/443
  (`kubectl -n ingress-nginx get svc`). Remember router DNS caching can lag.
* **`helm secrets` fails to decrypt** → the operator needs an `az login` session
  with **Key Vault Crypto Officer** on `mygpt-sops`.
* **Pod issues** → `k9s` (or `kubectl -n mygpt describe pod <name>`), then check
  logs with `kubectl -n mygpt logs deploy/<svc>`.
* **No models in the UI** → `kubectl -n mygpt exec deploy/mygpt-litellm -- …` hit
  `/v1/models` with `LITELLM_MASTER_KEY`; check `files/litellm_config.yaml` and
  the provider keys in the SOPS values.

## Migration history

Ran on Docker Compose until **2026-08-05**, then cut over to k3s + Helm. Full
write-up (cluster bootstrap, data migration, cutover): `docs/k8s-migration.md`.
