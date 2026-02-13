---
name: data-api-builder-mcp
description: Guide for SQL MCP Server (Data API Builder MCP). Use when configuring databases for AI agent access via Model Context Protocol.
license: MIT
---

# SQL MCP Server (Data API Builder MCP)


This skill powers GitHub Copilot assistance for **SQL MCP Server**, a feature of Data API Builder (DAB) version 1.7+ that exposes databases to AI agents via the Model Context Protocol (MCP). It provides conversational guidance for configuring, deploying, and securing SQL MCP Server for AI-powered database workflows.

## Documentation references

- https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/overview
- https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/quickstart-visual-studio-code
- https://modelcontextprotocol.io/

---

## Core Mental Model

SQL MCP Server enables AI agents to interact with databases through a secure, typed interface. It's **Data API Builder with MCP capabilities**, not a separate product. Users who need MCP capabilities but have never heard of DAB should be guided through the complete setup.

### What SQL MCP Server Provides

- **MCP endpoint** at `/mcp` that exposes database entities as MCP tools
- **Six DML tools** for agents: `describe_entities`, `create_record`, `read_records`, `update_record`, `delete_record`, `execute_entity`
- **Security through abstraction** - agents never touch SQL directly, only work through DAB's entity layer
- **Deterministic queries** - no NL2SQL, only NL2DAB (safe, predictable SQL generation)
- **RBAC enforcement** - role-based access control applies to every tool operation
- **Built-in caching** - automatic result caching for `read_records` operations
- **Full observability** - OpenTelemetry tracing, health checks, Azure monitoring

### Key Architecture

```
AI Agent (VS Code, Foundry, Custom) 
  → MCP Protocol 
    → SQL MCP Server (/mcp endpoint)
      → DAB Entity Abstraction Layer
        → Database (SQL Server, PostgreSQL, MySQL, etc.)
```

### Configuration Approach

SQL MCP Server uses the **same `dab-config.json`** as regular DAB:
- **`data-source`**: Database connection settings
- **`runtime.mcp`**: MCP-specific settings (enabled, path, tool controls)
- **`entities`**: Exposed tables/views/stored procedures with descriptions and permissions

**MCP is enabled by default** when you have DAB 1.7+. You only need to configure it when you want to restrict what agents can do.

---

## Understanding MCP vs Data API Builder

### Common User Starting Points

**Scenario 1: User comes with MCP needs**
- User: "I want to give my AI agent access to my database via MCP"
- Approach: Explain SQL MCP Server is DAB's MCP feature, guide through full setup

**Scenario 2: User knows DAB, wants MCP**
- User: "I have a DAB config, how do I enable MCP?"
- Approach: Just upgrade to v1.7+ - MCP is enabled by default

**Scenario 3: User confused about naming**
- User: "Is SQL MCP Server different from Data API Builder?"
- Approach: Clarify it's DAB 1.7+ with MCP capabilities enabled

### Terminology Guide

| Term | What It Means |
|---|---|
| **SQL MCP Server** | Marketing name for DAB's MCP capabilities |
| **Data API Builder (DAB)** | The underlying engine that powers everything |
| **MCP** | Model Context Protocol - standard for AI agent tool discovery |
| **DML Tools** | The six CRUD+execute operations exposed via MCP |
| **Entity abstraction** | DAB's security layer that protects your database schema |

---

## Installation & Prerequisites

### Version Requirements

**Critical:** SQL MCP Server requires **Data API builder 1.7+** (currently in preview/RC).

### Install DAB CLI (Prerelease)

```bash
dotnet tool install microsoft.dataapibuilder --prerelease
```

Or update existing:
```bash
dotnet tool update microsoft.dataapibuilder --prerelease
```

### Verify Installation

```bash
dab --version
# Should show 1.7.x or higher
```

### Prerequisites Checklist

- [ ] .NET 9.0+ installed
- [ ] DAB CLI 1.7+ installed  
- [ ] Database access (SQL Server, PostgreSQL, MySQL, Cosmos DB)
- [ ] Environment variable support (for connection strings)
- [ ] VS Code or MCP client for testing

