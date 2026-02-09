# Flower Shop — Copilot Demo

Built entirely by GitHub Copilot. From schema design to Azure deployment — no hand-written code.

## What Copilot Built

- **SQL Database Project** — 3 tables, seed data, SqlPackage deployment
- **Data API Builder** — REST + MCP endpoints, zero custom code
- **Docker Compose** — SQL Server 2025, DAB, SQL Commander
- **Azure Deployment** — Azure SQL, ACR, Container Apps (custom image pattern)
- **Copilot Skills** — 6 reusable skills for DAB, Docker, Aspire, MCP, CLI, Config

## Use the Skills in Your Own Workspace

Copy the `.github/` folder into any repo to give Copilot deep knowledge of Data API Builder, SQL projects, Docker, Aspire, and MCP. It includes:

- **`copilot-instructions.md`** — Workflow rules that guide Copilot from schema design through Azure deployment
- **6 skills** — Domain-specific instructions Copilot loads automatically when relevant

These files teach Copilot *how you work* so it follows your patterns instead of guessing.

## Run Locally

```powershell
.\docker.ps1
```

## Deploy to Azure

```powershell
.\azure.ps1
```

## Architecture

```
database/          SQL Database Project (schema + seed data)
dab-config.json    Data API Builder config (REST + MCP)
docker-compose.yml Local dev stack
docker.ps1         One-command local startup
azure.ps1          One-command Azure deployment
Dockerfile         Custom DAB image for Azure (no storage accounts)
.github/           Copilot instructions + 6 skills
```
