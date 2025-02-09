# Hybrid GPT Chat Application with Terraform Management

This repository provides a comprehensive setup for a hybrid GPT chat application designed for personal use, leveraging AI models from multiple cloud providers. It combines a user-friendly frontend (OpenWebUI), a robust proxy (LiteLLM), and supporting services (PostgreSQL, Redis, SearxNG) to deliver a high-performance, customizable AI experience. It also includes a script (`manager.sh`) to manage Docker Compose containers and a Git pre-commit hook to enforce Terraform code quality.

## Architectural Overview: Multicloud Hybrid AI

This application is built with a multicloud hybrid architecture, allowing you to utilize the strengths of different AI models from various cloud providers (e.g., OpenAI, Azure, Google Gemini) through a single, unified interface. The application's architecture ensures optimal performance, flexibility, and customizability for your personal AI needs.

```
+-------------------+      +-------------------+      +-------------------+
|     OpenWebUI     | <--> |     LiteLLM     | <--> |   LLM Providers   |
| (User Interface)  |      | (API Gateway)     |      | (OpenAI, Azure,...) |
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
```


### Key Components and Their Roles:

*   **OpenWebUI (Frontend):** Provides a modern, intuitive web interface for interacting with the LLMs. OpenWebUI is designed to be visually appealing and easy to use, making it simple to chat with AI models, manage conversations, and customize the application.  It allows you to select models, adjust settings, and manage your chat history.
*   **LiteLLM (Proxy):** Acts as a reverse proxy and API gateway, abstracting away the complexities of interacting with multiple LLM providers. LiteLLM allows you to seamlessly switch between different AI models from various cloud providers without changing the frontend code. It handles authentication, rate limiting, and load balancing, ensuring a smooth and reliable experience. This key architectural decision enables hybrid LLM infrastructure.
*   **PostgreSQL (Database):** Provides persistent storage for OpenWebUI and LiteLLM data. PostgreSQL stores user profiles, chat history, API key configurations, model information, and other application data. This ensures that your conversations and settings are preserved across sessions.  The database can be further configured for backup and redundancy.
*   **Redis (Caching):** Acts as an in-memory data store, caching frequently accessed data to improve performance. Redis reduces the load on the LLM providers and the database, resulting in faster response times and a smoother user experience.  This configuration improves responsiveness and reduces cloud provider costs.
*   **SearxNG (Web Search - RAG):** Enhances the LLM's knowledge by providing real-time information from the web. OpenWebUI integrates with SearxNG to perform web searches and inject the search results into the LLM's context, enabling more informed and accurate responses via Retrieval Augmented Generation (RAG).  This feature makes the LLM more aware of current events and provides access to a broader knowledge base.

### Component Relationships:

*   **OpenWebUI <-> LiteLLM:** OpenWebUI sends user prompts to LiteLLM and displays the responses. It leverages LiteLLM's API to access different LLMs and manage the interaction flow.
*   **LiteLLM <-> LLM Providers:** LiteLLM routes the requests to configured LLM providers (OpenAI, Azure, Gemini). It handles the specific authentication and API requirements of each provider.
*   **OpenWebUI & LiteLLM -> PostgreSQL:** OpenWebUI stores user information and chat histories in the PostgreSQL database, while LiteLLM may store API key configurations and model data.
*   **LiteLLM -> Redis:** LiteLLM caches data in Redis to improve response times and reduce API usage costs.
*   **OpenWebUI -> SearxNG:** When enabled (via `.env.owui`), OpenWebUI queries SearxNG to enrich prompts with relevant web search results.

## Requirements

*   **Docker:** Docker must be installed and running on your system.
*   **Docker Compose:** Docker Compose V2 must be installed. This setup is designed for Docker Compose.
*   **`pre-commit-terraform` Docker Image:** The `ghcr.io/antonbabenko/pre-commit-terraform` Docker image is used. Ensure you have network access to pull this image.
*   **`docker-compose.yml`:** A `docker-compose.yml` file must exist in the root of your project.
*   **.env Files:** Ensure `.env.litellm` and `.env.owui` exist with appropriate settings, or create them based on the provided examples.
*   **Terraform (Optional):** If you plan to use the `pre-commit-terraform` hook to manage your infrastructure-as-code, ensure Terraform is installed.

## LLM Stack Components