---

## Quick Start Workflow

### For Users New to Both MCP and DAB

**Recommended Path:**
1. Install DAB CLI (prerelease)
2. Create database and sample table
3. Initialize DAB config with MCP enabled (default)
4. Add entities with semantic descriptions
5. Start SQL MCP Server locally
6. Connect from VS Code or other MCP client
7. Test with agent prompts

**Example: 5-Minute Setup**

```bash
# 1. Initialize config (MCP enabled by default)
dab init \
  --database-type mssql \
  --connection-string "@env('DATABASE_CONNECTION_STRING')" \
  --host-mode Development \
  --config dab-config.json

# 2. Add entity with description
dab add Products \
  --source dbo.Products \
  --permissions "anonymous:read" \
  --description "Product catalog with pricing, inventory, and supplier information"

# 3. Add field descriptions (critical for AI understanding)
dab update Products \
  --fields.name ProductID \
  --fields.description "Unique product identifier" \
  --fields.primary-key true

dab update Products \
  --fields.name ProductName \
  --fields.description "Display name of the product"

dab update Products \
  --fields.name UnitPrice \
  --fields.description "Retail price per unit in USD"

# 4. Validate and start
dab validate && dab start
```

**Connect from VS Code:**
Create `.vscode/mcp.json`:
```json
{
  "servers": {
    "sql-mcp-server": {
      "type": "http",
      "url": "http://localhost:5000/mcp"
    }
  }
}
```

---

## Configuration Reference

### MCP Runtime Settings

**Default behavior:** MCP is **enabled** with all tools active. Only configure when restricting.

```json
{
  "runtime": {
    "mcp": {
      "enabled": true,              // default: true
      "path": "/mcp",               // default: /mcp
      "description": "Optional server description for clients",
      "dml-tools": {
        "describe-entities": true,  // default: true
        "create-record": true,      // default: true  
        "read-records": true,       // default: true
        "update-record": true,      // default: true
        "delete-record": true,      // default: true
        "execute-entity": true      // default: true
      }
    }
  }
}
```

### CLI Configuration Commands

```bash
# Enable/disable MCP globally
dab configure --runtime.mcp.enabled true
dab configure --runtime.mcp.path "/mcp"

# Disable specific tools globally (restrict all agents)
dab configure --runtime.mcp.dml-tools.delete-record false
dab configure --runtime.mcp.dml-tools.create-record false

# Add server description (shown to MCP clients)
dab configure --runtime.mcp.description "Production inventory database MCP endpoint"
```

### Entity-Level MCP Control

**Default:** Entities participate in MCP automatically. Only configure to exclude or restrict.

```json
{
  "entities": {
    "Products": {
      "mcp": {
        "dml-tools": true  // default: true (all tools allowed per runtime settings)
      }
    },
    "SensitiveData": {
      "mcp": {
        "dml-tools": false  // exclude this entity from MCP completely
      }
    },
    "AuditLogs": {
      "mcp": {
        "dml-tools": {
          "create-record": true,   // allow create
          "read-records": true,    // allow read
          "update-record": false,  // prevent updates
          "delete-record": false   // prevent deletes
        }
      }
    }
  }
}
```

---

## The Six DML Tools

SQL MCP Server exposes exactly **six tools** to AI agents:

### 1. describe_entities

**Purpose:** Returns all entities the current role can access, including fields, types, descriptions, and allowed operations.

**Key Points:**
- Doesn't query the database - reads from in-memory config
- Shows only entities/fields the current role can see
- Critical first step for agents to understand available data
- Includes semantic descriptions you add via `--description` flags

**Example Response:**
```json
{
  "entities": [
    {
      "name": "Products",
      "description": "Product catalog with pricing and inventory",
      "fields": [
        {
          "name": "ProductId",
          "type": "int",
          "isKey": true,
          "description": "Unique product identifier"
        },
        {
          "name": "UnitPrice",
          "type": "decimal",
          "description": "Retail price in USD"
        }
      ],
      "operations": ["read_records", "update_record"]
    }
  ]
}
```

### 2. create_record

