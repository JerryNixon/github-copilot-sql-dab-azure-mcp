---
name: data-api-builder-config
description: Guide for Data API Builder configuration files. Use when working with dab-config.json structure, validation, or configuration best practices.
license: MIT
---

# Data API Builder Configuration

This skill powers GitHub Copilot assistance for **Data API Builder (DAB) configuration files**. It provides expert guidance on the internal structure, schema validation, and best practices for `dab-config.json` files to ensure configurations are complete, valid, and aligned with DAB's capabilities.

## Documentation references

- https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/
- https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/entities
- https://github.com/Azure/data-api-builder/blob/main/schemas/dab.draft.schema.json

---

## Core Mental Model

DAB is **driven entirely by a JSON configuration file** (typically `dab-config.json`). This configuration defines:

1. **`$schema`** - JSON schema reference for validation
2. **`data-source`** - Database connection and settings
3. **`data-source-files`** - Optional array of child configuration files
4. **`runtime`** - Global runtime behavior (REST, GraphQL, MCP, auth, caching, telemetry)
5. **`entities`** - Database objects exposed as API endpoints

### Configuration Philosophy

- **Declarative over imperative** - Config declares intent, DAB handles implementation
- **Security by default** - Auth, RBAC, and policies are first-class citizens
- **Multi-file support** - Large projects can split entities across files
- **Environment variable support** - Secrets live outside config via `@env('VAR_NAME')`
- **Schema-driven validation** - Always validate against JSON schema

### Key Constraints

- Entity names must be **unique** across all configuration files
- Relationships cannot span across different configuration files
- Child configs can include `runtime`, but it's **ignored** (only top-level runtime applies)
- Every config file **must** include both `data-source` and `entities` sections
- Connection strings should **never** contain plain-text secrets in production

---

## Configuration File Structure

### Minimal Valid Configuration

```json
{
  "$schema": "https://github.com/Azure/data-api-builder/releases/latest/download/dab.draft.schema.json",
  "data-source": {
    "database-type": "mssql",
    "connection-string": "@env('DATABASE_CONNECTION_STRING')"
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
      "mode": "development"
    }
  },
  "entities": {}
}
```

### Full Configuration Anatomy

```json
{
  "$schema": "<schema-url>",
  "data-source": { /* database connection */ },
  "data-source-files": [ /* child config paths */ ],
  "runtime": {
    "pagination": { /* page size limits */ },
    "rest": { /* REST endpoint config */ },
    "graphql": { /* GraphQL endpoint config */ },
    "mcp": { /* MCP endpoint config (v1.7+) */ },
    "host": {
      "mode": "production|development",
      "max-response-size-mb": 158,
      "cors": { /* CORS settings */ },
      "authentication": { /* auth provider config */ }
    },
    "cache": { /* global caching */ },
    "telemetry": { /* logging, tracing, monitoring */ },
    "health": { /* health check settings */ }
  },
  "entities": {
    "{entity-name}": {
      "source": { /* database object details */ },
      "rest": { /* entity-level REST config */ },
      "graphql": { /* entity-level GraphQL config */ },
      "mcp": { /* entity-level MCP config (v1.7+) */ },
      "permissions": [ /* RBAC rules */ ],
      "relationships": { /* entity relationships */ },
      "mappings": { /* field aliasing */ },
      "cache": { /* entity-level caching */ },
      "health": { /* entity-level health checks */ }
    }
  }
}
```

---

## Schema ($root)

**Property:** `$schema`  
**Type:** string  
**Required:** ✔️ Yes  
**Default:** None

### Purpose

Points to the JSON schema file that validates the configuration structure. Enables IntelliSense in VS Code and other editors.

### Format

```json
{
  "$schema": "https://github.com/Azure/data-api-builder/releases/latest/download/dab.draft.schema.json"
}
```

### Versioned Schemas

You can pin to specific DAB versions:

```
https://github.com/Azure/data-api-builder/releases/download/v{VERSION}-{suffix}/dab.draft.schema.json
```

Example:
```
https://github.com/Azure/data-api-builder/releases/download/v0.3.7-alpha/dab.draft.schema.json
```

### Best Practices

- Always use `:latest` for active development
- Pin to specific version for production stability
- Schema enables editor autocomplete and real-time validation
- Schema violations prevent `dab validate` from passing

---

## Data Source

**Property:** `data-source`  
**Type:** object  
**Required:** ✔️ Yes  
**Default:** None

### Required Nested Properties

| Property | Type | Required | Description |
|---|---|---|---|
| `database-type` | enum | ✔️ Yes | Database engine type |
| `connection-string` | string | ✔️ Yes | Connection details |
| `options` | object | ❌ No | Database-specific settings |
| `health` | object | ❌ No | Data source health check config |

### Supported Database Types

