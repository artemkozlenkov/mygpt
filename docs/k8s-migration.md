# Helm Migration Plan: compose → k3s

Status: **chart deployed & verified (ingress off)**. Compose still serves in
parallel. cert-manager + Azure DNS-01 ClusterIssuer live; ingress-nginx staged
(ClusterIP). `helm secrets install mygpt` deployed all workloads — DB databases
+ pgvector, litellm health/models, searxng search, kokoro TTS, openwebui health
all verified. Remaining: data migration → flip ingress to LoadBalancer →
cutover → decommission. See also the [secret rotation
strategy](../README.md#secret-rotation-strategy).

## Current state

**Target cluster** (verified 2026-08-04):
- k3s `v1.36.2+k3s1`, single node `art` (`control-plane`, Ready)
- Traefik disabled (`--disable traefik` — host 80/443 kept free for Caddy during cutover)
- local-path storage (default), metrics-server + coredns running
- Helm `v4.2.3` at `~/.local/bin/helm`; `kubectl`/`helm` work as `art` via `KUBECONFIG=/etc/rancher/k3s/k3s.yaml`

**Stack to replace** (7 services on the `my_network` bridge):

| Service | Image | Notes |
|---|---|---|
| `caddy` | built `./caddy` (xcaddy + caddy-dns/azure) | deploy-profile; owns host 80/443; Azure DNS-01 TLS for `chat.softawebit.com` |
| `litellm` | `ghcr.io/berriai/litellm:v1.94.0` | LLM gateway; `litellm_config.yaml` + `.env` |
| `openwebui` | `ghcr.io/open-webui/open-webui:0.11.0` | UI; `DATABASE_URL` overridden to `openwebui` DB |
| `kokoro-web` | `ghcr.io/eduardolat/kokoro-web:0.1.3` | TTS sidecar; internal-only (host 3000 taken by reactive_resume) |
| `db` | `pgvector/pgvector:pg18` | Postgres 18 + pgvector; `./pgdata` bind mount; `initdb.d/initdb.sql` |
| `redis` | `redis:8.8.1` | cache |
| `searxng` | `docker.io/searxng/searxng:2026.7.28-c01178d03` | web search; `searxng/*` config |

Shared single `.env` (gitignored) consumed by all services. Resource caps just added in `compose.yml`: webui/db 2 CPU·2G, litellm 1 CPU·2G, kokoro-web/searxng 1 CPU·1G, caddy 0.5 CPU·256M, redis 0.5 CPU·256M.

## Strategy: one umbrella chart

Build `charts/mygpt` — a single chart rendering each compose service as a k8s workload — rather than wiring up independent third-party charts.

- 1:1 mirror of compose: same images, same config files, same resource caps; `helm install mygpt .` replaces `docker compose up -d`.
- Keeps existing configs as data: `litellm_config.yaml`, `initdb.sql`, `searxng/*` → ConfigMaps; `.env` → Secret.
- Deterministic rollback: `helm rollback mygpt` + `docker compose up -d caddy`.
- Third-party charts (LiteLLM, OpenWebUI publish official ones) bring operators/CRDs/security-context opinions that diverge from the pinned, known-good config. Fallback if the umbrella chart grows unmanageable.

## Phase 0 — Ingress + TLS foundation (replicates Caddy)

- Install **cert-manager** (Jetstack chart) with an `ACME` `ClusterIssuer` using the `dns01.azureDNS` solver — reuse the exact `AZURE_*` service principal Caddy uses today. Keeps HTTPS working behind CGNAT (DNS-01, not HTTP-01).
- Install **ingress-nginx**, bound to host 80/443. Cannot bind while Caddy holds 80/443 — see Phase 5 ordering.
- *Alternative:* a Caddy Helm chart with the `caddy-dns/azure` module — preserves Caddyfile semantics, less idiomatic on k8s.

## Phase 1 — State & data migration

| Data | Source today | Migration to k8s |
|---|---|---|
| Postgres (`openwebui` + `litellm` DBs, pgvector) | `./pgdata` bind mount | `pg_dump` → StatefulSet with `pgvector/pgvector:pg18`, PVC on local-path, initdb ConfigMap (existing `initdb.sql`), restore via Job. CNPG operator = later upgrade path (HA/backups). |
| OpenWebUI data (uploads/avatars) | `open-webui` volume | `docker cp` from `webui` container → PVC. Chat history/config live in shared Postgres once `DATABASE_URL` is set. |
| Redis | ephemeral | none — fresh. |
| Kokoro cache / Caddy certs | volumes | none — cache rebuilds; cert re-issues via Phase 0. |

## Phase 2 — Config & secrets

- `.env` → Secret `mygpt-secrets`. Secrets are **SOPS-encrypted with Azure Key Vault** and committed as `charts/mygpt/values.secrets.yaml` (see [SOPS + Azure KMS](#sops--azure-kms) below). `.env` itself stays gitignored and is only the compose-time source.
- `litellm_config.yaml`, `initdb.sql`, `searxng/*` → ConfigMaps.
- `Caddyfile` logic → `Ingress` for `chat.softawebit.com` → `openwebui` Service.

### SOPS + Azure KMS

Secrets are encrypted at rest in git with [SOPS](https://github.com/getsops/sops) using an **Azure Key Vault** key, and decrypted **client-side** at install time by the `helm-secrets` plugin. No plaintext secrets are ever committed.

- **Key Vault:** `mygpt-sops` (rg-dns-prod, swedencentral); key `sops` — full URL pinned in `.sops.yaml`.
- **Operator access:** the deploying identity needs `Key Vault Crypto Officer` on the vault (granted to the signed-in Azure user) plus an `az login` / SPN session.
- **Tooling (on the operator host):** `sops` (3.13.3) + `helm-secrets` plugin v4.7.7 installed from the release `.tgz` (Helm v4 requires tgz plugin installs, not repo URLs).
- **Workflow:**
  ```bash
  # edit → encrypt → commit
  helm secrets decrypt charts/mygpt/values.secrets.yaml   # → edits the file in place to plaintext
  # ... edit ...
  helm secrets encrypt charts/mygpt/values.secrets.yaml   # → back to ciphertext, then commit
  # install / upgrade (decrypts on the fly)
  helm secrets upgrade mygpt charts/mygpt -f charts/mygpt/values.secrets.yaml --namespace mygpt
  ```
- **Rotation:** rotate the KV key version → update `.sops.yaml` → re-encrypt. If the key is lost, secrets are unrecoverable — keep the KV durable and backed up.

## Phase 3 — Chart skeleton

```
charts/mygpt/
  Chart.yaml              # apiVersion v2, helm 3/4 compatible
  values.yaml             # images, replicas, resource caps
  templates/
    _helpers.tpl
    namespace.yaml        # mygpt
    secret.yaml           # from gitignored values.secrets.yaml
    configmap-*.yaml      # litellm / initdb / searxng
    deployment-*.yaml     # litellm, openwebui, kokoro-web, searxng
    statefulset-db.yaml   # pgvector Postgres + PVC
    deployment-redis.yaml
    service-*.yaml        # cluster-internal, by service name (matches compose DNS)
    ingress.yaml
```

## Phase 4 — DNS/network

- A record `chat.softawebit.com → 100.123.171.13` already points at this host's tailnet IP — **unchanged**, since ingress-nginx binds the same host 80/443.
- Internal services resolve by name in the `mygpt` namespace — identical to compose's service-name DNS (`litellm:4000`, `kokoro-web:3000`, `searxng:8080`, `db:5432`). No env changes needed.

## Phase 5 — Cutover & rollback

1. `helm install mygpt charts/mygpt` with ingress/ingress-nginx disabled → verify all pods healthy against internal DNS.
2. **Maintenance window:** stop Caddy (`docker compose stop caddy`) → start ingress-nginx (80/443 free) → verify `https://chat.softawebit.com`.
3. Run data migration (dump/restore + volume copy).
4. Verify SSO (same `https://chat.softawebit.com/oauth/microsoft/callback` — already registered in Azure, no app changes), TTS, web search, RAG.
5. Rollback = `helm rollback` + `docker compose up -d caddy`.
6. **Decommission:** `docker compose down`, prune old volumes, retire `./caddy` build + `Caddyfile`, move `compose.yml` to an archive path, update Makefile/README.

## Known risks & pitfalls

- **80/443 handover** is the single irreversible moment — Caddy must stop before ingress-nginx binds. Keep Caddy up until Phase 5 step 2.
- **Postgres fsGroup/UID**: the postgres image runs as root/999; set `fsGroup` on the PVC or init fails on permissions (compose `./pgdata` is root-owned — same class of issue).
- **cert-manager needs the same AZURE_\* credentials as Caddy** — rotate both together when credentials rotate.
- **Single-node storage**: local-path data lives under `/var/lib/rancher/k3s/storage` (root) — schedule DB backups (existing habit: SQL dumps in the repo root).
- **Helm v4**: `Chart.yaml` `apiVersion: v2` is supported; nothing here uses removed v3-only features.