**Purpose:** Insert new rows into tables.

**Requirements:**
- Entity must have `create` permission for current role
- Validates against entity schema
- Enforces create policies
- Returns created record with generated values (e.g., auto-increment IDs)

### 3. read_records

**Purpose:** Query tables and views with filtering, sorting, pagination, and field selection.

**Features:**
- Builds deterministic SQL from structured parameters (NL2DAB, not NL2SQL)
- Applies read permissions and field projections
- Enforces row-level security policies
- **Automatic caching** - results cached per DAB caching config

### 4. update_record

**Purpose:** Modify existing rows.

**Requirements:**
- Requires primary key and fields to update
- Validates PK exists
- Enforces update permissions and policies
- Only updates fields current role can modify

### 5. delete_record

**Purpose:** Remove existing rows.

**Requirements:**
- Requires primary key
- Validates PK exists
- Enforces delete permissions and policies

**Warning:** Many production deployments **disable this tool globally** to prevent accidental data loss.

### 6. execute_entity

**Purpose:** Execute stored procedures.

**Features:**
- Supports input parameters and output results
- Validates parameters against procedure signature
- Enforces execute permissions
- Passes parameters safely (prevents SQL injection)

---

## Semantic Descriptions (Critical for AI)

**Why descriptions matter:** AI agents rely on context. Without descriptions, agents only see technical names like `ProductID`. With descriptions, they understand it's "Unique identifier for each product in the catalog."

### Entity Descriptions

```bash
# Add during creation
dab add Products \
  --source dbo.Products \
  --permissions "anonymous:*" \
  --description "Product catalog with pricing, inventory, and supplier information"

# Update existing entity
dab update Products \
  --description "Product catalog with pricing, inventory, and supplier information"
```

### Field Descriptions

```bash
# Single field
dab update Products \
  --fields.name UnitPrice \
  --fields.description "Retail price per unit in USD"

# Multiple fields (call multiple times)
dab update Products \
  --fields.name ProductID \
  --fields.description "Unique identifier for each product" \
  --fields.primary-key true

dab update Products \
  --fields.name UnitsInStock \
  --fields.description "Current inventory count available for purchase"
```

### Stored Procedure Parameter Descriptions

```bash
dab add GetOrdersByDateRange \
  --source dbo.usp_GetOrdersByDateRange \
  --source.type stored-procedure \
  --permissions "authenticated:execute" \
  --description "Retrieves all orders placed within a specified date range" \
  --parameters.name "StartDate,EndDate,CustomerID" \
  --parameters.description "Beginning of date range (inclusive),End of date range (inclusive),Optional customer ID filter (null returns all customers)" \
  --parameters.required "true,true,false" \
  --parameters.default ",,null"
```

### Description Best Practices

**Do:**
- Be specific: "Customer shipping address" not "Address"
- Include units: "Price in USD", "Weight in kilograms"
- Mention formats: "ISO 8601 date format", "E.164 phone format"
- Explain business rules: "Negative values indicate credit balance"
- Note optional fields: "Optional; null returns all results"

**Don't:**
- Use only technical jargon
- Duplicate field names: "ProductID is the product ID" adds no value
- Write novels - keep to 1-2 sentences
- Ignore nullable fields - mention when null has special meaning

---

## Security & Authentication

### Two Authentication Directions

**Inbound (Client → SQL MCP Server):** How AI agents authenticate to your MCP endpoint
**Outbound (SQL MCP Server → Database):** How DAB authenticates to your database

### Outbound Authentication (to Database)

**Option 1: SQL User/Password (Development)**
```bash
dab init \
  --database-type mssql \
  --connection-string "@env('SQL_CONNECTION_STRING')"
```

Environment variable:
```
SQL_CONNECTION_STRING=Server=tcp:myserver.database.windows.net,1433;Database=mydb;User ID=myuser;Password=mypass;Encrypt=True;
```

**Option 2: Managed Identity (Recommended for Azure)**
```
Server=tcp:myserver.database.windows.net,1433;Database=mydb;Authentication=Active Directory Managed Identity;
```

