---
name: docker-sql-dab-mcp
description: Guide for Docker Compose setup of SQL Server + Data API Builder + SQL Commander + MCP Inspector. Use when asked to create a local Docker dev environment for DAB.
---

# Docker SQL Server + DAB + MCP Inspector (Local Dev)

This skill provides a minimal, repeatable workflow for running **SQL Server**, **Data API Builder (DAB)**, **SQL Commander**, and **MCP Inspector** together in Docker Compose for local development and testing.

---

## Core Mental Model

- **One docker-compose.yml** controls the full stack. Never use raw `docker run`.
- **Containers talk by service name**, not `localhost`.
- **DAB reads config from `/App/dab-config.json`** — mount it **read-only**.
- **SQL Server must be healthy before DAB starts** — use healthcheck + `depends_on: condition: service_healthy`.
- **MCP Inspector requires a special URL** to auto-connect to DAB’s `/mcp` endpoint.

---

## Prerequisites

- Docker Desktop running
- A `dab-config.json` in the workspace root (use `@env('DATABASE_CONNECTION_STRING')`)
- Non-default SQL Server host port (assume 1433 is in use)

> **MVP rule:** Only add `database.sql` / `sample-data.sql` if the user explicitly asks.

---

## Quick Workflow (Checklist)

1. Pick a **cute Compose project name** (e.g., `bloom-tracker`).
2. Create `.env` with passwords/connection strings (gitignored).
3. Create `docker-compose.yml` using the template below.
4. Start services with `docker compose up -d`.
5. Open **MCP Inspector** using the pre-wired URL.

---

## Templates

### `.env` (example)

```env
# Never commit this file
SA_PASSWORD=YourStrong@Passw0rd
DATABASE_CONNECTION_STRING=Server=sql-2025;Database=TodoDb;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=true
SQL_COMMANDER_CONNECTION_STRING=Server=sql-2025;Database=TodoDb;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=true
```

> **Note:** For container-to-container connections, use `Server=sql-2025` (the service name), **not** `localhost`.

### `docker-compose.yml`

```yaml
name: bloom-tracker  # change to match your use case

services:
  sql-2025:
    image: mcr.microsoft.com/mssql/server:2025-latest
    container_name: sql-2025
    restart: unless-stopped
    environment:
      - ACCEPT_EULA=Y
      - MSSQL_SA_PASSWORD=${SA_PASSWORD}
    ports:
      - "14330:1433"  # non-default host port
    volumes:
      - sql-2025-data:/var/opt/mssql
    healthcheck:
      test: /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "${SA_PASSWORD}" -C -Q "SELECT 1" || exit 1
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s

  sql-cmdr:
    image: jerrynixon/sql-commander:latest
    container_name: sql-cmdr
    restart: unless-stopped
    environment:
      - ConnectionStrings__db=${SQL_COMMANDER_CONNECTION_STRING}
    ports:
      - "8080:8080"
    depends_on:
      sql-2025:
        condition: service_healthy

  api-server:
    image: mcr.microsoft.com/azure-databases/data-api-builder:1.7.83-rc
    container_name: api-server
    restart: unless-stopped
    environment:
      - DATABASE_CONNECTION_STRING=${DATABASE_CONNECTION_STRING}
    ports:
      - "5000:5000"
    volumes:
      - ./dab-config.json:/App/dab-config.json:ro
    depends_on:
      sql-2025:
        condition: service_healthy

  mcp-inspector:
    image: ghcr.io/modelcontextprotocol/inspector:latest
    container_name: mcp-inspector
    restart: unless-stopped
    environment:
      - HOST=0.0.0.0
      - MCP_AUTO_OPEN_ENABLED=false
      - DANGEROUSLY_OMIT_AUTH=true
    ports:
      - "6274:6274"
      - "6277:6277"
    depends_on:
      - api-server

volumes:
  sql-2025-data:
    external: false
```

### MCP Inspector auto-connect URL

```
http://localhost:6274/?transport=streamable-http&serverUrl=http%3A%2F%2Fapi-server%3A5000%2Fmcp
```

> **Important:** `http://localhost:6274` alone won’t auto-connect.

---

## Minimal DAB MCP Config (reference)

Ensure `dab-config.json` enables MCP and uses env vars:

```json
{
  "$schema": "https://github.com/Azure/data-api-builder/releases/download/v1.7.83-rc/dab.draft.schema.json",
  "data-source": {
    "database-type": "mssql",
    "connection-string": "@env('DATABASE_CONNECTION_STRING')"
  },
  "runtime": {
    "rest": { "enabled": true, "path": "/api" },
    "graphql": { "enabled": true, "path": "/graphql", "allow-introspection": true },
    "mcp": { "enabled": true, "path": "/mcp" },
    "host": { "mode": "development" }
  }
}
```

---

## Verification

- `docker compose ps` shows all services running
- SQL container health is **healthy**
- DAB responds at `http://localhost:5000/health`
- MCP Inspector opens via the special URL and lists tools

---

## Troubleshooting

### DAB can’t connect to SQL Server
- Ensure `TrustServerCertificate=true` in the connection string
- Use `Server=sql-2025` (service name) inside containers
- Confirm SQL container is healthy before DAB starts

### MCP Inspector opens but doesn’t connect
- Use the **special auto-connect URL** (not plain `localhost:6274`)
- Verify DAB is running and `/mcp` is enabled

---

## Consistency Rules (MVP)

1. **Always use docker-compose.yml** (no raw `docker run`).
2. **Always use non-default SQL ports** on the host.
3. **Always mount `dab-config.json` read-only** (`:ro`).
4. **Always use healthcheck + `depends_on: condition: service_healthy`.**
5. **Always include SQL Commander** and **MCP Inspector** in the compose stack.
6. **Use service names** for container-to-container connections.
7. **Ask before adding schema or seed files** (`database.sql`, `sample-data.sql`).
8. **Prefer a dedicated SQL login** for app connections; only use `sa` to bootstrap if needed.
