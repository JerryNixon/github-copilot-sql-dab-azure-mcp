---
name: data-api-builder-cli
description: Data API Builder CLI commands for init, add, update, export, and start. Use when asked to create a dab-config, add entities, configure REST/GraphQL endpoints, or run DAB locally via CLI.
license: MIT
---

# Data API Builder (DAB) CLI

This skill powers GitHub Copilot assistance for the **Data API Builder (DAB)** CLI tool. It provides conversational guidance for creating, configuring, validating, and running DAB projects that expose database objects as REST, GraphQL, and MCP endpoints.

---

## Core Mental Model

DAB is driven by a JSON config file (typically `dab-config.json`) containing:

- **`data-source`**: Database connection settings (type, connection string, provider options)
- **`runtime`**: Endpoint configuration (REST/GraphQL/MCP paths, auth, CORS, host mode)
- **`entities`**: Exposed tables/views/stored procedures with permissions, relationships, mappings, and policies

### Recommended Workflow
1. `dab init` — Create baseline config
2. `dab add` — Add entities (tables/views/stored procedures)
3. `dab update` — Evolve entities (permissions, relationships, mappings, policies)
4. `dab configure` — Tune runtime and data-source settings
5. `dab validate` — Preflight validation checks
6. `dab start` — Run the DAB engine

### Security Default
**Always prefer environment variables for connection strings:**
- Use `@env('ENV_VAR_NAME')` in config/CLI arguments
- Ask user before inlining secrets

---

## Command Reference

### 1. `dab init` — Initialize Configuration

**Purpose:** Create a new DAB configuration file. This is typically the **first step** in a project.

**Syntax:**
```bash
dab init [options]
```

**Critical Behavior:**
- **Overwrites existing config files** without merging
- Recommend git usage or backups before running

**Must Collect (ask if missing):**
- `--database-type` (`mssql`, `postgresql`, `mysql`, `cosmosdb_nosql`, `cosmosdb_postgresql`)
- `--connection-string` (direct value or `@env('VAR_NAME')`)

**Common Options:**

| Category | Option | Default | Description |
|---|---|---|---|
| **File** | `--config`, `-c` | `dab-config.json` | Output file path |
| **Database** | `--database-type` | *(required)* | Database engine type |
| | `--connection-string` | `@env('CONNECTION_STRING')` | Connection string (supports `@env()`) |
| | `--set-session-context` | `false` | Enable SQL Server session context (mssql only) |
| | `--cosmosdb_nosql-database` | *(required for cosmos)* | Cosmos DB database name |
| | `--cosmosdb_nosql-container` | *(optional)* | Cosmos DB container name |
| | `--graphql-schema` | *(required for cosmos)* | GraphQL schema path for Cosmos DB NoSQL |
| **REST** | `--rest.enabled` | `true` | Enable REST endpoint |
| | `--rest.path` | `/api` | REST endpoint prefix |
| | `--rest.request-body-strict` | `true` | Enforce strict request validation |
| **GraphQL** | `--graphql.enabled` | `true` | Enable GraphQL endpoint |
| | `--graphql.path` | `/graphql` | GraphQL endpoint prefix |
| | `--graphql.allow-introspection` | *(varies)* | Allow schema introspection (true in dev, false in prod) |
| | `--graphql.multiple-create.enabled` | `false` | Allow multiple create mutations |
| **MCP** | `--mcp.enabled` | `true` | Enable MCP endpoint (v1.7+) |
| | `--mcp.path` | `/mcp` | MCP endpoint prefix |
| **Host** | `--host-mode` | `Production` | `Development` or `Production` |
| | `--cors-origin` | *(none)* | Comma-separated allowed origins |
| | `--runtime.base-route` | *(none)* | Global prefix for all endpoints |
| **Auth** | `--auth.provider` | *(none)* | Identity provider (e.g., `AzureAD`) |
| | `--auth.audience` | *(none)* | JWT audience claim |
| | `--auth.issuer` | *(none)* | JWT issuer claim |

**Important:** Don't mix `--*.enabled` flags with legacy `--*.disabled` flags for the same subsystem.

**Examples:**