For User-Assigned Managed Identity (UAMI):
```
Server=tcp:myserver.database.windows.net,1433;Database=mydb;Authentication=Active Directory Managed Identity;User Id=<uami-client-id>;
```

### Inbound Authentication (from Clients)

**Option 1: Anonymous (Development Only)**
```bash
# No auth config needed - defaults to anonymous
# Agents use only what 'anonymous' role permits
```

**Option 2: Microsoft Entra ID / JWT (Production)**
```bash
dab configure \
  --runtime.host.authentication.provider EntraId

dab configure \
  --runtime.host.authentication.jwt.audience "<app-client-id-guid>"

dab configure \
  --runtime.host.authentication.jwt.issuer "https://login.microsoftonline.com/<tenant-id>/v2.0"

# Grant permissions for authenticated users
dab update Products --permissions "authenticated:read"
```

**Option 3: API Gateway (Key-Based)**
- SQL MCP Server doesn't support API keys directly
- Front the `/mcp` endpoint with Azure API Management or similar gateway
- Gateway handles key validation, forwards to SQL MCP Server

### RBAC (Role-Based Access Control)

Every DML tool operation enforces RBAC rules:
- Which entities are visible
- Which operations are allowed (create/read/update/delete/execute)
- Which fields are included/excluded
- Whether row-level policies apply

```bash
# Anonymous can only read specific fields
dab add Products --source dbo.Products --permissions "anonymous:read"
dab update Products --fields.exclude "Cost,Margin,SupplierID"

# Authenticated users can CRUD
dab update Products --permissions "authenticated:*"

# Admin can see everything
dab update Products --permissions "admin:*"
```

---

## Deployment Scenarios

### Local Development (VS Code)

**Steps:**
1. Run `dab start` in terminal
2. Create `.vscode/mcp.json` in workspace
3. Configure MCP server in VS Code
4. Test with Copilot Chat

**MCP Config:**
```json
{
  "servers": {
    "sql-mcp-server": {
      "type": "http",
      "url": "http://localhost:5000/mcp"
    }
  }
}
```

### Azure Container Apps

**Key Steps:**
1. Create Azure SQL Database
2. Configure `dab-config.json`
3. Create Dockerfile with embedded config
4. Build and push to Azure Container Registry
5. Deploy to Container Apps with connection string secret
6. Get public MCP endpoint URL

**Dockerfile:**
```dockerfile
FROM mcr.microsoft.com/azure-databases/data-api-builder:1.7.83-rc
COPY dab-config.json /App/dab-config.json
```

> **⚠️ ANTI-PATTERN:** Never use Azure Files, storage accounts, or volume mounts for `dab-config.json`. Always build a custom Docker image with the config embedded and push to ACR. Storage mounts add latency, failure modes, and unnecessary complexity.

**Deploy:**
```bash
az containerapp create \
  --name sql-mcp-server \
  --resource-group rg-sql-mcp \
  --environment sql-mcp-env \
  --image <acr>.azurecr.io/sql-mcp-server:1 \
  --target-port 5000 \
  --ingress external \
  --secrets "mssql-connection-string=<connection-string>" \
  --env-vars "MSSQL_CONNECTION_STRING=secretref:mssql-connection-string"
```

### .NET Aspire

**Integration Pattern:**
1. Add DAB as Aspire component
2. Configure via `appsettings.json` or environment
3. MCP endpoint available within Aspire service mesh
4. Use with Aspire-hosted AI agents

### Microsoft AI Foundry

**Connection Steps:**
1. Deploy SQL MCP Server (Container Apps or other hosting)
2. In Foundry project: **Add a tool** → **Custom** → **Model Context Protocol**
3. Set remote MCP endpoint URL
4. Configure authentication (Unauthenticated, Entra ID, or OAuth passthrough)
5. Test with agent prompts

---

## Common Conversational Patterns

### User: "I want to give my AI agent database access"

**Ask:**
1. Do you have a database set up?
2. Have you heard of Data API Builder (DAB)?
3. What database type? (SQL Server, PostgreSQL, MySQL, Cosmos DB)
4. Where will the agent run? (VS Code, Azure AI Foundry, custom client)
5. What tables/views should the agent access?