| `database-type` | Description | Min Version |
|---|---|---|
| `mssql` | Azure SQL, SQL Server, SQL in Fabric | SQL Server 2016+ |
| `dwsql` | Azure Synapse, Fabric Warehouse, Fabric SQL Analytics | - |
| `postgresql` | PostgreSQL | 11+ |
| `mysql` | MySQL | 8+ |
| `cosmosdb_nosql` | Azure Cosmos DB for NoSQL | - |
| `cosmosdb_postgresql` | Azure Cosmos DB for PostgreSQL | - |

### Format

```json
{
  "data-source": {
    "database-type": "mssql|postgresql|mysql|cosmosdb_nosql|cosmosdb_postgresql|dwsql",
    "connection-string": "@env('CONNECTION_STRING')",
    "options": {
      "set-session-context": true,
      "database": "cosmos-db-name",
      "container": "cosmos-container-name",
      "schema": "path/to/schema.graphql"
    },
    "health": {
      "enabled": true,
      "name": "primary-db",
      "threshold-ms": 1000
    }
  }
}
```

### Connection String Best Practices

**Development:**
```json
{
  "connection-string": "@env('DEV_CONNECTION_STRING')"
}
```

**Production with Managed Identity (Recommended):**
```
Server=tcp:myserver.database.windows.net,1433;Database=mydb;Authentication=Active Directory Managed Identity;
```

**User-Assigned Managed Identity:**
```
Server=tcp:myserver.database.windows.net,1433;Database=mydb;Authentication=Active Directory Managed Identity;User Id=<uami-client-id>;
```

### Database-Specific Options

#### SQL Server (`mssql`)

| Option | Type | Default | Description |
|---|---|---|---|
| `set-session-context` | boolean | `true` | Passes JWT claims to `SESSION_CONTEXT` |

**Example:**
```json
{
  "data-source": {
    "database-type": "mssql",
    "connection-string": "@env('SQL_CONNECTION_STRING')",
    "options": {
      "set-session-context": true
    }
  }
}
```

**Consuming SESSION_CONTEXT in SQL:**
```sql
CREATE PROC GetUser @userId INT AS
BEGIN
    IF SESSION_CONTEXT(N'user_role') = 'admin'
    BEGIN
        -- Admin-specific logic
    END
    
    SELECT Id, Name FROM Users WHERE Id = @userId;
END
```

#### Cosmos DB NoSQL (`cosmosdb_nosql`)

| Option | Type | Required | Description |
|---|---|---|---|
| `database` | string | ✔️ Yes | Cosmos DB database name |
| `container` | string | ❌ No | Default container name |
| `schema` | string | ✔️ Yes | Path to GraphQL schema file |

**Example:**
```json
{
  "data-source": {
    "database-type": "cosmosdb_nosql",
    "connection-string": "@env('COSMOS_CONNECTION_STRING')",
    "options": {
      "database": "MyCosmosDatabase",
      "container": "MyContainer",
      "schema": "schema.graphql"
    }
  }
}
```

### Connection Resiliency

DAB automatically retries transient errors using **Exponential Backoff**:

| Attempt | Delay |
|---|---|
| 1st | 2s |
| 2nd | 4s |
| 3rd | 8s |
| 4th | 16s |
| 5th | 32s |

### Health Configuration

| Property | Type | Default | Description |
|---|---|---|---|
| `enabled` | boolean | `true` | Enables health checks for this data source |
| `name` | string | database-type | Identifier in health reports |
| `threshold-ms` | integer | `1000` | Max acceptable query duration (ms) |

**Format:**
```json
{
  "data-source": {
    "health": {
      "enabled": true,
      "name": "primary-sql-db",
      "threshold-ms": 500
    }
  }
}
```

### Common Mistakes

❌ **Plain-text secrets in config:**
```json
{
  "connection-string": "Server=...;Password=MyPassword123"
}
```

✅ **Use environment variables:**
```json
{
  "connection-string": "@env('SQL_CONNECTION_STRING')"
}
```

❌ **Missing schema for Cosmos DB NoSQL:**
```json
{
  "database-type": "cosmosdb_nosql",
  "connection-string": "@env('COSMOS_STRING')"
  // Missing options.schema!
}
```

✅ **Include required options:**
```json
{
  "database-type": "cosmosdb_nosql",
  "connection-string": "@env('COSMOS_STRING')",
  "options": {
    "database": "MyDB",
    "schema": "schema.graphql"
  }
}
```

---

## Data Source Files

**Property:** `data-source-files`  
**Type:** string array  
**Required:** ❌ No  
**Default:** None

### Purpose

Allows splitting configuration across multiple files for better organization. Useful for large projects with many entities.

### Format

```json
{
  "data-source-files": [
    "dab-config-users.json",
    "entities/products.json",
    "entities/orders/config.json"
  ]
}
```

### Multi-File Configuration Rules

**MUST:**
- Every config file must include `data-source`
- Every config file must include `entities`
- Top-level config must include `runtime`
- Entity names must be unique across **all** files

**MAY:**
- Child configs can include `runtime` (ignored)
- Child configs can include their own child files
- Files can be organized in subfolders