```bash
# Minimal (recommended, env var)
dab init \
  --database-type mssql \
  --connection-string "@env('DATABASE_CONNECTION_STRING')"

# REST-only
dab init \
  --database-type mssql \
  --connection-string "@env('DATABASE_CONNECTION_STRING')" \
  --rest.enabled true \
  --graphql.enabled false

# MCP-only (agent scenarios)
dab init \
  --database-type mssql \
  --connection-string "@env('DATABASE_CONNECTION_STRING')" \
  --rest.enabled false \
  --graphql.enabled false \
  --mcp.enabled true \
  --mcp.path "/mcp"

# Production with auth
dab init \
  --database-type mssql \
  --connection-string "@env('DATABASE_CONNECTION_STRING')" \
  --host-mode production \
  --auth.provider AzureAD \
  --auth.issuer "https://login.microsoftonline.com/{tenant-id}/v2.0" \
  --auth.audience "https://example.com/api" \
  --cors-origin "https://app.example.com"
```

**What to Say Next:**
"Config created! Next, add entities with `dab add`, then validate with `dab validate`."

---

### 2. `dab add` — Add Entity

**Purpose:** Add a new entity (table/view/stored procedure) to an existing config.

**Syntax:**
```bash
dab add <entity-name> [options]
```

**Must Collect (ask if missing):**
- `<entity-name>` (logical API name, case-sensitive)
- `--source`, `-s` (database object name, including schema)
- `--permissions`, `-p` (at least one `"role:actions"` pair)

**Source Types & Requirements:**

| Source Type | `--source.type` | Key Fields Required? | Actions | Notes |
|---|---|---|---|---|
| **Table** | `table` (default) | No (auto-detected) | `create, read, update, delete, *` | Most common |
| **View** | `view` | **Yes** (via `--source.key-fields`) | `create, read, update, delete, *` | Must specify PK fields |
| **Stored Procedure** | `stored-procedure` | No | `execute, *` | Use `--source.params` for defaults |

**Permission Model:**

| Role | Description | Common Use |
|---|---|---|
| `anonymous` | Unauthenticated users | Public read-only data |
| `authenticated` | Any authenticated user | Protected resources |
| Custom roles | Per auth provider | Fine-grained access (e.g., `admin`, `editor`) |

**Actions:**
- Tables/Views: `create`, `read`, `update`, `delete`, `*`
- Stored Procedures: `execute`, `*`

**Common Options:**

| Category | Option | Description |
|---|---|---|
| **Source** | `--source`, `-s` | Database object name |
| | `--source.type` | `table`, `view`, `stored-procedure` (default: `table`) |
| | `--source.key-fields` | Primary key fields (required for views, comma-separated) |
| | `--source.params` | Stored procedure default params (`param:value,param:value`) |
| **Permissions** | `--permissions`, `-p` | Role and actions (`role:action1,action2`) |
| **REST** | `--rest` | `true`, `false`, or custom path |
| | `--rest.methods` | Stored procedures: allowed verbs (`GET,POST,PUT,PATCH,DELETE`) |
| **GraphQL** | `--graphql` | `true`, `false`, `singular`, or `singular:plural` |
| | `--graphql.operation` | Stored procedures: `query` or `mutation` (default: `mutation`) |
| **Fields** | `--fields.include` | Comma-separated included fields (`*` = all) |
| | `--fields.exclude` | Comma-separated excluded fields |
| | `--fields.name` | Field names to describe (comma-separated, v1.7+) |
| | `--fields.alias` | Field aliases (aligned to `--fields.name`, v1.7+) |
| | `--fields.description` | Field descriptions (aligned to `--fields.name`, v1.7+) |
| | `--fields.primary-key` | PK flags (aligned to `--fields.name`, v1.7+) |
| **Cache** | `--cache.enabled` | Enable caching |
| | `--cache.ttl` | TTL in seconds |
| **Description** | `--description` | Entity description (v1.7+) |
| **Parameters** | `--parameters.name` | Stored procedures: parameter names (comma-separated, v1.7+) |
| | `--parameters.description` | Parameter descriptions (aligned, v1.7+) |
| | `--parameters.required` | Parameter required flags (aligned, v1.7+) |
| | `--parameters.default` | Parameter default values (aligned, v1.7+) |

**Examples:**