**Guide through:**
1. Install DAB CLI 1.7+ (prerelease)
2. Initialize config with database connection
3. Add entities with descriptions
4. Start locally for testing
5. Deploy to Azure if needed

### User: "How do I enable MCP on my existing DAB config?"

**Answer:**
- MCP is enabled by default in DAB 1.7+
- Just upgrade: `dotnet tool update microsoft.dataapibuilder --prerelease`
- Restart with `dab start` - `/mcp` endpoint is live
- Only configure if you want to restrict tools or entities

### User: "My agent can't see my tables"

**Troubleshoot:**
1. Is entity added to config? (`dab add`)
2. Does current role have permissions? (check `--permissions`)
3. Is entity excluded from MCP? (check `mcp.dml-tools: false`)
4. Is tool disabled globally? (check `runtime.mcp.dml-tools`)
5. Did agent call `describe_entities` first?

### User: "How do I prevent agents from deleting data?"

**Options:**
1. **Global:** `dab configure --runtime.mcp.dml-tools.delete-record false`
2. **Per-entity:** Set `mcp.dml-tools.delete-record: false` in entity config
3. **RBAC:** Don't grant `delete` action to agent's role

### User: "Can agents write raw SQL?"

**Answer:**
- **No.** SQL MCP Server intentionally doesn't support NL2SQL.
- Agents use structured DML tools that generate deterministic SQL via DAB's query builder.
- This prevents SQL injection and ensures safety/predictability.
- Think of it as NL2DAB (natural language → DAB API → safe SQL).

### User: "How do I add descriptions for better AI understanding?"

**Guide:**
1. **Entity level:** Use `--description` in `dab add` or `dab update`
2. **Field level:** Use `--fields.name` and `--fields.description` in `dab update`
3. **Parameters:** Use `--parameters.name` and `--parameters.description` for stored procedures
4. Include units, formats, business rules, and context

**Example:**
```bash
dab update Products \
  --fields.name UnitPrice \
  --fields.description "Retail price per unit in USD (includes tax)"
```

### User: "How do I deploy to production?"

**Recommend:**
1. **Azure Container Apps** (simplest Azure hosting)
2. **Azure App Service** (alternative)
3. **Kubernetes** (advanced)

**Key considerations:**
- Use managed identity for database auth
- Enable Microsoft Entra ID for inbound auth
- Disable `delete-record` tool if appropriate
- Configure CORS and rate limiting
- Enable Application Insights monitoring
- Store connection strings in Azure Key Vault

---

## Validation & Testing

### Validate Config Before Starting

```bash
dab validate && dab start
```

**Validation checks:**
1. JSON schema correctness
2. Entity configuration validity
3. Database connectivity
4. Environment variable resolution
5. Permissions and policies

### Test MCP Endpoint

**Health check:**
```bash
curl http://localhost:5000/health
```

**List tools:**
```bash
# Use MCP Inspector or VS Code MCP extension
# Connect to http://localhost:5000/mcp
# Verify 6 tools appear: describe_entities, create_record, read_records, update_record, delete_record, execute_entity
```

### Test with AI Agent

**VS Code Copilot Chat Examples:**
```
"Which products have low inventory?"
"Show me all products under $50"
"What categories do we have?"
"How many units of Product X are in stock?"
```

---

## Monitoring & Observability

### Built-in Features

**OpenTelemetry Tracing:**
- Every DML tool operation is traced
- Correlate across distributed systems
- Export to Application Insights, Jaeger, etc.

**Health Checks:**
- `/health` endpoint for liveness/readiness
- Per-entity health validation
- Performance threshold monitoring

**Logging:**
- Structured logs to Azure Log Analytics
- Application Insights integration
- Local file logs in containers

### Enable Application Insights

```bash
dab configure --runtime.telemetry.application-insights.connection-string "@env('APPLICATIONINSIGHTS_CONNECTION_STRING')"
```

---

## Migration & Upgrade Paths

### Upgrading Existing DAB to MCP

