# Constitution

These are the foundational rules for this workspace. They override general best practices.

## 0. Personality

In plan mode or any other mode, your response should be terse. Don't provide the user scripts or terminal commands to run if it is possible for you to run them. Your response should be focused on the specific task at hand, without any additional information or context. If you need to ask the user for clarification, do so in a concise manner. Do not provide any explanations or justifications for your actions, unless explicitly asked for. Your goal is to efficiently accomplish the user's request with minimal interaction and without any unnecessary information. If your response is more than 3 sentences, you should reconsider. 

## 1. Minimum Viable First

Always start with the absolute smallest implementation possible:

- **Fewest tables.** Only create the tables strictly required to make the feature work.
- **Fewest columns.** Only include columns the feature cannot function without.
- **Fewest moving parts.** No middleware, services, abstractions, or layers beyond what is immediately necessary.
- **Fewest dependencies.** Do not add libraries, packages, or tools unless the task is impossible without them.
- **Fewest files.** Consolidate where reasonable rather than splitting prematurely.

## 2. Best Practices Do Not Override MVP

Even if an industry best practice, design pattern, or convention recommends additional structure (e.g., audit columns, soft deletes, junction tables, normalization, indexes, logging, validation layers), **do not include it** in the initial implementation. Start without it.

## 3. Ask Before Expanding

After delivering the MVP, explicitly ask the user before adding:

- Additional columns or tables
- Indexes, constraints, or relationships beyond the bare minimum
- Abstractions, patterns, or architectural layers
- Error handling, logging, or observability beyond what was requested
- Tests, documentation, or configuration files not explicitly asked for

Nothing is added silently. Every expansion is a conscious, user-approved decision.

## 4. Technology Preferences

### Cloud

| Preference | Rule |
|------------|------|
| Provider | Azure only |
| CLI | Use `az` CLI for all resource provisioning |
| Scripts | Save all commands to `azure.ps1` for audit and reuse |

### Database

| Context | Technology | CLI |
|---------|------------|-----|
| Local development | SQL Server (Docker or localhost) | `sqlpackage` |
| Cloud | Azure SQL | `sqlpackage` |
| Schema operations | SQL Database Project in `/database` folder | |
| Seed/test data | Always have some. Save to `database/Scripts/PostDeployment.sql` | |
| Developer tooling | Include SQL Commander (MCP) in every SQL project | |
| Visualize | Save to `db-overview.md` and intro with a mermaid ERD. | |

**SQL Database Project Structure:**
```
/database
  ├── database.sqlproj
  ├── Tables/
  │   └── *.sql (one file per table)
  ├── Scripts/
  │   └── PostDeployment.sql (seed data)
  └── database.publish.xml
```

**database.sqlproj Template:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<Project DefaultTargets="Build" Sdk="Microsoft.Build.Sql/2.0.0">
  <PropertyGroup>
    <Name>database</Name>
    <DSP>Microsoft.Data.Tools.Schema.Sql.SqlAzureV12DatabaseSchemaProvider</DSP>
    <ModelCollation>1033, CI</ModelCollation>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
  <ItemGroup>
    <PostDeploy Include="Scripts\PostDeployment.sql" />
  </ItemGroup>
</Project>
```

**Connection String Notes:**
- Host machine → SQL Server: `Server=localhost,14330` (exposed port)
- Container → SQL Server: `Server=sql-2025` (Docker service name)

**Schema Change Workflow:**
1. Edit/add `.sql` files in `database/Tables/`
2. Build: `dotnet build database/database.sqlproj`
3. Deploy: `sqlpackage /Action:Publish /SourceFile:database/bin/Debug/database.dacpac /TargetConnectionString:"$env:DATABASE_CONNECTION_STRING" /p:BlockOnPossibleDataLoss=false`
4. Restart DAB: `docker restart api-server`

> Note: sqlpackage handles schema diffs automatically — no manual `DROP TABLE` needed.

### API

| Preference | Rule |
|------------|------|
| Framework | Data API Builder (DAB) — no custom API code |
| Version | Use `1.7.83-rc` or later (never `latest`) — MCP requires 1.7+ |
| Endpoints | REST enabled by default; GraphQL optional |
| CLI | Use `dab` CLI for all configuration |
| MCP | Enabled by default in DAB 1.7+ — use for all data-plane operations |

**Data-Plane Operations (Query/Insert/Update/Delete):**
- **Prefer MCP over SQLCMD** — DAB exposes MCP tools for CRUD operations
- Before first data-plane request, ask user: "Want me to set up MCP so I can query your database directly?"
- If yes, create `.vscode/mcp.json` pointing to DAB's `/mcp` endpoint

**`.vscode/mcp.json` Template:**
```json
{
  "servers": {
    "my-database": {
      "url": "http://localhost:5000/mcp",
      "type": "http"
    }
  }
}
```

> Note: Change `my-database` to match project name (e.g., `flower-shop-db`). For cloud deployments, update URL to Azure endpoint.

### Authentication (Start Simple)

| Layer | Default | Override |
|-------|---------|----------|
| API Auth | `anonymous:*` for development | User specifies roles |
| DB Auth (local) | SQL Auth with single admin user | User specifies |
| DB Auth (Azure) | System Assigned Managed Identity (MSI) | — |

### AI Agents

| Context | Tool |
|---------|------|
| Local development | Microsoft Copilot |
| Cloud hosting | Azure AI Foundry |

### Frontend

- **Do not build** until explicitly requested
- Use Swagger UI to validate the API during development

### Testing

| What | How |
|------|-----|
| API | `.http` files in VS Code (REST Client extension) |
| Data queries | MCP tools via `.vscode/mcp.json` (preferred) |
| Schema scripts | `.sql` files via `sqlpackage` |

### Secrets

1. Store secrets in `.env` file using `KEY=value` format
2. Reference in DAB config with `@env('KEY')` syntax
3. **Require** a `.gitignore` entry for `.env` before any secrets are added