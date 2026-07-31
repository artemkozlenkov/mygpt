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
*   **LiteLLM <-> LLM Providers:** LiteLLM routes the requests to configured LLM providers (OpenAI, Azure, Gemini, DeepSeek, Moonshot). It handles the specific authentication and API requirements of each provider.
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
*   **`.env`:** Environment configuration for both LiteLLM and OpenWebUI.
*   **`nginx.conf`:** Nginx configuration (optional, removed from compose by default).
*   **`initdb.d/`:** PostgreSQL initialization scripts.
*   **`searxng/`:** SearxNG configuration files.
*   **`.gitleaks.toml`:** Gitleaks configuration.

## Quick Start on a Fresh VM

These steps bring up the whole stack (OpenWebUI + LiteLLM + PostgreSQL + Redis +
SearxNG) on a brand-new Ubuntu VM (tested on Ubuntu 24.04). Total time: ~10 minutes.

### 1. Install Docker

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
| **DeepSeek** (recommended, cheap) | `DEEPSEEK_API_KEY` | https://platform.deepseek.com |
| **xAI / Grok** | `XAI_API_KEY` | https://console.x.ai |
| **Azure OpenAI** | `AZURE_API_KEY` + `AZURE_API_BASE` | https://portal.azure.com |
| **Google Gemini** | `GEMINI_API_KEY` | https://aistudio.google.com |
| **Moonshot / Kimi** | `MOONSHOT_API_KEY` | https://platform.moonshot.cn |

### 5. Start the stack

```bash
make start
```

This pulls the images, creates the databases, and starts everything in detached
mode. First run takes a few minutes (image pulls + DB initialization).

### 6. Verify it's healthy

```bash
make status                                  # all containers should be "Up"
curl -s http://localhost:4000/health/liveliness   # LiteLLM → "I'm alive!"
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000  # OpenWebUI → 200
```

List the configured models and send a real chat request through LiteLLM:

```bash
# List models (replace the key with your LITELLM_MASTER_KEY from .env)
curl -s -H "Authorization: Bearer <LITELLM_MASTER_KEY>" http://localhost:4000/v1/models

# Test a completion via DeepSeek
curl -s -X POST http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer <LITELLM_MASTER_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"Say hi"}]}'
```

### 7. Open the UI

- **OpenWebUI:** http://localhost:8000 (auth is disabled by default — you land straight in)
- **LiteLLM:** http://localhost:4000
- **SearxNG:** http://localhost:8080

Or use the Makefile helpers: `make open-ui`, `make open-proxy`.

> **Note on ports:** PostgreSQL is exposed on host port **5433** and Redis on
> **6380** (not the defaults 5432/6379) so the stack can run alongside other
> projects that use the standard ports. Inside the Docker network the services
> still use `db:5432` and `redis:6379` — only the host-facing mappings differ.

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
make open-ui        # Open OpenWebUI in the browser
make open-proxy     # Open LiteLLM in the browser
```

## Configuration

### `compose.yml`

The `compose.yml` file defines the services for your LLM stack and their relationships.
All images are pinned to **stable tagged releases** (no rolling `latest`/`main` tags):

| Service | Image | Host port |
|---------|-------|-----------|
| `litellm` | `ghcr.io/berriai/litellm:v1.94.0` | `4000` |
| `openwebui` | `ghcr.io/open-webui/open-webui:0.11.0` | `8000` |
| `db` | `pgvector/pgvector:pg18` (PostgreSQL 18 + pgvector) | `5433` |
| `redis` | `redis:8.8.1` | `6380` |
| `searxng` | `searxng/searxng:2026.7.28-c01178d03` | `8080` |

Service notes:

*   **litellm:**
    *   Exposes LiteLLM on port 4000.
    *   Reads configuration from `litellm_config.yaml` and environment variables from `.env`.
    *   **Depends On:** `db` (PostgreSQL) and `redis`.
    *   **Relationship:** The core of the hybrid LLM architecture, routing requests to multiple LLM providers.
*   **openwebui:**
    *   Exposes OpenWebUI on port 8000 (mapped from container port 8080).
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
    *   Exposes SearxNG on port 8080.
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
    *   **`DEEPSEEK_API_KEY`:** DeepSeek models via `https://api.deepseek.com/v1`. Register at https://platform.deepseek.com.
    *   **`XAI_API_KEY`:** Grok models via `https://api.x.ai/v1`. Register at https://console.x.ai.
    *   **`AZURE_API_KEY` / `AZURE_API_BASE`:** Azure OpenAI models.
    *   **`GEMINI_API_KEY`:** Google Gemini models.
    *   **`MOONSHOT_API_KEY`:** Moonshot/Kimi models via `https://api.moonshot.cn/v1`. Register at https://platform.moonshot.cn.