**Steps:**
1. Upgrade CLI: `dotnet tool update microsoft.dataapibuilder --prerelease`
2. Update config file version (if needed)
3. Add entity/field descriptions for AI context
4. Test MCP endpoint: `dab start`
5. Connect from MCP client

**No breaking changes** - MCP is additive to existing REST/GraphQL endpoints.

### From Other MCP Database Solutions

**Key differences:**
- SQL MCP Server uses entity abstraction (safer than direct schema exposure)
- No NL2SQL - deterministic query generation only
- Built-in RBAC, caching, monitoring
- Single config for REST/GraphQL/MCP

**Migration approach:**
1. Map existing schema to DAB entities
2. Add semantic descriptions
3. Configure equivalent permissions
4. Test agent workflows
5. Switch MCP client connection

---

## Troubleshooting Guide

### Problem: "MCP endpoint returns 404"

**Checks:**
- Is DAB version 1.7+? Run `dab --version`
- Is MCP enabled? Check `runtime.mcp.enabled: true`
- Correct path? Default is `/mcp`, check `runtime.mcp.path`
- Did you restart after config changes?

### Problem: "Agent can't see any entities"

**Checks:**
- Are entities added? Run `dab validate`
- Does role have permissions? Check entity `permissions` config
- Are entities excluded from MCP? Check `mcp.dml-tools: false`
- Did agent call `describe_entities` first?

### Problem: "Connection string not resolving"

**Checks:**
- Is environment variable set? Check `echo $DATABASE_CONNECTION_STRING`
- Using correct syntax? `@env('VAR_NAME')`
- Is `.env` file in working directory? (local dev)
- For Azure: Are secrets configured in Container Apps settings?

### Problem: "Validation fails with database error"

**Checks:**
- Can you connect to database with connection string?
- Are tables/views/stored procedures spelled correctly?
- Do they exist in the specified schema? (e.g., `dbo.Products`)
- For views: Did you specify `--source.key-fields`?

### Problem: "Agent queries are slow"

**Solutions:**
- Enable caching: `dab update <entity> --cache.enabled true --cache.ttl 300`
- Add database indexes on frequently queried columns
- Review Application Insights for slow queries
- Consider scaling up Container Apps CPU/memory

### Problem: "Authentication fails from Foundry"

**Checks:**
- Does auth mode match? (Foundry setting vs DAB `runtime.host.authentication`)
- For Entra ID: Are `audience` and `issuer` correct?
- Is token being passed correctly?
- Check Container Apps logs for auth errors

---

## Quick Reference: CLI Commands

### Initialization
```bash
dab init --database-type mssql --connection-string "@env('CONNECTION_STRING')" --host-mode Development
```

### Add Entities
```bash
# Table
dab add Products --source dbo.Products --permissions "anonymous:read" --description "Product catalog"

# View
dab add ProductSummary --source dbo.vw_ProductSummary --source.type view --source.key-fields "ProductId" --permissions "anonymous:read"

# Stored Procedure
dab add GetProducts --source dbo.usp_GetProducts --source.type stored-procedure --permissions "anonymous:execute" --graphql.operation query
```

### Add Descriptions
```bash
# Entity
dab update Products --description "Product catalog with pricing and inventory"

# Fields
dab update Products --fields.name UnitPrice --fields.description "Retail price in USD"
dab update Products --fields.name ProductID --fields.description "Unique identifier" --fields.primary-key true

# Stored Procedure Parameters
dab add GetOrdersByDate \
  --source dbo.usp_GetOrdersByDate \
  --source.type stored-procedure \
  --permissions "authenticated:execute" \
  --parameters.name "StartDate,EndDate" \
  --parameters.description "Start date (inclusive),End date (inclusive)" \
  --parameters.required "true,true"
```

### Configure MCP
```bash
# Enable/disable globally
dab configure --runtime.mcp.enabled true
dab configure --runtime.mcp.path "/mcp"

# Disable specific tools
dab configure --runtime.mcp.dml-tools.delete-record false

# Add server description
dab configure --runtime.mcp.description "Production inventory MCP endpoint"
```