```bash
# Add a table (anonymous read)
dab add Product \
  --source dbo.Products \
  --source.type table \
  --permissions "anonymous:read"

# Add a view (requires key fields)
dab add ProductSummary \
  --source dbo.vw_ProductSummary \
  --source.type view \
  --source.key-fields "ProductId,Region" \
  --permissions "anonymous:read"

# Add a stored procedure (execute)
dab add GetProductsByCategory \
  --source dbo.usp_GetProductsByCategory \
  --source.type stored-procedure \
  --permissions "anonymous:execute" \
  --graphql.operation query \
  --rest.methods GET,POST

# Add with field mappings and descriptions (v1.7+)
dab add Products \
  --source dbo.Products \
  --permissions "anonymous:*" \
  --fields.name "ProductID,ProductName,UnitPrice" \
  --fields.alias "product_id,product_name,price" \
  --fields.description "Unique identifier,Product display name,Unit price in USD" \
  --fields.primary-key "true,false,false"

# Add stored procedure with parameter metadata (v1.7+)
dab add GetOrdersByDateRange \
  --source dbo.usp_GetOrdersByDateRange \
  --source.type stored-procedure \
  --permissions "authenticated:execute" \
  --description "Retrieves orders within a date range" \
  --parameters.name "StartDate,EndDate,CustomerID" \
  --parameters.description "Start of range (inclusive),End of range (inclusive),Optional customer filter" \
  --parameters.required "true,true,false" \
  --parameters.default ",,null"
```

**Common Mistake:**
`--permissions` is **not repeatable** in `dab add`. To add multiple roles:
1. Add entity with one role in `dab add`
2. Add additional roles with `dab update`

**What to Say Next:**
"Entity added! Add more entities, or run `dab validate` to check the config."

---

### 3. `dab update` — Modify Entity

**Purpose:** Modify an existing entity's properties (permissions, relationships, mappings, policies, REST/GraphQL exposure, caching).

**Syntax:**
```bash
dab update <entity-name> [options]
```

**Critical Behaviors:**
- Entity **must already exist** (case-sensitive match)
- `--permissions` updates or adds the specified role
- `--map` **replaces entire mapping set** (not additive)
- `--fields.include`/`--fields.exclude` **replace** existing field lists

**Option Groups:**

#### Source
| Option | Description |
|---|---|
| `--source`, `-s` | Change database object |
| `--source.type` | Change to `table`, `view`, or `stored-procedure` |
| `--source.key-fields` | Update key fields (views/non-PK tables) |
| `--source.params` | Update stored procedure default params |

#### Permissions & Policies
| Option | Description |
|---|---|
| `--permissions`, `-p` | Add/update permissions for a role: `"role:actions"` |
| `--policy-database` | OData-style filter injected in DB query |
| `--policy-request` | Request-level policy evaluated before DB call |

#### Fields & Mappings
| Option | Description |
|---|---|
| `--fields.include` | Set included fields (replaces existing) |
| `--fields.exclude` | Set excluded fields (replaces existing) |
| `-m, --map` | Field mappings `dbField:apiField` (replaces all mappings) |
| `--fields.name` | Field names to describe (v1.7+) |
| `--fields.alias` | Field aliases (v1.7+) |
| `--fields.description` | Field descriptions (v1.7+) |
| `--fields.primary-key` | PK flags (v1.7+) |

#### REST
| Option | Description |
|---|---|
| `--rest` | Enable/disable or set custom path |
| `--rest.methods` | Stored procedures: allowed HTTP verbs |

#### GraphQL
| Option | Description |
|---|---|
| `--graphql` | Enable/disable or set `singular:plural` names |
| `--graphql.operation` | Stored procedures: `query` or `mutation` |

#### Relationships

Relationships define how entities are connected (one-to-one, one-to-many, many-to-one, many-to-many).

| Option | Description |
|---|---|
| `--relationship` | Relationship name (used in API responses) |
| `--cardinality` | `one` or `many` (defines relationship type) |
| `--target.entity` | Target entity name |
| `--relationship.fields` | Field mappings `sourceField:targetField` (comma-separated for composite keys) |
| `--linking.object` | Many-to-many join table (schema.table format) |
| `--linking.source.fields` | Join table fields (source side, comma-separated) |
| `--linking.target.fields` | Join table fields (target side, comma-separated) |

**Relationship Types:**
- **One-to-one:** `cardinality: "one"` (e.g., User → Profile)
- **One-to-many:** `cardinality: "many"` (e.g., Category → Products)
- **Many-to-one:** `cardinality: "one"` (e.g., Product → Category)
- **Many-to-many:** `cardinality: "many"` with `linking.object` (e.g., Students ↔ Courses)

#### Cache
| Option | Description |
|---|---|
| `--cache.enabled` | Enable/disable caching |
| `--cache.ttl` | TTL in seconds |

