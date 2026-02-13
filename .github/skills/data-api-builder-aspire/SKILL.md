---
name: data-api-builder-aspire
description: Guide for .NET Aspire orchestration of SQL Server + Data API Builder + SQL Commander + MCP Inspector. Use when asked to create an Aspire-based DAB environment.
---

# .NET Aspire + Data API Builder (AppHost Project Orchestration)

This skill provides a minimal workflow for running **SQL Server**, **Data API Builder (DAB)**, **SQL Commander**, and **MCP Inspector** using a standard **Aspire AppHost project** (`apphost.csproj` + `Program.cs`) for local development.

## Documentation references

- https://learn.microsoft.com/azure/data-api-builder/
- https://github.com/Azure/data-api-builder/tree/main/samples/aspire
- https://aspire.dev/
- https://learn.microsoft.com/dotnet/aspire/get-started/build-your-first-aspire-app

---

## Core Mental Model

- **One AppHost project** orchestrates everything (`apphost/apphost.csproj` + `apphost/Program.cs`)
- **`dotnet run --project apphost/apphost.csproj`** starts all services with health checks, dependencies, and telemetry
- **Containers talk by service name**, not localhost
- **DAB reads config from bind-mounted file** — mount `dab-config.json` read-only
- **SQL Server must be healthy before DAB starts** — use `.WaitFor()` and health checks
- **Aspire Dashboard** provides visual monitoring, logs, and metrics at `http://localhost:15888`

---

## Prerequisites

- **.NET 10+ SDK** — verify with `dotnet --version`
- **Aspire AppHost packages via NuGet** (no Aspire CLI required)
- **Docker Desktop running** — SQL Server runs in container
- **`dab-config.json`** in workspace root using `@env('MSSQL_CONNECTION_STRING')`

> **MVP rule:** Only add database schema/seed scripts if user explicitly asks.

---

## Quick Workflow (Checklist)

1. Create `.env` with connection string (gitignored).
2. Create `apphost/apphost.csproj` and `apphost/Program.cs` using the templates below.
3. Run with `dotnet run --project apphost/apphost.csproj`.
4. Access services via Aspire Dashboard.

---

## Templates

### `.env` (example)

```env
# Never commit this file
SA_PASSWORD=YourStrong@Passw0rd
MSSQL_CONNECTION_STRING=Server=sql-server;Database=MyDb;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=true
```

> **Critical:** Add `.env`, `**\bin`, and `**\obj` to `.gitignore` before creating secrets.

---

### `apphost/apphost.csproj` (minimal template)

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <Sdk Name="Aspire.AppHost.Sdk" Version="13.1.0" />

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <IsAspireHost>true</IsAspireHost>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Aspire.Hosting.SqlServer" Version="13.1.0" />
    <PackageReference Include="CommunityToolkit.Aspire.Hosting.Azure.DataApiBuilder" Version="13.1.2-beta.516" />
    <PackageReference Include="CommunityToolkit.Aspire.Hosting.McpInspector" Version="9.8.0" />
  </ItemGroup>
</Project>
```

---

### `apphost/Program.cs` (minimal template)

```csharp
// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

var builder = DistributedApplication.CreateBuilder(args);

var options = new
{
    SqlDatabase = "MyDb",
    DabConfig = "dab-config.json",
    DabImage = "1.7.83-rc",
    SqlCmdrImage = "latest"
};

var sqlServer = builder
    .AddSqlServer("sql-server")
    .WithDataVolume("sql-data")
    .WithEnvironment("ACCEPT_EULA", "Y")
    .WithLifetime(ContainerLifetime.Persistent);

var sqlDatabase = sqlServer
    .AddDatabase(options.SqlDatabase);

var dabServer = builder
    .AddContainer("data-api", image: "azure-databases/data-api-builder", tag: options.DabImage)
    .WithImageRegistry("mcr.microsoft.com")
    .WithBindMount(source: new FileInfo(options.DabConfig).FullName, target: "/App/dab-config.json", isReadOnly: true)
    .WithHttpEndpoint(targetPort: 5000, name: "http")
    .WithEnvironment("MSSQL_CONNECTION_STRING", sqlDatabase)
    .WithUrls(context =>
    {
        context.Urls.Clear();
        context.Urls.Add(new() { Url = "/graphql", DisplayText = "GraphQL", Endpoint = context.GetEndpoint("http") });
        context.Urls.Add(new() { Url = "/swagger", DisplayText = "Swagger", Endpoint = context.GetEndpoint("http") });
        context.Urls.Add(new() { Url = "/health", DisplayText = "Health", Endpoint = context.GetEndpoint("http") });
    })
    .WithOtlpExporter()
    .WithParentRelationship(sqlDatabase)
    .WithHttpHealthCheck("/health")
    .WaitFor(sqlDatabase);

var sqlCommander = builder
    .AddContainer("sql-cmdr", "jerrynixon/sql-commander", options.SqlCmdrImage)
    .WithImageRegistry("docker.io")
    .WithHttpEndpoint(targetPort: 8080, name: "http")
    .WithEnvironment("ConnectionStrings__db", sqlDatabase)
    .WithUrls(context =>
    {
        context.Urls.Clear();
        context.Urls.Add(new() { Url = "/", DisplayText = "Commander", Endpoint = context.GetEndpoint("http") });
    })
    .WithParentRelationship(sqlDatabase)
    .WithHttpHealthCheck("/health")
    .WaitFor(sqlDatabase);