**CANNOT:**
- Define relationships between entities in different files

### Example: Multi-File Structure

**dab-config.json (top-level):**
```json
{
  "$schema": "...",
  "data-source": {
    "database-type": "mssql",
    "connection-string": "@env('CONNECTION_STRING')"
  },
  "data-source-files": [
    "entities/users-config.json",
    "entities/products-config.json"
  ],
  "runtime": {
    "host": { "mode": "production" }
  },
  "entities": {
    "HealthCheck": {
      "source": { "object": "dbo.HealthCheck", "type": "table" },
      "permissions": [{ "role": "anonymous", "actions": ["read"] }]
    }
  }
}
```

**entities/users-config.json:**
```json
{
  "data-source": {
    "database-type": "mssql",
    "connection-string": "@env('CONNECTION_STRING')"
  },
  "entities": {
    "User": {
      "source": { "object": "dbo.Users", "type": "table" },
      "permissions": [{ "role": "authenticated", "actions": ["*"] }]
    }
  }
}
```

### When to Use Multi-File Configs

**Good fit:**
- 20+ entities in a single config
- Logical domain separation (users, products, orders)
- Multiple teams working on different entities
- Microservice-style organization

**Not needed:**
- Small projects (< 10 entities)
- Simple CRUD APIs
- Proof-of-concept projects

---

## Runtime

**Property:** `runtime`  
**Type:** object  
**Required:** ✔️ Yes (top-level only)  
**Default:** None

### Top-Level Runtime Sections

```json
{
  "runtime": {
    "pagination": { /* page size settings */ },
    "rest": { /* REST global config */ },
    "graphql": { /* GraphQL global config */ },
    "mcp": { /* MCP global config (v1.7+) */ },
    "host": {
      "mode": "production|development",
      "max-response-size-mb": 158,
      "cors": { /* CORS settings */ },
      "authentication": { /* auth config */ }
    },
    "cache": { /* global caching */ },
    "telemetry": { /* monitoring */ },
    "health": { /* health checks */ }
  }
}
```

### Pagination (runtime)

| Property | Type | Default | Description |
|---|---|---|---|
| `max-page-size` | integer | `100000` | Maximum records per page |
| `default-page-size` | integer | `100` | Default records per response |
| `next-link-relative` | boolean | `false` | Use relative URLs in `nextLink` |

**Format:**
```json
{
  "runtime": {
    "pagination": {
      "max-page-size": 1000,
      "default-page-size": 50,
      "next-link-relative": false
    }
  }
}
```

**Special Values:**
- `-1` for `max-page-size` = use maximum supported value
- `-1` for `default-page-size` = use `max-page-size` value
- `0` or negative (except -1) = not supported

### REST (runtime)

| Property | Type | Default | Description |
|---|---|---|---|
| `enabled` | boolean | `true` | Global REST enable/disable |
| `path` | string | `"/api"` | Base path for REST endpoints |
| `request-body-strict` | boolean | `true` | Reject extraneous fields in request |

**Format:**
```json
{
  "runtime": {
    "rest": {
      "enabled": true,
      "path": "/api",
      "request-body-strict": true
    }
  }
}
```

**Important:** If global `enabled` is `false`, entity-level REST settings are ignored.

### GraphQL (runtime)

| Property | Type | Default | Description |
|---|---|---|---|
| `enabled` | boolean | `true` | Global GraphQL enable/disable |
| `path` | string | `"/graphql"` | GraphQL endpoint path |
| `allow-introspection` | boolean | `true` | Allow schema introspection |
| `depth-limit` | integer | `null` | Max query nesting depth |
| `multiple-mutations.create.enabled` | boolean | `false` | Enable multiple-create mutations |

**Format:**
```json
{
  "runtime": {
    "graphql": {
      "enabled": true,
      "path": "/graphql",
      "allow-introspection": true,
      "depth-limit": 5,
      "multiple-mutations": {
        "create": {
          "enabled": false
        }
      }
    }
  }
}
```

**Security Note:** Set `allow-introspection: false` in production to hide schema.

### MCP (runtime) - v1.7+

| Property | Type | Default | Description |
|---|---|---|---|
| `enabled` | boolean | `true` | Global MCP enable/disable |
| `path` | string | `"/mcp"` | MCP endpoint path |
| `description` | string | `null` | Server description for MCP clients |
| `dml-tools.*` | boolean | `true` | Enable/disable specific DML tools |

**Format:**
```json
{
  "runtime": {
    "mcp": {
      "enabled": true,
      "path": "/mcp",
      "description": "Production inventory database",
      "dml-tools": {
        "describe-entities": true,
        "create-record": true,
        "read-records": true,
        "update-record": true,
        "delete-record": false,
        "execute-entity": true
      }
    }
  }
}
```

### Host Mode (runtime)