#### Parameters (Stored Procedures)
| Option | Description |
|---|---|
| `--parameters.name` | Parameter names (v1.7+) |
| `--parameters.description` | Parameter descriptions (v1.7+) |
| `--parameters.required` | Parameter required flags (v1.7+) |
| `--parameters.default` | Parameter default values (v1.7+) |

#### Other
| Option | Description |
|---|---|
| `--description` | Update entity description (v1.7+) |
| `--config`, `-c` | Config file path |

**Examples:**

```bash
# Add/replace permissions for a role
dab update Product --permissions "admin:*"
dab update Product --permissions "authenticated:read,update"

# Add field mappings (replaces all existing mappings!)
dab update Product \
  --map "ProductName:name,UnitPrice:price,UnitsInStock:stock"

# Exclude sensitive fields
dab update User \
  --fields.exclude "PasswordHash,SecurityStamp,TwoFactorSecret"

# Change REST path
dab update Product --rest "products"

# Disable GraphQL for entity
dab update InternalData --graphql false

# Enable caching
dab update Product --cache.enabled true --cache.ttl 300

# One-to-many relationship: Category has many Products
dab update Category \
  --relationship "products" \
  --cardinality many \
  --target.entity Product \
  --relationship.fields "CategoryId:CategoryId"

# Many-to-many: Student to Course via Enrollments
dab update Student \
  --relationship "courses" \
  --cardinality many \
  --target.entity Course \
  --linking.object "dbo.Enrollments" \
  --linking.source.fields "StudentId" \
  --linking.target.fields "CourseId"

# Self-referencing: Employee has a Manager
dab update Employee \
  --relationship "manager" \
  --cardinality one \
  --target.entity Employee \
  --relationship.fields "ManagerId:EmployeeId"

# Row-level security: users can only read their own orders
dab update Order \
  --permissions "authenticated:read" \
  --policy-database "@item.UserId eq @claims.userId"

# Request policy: validate payload
dab update Order \
  --permissions "authenticated:create" \
  --policy-request "@item.Quantity gt 0 and @item.Quantity lt 100"
```

**Common Mistakes:**
- Entity name mismatch (case-sensitive)
- Incomplete relationship (missing `--cardinality` or `--target.entity`)
- Wrong policy syntax (use OData-style expressions, not SQL)
- Using `--map` without restating all desired mappings

**What to Say Next:**
"Entity updated! Run `dab validate` to check the changes."

---

### 4. `dab configure` — Update Runtime/Data-Source

**Purpose:** Modify **runtime** and **data-source** properties that are **not entity-specific**.

**Syntax:**
```bash
dab configure [options]
```

**Key Behaviors:**
- Does **not** change entities (use `dab update` for that)
- Modifies global config: data-source, runtime endpoints, auth, host settings

**When to Use:**
- Update database connection settings
- Toggle/adjust REST/GraphQL/MCP runtime endpoints
- Configure authentication provider
- Set CORS origins
- Change host mode

**What to Ask:**
1. Which config file?
2. What to change?
   - Data-source (database type, connection string)
   - Runtime (REST/GraphQL/MCP paths, auth, host mode, CORS)

**Best Practice:**
Use small, focused `dab configure` commands to isolate failures.

**Example Use Cases:**
```bash
# Update connection string
dab configure --connection-string "@env('NEW_CONNECTION_STRING')"

# Enable MCP endpoint
dab configure --mcp.enabled true --mcp.path "/mcp"

# Add CORS origins
dab configure --cors-origin "https://app.example.com,https://admin.example.com"

# Switch to development mode
dab configure --host-mode development
```

**What to Say Next:**
"Configuration updated! Run `dab validate` to verify changes."

---

### 5. `dab validate` — Validate Configuration

**Purpose:** Check DAB config for errors **before** starting the engine.

**Syntax:**
```bash
dab validate [--config <path>]
```

**Options:**
| Option | Default | Description |
|---|---|---|
| `--config`, `-c` | `dab-config.json` | Config file path |

**Validation Stages:**
1. **Schema validation** — JSON structure and schema compliance
2. **Config properties** — Logical consistency of settings
3. **Permissions** — Role/action/policy correctness
4. **Database connection** — Connectivity and env var resolution
5. **Entity metadata** — Database objects/columns/params/relationships exist

**Exit Codes:**
- `0` — Valid
- Non-zero — Invalid