var mcpInspector = builder
    .AddMcpInspector("mcp-inspector")
    .WithMcpServer(dabServer)
    .WithParentRelationship(dabServer)
    .WithEnvironment("NODE_TLS_REJECT_UNAUTHORIZED", "0")
    .WaitFor(dabServer)
    .WithUrls(context =>
    {
        context.Urls.First().DisplayText = "Inspector";
    });

await builder.Build().RunAsync();
```

---

### `dab-config.json` (minimal)

```json
{
  "$schema": "https://dataapibuilder.azureedge.net/schemas/latest/dab.draft.schema.json",
  "data-source": {
    "database-type": "mssql",
    "connection-string": "@env('MSSQL_CONNECTION_STRING')"
  },
  "runtime": {
    "rest": {
      "enabled": true,
      "path": "/api"
    },
    "graphql": {
      "enabled": true,
      "path": "/graphql"
    },
    "host": {
      "mode": "development",
      "cors": {
        "origins": ["*"],
        "allow-credentials": false
      }
    },
    "mcp": {
      "enabled": true
    }
  },
  "entities": {}
}
```

---

## Running the Stack

### Start Services

```powershell
dotnet run --project apphost/apphost.csproj
```

This command:
- Builds and restores packages
- Starts SQL Server container
- Waits for SQL health check
- Starts DAB container with bind-mounted config
- Starts SQL Commander
- Starts MCP Inspector
- Opens Aspire Dashboard

**Aspire Dashboard:** `http://localhost:15888`

---

### Access Services

| Service | URL | Purpose |
|---------|-----|---------|
| Aspire Dashboard | `http://localhost:15888` | Monitor all services, logs, metrics |
| DAB GraphQL | Click "GraphQL" link in dashboard | Query data via GraphQL |
| DAB Swagger | Click "Swagger" link in dashboard | REST API documentation |
| DAB Health | Click "Health" link in dashboard | Service health status |
| SQL Commander | Click "Commander" link in dashboard | SQL query tool |
| MCP Inspector | Click "Inspector" link in dashboard | Test MCP endpoints |

> **Note:** Aspire assigns dynamic ports. Use dashboard links instead of hardcoded URLs.

---

### Stop Services

Press `Ctrl+C` in terminal where `dotnet run --project apphost/apphost.csproj` is active, or:

Close the app from Aspire tooling and dashboard if needed.

---

## Adding Database Schema (Optional)

To deploy a SQL schema on startup, add this before `var dabServer`:

```csharp
var sqlDatabaseWithSchema = sqlDatabase
    .WithSqlProject(new FileInfo("database.sql").FullName);
```

Then change `dabServer` to wait for `sqlDatabaseWithSchema` instead of `sqlDatabase`:

```csharp
.WaitFor(sqlDatabaseWithSchema);
```

---

## Troubleshooting

### AppHost project fails to start

**Fix:**
- Verify .NET SDK and restore packages: `dotnet restore apphost/apphost.csproj`
- Re-run: `dotnet run --project apphost/apphost.csproj`

### SQL Server container fails to start

**Check Docker:**
```powershell
docker ps -a
docker logs <container-id>
```

### DAB can't connect to SQL Server

**Verify connection string** in `.env` uses service name `sql-server`, not `localhost`:
```env
MSSQL_CONNECTION_STRING=Server=sql-server;Database=MyDb;...
```

### Port conflicts

Aspire auto-assigns ports. If dashboard doesn't open, check terminal output for actual URL.

---

## Aspire vs Docker Compose

| Feature | Aspire | Docker Compose |
|---------|--------|----------------|
| **Definition** | AppHost project (`.csproj` + `Program.cs`) | YAML file |
| **Language** | C# | YAML |
| **Dependencies** | `.WaitFor()` + health checks | `depends_on` + healthcheck |
| **Monitoring** | Built-in dashboard with logs, metrics, traces | External tools required |
| **Service Discovery** | Automatic | Manual with service names |
| **Hot Reload** | Yes with `dotnet watch --project apphost/apphost.csproj` | No |
| **Debugging** | Native .NET debugging | Container debugging only |

**Use Aspire when:**
- You're already in a .NET project
- You want integrated telemetry and monitoring
- You need complex startup orchestration

**Use Docker Compose when:**
- You need multi-language support
- You want standard container orchestration
- You don't want a .NET AppHost project

---

## Configuration Details

### Service Names (DNS)

Containers reference each other by service name:
- SQL Server: `sql-server`
- DAB: `data-api`
- SQL Commander: `sql-cmdr`
- MCP Inspector: `mcp-inspector`

### Volumes

SQL Server data persists in Docker volume `sql-data`:
```powershell
docker volume ls | Select-String sql-data
```

To reset database:
```powershell
dotnet run --project apphost/apphost.csproj  # Stop with Ctrl+C
docker volume rm <volume-name>
dotnet run --project apphost/apphost.csproj  # Restart
```

### Health Checks

- SQL Server: Default SQL health check
- DAB: `GET /health` (must return 200)
- SQL Commander: `GET /health`

Services won't start until dependencies are healthy.

---

## Reference

- [Aspire Sample (Official)](https://github.com/Azure/data-api-builder/tree/main/samples/aspire)
- [Aspire AppHost Quickstart](https://learn.microsoft.com/dotnet/aspire/get-started/build-your-first-aspire-app)
- [Aspire Dashboard Docs](https://aspire.dev/dashboard/overview/)
- [DAB Configuration](https://learn.microsoft.com/azure/data-api-builder/configuration-file)