| Value | Behavior |
|---|---|
| `production` | Strict settings, minimal logging |
| `development` | Swagger UI, GraphQL IDE, verbose logs, anonymous health checks |

**Format:**
```json
{
  "runtime": {
    "host": {
      "mode": "development"
    }
  }
}
```

**Development Mode Enables:**
- Nitro (GraphQL IDE)
- Swagger UI (REST docs)
- Anonymous health endpoint access
- Debug-level logging

### CORS (host runtime)

| Property | Type | Default | Description |
|---|---|---|---|
| `origins` | string array | `[]` | Allowed CORS origins |
| `allow-credentials` | boolean | `false` | Sets `Access-Control-Allow-Credentials` |

**Format:**
```json
{
  "runtime": {
    "host": {
      "cors": {
        "origins": [
          "https://app.example.com",
          "https://admin.example.com",
          "*"
        ],
        "allow-credentials": true
      }
    }
  }
}
```

**Note:** Wildcard `*` is valid for `origins`.

### Authentication (host runtime)

| Provider | Use Case | Identity Source |
|---|---|---|
| _(omitted)_ | Anonymous-only | None |
| `AppService` | Azure App Service EasyAuth | `X-MS-CLIENT-PRINCIPAL` header |
| `EntraId` | Microsoft Entra ID (Azure AD) | JWT bearer token |
| `Custom` | Third-party IdPs (Okta, Auth0) | JWT bearer token |
| `Simulator` | Local testing only | Simulated claims |

**Anonymous (no provider):**
```json
{
  "runtime": {
    "host": {
      // authentication section omitted
    }
  }
}
```

**AppService:**
```json
{
  "runtime": {
    "host": {
      "authentication": {
        "provider": "AppService"
      }
    }
  }
}
```

**EntraId (recommended for Azure):**
```json
{
  "runtime": {
    "host": {
      "authentication": {
        "provider": "EntraId",
        "jwt": {
          "audience": "<app-id>",
          "issuer": "https://login.microsoftonline.com/<tenant-id>/v2.0"
        }
      }
    }
  }
}
```