**Best Practices:**
```bash
# Validate after every change
dab add Product --source dbo.Products --permissions "anonymous:read"
dab validate

# Validate before starting
dab validate && dab start

# CI/CD validation
dab validate --config dab-config.production.json
```

**On Validation Failure:**
1. Ask user for the **first error** from output
2. Identify the failing stage (schema, permissions, connectivity, etc.)
3. Suggest targeted fix using `dab update` or `dab configure`
4. Re-validate

**What to Say Next:**
"Validation passed! Start the engine with `dab start`."

---

### 6. `dab start` — Start Runtime

**Purpose:** Start the DAB engine and expose configured endpoints.

**Syntax:**
```bash
dab start [options]
```

**Options:**
| Option | Description |
|---|---|
| `--config`, `-c` | Config file path |
| `--verbose` | Enable verbose logging |
| `--no-https-redirect` | Disable HTTP→HTTPS redirect |
| `--LogLevel <level>` | Set log level (`Debug`, `Information`, `Warning`, `Error`) |

**Prerequisites (check before starting):**
1. DAB CLI installed
2. Config file exists
3. Environment variables set (if using `@env()`)
4. Config validated (`dab validate`)

**Success Indicators:**
- Logs show "Now listening on: http://localhost:5000" (or similar)
- Runtime stays running until Ctrl+C

**Examples:**
```bash
# Start with default config
dab start

# Start with specific config
dab start --config dab-config.production.json

# Start with verbose logging
dab start --verbose

# Start with debug logging
dab start --LogLevel Debug
```

**Important:**
DAB does **not** hot-reload config. Restart the runtime to apply changes.

**What to Say Next:**
"DAB is running! Access endpoints at the displayed URL."

---

## Conversational Decision Trees

### User says: "init" or "create config"
**Ask:**
1. Database type? (`mssql`, `postgresql`, `mysql`, `cosmosdb_nosql`, `cosmosdb_postgresql`)
2. Config file name? (default: `dab-config.json`)
3. Connection string inline or via `@env()`? (recommend `@env()`)
4. Which endpoints? (REST, GraphQL, MCP — defaults to all enabled)
5. Host mode? (`development` or `production`)
6. Auth provider? (optional: `AzureAD`, etc.)

**Offer template:**
```bash
dab init \
  --database-type mssql \
  --connection-string "@env('DATABASE_CONNECTION_STRING')" \
  --host-mode development
```

### User says: "add entity" or "add table/view/stored procedure"
**Ask:**
1. Entity name? (logical API name)
2. Source object? (include schema, e.g., `dbo.Products`)
3. Source type? (`table`, `view`, `stored-procedure`)
4. Key fields? (required for views)
5. Permissions? (at least one `role:actions` pair)
6. REST/GraphQL exposure? (enable/disable, custom naming)

**Offer templates:**
```bash
# Table
dab add Product \
  --source dbo.Products \
  --permissions "anonymous:read"

# View
dab add ProductSummary \
  --source dbo.vw_ProductSummary \
  --source.type view \
  --source.key-fields "ProductId" \
  --permissions "anonymous:read"

# Stored procedure
dab add GetProducts \
  --source dbo.usp_GetProducts \
  --source.type stored-procedure \
  --permissions "anonymous:execute" \
  --graphql.operation query
```

### User says: "change entity" or "update entity"
**Ask:**
1. Which entity?
2. What to change?
   - Permissions (add/update role)
   - Relationships (define/update)
   - Mappings (rename fields)
   - Policies (row-level security)
   - REST/GraphQL exposure
   - Caching
   - Field inclusion/exclusion

**Offer targeted commands based on answer.**

### User says: "add relationship" or "connect entities"
**Ask:**
1. Source entity name?
2. Target entity name?
3. Relationship name? (how it appears in API, e.g., "products", "category", "courses")
4. Relationship type?
   - **One-to-many:** Parent has many children (e.g., Category → Products)
   - **Many-to-one:** Child belongs to parent (e.g., Product → Category)
   - **One-to-one:** Single record to single record (e.g., User → Profile)
   - **Many-to-many:** Requires join table (e.g., Students ↔ Courses)
5. Which fields connect them? (foreign key to primary key)
6. For many-to-many: What's the join table name?

