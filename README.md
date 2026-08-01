# Hybrid GPT Chat Application

This repository provides a comprehensive setup for a hybrid GPT chat application designed for personal use, leveraging AI models from multiple cloud providers. It combines a user-friendly frontend (OpenWebUI), a robust proxy (LiteLLM), and supporting services (PostgreSQL, Redis, SearxNG) to deliver a high-performance, customizable AI experience.

## Architectural Overview: Multicloud Hybrid AI

This application is built with a multicloud hybrid architecture, allowing you to utilize the strengths of different AI models from various cloud providers (e.g., OpenAI, Azure, Google Gemini) through a single, unified interface. The application's architecture ensures optimal performance, flexibility, and customizability for your personal AI needs.

```
+-------------------+      +-------------------+      +-------------------+
|     OpenWebUI     | <--> |     LiteLLM     | <--> |   LLM Providers   |
| (User Interface)  |      | (API Gateway)     |      | (Azure, Gemini,...) |
+-------------------+      +-------------------+      +-------------------+
      ^       |                ^
      |       | Uses           | Uses
      |       v                |
+-----+-------+        +-----+-------+
| SearxNG     |        |  Redis    |
| (Web Search)  |        | (Caching)  |
+-----+-------+        +-----+-------+
      ^                       ^
      |                       |
      | Stores Data, Configuration, & Embeddings
      v                       v
+-----------------------------------------------------+
|                PostgreSQL Database                  |
+-----------------------------------------------------+
      ^
      |
      +---> Vector Extension (for RAG)
```


### Key Components and Their Roles:

*   **OpenWebUI (Frontend):** Provides a modern, intuitive web interface for interacting with the LLMs. OpenWebUI is designed to be visually appealing and easy to use, making it simple to chat with AI models, manage conversations, and customize the application.  It allows you to select models, adjust settings, and manage your chat history.
*   **LiteLLM (Proxy):** Acts as a reverse proxy and API gateway, abstracting away the complexities of interacting with multiple LLM providers. LiteLLM allows you to seamlessly switch between different AI models from various cloud providers without changing the frontend code. It handles authentication, rate limiting, and load balancing, ensuring a smooth and reliable experience. This key architectural decision enables hybrid LLM infrastructure.
*   **PostgreSQL (Database):** Provides persistent storage for OpenWebUI and LiteLLM data. PostgreSQL stores user profiles, chat history, API key configurations, model information, and other application data. This ensures that your conversations and settings are preserved across sessions.  The database can be further configured for backup and redundancy.
*   **Redis (Caching):** Acts as an in-memory data store, caching frequently accessed data to improve performance. Redis reduces the load on the LLM providers and the database, resulting in faster response times and a smoother user experience.  This configuration improves responsiveness and reduces cloud provider costs.
*   **SearxNG (Web Search - RAG):** Enhances the LLM's knowledge by providing real-time information from the web. OpenWebUI integrates with SearxNG to perform web searches and inject the search results into the LLM's context, enabling more informed and accurate responses via Retrieval Augmented Generation (RAG).  This feature makes the LLM more aware of current events and provides access to a broader knowledge base.

### Component Relationships:

*   **OpenWebUI <-> LiteLLM:** OpenWebUI sends user prompts to LiteLLM and displays the responses. It leverages LiteLLM's API to access different LLMs and manage the interaction flow.
*   **LiteLLM <-> LLM Providers:** LiteLLM routes the requests to configured LLM providers (Azure AI Foundry, Gemini, Moonshot). It handles the specific authentication and API requirements of each provider.
*   **OpenWebUI & LiteLLM -> PostgreSQL:** Both services connect to the same PostgreSQL instance but use separate databases (`litellm` and `openwebui`).
*   **LiteLLM -> Redis:** LiteLLM caches data in Redis to improve response times and reduce API usage costs.
*   **OpenWebUI -> SearxNG:** When enabled (via `.env`), OpenWebUI queries SearxNG to enrich prompts with relevant web search results.

## Requirements

*   **Docker:** Docker must be installed and running on your system.
*   **Docker Compose:** Docker Compose V2 must be installed. This setup is designed for Docker Compose.
*   **`compose.yml`:** A `compose.yml` file must exist in the root of your project.
*   **.env Files:** Ensure `.env` exists with appropriate settings, or create it from `.env.example`.

## LLM Stack Components