*   **`DEFAULT_MODELS`:** The model pre-selected in OpenWebUI (e.g. `deepseek-chat`).

> ⚠️ **Never commit `.env`** — it contains real API keys. It is git-ignored.

### `litellm_config.yaml`

Configure the LLM models that LiteLLM will route requests to:

*   **`model_list`:** Define the models you want to use, including:
    *   **`model_name`:** The name of the model as it will appear in OpenWebUI.
    *   **`litellm_params`:** The actual model configuration, including:
        *   **`model`:** The model identifier (e.g., `azure/gpt-4o`, `gemini/gemini-2.0-flash`, `deepseek/deepseek-chat`).
        *   **`api_base`:** The API base URL (for Azure, DeepSeek, Moonshot).
        *   **`api_key`:** The API key.
        *   **`api_version`:** The API version (for Azure).
*   **`litellm_settings`:** Global settings for LiteLLM.

The config includes models out of the box:

*   **DeepSeek:** `deepseek-chat` (OpenAI-compatible at `https://api.deepseek.com/v1`)
*   **xAI / Grok:** `grok-4.3`, `grok-4.5` (at `https://api.x.ai/v1`)

> **Model IDs matter:** Grok IDs are `grok-4.3` / `grok-4.5` **with a dot** —
> `grok-4-3` returns a model-not-found error. Only models whose API key is set
> in `.env` actually respond; add more models here as needed (LiteLLM supports
> Azure, Gemini, OpenAI, Anthropic, and hundreds more via the `provider/model` prefix).

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

*   **`settings.yml`:** Main SearxNG settings.
*   **`limiter.toml`:** Rate limiting configuration.
*   **`uwsgi.ini`:** uWSGI configuration for performance tuning.

### PostgreSQL Initialization (`initdb.d/`)

The `initdb.d/` directory contains SQL scripts that run automatically when the PostgreSQL container is first created:

*   **`initdb.sql`:** Creates the `openwebui` and `litellm` databases and enables the vector extension for RAG functionality.

### Gitleaks Configuration (`.gitleaks.toml`)

The Gitleaks configuration scans for secrets and sensitive information in your codebase. It extends the default Gitleaks configuration and allows secrets in the `cmd/generate/config/rules` directory.

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

*   **OpenWebUI:** `http://localhost:8000`
*   **LiteLLM:** `http://localhost:4000`
*   **SearxNG:** `http://localhost:8080`

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
    (e.g. `text-embedding-ada-002`). Note: embeddings currently require an
    OpenAI-compatible key; if you only have a DeepSeek/Grok key, chat works but
    RAG document uploads may need an embedding provider.
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
*   **"Port is already allocated"** on 5432/6379: another PostgreSQL/Redis on the host.
    This stack maps to **5433** and **6380** by default to avoid collisions — or stop
    the other service. Check who holds a port with `lsof -i :5432`.
*   **Postgres container keeps restarting**: The Postgres 18+ image stores data in
    `/var/lib/postgresql` (not `/var/lib/postgresql/data`) and refuses to start with
    the old mount point. Make sure `compose.yml` mounts `./pgdata:/var/lib/postgresql:rw`.
*   **`extension "vector" is not available`**: The plain `postgres` image does not ship
    pgvector. Use the `pgvector/pgvector:pg18` image (already set in `compose.yml`).
*   **No models appear in OpenWebUI**: Check `litellm_config.yaml` and confirm at least
    one provider key is set in `.env`; reload with `docker compose up -d litellm`.
*   **`model not found` for Grok**: The IDs are `grok-4.3` and `grok-4.5` **with a dot**,
    not a dash.
*   **LiteLLM cannot call provider APIs**: Test a model directly:
    `curl -s -H "Authorization: Bearer <LITELLM_MASTER_KEY>" http://localhost:4000/v1/chat/completions ...`.
    Check the API endpoint and key.
*   **Database changes not applied**: To re-run `initdb.d/initdb.sql`, stop the stack
    (`make stop`), delete `./pgdata` (⚠️ destroys all data), then `make start`.
*   **Gitleaks false positives**: Add exceptions to the `allowlist` section of `.gitleaks.toml`.
*   **SearxNG misbehaving**: Check `searxng/settings.yml` — ensure `secret_key` is unique
    and the `limiter` is configured correctly.
*   **Check logs for any service**: `docker compose -f compose.yml logs <service>`
    (`litellm`, `openwebui`, `db`, `redis`, `searxng`).

This setup provides a solid foundation for a personal, customized hybrid GPT chat application, with a clear architecture and robust management tools. Remember to adapt the configurations to your specific needs and security requirements.