### Configure Authentication
```bash
# Entra ID
dab configure --runtime.host.authentication.provider EntraId
dab configure --runtime.host.authentication.jwt.audience "<app-client-id-guid>"
dab configure --runtime.host.authentication.jwt.issuer "https://login.microsoftonline.com/<tenant-id>/v2.0"

# Update permissions for authenticated users
dab update Products --permissions "authenticated:*"
```

### Validation & Start
```bash
dab validate
dab start
dab start --verbose
dab start --LogLevel Debug
```

---

## Key Differences from Regular DAB

| Aspect | Regular DAB | SQL MCP Server |
|---|---|---|
| **Primary Use** | REST/GraphQL APIs | AI agent database access |
| **Client Type** | Web apps, mobile apps | AI agents, copilots |
| **Protocol** | HTTP REST, GraphQL | MCP over HTTP or stdio |
| **Version** | 1.0+ | 1.7+ (preview) |
| **Endpoint** | `/api`, `/graphql` | `/mcp` |
| **Query Method** | OData filters, GraphQL queries | DML tool calls |
| **Descriptions** | Optional | Critical for AI understanding |
| **Default State** | REST + GraphQL enabled | REST + GraphQL + MCP enabled |

---

## When to Recommend SQL MCP Server

**Good fit:**
- User wants AI agents to access database safely
- User needs controlled CRUD operations for agents
- User requires RBAC for agent database access
- User wants caching and monitoring built-in
- User needs MCP-compatible database endpoint

**Not a good fit:**
- User needs raw SQL execution from agents (use NL2SQL tools instead)
- User needs schema modification (DDL) from agents
- User only needs REST or GraphQL APIs (use regular DAB)

**Migration candidates:**
- Existing DAB users adding AI agent capabilities
- Custom MCP database servers wanting enterprise features
- NL2SQL implementations wanting deterministic queries

---

## References & Resources

### Official Documentation
- [SQL MCP Server Overview](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/overview)
- [DML Tools Reference](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/data-manipulation-language-tools)
- [Adding Descriptions](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/how-to-add-descriptions)
- [Configure Authentication](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/how-to-configure-authentication)

### Quickstarts
- [VS Code Quickstart](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/quickstart-visual-studio-code)
- [Azure Container Apps Deployment](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/quickstart-azure-container-apps)
- [.NET Aspire Integration](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/quickstart-dotnet-aspire)
- [Azure AI Foundry Integration](https://learn.microsoft.com/en-us/azure/data-api-builder/mcp/quickstart-azure-ai-foundry)

### DAB Core Documentation
- [DAB CLI Reference](https://learn.microsoft.com/en-us/azure/data-api-builder/command-line/)
- [DAB Configuration Reference](https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/)
- [Entity Configuration](https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/entities)
- [Security & Authorization](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/security/authorization)

### Related Skills
- See `data-api-builder.md` for comprehensive DAB CLI guidance
- See `dab-cli.skill.md` for detailed command reference

---

## Consistency Rules

1. **Always install prerelease version** for v1.7+ features
2. **Require `.gitignore`** with `.env`, `**\bin`, and `**\obj` entries before adding secrets
3. **Descriptions are critical** for AI agent success - always recommend adding them
3. **MCP is enabled by default** - only configure when restricting
4. **Security first** - recommend managed identity + Entra ID for production
5. **Use entity abstraction** - never recommend exposing raw schema to agents
6. **Validate before start** - always `dab validate && dab start`
7. **Environment variables for secrets** - use `@env('VAR_NAME')` pattern
8. **No NL2SQL** - explain the NL2DAB deterministic approach
9. **RBAC applies to all tools** - every operation respects role permissions
10. **Stdio for local, HTTP for remote** - use appropriate transport

---

## Version Notes

**Current State (v1.7.x-rc):**
- SQL MCP Server is in preview
- Must use `--prerelease` flag to install
- Documentation and implementation may change
- Not yet in `:latest` Docker tag

**When GA releases:**
- Will be included in stable releases
- `:latest` Docker tag will include MCP
- May have config schema changes

**Always check:** `dab --version` to confirm 1.7+