> **CRITICAL — Entra ID Token Configuration:**
> - Always use `"EntraId"` as the provider value — `"AzureAD"` is deprecated.
> - Set `requestedAccessTokenVersion` to `2` on the app registration (via Graph API PATCH). Default is `null` which issues v1 tokens with a different issuer format (`https://sts.windows.net/{tenant}/` instead of `https://login.microsoftonline.com/{tenant}/v2.0`).
> - The `audience` value MUST be the **bare Application (client) ID** (e.g., `"00c6ca6d-..."`) — NOT the `api://` prefixed URI (e.g., ~~`"api://00c6ca6d-..."`~~). v2.0 tokens emit the bare GUID in the `aud` claim.
> - The `issuer` MUST end with `/v2.0` to match v2.0 token format.
```

**Custom JWT:**
```json
{
  "runtime": {
    "host": {
      "authentication": {
        "provider": "Custom",
        "jwt": {
          "audience": "<api-audience>",
          "issuer": "https://<your-idp-domain>/"
        }
      }
    }
  }
}
```

**Simulator (development only):**
```json
{
  "runtime": {
    "host": {
      "mode": "development",
      "authentication": {
        "provider": "Simulator"
      }
    }
  }
}
```

**Important:** Simulator only works in development mode. DAB fails to start if Simulator is used in production.

### Cache (runtime)

| Property | Type | Default | Description |
|---|---|---|---|
| `enabled` | boolean | `false` | Global caching enable/disable |
| `ttl-seconds` | integer | `5` | Default TTL for cached responses |

**Format:**
```json
{
  "runtime": {
    "cache": {
      "enabled": true,
      "ttl-seconds": 300
    }
  }
}
```

**Note:** Entity-level cache inherits this TTL unless overridden.

### Telemetry (runtime)

**Application Insights:**
```json
{
  "runtime": {
    "telemetry": {
      "application-insights": {
        "enabled": true,
        "connection-string": "@env('APPLICATIONINSIGHTS_CONNECTION_STRING')"
      }
    }
  }
}
```

**OpenTelemetry:**
```json
{
  "runtime": {
    "telemetry": {
      "open-telemetry": {
        "enabled": true,
        "endpoint": "http://localhost:4317",
        "service-name": "dab",
        "exporter-protocol": "grpc",
        "headers": {
          "x-custom-header": "value"
        }
      }
    }
  }
}
```

**Log Level (namespace-specific):**
```json
{
  "runtime": {
    "telemetry": {
      "log-level": {
        "Azure.DataApiBuilder": "Debug",
        "Microsoft.EntityFrameworkCore": "Information"
      }
    }
  }
}
```

### Health (runtime)

| Property | Type | Default | Description |
|---|---|---|---|
| `enabled` | boolean | `true` | Global health check enable/disable |
| `roles` | string array | `null` | Roles allowed to access comprehensive health endpoint |
| `cache-ttl-seconds` | integer | `5` | Health report cache TTL |
| `max-query-parallelism` | integer | `4` | Max concurrent health checks (1-8) |

**Format:**
```json
{
  "runtime": {
    "health": {
      "enabled": true,
      "roles": ["admin", "sre"],
      "cache-ttl-seconds": 10,
      "max-query-parallelism": 8
    }
  }
}
```

---

## Entities

**Property:** `entities`  
**Type:** object  
**Required:** ✔️ Yes  
**Default:** None

### Entity Structure

```json
{
  "entities": {
    "{entity-name}": {
      "source": { /* required */ },
      "permissions": [ /* required */ ],
      "rest": { /* optional */ },
      "graphql": { /* optional */ },
      "mcp": { /* optional, v1.7+ */ },
      "mappings": { /* optional */ },
      "relationships": { /* optional */ },
      "cache": { /* optional */ },
      "health": { /* optional */ }
    }
  }
}
```

### Source (entity)

**Required:** ✔️ Yes

| Property | Type | Required | Description |
|---|---|---|---|
| `object` | string | ✔️ Yes | Database object name (include schema) |
| `type` | enum | ✔️ Yes | `table`, `view`, or `stored-procedure` |
| `key-fields` | string array | ⚠️ Conditional | Required for views (primary keys) |
| `parameters` | object | ⚠️ Conditional | Required for stored procedures with defaults |

**Table:**
```json
{
  "source": {
    "object": "dbo.Products",
    "type": "table"
  }
}
```

**View (requires key-fields):**
```json
{
  "source": {
    "object": "dbo.vw_ProductSummary",
    "type": "view",
    "key-fields": ["ProductId", "CategoryId"]
  }
}
```

**Stored Procedure:**
```json
{
  "source": {
    "object": "dbo.usp_GetProducts",
    "type": "stored-procedure",
    "parameters": {
      "CategoryId": null,
      "MinPrice": 0,
      "MaxPrice": 1000
    }
  }
}
```

**Schema Notes:**
- `dbo` schema is optional: `"dbo.Users"` == `"Users"`
- Square brackets supported: `"[dbo].[Users]"` == `"dbo.Users"`
- Always specify schema for non-dbo objects: `"sales.Orders"`

### Permissions (entity)

**Required:** ✔️ Yes (at least one role)

**System Roles:**
- `anonymous` - Unauthenticated users
- `authenticated` - Any authenticated user

**Custom Roles:** Match your auth provider's roles (e.g., `admin`, `editor`, `reader`)

**Actions:**
- Tables/Views: `create`, `read`, `update`, `delete`, `*`
- Stored Procedures: `execute`, `*`

**Simple Format (string array):**
```json
{
  "permissions": [
    {
      "role": "anonymous",
      "actions": ["read"]
    },
    {
      "role": "authenticated",
      "actions": ["*"]
    }
  ]
}
```

**Advanced Format (with fields and policies):**
```json
{
  "permissions": [
    {
      "role": "reader",
      "actions": [
        {
          "action": "read",
          "fields": {
            "include": ["*"],
            "exclude": ["PasswordHash", "SecurityStamp"]
          },
          "policy": {
            "database": "@item.IsPublic eq true"
          }
        }
      ]
    },
    {
      "role": "owner",
      "actions": [
        {
          "action": "update",
          "policy": {
            "database": "@item.UserId eq @claims.userId"
          }
        }
      ]
    }
  ]
}
```

**Database Policy Syntax (OData-style):**

| Operator | Example |
|---|---|
| `eq` | `@item.Status eq 'Active'` |
| `ne` | `@item.IsDeleted ne true` |
| `gt` | `@item.Price gt 100` |
| `lt` | `@item.Stock lt 10` |
| `ge` | `@item.Age ge 18` |
| `le` | `@item.Price le 1000` |
| `and` | `@item.IsActive eq true and @item.Price gt 0` |
| `or` | `@item.Category eq 'A' or @item.Category eq 'B'` |
| `@item.*` | References entity field |
| `@claims.*` | References JWT claim |

**Policy Rules:**
- Supported for: `read`, `update`, `delete`
- NOT supported for: `create`, `execute`
- Use mapped field names if mappings are defined
- Claims are injected from authenticated user's JWT

### Mappings (entity)

**Purpose:** Alias database column names to API field names.

```json
{
  "mappings": {
    "ProductID": "product_id",
    "sku_title": "title",
    "sku_status": "status",
    "UnitPrice": "price"
  }
}
```

**Effect:**
- REST requests use `price` instead of `UnitPrice`
- GraphQL schema shows `price` field
- Policies must reference mapped names

### REST (entity)

| Property | Type | Default | Description |
|---|---|---|---|
| `enabled` | boolean | `true` | Enable REST for this entity |
| `path` | string | `"{entity-name}"` | Custom REST route |
| `methods` | string array | `["POST"]` | Allowed HTTP methods (stored procedures only) |

```json
{
  "rest": {
    "enabled": true,
    "path": "products",
    "methods": ["GET", "POST"]
  }
}
```

### GraphQL (entity)

| Property | Type | Default | Description |
|---|---|---|---|
| `enabled` | boolean | `true` | Enable GraphQL for this entity |
| `type.singular` | string | `"{entity-name}"` | Singular type name |
| `type.plural` | string | `"{singular}s"` | Plural type name |
| `operation` | enum | `"mutation"` | `query` or `mutation` (stored procedures only) |

```json
{
  "graphql": {
    "enabled": true,
    "type": {
      "singular": "Product",
      "plural": "Products"
    },
    "operation": "query"
  }
}
```

### MCP (entity) - v1.7+

| Property | Type | Default | Description |
|---|---|---|---|
| `dml-tools` | boolean/object | `true` | Enable/disable MCP tools for this entity |

**Enable all tools:**
```json
{
  "mcp": {
    "dml-tools": true
  }
}
```

**Disable all tools:**
```json
{
  "mcp": {
    "dml-tools": false
  }
}
```

**Granular control:**
```json
{
  "mcp": {
    "dml-tools": {
      "describe-entities": true,
      "create-record": false,
      "read-records": true,
      "update-record": false,
      "delete-record": false,
      "execute-entity": true
    }
  }
}
```

### Relationships (entity)

**Relationship Types:**
- **One-to-one:** `cardinality: "one"` (User → Profile)
- **One-to-many:** `cardinality: "many"` (Category → Books)
- **Many-to-one:** `cardinality: "one"` (Book → Category)
- **Many-to-many:** `cardinality: "many"` with `linking.object` (Students ↔ Courses)

**One-to-Many:**
```json
{
  "relationships": {
    "products": {
      "cardinality": "many",
      "target.entity": "Product",
      "source.fields": ["CategoryId"],
      "target.fields": ["CategoryId"]
    }
  }
}
```

**Many-to-Many:**
```json
{
  "relationships": {
    "courses": {
      "cardinality": "many",
      "target.entity": "Course",
      "linking.object": "dbo.Enrollments",
      "linking.source.fields": ["StudentId"],
      "linking.target.fields": ["CourseId"]
    }
  }
}
```

**Self-Referencing:**
```json
{
  "relationships": {
    "manager": {
      "cardinality": "one",
      "target.entity": "Employee",
      "source.fields": ["ManagerId"],
      "target.fields": ["EmployeeId"]
    }
  }
}
```

### Cache (entity)

```json
{
  "cache": {
    "enabled": true,
    "ttl-seconds": 600
  }
}
```

**Note:** If not specified, `ttl-seconds` inherits from `runtime.cache.ttl-seconds`.

### Health (entity)

```json
{
  "health": {
    "enabled": true,
    "first": 10,
    "threshold-ms": 500
  }
}
```

| Property | Type | Default | Description |
|---|---|---|---|
| `enabled` | boolean | `true` | Enable health checks for this entity |
| `first` | integer | `1` | Number of rows to fetch (1-500) |
| `threshold-ms` | integer | `1000` | Max acceptable query duration (ms) |

---

## Configuration Validation Rules

### Schema Validation

Always validate against the JSON schema:

```bash
dab validate --config dab-config.json
```

### Common Validation Errors

**Missing required properties:**
```
Error: Missing required property 'source' in entity 'Product'
```

**Invalid enum value:**
```
Error: Invalid database-type 'sql'. Must be one of: mssql, postgresql, mysql, cosmosdb_nosql, cosmosdb_postgresql, dwsql
```

**View without key-fields:**
```
Error: Entity 'ProductSummary' has type 'view' but no key-fields specified
```

**Duplicate entity names:**
```
Error: Entity name 'User' is already defined in another configuration file
```

**Cross-file relationships:**
```
Error: Relationship 'products' in entity 'Category' targets 'Product' which is in a different configuration file
```

### Entity Name Rules

- Must be unique across all config files
- Case-sensitive
- No special characters (alphanumeric + underscores)
- Cannot start with a number

### Field Inclusion/Exclusion Rules

**Cannot use both include and exclude:**
```json
{
  "fields": {
    "include": ["Id", "Name"],  // ❌ Error
    "exclude": ["Password"]     // ❌ Error
  }
}
```

**Use one or the other:**
```json
{
  "fields": {
    "include": ["Id", "Name", "Email"]  // ✅ OK
  }
}
```

**Wildcard with exclude:**
```json
{
  "fields": {
    "include": ["*"],
    "exclude": ["PasswordHash", "SecurityStamp"]  // ✅ OK
  }
}
```

---

## Configuration Patterns & Best Practices

### Pattern: Environment-Specific Configs

**Development:**
```json
{
  "data-source": {
    "connection-string": "@env('DEV_CONNECTION_STRING')"
  },
  "runtime": {
    "host": {
      "mode": "development",
      "authentication": {
        "provider": "Simulator"
      }
    }
  }
}
```

**Production:**
```json
{
  "data-source": {
    "connection-string": "@env('PROD_CONNECTION_STRING')"
  },
  "runtime": {
    "host": {
      "mode": "production",
      "cors": {
        "origins": ["https://app.example.com"]
      },
      "authentication": {
        "provider": "EntraId",
        "jwt": {
          "audience": "<app-client-id>",
          "issuer": "https://login.microsoftonline.com/<tenant>/v2.0"
        }
      }
    },
    "graphql": {
      "allow-introspection": false
    }
  }
}
```

### Pattern: Public Read, Authenticated Write

```json
{
  "entities": {
    "Product": {
      "source": { "object": "dbo.Products", "type": "table" },
      "permissions": [
        {
          "role": "anonymous",
          "actions": ["read"]
        },
        {
          "role": "authenticated",
          "actions": ["create", "update", "delete"]
        }
      ]
    }
  }
}
```

### Pattern: Row-Level Security

```json
{
  "entities": {
    "Order": {
      "source": { "object": "dbo.Orders", "type": "table" },
      "permissions": [
        {
          "role": "customer",
          "actions": [
            {
              "action": "read",
              "policy": {
                "database": "@item.UserId eq @claims.userId"
              }
            }
          ]
        },
        {
          "role": "admin",
          "actions": ["*"]
        }
      ]
    }
  }
}
```

### Pattern: Field-Level Security

```json
{
  "entities": {
    "User": {
      "source": { "object": "dbo.Users", "type": "table" },
      "permissions": [
        {
          "role": "public",
          "actions": [
            {
              "action": "read",
              "fields": {
                "include": ["Id", "Name", "ProfilePicture"]
              }
            }
          ]
        },
        {
          "role": "self",
          "actions": [
            {
              "action": "read",
              "fields": {
                "include": ["*"],
                "exclude": ["PasswordHash"]
              },
              "policy": {
                "database": "@item.Id eq @claims.userId"
              }
            }
          ]
        }
      ]
    }
  }
}
```

### Pattern: Stored Procedure with GraphQL Query

```json
{
  "entities": {
    "GetTopProducts": {
      "source": {
        "object": "dbo.usp_GetTopProducts",
        "type": "stored-procedure",
        "parameters": {
          "TopN": 10,
          "CategoryId": null
        }
      },
      "graphql": {
        "operation": "query"
      },
      "rest": {
        "methods": ["GET", "POST"]
      },
      "permissions": [
        {
          "role": "anonymous",
          "actions": ["execute"]
        }
      ]
    }
  }
}
```

### Pattern: Multiple Config Files by Domain

**dab-config.json:**
```json
{
  "$schema": "...",
  "data-source": { "..." },
  "data-source-files": [
    "entities/catalog.json",
    "entities/orders.json",
    "entities/users.json"
  ],
  "runtime": { "..." },
  "entities": {}
}
```

**entities/catalog.json:**
```json
{
  "data-source": { "..." },
  "entities": {
    "Product": { "..." },
    "Category": { "..." },
    "Supplier": { "..." }
  }
}
```

**entities/orders.json:**
```json
{
  "data-source": { "..." },
  "entities": {
    "Order": { "..." },
    "OrderItem": { "..." },
    "Invoice": { "..." }
  }
}
```

---

## Troubleshooting Configuration Issues

### Issue: "Entity not found"

**Cause:** Entity name mismatch (case-sensitive).

**Solution:** Verify exact entity name in config:
```json
{
  "entities": {
    "Product": { }  // ← Case-sensitive
  }
}
```

### Issue: "Validation failed: connection"

**Cause:** Connection string or environment variable issue.

**Solution:**
1. Verify environment variable is set
2. Test connection string manually
3. Check for typos in `@env('VAR_NAME')`

### Issue: "View requires key-fields"

**Cause:** View entity missing `key-fields`.

**Solution:**
```json
{
  "source": {
    "object": "dbo.vw_ProductSummary",
    "type": "view",
    "key-fields": ["ProductId"]  // ← Required
  }
}
```

### Issue: "Cross-file relationship not supported"

**Cause:** Relationship targets entity in different config file.

**Solution:** Move both entities to the same config file.

### Issue: "Duplicate entity name"

**Cause:** Entity name used in multiple config files.

**Solution:** Rename one of the entities to be unique.

### Issue: "Invalid policy syntax"

**Cause:** SQL-style syntax in database policy.

**Solution:** Use OData-style operators:
```json
{
  "policy": {
    "database": "@item.Status eq 'Active'"  // ✅ OData
  }
}
```

Not SQL:
```json
{
  "policy": {
    "database": "Status = 'Active'"  // ❌ SQL
  }
}
```

---

## Configuration Drift Prevention

### Schema Pinning

Pin to specific schema version in production:
```json
{
  "$schema": "https://github.com/Azure/data-api-builder/releases/download/v1.7.0/dab.draft.schema.json"
}
```

### Validation in CI/CD

```bash
dab validate --config dab-config.json
if [ $? -ne 0 ]; then
  echo "Configuration validation failed"
  exit 1
