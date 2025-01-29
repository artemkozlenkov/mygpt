# Project README

## Overview

This project uses Docker Compose to set up a multi-service architecture consisting of a machine learning application (Litellm), a PostgreSQL database, a Redis cache, a search engine (SearXNG), and a web interface (Open Web UI). Each component runs in its own container, facilitating easy deployment and management.

## Services

### 1. Litellm
- **Description**: A machine learning application.
- **Container Name**: `litellm`
- **Image**: `ghcr.io/berriai/litellm:main-v1.57.8`
- **Ports**: Exposed on port `4000`.
- **Dependencies**: Requires the `db` service to be running first.
- **Configuration**: 
  - Configuration file is mounted from `./litellm_config.yaml` to `/app/config.yaml`.
  - Environment variables are loaded from `.env.litellm`.
- **Command**: Runs with the configuration and detailed debug options.
- **Network**: Connected to the `my_network`.

### 2. Open Web UI
- **Description**: Web interface for interacting with the machine learning model.
- **Container Name**: `webui`
- **Image**: `ghcr.io/open-webui/open-webui:latest`
- **Ports**: Exposed on port `8000`.
- **Dependencies**: Waits for the `db` service.
- **Configuration**: Environment variables are sourced from `.env.owui`.
- **Network**: Part of `my_network`.

### 3. PostgreSQL Database (db)
- **Description**: Relational database management system for storing application data.
- **Container Name**: `db`
- **Image**: `postgres:latest`
- **Ports**: Exposed on port `5432`.
- **Environment Variables**:
  - `POSTGRES_USER`: Set to `llmproxy`.
  - `POSTGRES_PASSWORD`: Set to `dbpassword9090`.
- **Volumes**: 
  - Data is persisted to `./pgdata` directory.
  - Initialization scripts are run from `./initdb.d`.
- **Network**: Connected to `my_network`.

### 4. Redis Cache
- **Description**: In-memory data structure store used as a cache.
- **Container Name**: `redis`
- **Image**: `redis:latest`
- **Ports**: Exposed on port `6379`.
- **Network**: Part of `my_network`.

### 5. SearXNG
- **Description**: Privacy-respecting metasearch engine.
- **Container Name**: `searxng`
- **Image**: `docker.io/searxng/searxng:latest`
- **Ports**: Exposed on port `8080`.
- **Configuration**:
  - Local config directory is mounted at `./searxng`.
  - Base URL and threading settings configured via environment variables.
- **Capabilities**: Drops all capabilities except for `CHOWN`, `SETGID`, `SETUID`.
- **Logging**: Configured to limit log size and rotation.
- **Network**: Connected to `my_network`.

## Volumes
- **litellm**: Persistent storage for the Litellm service.
- **open-webui**: Persistent storage for the Open Web UI.
- **pgdata**: Persistent storage for PostgreSQL data.

## Networks
- **my_network**: A user-defined bridge network allowing containers to communicate with one another.

## Usage

1. Ensure you have Docker and Docker Compose installed on your machine.
2. Clone the repository to your local machine:
   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```
3. Start the services using Docker Compose:
   ```bash
   docker-compose up -d
   ```
4. Access the services:
   - Litellm: [http://localhost:4000](http://localhost:4000)
   - Open Web UI: [http://localhost:8000](http://localhost:8000)
   - SearXNG: [http://localhost:8080](http://localhost:8080)

## Stopping the Services

To stop all running services, use:
```bash
docker-compose down
```

## Note
Make sure to configure any required environment files (`.env.litellm` and `.env.owui`) based on your requirements before starting the services.

## Contributing

If you wish to contribute to this project, please submit a pull request or open an issue.

## License

This project is licensed under the MIT License. See the LICENSE file for details.