**Offer templates:**
```bash
# One-to-many: Category has many Products
dab update Category \
  --relationship "products" \
  --cardinality many \
  --target.entity Product \
  --relationship.fields "CategoryId:CategoryId"

# Many-to-one: Product belongs to Category
dab update Product \
  --relationship "category" \
  --cardinality one \
  --target.entity Category \
  --relationship.fields "CategoryId:CategoryId"

# Many-to-many: Student has many Courses
dab update Student \
  --relationship "courses" \
  --cardinality many \
  --target.entity Course \
  --linking.object "dbo.Enrollments" \
  --linking.source.fields "StudentId" \
  --linking.target.fields "CourseId"

# Self-referencing: Employee has a Manager
dab update Employee \
  --relationship "manager" \
  --cardinality one \
  --target.entity Employee \
  --relationship.fields "ManagerId:EmployeeId"
```

### User says: "configure" or "change runtime"
**Ask:**
1. Which config file?
2. What to change?
   - Database connection
   - REST/GraphQL/MCP settings
   - Auth provider
   - CORS origins
   - Host mode

**Confirm it's not an entity change** (use `dab update` for that).

### User says: "validate" or "check config"
**Ask:**
1. Which config file? (default: `dab-config.json`)
2. Are required env vars set?

**If validation fails:**
1. Ask for first error from output
2. Identify stage (schema, permissions, connectivity, etc.)
3. Suggest fix

### User says: "start" or "run"
**Ask:**
1. Which config file?
2. Are env vars set?
3. Has config been validated?

**Offer:**
```bash
dab validate && dab start
```

---

## Quick Reference Templates

### New Project
```bash
# 1. Create config
dab init \
  --database-type mssql \
  --connection-string "@env('DATABASE_CONNECTION_STRING')" \
  --host-mode development

# 2. Add entity
dab add Product \
  --source dbo.Products \
  --permissions "anonymous:read"

# 3. Validate and start
dab validate && dab start
```

### Common Patterns

#### Add Table with Multiple Roles
```bash
dab add Product --source dbo.Products --permissions "anonymous:read"
dab update Product --permissions "authenticated:*"
dab update Product --permissions "admin:*"
```

#### One-to-Many Relationship (Parent → Children)
```bash
# Category has many Products
dab update Category \
  --relationship "products" \
  --cardinality many \
  --target.entity Product \
  --relationship.fields "CategoryId:CategoryId"

# Effect: Category API responses include nested "products" array
# GraphQL: category { products { productId name } }
# REST: GET /api/Category/1?$expand=products
```

#### Many-to-One Relationship (Child → Parent)
```bash
# Product belongs to Category
dab update Product \
  --relationship "category" \
  --cardinality one \
  --target.entity Category \
  --relationship.fields "CategoryId:CategoryId"

# Effect: Product API responses include nested "category" object
# GraphQL: product { category { categoryId name } }
# REST: GET /api/Product/1?$expand=category
```

#### Bidirectional Relationships (Both Directions)
```bash
# Add both relationships for full navigation
dab update Category \
  --relationship "products" \
  --cardinality many \
  --target.entity Product \
  --relationship.fields "CategoryId:CategoryId"

dab update Product \
  --relationship "category" \
  --cardinality one \
  --target.entity Category \
  --relationship.fields "CategoryId:CategoryId"
```

#### Many-to-Many Relationship (via Join Table)
```bash
# Student has many Courses through Enrollments
dab update Student \
  --relationship "courses" \
  --cardinality many \
  --target.entity Course \
  --linking.object "dbo.Enrollments" \
  --linking.source.fields "StudentId" \
  --linking.target.fields "CourseId"

# Course has many Students through Enrollments
dab update Course \
  --relationship "students" \
  --cardinality many \
  --target.entity Student \
  --linking.object "dbo.Enrollments" \
  --linking.source.fields "CourseId" \
  --linking.target.fields "StudentId"

# Effect: Both sides can navigate through junction table
# GraphQL: student { courses { courseId name } }
# GraphQL: course { students { studentId name } }
```

#### Self-Referencing Relationship (Hierarchy)
```bash
# Employee has a Manager (also an Employee)
dab update Employee \
  --relationship "manager" \
  --cardinality one \
  --target.entity Employee \
  --relationship.fields "ManagerId:EmployeeId"

# Employee has many DirectReports
dab update Employee \
  --relationship "directReports" \
  --cardinality many \
  --target.entity Employee \
  --relationship.fields "EmployeeId:ManagerId"
```