fi
```

### Version Control Best Practices

- Always commit `dab-config.json`
- Never commit `.env` files
- **Require `.gitignore`** with `.env`, `**\bin`, and `**\obj` entries before adding any secrets
- Use separate configs per environment
- Review diffs carefully (permissions changes are security-critical)

### Azure Deployment (Custom Image Pattern)

**Always build a custom Docker image** that embeds `dab-config.json` for Azure deployments:

```dockerfile
FROM mcr.microsoft.com/azure-databases/data-api-builder:1.7.83-rc
COPY dab-config.json /App/dab-config.json
```

> **⚠️ ANTI-PATTERN:** Never use Azure Files, storage accounts, or volume mounts for `dab-config.json`. The config must be baked into the image for immutable, versioned, reproducible deployments.

### Documentation

Add comments via unused properties (DAB ignores unknown properties):
```json
{
  "_comment": "This entity exposes the Products table for public read access",
  "entities": {
    "Product": {
      "source": { "object": "dbo.Products", "type": "table" },
      "permissions": [
        { "role": "anonymous", "actions": ["read"] }
      ]
    }
  }
}
```

---

## Consistency Rules

1. **Always use `@env()` for secrets** - Never plain-text connection strings
2. **Validate before deploy** - `dab validate` must pass
3. **Entity names are case-sensitive** - Be consistent
4. **Views require key-fields** - DAB cannot infer primary keys from views
5. **Stored procedures use `execute`** - Not `read`
6. **OData policies for database** - Not SQL syntax
7. **Relationships cannot cross files** - Keep related entities together
8. **Global runtime overrides entity settings** - If global REST is disabled, entity REST is ignored
9. **Mappings affect policy references** - Use mapped names in policies
10. **Schema validation is mandatory** - Always include `$schema` property
11. **Use `EntraId` not `AzureAD`** - `AzureAD` is a deprecated provider enum value
12. **Audience is bare GUID** - v2.0 tokens use bare client ID as `aud` claim; never use `api://` prefix
13. **Set `requestedAccessTokenVersion` to 2** - Default (`null`) issues v1 tokens with incompatible issuer format