*   **LiteLLM:** [https://litellm.ai/](https://litellm.ai/)
*   **OpenWebUI:** [https://github.com/open-webui/open-webui](https://github.com/open-webui/open-webui)
*   **PostgreSQL:** [https://www.postgresql.org/](https://www.postgresql.org/)
*   **Redis:** [https://redis.io/](https://redis.io/)
*   **SearxNG:** [https://searxng.org/](https://searxng.org/)

## Files

*   **`manager.sh`:** The management script.
*   **`.git/hooks/pre-commit`:** The pre-commit hook for `pre-commit-terraform`.
*   **`docker-compose.yml`:** Defines the services for the LLM stack.
*   **`.env.litellm`:** Configuration for LiteLLM.
*   **`.env.owui`:** Configuration for OpenWebUI.

## Setup

1.  **Clone the Repository:**

    Clone this repository to your local machine. If you only need the scripts, you can download the raw scripts directly.

2.  **Place `manager.sh`:**

    Copy the `manager.sh` script to the root of your project (or a location of your choosing). Alternatively, ensure `manager.sh` is in your system's `PATH`.

3.  **Make `manager.sh` Executable:**

    ```bash
    chmod +x manager.sh
    ```

4.  **Create `.env` Files:**

    Create `.env.litellm` and `.env.owui` files in the root of your project. Populate them with the following example content, adjusting the values as needed:

    **`.env.litellm`:**

    ```shell
    DATABASE_URL=postgresql://llmproxy:dbpassword9090@db:5432/litellm
    STORE_MODEL_IN_DB="True"
    LITELLM_MASTER_KEY="sk-124781258123"
    LITELLM_TLS_ENABLED="True"
    REDIS_SSL="True"
    REDIS_URL="rediss://redis:6379/1"
    LITELLM_LOG="INFO"
    #custom
    AZURE_API_KEY=""
    AZURE_API_BASE=""
    GEMINI_API_KEY=""
    UI_USERNAME=""
    UI_PASSWORD=""
    MICROSOFT_REDIRECT_URI=""
    ```

    **`.env.owui`:**

    ```shell
    #basic
    WEBUI_AUTH=False
    ENABLE_OLLAMA_API=False
    ENABLE_LOGIN_FORM=false
    ENABLE_OAUTH_SIGNUP=true
    OPENWEBUI_NO_CHANGELOG=true
    ADMIN_EMAIL="admin@admin.com"
    WEBUI_NAME="MY GPT"
    DEFAULT_USER_ROLE="user"
    SHOW_ADMIN_DETAILS=false
    GLOBAL_LOG_LEVEL=ERROR
    #openai
    OPENAI_API_BASE_URL="http://litellm:4000"
    OPENAI_API_KEYS="sk-124781258123"
    #model
    DEFAULT_MODELS=gpt-4o
    REDIRECT_URI="http://localhost:8000/auth/callback"
    #oauth=""
    MICROSOFT_CLIENT_ID=""
    MICROSOFT_CLIENT_SECRET=""
    MICROSOFT_CLIENT_TENANT_ID=""
    MICROSOFT_REDIRECT_URI=""
    #db=""
    DATABASE_URL=postgresql://llmproxy:dbpassword9090@db:5432/openwebui
    #websearch
    ENABLE_RAG_WEB_SEARCH=True
    ENABLE_SEARCH_QUERY=True
    ENABLE_RAG_WEB_SEARCH=True
    RAG_WEB_SEARCH_ENGINE="searxng"
    RAG_WEB_SEARCH_RESULT_COUNT=3
    RAG_WEB_SEARCH_CONCURRENT_REQUESTS=10
    SEARXNG_QUERY_URL="http://searxng:8080/search?q=<query>"
    # redis
    # REDIS_URL="rediss://redis:6379"
    #Embeddings
    RAG_EMBEDDING_MODEL=text-embedding-ada-002
    RAG_EMBEDDING_MODEL_AUTO_UPDATE=True
    RAG_EMBEDDING_ENGINE=openai
    PDF_EXTRACT_IMAGES=True
    RAG_OPENAI_API_BASE_URL=""
    RAG_OPENAI_API_KEY=""
    # Speech
    # AUDIO_TTS_ENGINE=azure
    # AUDIO_TTS_AZURE_SPEECH_OUTPUT_FORMAT=audio-24khz-160kbitrate-mono-mp3
    # AUDIO_TTS_AZURE_SPEECH_REGION=swedencentral
    # AUDIO_TTS_VOICE=en-US-AlloyMultilingualNeuralHD
    # AUDIO_TTS_API_KEY=""
    ```

5.  **Install the Pre-Commit Hook (Optional):**

    *   If you plan to use the `pre-commit-terraform` hook, copy the contents of the `pre-commit` file to `.git/hooks/pre-commit` in your Git repository. If the `.git/hooks` directory doesn't exist, create it first. Be sure to name the file *exactly* `pre-commit` (no extension).

    *   Make the `pre-commit` hook executable:

        ```bash
        chmod +x .git/hooks/pre-commit
        ```

6.  **Configure the `pre-commit` hook (Optional):**

    *   If you plan to use the `pre-commit-terraform` hook, edit the `.git/hooks/pre-commit` file and ensure the `MANAGER_SCRIPT` variable points to the correct location of your `manager.sh` script. **This is critical for the hook to work!**

## Configuration

### `manager.sh`

The `manager.sh` script has the following configurable variables:

*   **`COMPOSE_FILE`:** (Default: `docker-compose.yml`) Specifies the name of the Docker Compose file. Edit the `manager.sh` file directly to change this.
*   **`PRE_COMMIT_TERRAFORM_TAG`:** (Default: `latest`) Specifies the tag for the `ghcr.io/antonbabenko/pre-commit-terraform` Docker image. Edit the `manager.sh` file directly to change this.
*   **`MANAGER_SCRIPT`:** This variable in the `.git/hooks/pre-commit` file. This *must* point to the correct location of the `manager.sh` script for the hook to function correctly.

### `docker-compose.yml`

The `docker-compose.yml` file defines the services for your LLM stack and their relationships:

*   **litellm:**
    *   Exposes LiteLLM on port 4000.
    *   Reads configuration from `litellm_config.yaml` (optional) and environment variables from `.env.litellm`.
    *   **Depends On:** `db` (PostgreSQL) and `redis`.
    *   **Relationship:** The core of the hybrid LLM architecture, routing requests to multiple LLM providers.
*   **openwebui:**
    *   Exposes OpenWebUI on port 8000.
    *   Uses a persistent volume `open-webui` for storing data.
    *   Reads environment variables from `.env.owui`.
    *   **Depends On:** `db` (PostgreSQL).
    *   **Relationship:** The user-facing interface, providing a chat experience and leveraging LiteLLM for model access and SearxNG for RAG.
*   **db:**
    *   Runs a PostgreSQL database for LiteLLM and OpenWebUI.
    *   Uses a persistent volume `pgdata` for storing the database.
    *   **Relationship:** Provides persistent storage for the entire application.
*   **redis:**
    *   Runs a Redis instance for caching.
    *   **Relationship:** Accelerates LiteLLM performance through caching.
*   **searxng:**
    *   Runs the SearxNG metasearch engine.
    *   Exposes SearxNG on port 8080.
    *   **Relationship:** Enables OpenWebUI to perform web searches for RAG, enhancing the LLM's knowledge.

### `.env.litellm`

Key settings:

*   **`DATABASE_URL`:** The PostgreSQL connection string.
*   **`LITELLM_MASTER_KEY`:** A secure API key.
*   **`REDIS_URL`:** The Redis connection string.
*   **`AZURE_API_KEY`, `GEMINI_API_KEY`:** API keys for specific LLM providers you intend to use.
*   *Configure specific models for each LLM in `litellm_config.yaml`*

### `.env.owui`

Key settings:

*   **`OPENAI_API_BASE_URL`:** `http://litellm:4000` (points to your local LiteLLM).
*   **`OPENAI_API_KEYS`:** Same as `LITELLM_MASTER_KEY`.
*   **`DATABASE_URL`:** The PostgreSQL connection string.
*   **`SEARXNG_QUERY_URL`:** `http://searxng:8080/search?q=<query>` (for RAG).

## Usage

### `manager.sh` Commands

*   **`start`:** Starts the LLM stack.
    ```bash
    ./manager.sh start
    ```
*   **`stop`:** Stops the LLM stack.
    ```bash
    ./manager.sh stop
    ```
*   **`status`:** Shows the status of the containers.
    ```bash
    ./manager.sh status
    ```
*   **`gitleaks`:** Runs Gitleaks.
    ```bash
    ./manager.sh gitleaks
    ```
*   **`pre-commit-terraform`:** Runs `pre-commit-terraform`.
    ```bash
    ./manager.sh pre-commit-terraform
    ```

### Accessing the Application

*   **OpenWebUI:** `http://localhost:8000`
*   **LiteLLM:** `http://localhost:4000`
*   **SearxNG:** `http://localhost:8080`

### Key steps for configuration

1.  **Configure LLM Models**: Specify cloud based or local LLM models in your `litellm_config.yaml` or env variables.
2.  **Test each model**: Test each model separately by calling the LiteLLM proxy API to check API_KEY and function call integration
3.  **Set up frontend models**: Select tested models to use with UI

## Important Considerations

*   **Security:** Ensure all API keys and database passwords are changed from the defaults.
*   **Model Configuration:** Carefully configure the LLM models within LiteLLM to ensure compatibility and optimal performance. Refer to LiteLLM documentation for configuration best practices. Test each model before using with the UI.
*   **Personalization:** Customize OpenWebUI's appearance, settings, and RAG features to align with your preferences. Experiment with personalization and test after each change.
*   **Hybrid AI Provider Considerations:** When you use multiple AI model providers, you may need to test the latency of each model to ensure reasonable performance.

## Troubleshooting

*   **"docker compose command not found"**: Ensure Docker Compose is installed and in your `PATH`.
*   **"Permission denied"**: Ensure scripts are executable (`chmod +x`).
*   **LLM Stack Issues:** Check container logs (`docker compose logs <service>`). Common problems:
    *   Database connection issues.
    *   Missing API keys in `.env.litellm`.
    *   Incorrect `OPENAI_API_BASE_URL` in `.env.owui`.
    *   SearxNG not functioning.
*   **Incorrect user permissions**: Ensure USERID matches your local user.
*   **LiteLLM cannot call model provider APIs**: Test individual models from your providers using a curl command. Check the API endpoints and keys.

This setup provides a solid foundation for a personal, customized hybrid GPT chat application, with a clear architecture and robust management tools. Remember to adapt the configurations to your specific needs and security requirements.