#### Composite Key Relationship
```bash
# OrderItem links to Order via OrderId + LineNumber
dab update OrderItem \
  --relationship "order" \
  --cardinality one \
  --target.entity Order \
  --relationship.fields "OrderId:OrderId,LineNumber:LineNumber"
```

#### Row-Level Security
```bash
dab update Order \
  --permissions "authenticated:read" \
  --policy-database "@item.UserId eq @claims.userId"
```

#### REST-Only Endpoint
```bash
dab init \
  --database-type mssql \
  --connection-string "@env('DATABASE_CONNECTION_STRING')" \
  --rest.enabled true \
  --graphql.enabled false \
  --mcp.enabled false
```

#### MCP-Only Endpoint (Agent Scenarios)
```bash
dab init \
  --database-type mssql \
  --connection-string "@env('DATABASE_CONNECTION_STRING')" \
  --rest.enabled false \
  --graphql.enabled false \
  --mcp.enabled true
```

---

## Consistency Rules

1. **Always recommend `dab validate` before `dab start`**
2. **Use environment variables** for connection strings (security)
3. **Require `.gitignore`** with `.env`, `**\bin`, and `**\obj` entries before adding secrets
4. **Azure deployments: build custom Docker image** with embedded `dab-config.json` pushed to ACR — never use Azure Files, storage accounts, or volume mounts
3. **Stored procedures use `execute` permission**, not `read`
4. **Views require explicit key fields** via `--source.key-fields`
5. **Field mappings (`--map`) replace all existing mappings** (not additive)
6. **Entity changes use `dab update`**, runtime changes use `dab configure`
7. **Permissions in `dab add` are not repeatable** — add first role in `dab add`, others in `dab update`
8. **Policy syntax is OData-style**, not SQL (e.g., `eq`, `gt`, `and`, `@item`, `@claims`)
9. **Relationships are defined on source entity** via `dab update` (not `dab add`)
10. **Cardinality `many` creates array**, `one` creates nested object in API responses
11. **Many-to-many requires junction table** specified via `--linking.object`
12. **Both entities must exist** before creating relationships between them

---

## Common Troubleshooting

### "Entity doesn't exist"
- Check entity name (case-sensitive)
- Verify entity was added with `dab add`

### "Relationship target entity not found"
- Ensure target entity exists in config
- Check entity name spelling (case-sensitive)
- Cannot reference entities in different config files (multi-file limitation)

### "Relationship validation failed"
- Verify field names match actual database columns
- Check that source and target fields are compatible types
- For many-to-many: ensure linking table exists
- Ensure both source and target fields are specified

### "Validation failed: connection"
- Verify environment variable is set
- Check connection string format
- Test database connectivity

### "Validation failed: permissions"
- Check role names (match auth provider roles)
- Verify action names (`create`, `read`, `update`, `delete`, `execute`, `*`)
- Check policy syntax (OData-style)

### "Validation failed: entity metadata"
- Verify database object exists (table/view/stored procedure)
- Check schema name (e.g., `dbo.TableName`)
- For views: ensure `--source.key-fields` are specified

### "Runtime won't start"
- Run `dab validate` first
- Check port availability
- Verify environment variables are set

---

## Version-Specific Features

### v1.7+ Only (RC/Prerelease)
- `--description` (entity and field descriptions)
- `--fields.name`, `--fields.alias`, `--fields.description`, `--fields.primary-key`
- `--parameters.name`, `--parameters.description`, `--parameters.required`, `--parameters.default`
- `--mcp.enabled`, `--mcp.path` (MCP endpoint support)

To install v1.7 RC:
```bash
dotnet tool install microsoft.dataapibuilder --prerelease
```

---

## References

- [DAB CLI Overview](https://learn.microsoft.com/en-us/azure/data-api-builder/command-line/)
- [dab init](https://learn.microsoft.com/en-us/azure/data-api-builder/command-line/dab-init)
- [dab add](https://learn.microsoft.com/en-us/azure/data-api-builder/command-line/dab-add)
- [dab update](https://learn.microsoft.com/en-us/azure/data-api-builder/command-line/dab-update)
- [dab configure](https://learn.microsoft.com/en-us/azure/data-api-builder/command-line/dab-configure)
- [dab validate](https://learn.microsoft.com/en-us/azure/data-api-builder/command-line/dab-validate)
- [dab start](https://learn.microsoft.com/en-us/azure/data-api-builder/command-line/dab-start)
- [DAB Installation](https://learn.microsoft.com/en-us/azure/data-api-builder/command-line/install)