---

## Troubleshooting: Entra ID Authentication (401 Unauthorized)

When DAB returns 401 with `AuthN state: Anonymous` in logs, check these three things in order:

### 1. Token Version Mismatch
**Symptom:** DAB logs show `AuthN state: Anonymous` despite valid Bearer token.  
**Cause:** App registration `accessTokenAcceptedVersion` is `null` (default), which issues v1 tokens. v1 tokens have issuer `https://sts.windows.net/{tenant}/` which doesn't match the v2.0 issuer in DAB config.  
**Fix:**
```powershell
# Set token version to 2 via Graph API
$patch = @{ api = @{ requestedAccessTokenVersion = 2 } } | ConvertTo-Json -Depth 3
az rest --method PATCH --uri "https://graph.microsoft.com/v1.0/applications/{object-id}" --headers "Content-Type=application/json" --body $patch
```
**Prevention:** Always include `requestedAccessTokenVersion = 2` in the app registration PATCH during setup.

### 2. Audience Mismatch (`aud` claim)
**Symptom:** 401 even after fixing token version.  
**Cause:** v2.0 tokens emit the **bare Application (client) ID** as the `aud` claim (e.g., `00c6ca6d-...`). If DAB config has `api://00c6ca6d-...` as the audience, validation fails.  
**Fix:** Set audience to the bare client ID — no `api://` prefix:
```json
"audience": "00c6ca6d-7e2c-43c3-937e-b3f0c487f788"
```
**Prevention:** Always use `$($app.appId)` (bare GUID) in setup scripts, never `"api://$($app.appId)"`.

### 3. Provider Enum Value
**Symptom:** Configuration errors or unexpected behavior.  
**Cause:** `"AzureAD"` is the deprecated provider enum value.  
**Fix:** Use `"EntraId"` instead:
```json
"provider": "EntraId"
```

---

## References

- [Configuration Overview](https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/)
- [Data Source Configuration](https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/data-source)
- [Runtime Configuration](https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/runtime)
- [Entity Configuration](https://learn.microsoft.com/en-us/azure/data-api-builder/configuration/entities)
- [JSON Schema](https://github.com/Azure/data-api-builder/blob/main/schemas/dab.draft.schema.json)
- [Database Policies](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/security/how-to-configure-database-policies)
- [Authorization and Roles](https://learn.microsoft.com/en-us/azure/data-api-builder/concept/security/authorization)
- [Relationships Breakdown](https://devblogs.microsoft.com/azure-sql/data-api-builder-relationships/)

---

## Related Skills

- See `data-api-builder-cli` for comprehensive DAB CLI guidance
- See `data-api-builder-mcp` for SQL MCP Server configuration