*   **LiteLLM:** [https://litellm.ai/](https://litellm.ai/)
*   **OpenWebUI:** [https://github.com/open-webui/open-webui](https://github.com/open-webui/open-webui)
*   **PostgreSQL:** [https://www.postgresql.org/](https://www.postgresql.org/)
*   **Redis:** [https://redis.io/](https://redis.io/)
*   **SearxNG:** [https://searxng.org/](https://searxng.org/)

## Files

*   **`Makefile`:** The management Makefile (use `make` to see available targets).
*   **`compose.yml`:** Defines the services for the LLM stack.
*   **`.env.example`:** Example environment file (copy to `.env` and fill in your API keys).
*   **`.env`:** Environment configuration for both LiteLLM and OpenWebUI (git-ignored).
*   **`litellm_config.yaml`:** LiteLLM model list (Azure AI Foundry + xAI).
*   **`initdb.d/`:** PostgreSQL initialization scripts.
*   **`searxng/`:** SearxNG configuration files.
*   **`.gitleaks.toml`:** Gitleaks configuration.
*   **`.githooks/`:** Git hooks (pre-commit secret scan).

## Quick Start on a New Machine

These steps bring up the whole stack (OpenWebUI + LiteLLM + PostgreSQL + Redis +
SearxNG) on a brand-new machine — macOS (Docker Desktop) or Linux (Ubuntu 24.04
VM/server). Total time: ~10 minutes.

### What you need before you begin

- [ ] **Docker** with Docker Compose v2 (install steps below)
- [ ] **API key** for at least one LLM provider — Azure AI Foundry recommended
- [ ] **A Tailscale tailnet** with this machine on it, plus **Azure DNS** for your
      domain. HTTPS is served at `https://chat.softawebit.com`, reachable by your
      tailnet devices only.

### 1. Install Docker

#### macOS (Docker Desktop)

1. Download and install Docker Desktop from
   https://www.docker.com/products/docker-desktop/
2. Launch Docker Desktop and wait for the whale icon to stop animating
   (Docker daemon must be running before `docker` commands work).
3. Verify:

   ```bash
   docker --version && docker compose version
   ```

#### Linux (Ubuntu 24.04)

```bash
# Install prerequisites
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# Add Docker's official GPG key and repository
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine + Compose plugin
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Allow your user to run docker without sudo (re-login afterwards)
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version && docker compose version
```

### 2. Clone the repository

```bash
git clone <your-repo-url> mygpt
cd mygpt
```

### 3. Create `.env` from the example

```bash
make setup    # copies .env.example → .env (never overwrites an existing .env)
nano .env     # or vim/emacs
```

### 4. Fill in at least one provider API key

The stack is provider-agnostic — the models that appear in the UI are the ones
whose keys you set. At minimum, set **one** of these in `.env`:

| Provider | Variable | Get a key at |
|----------|----------|--------------|
| **Azure AI Foundry** (chat, Grok, embeddings) | `AZURE_AI_API_KEY` + `AZURE_AI_API_BASE` | https://ai.azure.com |
| **Google Gemini** | `GEMINI_API_KEY` | https://aistudio.google.com |
| **Moonshot / Kimi** | `MOONSHOT_API_KEY` | https://platform.moonshot.cn |

> **Azure AI Foundry** is used for `gpt-5.6-luna` (chat) and `text-embedding-3-large`
> (RAG embeddings). Set `AZURE_AI_API_BASE` (e.g.
> `https://foundry-ai.<region>.services.ai.azure.com`) and `AZURE_API_VERSION`
> (e.g. `2024-05-01-preview`) — the deployments must exist in your Foundry project.
> **xAI** is used for `grok-4.5` directly (key at https://console.x.ai).

### 5. Start the stack

```bash
make start
```

This pulls the images, creates the databases, and starts everything in detached
mode. First run takes a few minutes (image pulls + DB initialization).

### 6. Verify it's healthy

```bash
make status                          # all containers should be "Up"
curl -s https://chat.softawebit.com  # OpenWebUI via HTTPS → 200
```

LiteLLM is internal-only now, so check it from inside the container:

```bash
# Health check → "I'm alive!"
docker compose exec litellm python3 -c "import urllib.request as u; print(u.urlopen('http://localhost:4000/health/liveliness').read().decode())"

# List configured models (replace the key with your LITELLM_MASTER_KEY from .env)
docker compose exec litellm python3 -c "
import urllib.request as u
r = u.Request('http://localhost:4000/v1/models', headers={'Authorization': 'Bearer <LITELLM_MASTER_KEY>'})
print(u.urlopen(r).read().decode())"

# Test a completion via gpt-5.6-luna
docker compose exec litellm python3 -c "
import urllib.request as u, json
body = json.dumps({'model': 'gpt-5.6-luna', 'messages': [{'role': 'user', 'content': 'Say hi'}]}).encode()
r = u.Request('http://localhost:4000/v1/chat/completions', data=body,
              headers={'Authorization': 'Bearer <LITELLM_MASTER_KEY>', 'Content-Type': 'application/json'})
print(u.urlopen(r).read().decode())"
```

### 7. Open the UI

- **OpenWebUI:** https://chat.softawebit.com (auth is disabled by default — you land straight in)
- **LiteLLM / SearxNG:** internal-only — reach them through OpenWebUI

Or use the Makefile helpers: `make open-ui`, `make open-proxy`.

> **Note on topology:** TLS is terminated by **Caddy** on host port 443. The
> certificate for `chat.softawebit.com` is issued via the **Azure DNS-01 challenge**
> (no inbound ports needed — this box is behind CGNAT), and Caddy reverse-proxies
> to `openwebui:8080`. Every backend (`openwebui`, `litellm`, `searxng`, `db`,
> `redis`) is reachable **only on the internal `my_network`**, by service name.
> To debug an internal service from the host, exec into it
> (`docker compose exec <svc> sh`) or run a one-off container on the network
> (`docker run --rm --network mygpt_my_network curlimages/curl ...`).

### Full command reference

```bash
make                # Show all targets
make start          # Start all containers
make stop           # Stop all containers
make status         # Container status
make logs           # Tail logs from all services
make logs/svc svc=X # Logs from one service (litellm|openwebui|db|redis|searxng)
make setup          # Create .env from .env.example
make pull           # Pull latest images
make config         # Validate compose.yml syntax
make clean          # Stop containers and remove volumes (⚠️ destroys data)
make gitleaks       # Run Gitleaks security scan
make open-ui        # Open OpenWebUI in the browser (HTTPS, tailnet only)
make open-proxy     # Show how to reach the internal-only LiteLLM proxy
make caddy-reload   # Reload Caddy config after editing Caddyfile
```

## HTTPS with a custom domain (Azure DNS-01)

This machine sits behind **CGNAT** — its public IP is unreachable from the internet,
so HTTP-01 certificate challenges are impossible, and Tailscale's built-in HTTPS
only issues certificates for the random `*.ts.net` tailnet name (which cannot be set
to a custom name). So `chat.softawebit.com` is served over your **Tailscale tailnet**
with a real Let's Encrypt certificate obtained via **DNS-01** against the **Azure
DNS** zone for `softawebit.com`:

```
tailnet device → https://chat.softawebit.com   (Caddy, TLS via Azure DNS-01)
              → openwebui:8080
```

*   DNS: an **A/CNAME record** for `chat.softawebit.com` resolves to this node's
    Tailscale IP (`100.123.171.13`) — publicly resolvable, but the address is CGNAT
    space, so **only tailnet devices can connect**.
*   **Caddy** (`caddy:2.11.4` + the `caddy-dns/azure` module, built in `./caddy`)
    owns host port **443** and issues/renews the certificate automatically via the
    Azure DNS-01 challenge — no inbound ports, no cron.
*   Only devices on your tailnet can reach the site — nothing is exposed to the
    public internet.

### One-time setup

1. Create an Azure service principal with **DNS Zone Contributor** on the
   `softawebit.com` zone:
   ```bash
   az ad sp create-for-rbac --name mygpt-caddy --role "DNS Zone Contributor" \
     --scopes "/subscriptions/<SUB>/resourceGroups/<RG>/providers/Microsoft.Network/dnszones/softawebit.com"
   ```
2. Fill the five `AZURE_*` values (subscription, resource group, tenant, client id,
   client secret) into `.env`.
3. Add an **A record** `chat.softawebit.com` → `100.123.171.13` in Azure DNS.
4. `make start` — Caddy issues the certificate automatically on first boot.

From any tailnet device, open **https://chat.softawebit.com**.

### Managing routes

Routes live in `Caddyfile`. After editing, reload without downtime:

```bash
make caddy-reload
```

## Configuration

### `compose.yml`

The `compose.yml` file defines the services for your LLM stack and their relationships.
All images are pinned to **stable tagged releases** (no rolling `latest`/`main` tags):

| Service | Image | Host port |
|---------|-------|-----------|
| `caddy` | `caddy:2.11.4` + `caddy-dns/azure` (built from `./caddy`) | `80`, `443` |
| `litellm` | `ghcr.io/berriai/litellm:v1.94.0` | internal |
| `openwebui` | `ghcr.io/open-webui/open-webui:0.11.0` | internal |
| `db` | `pgvector/pgvector:pg18` (PostgreSQL 18 + pgvector) | internal |
| `redis` | `redis:8.8.1` | internal |
| `searxng` | `searxng/searxng:2026.7.28-c01178d03` | internal |

Service notes:

*   **caddy:**
    *   Custom image (`./caddy`) with the `caddy-dns/azure` module. Owns host port
        443 and terminates TLS for `chat.softawebit.com`, obtaining the certificate
        via the Azure DNS-01 challenge, then reverse-proxies to `openwebui:8080`.
    *   **Depends On:** `openwebui`.
    *   **Relationship:** Serves the stack over HTTPS on the tailnet; edit
        `Caddyfile` and run `make caddy-reload` to apply changes without downtime.
*   **litellm:**
    *   Internal-only on port 4000 (reachable by service name `litellm`).
    *   Reads configuration from `litellm_config.yaml` and environment variables from `.env`.
    *   **Depends On:** `db` (PostgreSQL) and `redis`.
    *   **Relationship:** The core of the hybrid LLM architecture, routing requests to multiple LLM providers.
*   **openwebui:**
    *   Internal-only on port 8080; served over HTTPS at `https://chat.softawebit.com`.
    *   Uses a persistent volume `open-webui` for storing data.
    *   Reads environment variables from `.env` (with `DATABASE_URL` overridden in compose.yml for its own database).
    *   **Depends On:** `db` (PostgreSQL).
    *   **Relationship:** The user-facing interface, providing a chat experience and leveraging LiteLLM for model access and SearxNG for RAG.
*   **db:**
    *   Runs a PostgreSQL database for LiteLLM and OpenWebUI, **including the
        pgvector extension** (needed for RAG embeddings).
    *   Uses `./pgdata` for storing the database (mounted at `/var/lib/postgresql` —
        the Postgres 18+ layout).
    *   **Depends On:** initializes the `litellm` and `openwebui` databases from
        `initdb.d/initdb.sql` on first run.
    *   **Relationship:** Provides persistent storage for the entire application.
*   **redis:**
    *   Runs a Redis instance for caching.
    *   **Relationship:** Accelerates LiteLLM performance through caching.
*   **searxng:**
    *   Runs the SearxNG metasearch engine.
    *   Internal-only on port 8080; queried by OpenWebUI for web search.
    *   **Relationship:** Enables OpenWebUI to perform web searches for RAG, enhancing the LLM's knowledge.

### `.env`

Both services read from a single `.env` file. Key settings:

*   **`DATABASE_URL`:** The PostgreSQL connection string (internal: `db:5432`).
*   **`OPENWEBUI_DATABASE_URL`:** OpenWebUI's own database (`openwebui`), injected
    in `compose.yml`.
*   **`LITELLM_MASTER_KEY`:** The API key used to talk to the LiteLLM proxy
    (also set as `OPENAI_API_KEYS` so OpenWebUI authenticates against it).
*   **`REDIS_URL`:** The Redis connection string (non-TLS, as Redis has no SSL configured).
*   **Provider API keys** — set at least one for the models you want:
    *   **`AZURE_AI_API_KEY` / `AZURE_AI_API_BASE`:** Azure AI Foundry — `gpt-5.6-luna`
        and the `text-embedding-3-large` embeddings. Key from https://ai.azure.com.
    *   **`XAI_API_KEY`:** Grok via the xAI provider directly (`grok-4.5`).
        Key from https://console.x.ai.
    *   **`GEMINI_API_KEY`:** Google Gemini models.
    *   **`MOONSHOT_API_KEY`:** Moonshot/Kimi models via `https://api.moonshot.cn/v1`. Register at https://platform.moonshot.cn.
*   **`DEFAULT_MODELS`:** The model pre-selected in OpenWebUI (e.g. `gpt-5.6-luna`).
*   **`ENABLE_EVALUATION_ARENA_MODELS`:** Set to `False` to hide the OpenWebUI
    Model Arena (a virtual model used for A/B model comparison).
*   **`DEFAULT_PROMPT_SUGGESTIONS`:** JSON array of the suggestion chips shown
    in the OpenWebUI chat input (email, proofread, set tone, grammar, fact-check,
    web search, deep analysis). Edit the `title`/`content` to your own prompts.

> ⚠️ **Never commit `.env`** — it contains real API keys. It is git-ignored.
>
> ℹ️ **DB overrides env:** OpenWebUI stores these settings in its database on
> first boot. After changing them in `.env`, restart the container and, if the
> old values stick, update the corresponding `config` table rows:
> `docker compose exec db psql -U llmproxy -d openwebui -c "UPDATE config SET value=... WHERE key='ui.prompt_suggestions';"`

### `litellm_config.yaml`

Configure the LLM models that LiteLLM will route requests to:

*   **`model_list`:** Define the models you want to use, including:
    *   **`model_name`:** The name of the model as it will appear in OpenWebUI.
    *   **`litellm_params`:** The actual model configuration, including:
        *   **`model`:** The model identifier (e.g., `azure_ai/gpt-5.6-luna`, `xai/grok-4.5`).
        *   **`api_base`:** The API base URL (for Azure, Moonshot).
        *   **`api_key`:** The API key.
        *   **`api_version`:** The API version (for Azure).
*   **`litellm_settings`:** Global settings for LiteLLM.

The config includes models out of the box:

*   **Azure AI Foundry chat:** `gpt-5.6-luna` (via `azure_ai/`)
*   **xAI (direct):** `grok-4.5` (via `xai/`)
*   **Azure AI Foundry embeddings (RAG):** `text-embedding-3-large`

> **Model IDs matter:** Grok IDs are `grok-4.3` / `grok-4.5` **with a dot** —
> `grok-4-3` returns a model-not-found error. Only models whose key/deployment is
> configured actually respond. Azure deployments must exist in your Foundry
> project and match the names in `litellm_config.yaml`.

To test a model after editing the config:

```bash
docker compose up -d litellm          # reload config
curl -s -H "Authorization: Bearer <LITELLM_MASTER_KEY>" http://localhost:4000/v1/models
```

### `.env.example`

A template environment file. Copy it to `.env` and fill in your API keys before starting the stack:

```bash
cp .env.example .env
```

### SearxNG Configuration (`searxng/`)

The SearxNG service includes configuration files:

*   **`settings.yml`:** Main SearxNG settings (rate limiter is disabled).
*   **`uwsgi.ini`:** uWSGI configuration for performance tuning.

### PostgreSQL Initialization (`initdb.d/`)

The `initdb.d/` directory contains SQL scripts that run automatically when the PostgreSQL container is first created:

*   **`initdb.sql`:** Creates the `openwebui` and `litellm` databases and enables the vector extension for RAG functionality.

### Gitleaks Configuration (`.gitleaks.toml`)

Gitleaks scans for secrets in the working tree **and** git history. The config
extends Gitleaks' default rules. The only allowlist entry is
`searxng/settings.yml`, which historically contained the local SearxNG
session-signing key (low risk, now moved to the `SEARXNG_SECRET` env var).

**Pre-commit hook:** `.githooks/pre-commit` runs `gitleaks git --staged` on every
commit and blocks commits that introduce secrets. Enable it in a fresh clone:

```bash
git config core.hooksPath .githooks
```

Run a full scan manually with `make gitleaks` (local binary if installed,
otherwise a pinned Docker image).

## Usage

### Makefile Commands

The project includes a `Makefile` for common tasks. Run `make` to see all targets:

```bash
make          # Show help
make start    # Start all containers
make stop     # Stop all containers
make restart  # Restart all containers
make status   # Show container status (alias: make ps)
make logs     # Tail logs from all services
make logs/svc svc=<name>  # Logs from one service
make setup    # Create .env from .env.example
make pull     # Pull latest Docker images
make config   # Validate compose.yml syntax
make gitleaks # Run Gitleaks security scan
make clean    # Stop containers and remove volumes (⚠️ destroys data)
make open-ui  # Open OpenWebUI in the browser
make open-proxy # Open LiteLLM in the browser
```

### Gitleaks Security Scan

The Gitleaks configuration scans for secrets and sensitive information in your codebase. To run a manual scan:

```bash
make gitleaks
```

This will scan all files in the repository for potential secrets and report any findings.

### Accessing the Application

*   **OpenWebUI:** `https://chat.softawebit.com` (HTTPS, tailnet only)
*   **LiteLLM:** internal-only (`litellm:4000` on the Docker network)
*   **SearxNG:** internal-only (`searxng:8080` on the Docker network)

### Using Example Configuration Files

To get started quickly, copy the example file and edit it:

```bash
# Copy the example file and edit
cp .env.example .env
nano .env
```

### RAG and Web Search

The application supports Retrieval Augmented Generation (RAG) with web search capabilities:

*   **SearxNG:** Provides web search functionality. Configure the search engine in `.env`.
*   **Vector Extension:** PostgreSQL (via the `pgvector/pgvector` image) includes the
    pgvector extension for storing and querying embeddings. It is enabled on both
    databases automatically via `initdb.d/initdb.sql`.
*   **Embedding Model:** Configure the embedding model in `.env`
    (e.g. `text-embedding-3-large`, served via Azure AI Foundry). The embedding
    deployment must exist in your Foundry project for RAG document uploads to work.
*   **Web Search:** Enable web search by setting `ENABLE_RAG_WEB_SEARCH=True` in `.env`.

### Key steps for configuration

1.  **Configure LLM Models**: Specify cloud based or local LLM models in your `litellm_config.yaml` or env variables.
2.  **Test each model**: Test each model separately by calling the LiteLLM proxy API to check API_KEY and function call integration.
3.  **Set up frontend models**: Select tested models to use with UI.

## Important Considerations

*   **Security:** Ensure all API keys and database passwords are changed from the defaults. Never commit `.env` files to version control.
*   **Model Configuration:** Carefully configure the LLM models within LiteLLM to ensure compatibility and optimal performance. Refer to LiteLLM documentation for configuration best practices. Test each model before using with the UI.
*   **Personalization:** Customize OpenWebUI's appearance, settings, and RAG features to align with your preferences. Experiment with personalization and test after each change.
*   **Hybrid AI Provider Considerations:** When you use multiple AI model providers, you may need to test the latency of each model to ensure reasonable performance.
*   **Environment File:** The `.env.example` file contains a template configuration. Copy it to `.env` and fill in your API keys. Never commit the actual `.env` file to version control.
*   **Gitleaks:** The Gitleaks configuration scans for secrets. Review the `.gitleaks.toml` file to understand what is being scanned and what is being allowed.
*   **Backup:** Regularly backup your PostgreSQL database by copying the `pgdata` volume to a safe location.
*   **Monitoring:** Monitor the container logs regularly to ensure all services are running correctly and to catch any issues early.
*   **Rate Limiting:** Configure rate limiting in SearxNG to prevent abuse and ensure fair usage.

## Troubleshooting

*   **"docker compose command not found"**: Ensure Docker Compose v2 is installed and in your `PATH`.
*   **"Permission denied"**: Ensure the Makefile is executable (`chmod +x Makefile`) or run `make <target>` directly.
*   **"Port 443 already in use"**: host port 443 is taken — **Caddy** binds it now.
    Find the holder with `lsof -i :443` and stop it (this may include a leftover
    `tailscale serve` from a previous setup — clear it with `tailscale serve reset`).
*   **Postgres container keeps restarting**: The Postgres 18+ image stores data in
    `/var/lib/postgresql` (not `/var/lib/postgresql/data`) and refuses to start with
    the old mount point. Make sure `compose.yml` mounts `./pgdata:/var/lib/postgresql:rw`.
*   **`extension "vector" is not available`**: The plain `postgres` image does not ship
    pgvector. Use the `pgvector/pgvector:pg18` image (already set in `compose.yml`).
*   **No models appear in OpenWebUI**: Check `litellm_config.yaml` and confirm at least
    one provider key is set in `.env`; reload with `docker compose up -d litellm`.
*   **`model not found` for Grok**: The IDs are `grok-4.3` / `grok-4.5` **with a dot**,
    not a dash. Via Azure Foundry, the deployment must exist under that name.
*   **LiteLLM cannot call provider APIs**: Test a model directly from inside the
    container (see the completion command in [step 6](#6-verify-its-healthy)) or
    watch logs with `make logs/svc svc=litellm`. Check the API endpoint and key.
*   **Database changes not applied**: To re-run `initdb.d/initdb.sql`, stop the stack
    (`make stop`), delete `./pgdata` (⚠️ destroys all data), then `make start`.
*   **Gitleaks false positives**: Add exceptions to the `allowlist` section of `.gitleaks.toml`.
*   **SearxNG misbehaving**: Check `searxng/settings.yml` — ensure `SEARXNG_SECRET`
    is set in `.env` (it overrides the placeholder `secret_key` in the file).
*   **Check logs for any service**: `docker compose -f compose.yml logs <service>`
    (`litellm`, `openwebui`, `db`, `redis`, `searxng`).

This setup provides a solid foundation for a personal, customized hybrid GPT chat application, with a clear architecture and robust management tools. Remember to adapt the configurations to your specific needs and security requirements.