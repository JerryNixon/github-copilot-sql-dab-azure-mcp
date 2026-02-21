---
name: data-api-builder-demo
description: Operational guide for building and maintaining DAB quickstart demos. Use when creating a new quickstart, renaming folders, validating structure, or preparing a demo for presentation.
---

# Data API Builder — Demo Operations

This skill captures lessons learned from building the DAB quickstart series. Follow these rules when creating, modifying, or validating any quickstart project.

---

## Quickstart Folder Structure

Every quickstart follows this canonical layout:

```
quickstart<N>/
  ├── quickstart<N>.sln         # Solution file
  ├── azure.yaml                # azd entry point
  ├── database.sql              # Legacy flat schema (keep for reference)
  ├── README.md                 # Quickstart documentation
  ├── .gitignore                # Must exclude .env, **\bin, **\obj
  ├── .config/
  │   └── dotnet-tools.json     # Tool manifest (dab, sqlpackage)
  ├── .vscode/
  │   └── mcp.json              # MCP server config for Copilot
  ├── aspire-apphost/           # .NET Aspire orchestration
  │   ├── Aspire.AppHost.csproj
  │   └── Program.cs
  ├── data-api/                 # DAB configuration + Dockerfile
  │   ├── dab-config.json
  │   └── Dockerfile
  ├── database/                 # SQL Database Project
  │   ├── database.sqlproj
  │   ├── database.publish.xml
  │   ├── Tables/*.sql
  │   └── Scripts/PostDeployment.sql
  ├── mcp-inspector/            # MCP Inspector containerization (for Azure)
  │   ├── Dockerfile
  │   ├── entrypoint.sh
  │   └── nginx.conf
  ├── web-app/                  # Frontend (nginx-served static files)
  │   ├── index.html
  │   ├── app.js
  │   ├── config.js
  │   ├── dab.js
  │   ├── styles.css
  │   └── Dockerfile
  └── azure-infra/              # Azure deployment (Bicep + scripts)
      ├── main.bicep
      ├── resources.bicep
      └── post-provision.ps1
```

---

## Folder Naming Conventions

| Folder | Name | Rationale |
|--------|------|-----------|
| Aspire orchestration | `aspire-apphost` | Lowercase, hyphenated — matches skill naming |
| DAB config | `data-api` | Describes what it is, not the tool |
| Database project | `database` | Standard SQL project location |
| MCP Inspector | `mcp-inspector` | Full name, not abbreviated |
| Web frontend | `web-app` | Distinguishes from web API |
| Azure infrastructure | `azure-infra` | Clarifies it's infrastructure, not app code |

**Rules:**
- All folder names are **lowercase with hyphens**
- No dots in folder names (use `aspire-apphost`, not `Aspire.AppHost`)
- The `.csproj` file name inside can differ from the folder name

---

## Renaming Folders — Checklist

When renaming any folder, **always** update all references. Files that commonly contain folder paths:

| File | What to check |
|------|---------------|
| `*.sln` | Project path in `Project(...)` line |
| `azure.yaml` | `infra.path` and `hooks.*.run` paths |
| `aspire-apphost/Program.cs` | `Path.Combine(root, ...)` references |
| `azure-infra/post-provision.ps1` | `Copy-Item`, file path strings |
| `aspire-apphost/*.csproj` | `<ProjectReference>` paths |
| `README.md` | Folder references (usually none — keep READMEs path-free) |

**After every rename:**

1. **Search for the old name** across the quickstart — use regex `\bold-name[/\\]` and `"old-name"`
2. **Update all references** found
3. **Clean and rebuild** — `Remove-Item -Recurse obj, bin; dotnet build`
4. **Verify build succeeds** with 0 errors
5. **Review the README** — confirm it doesn't reference folder paths directly

> **Tip:** `obj/` and `bin/` contain cached paths. Always delete them after renames and rebuild.

---

## README Standards

Each quickstart README follows this structure:

1. **Title** — `# Quickstart N: <Auth Topic>`
2. **Intro** — 2-3 sentences explaining the auth pattern
3. **What You'll Learn** — Bullet list (3-4 items)
4. **Auth Matrix** — Table showing auth at each hop
5. **Architecture** — Mermaid flowchart showing services and auth flows
6. **Considerations** — Callout about the auth pattern's tradeoffs
7. **Connection String Example** — Formatted connection string for the pattern
8. **Prerequisites** — Links to required tools
9. **Run Locally** — Exact commands (`dotnet tool restore`, `aspire run`)
10. **Deploy to Azure** — Exact commands (`azd auth login`, `azd up`)
11. **Database Schema** — Mermaid ERD matching the SQL Database Project
12. **Next Steps** — Links to other quickstarts

**README rules:**
- **Never reference folder paths** — keep READMEs resilient to renames
- **Mermaid ERD types must be simple** — `nvarchar` not `nvarchar(200)`
- **Architecture diagrams use service names** — no ports, no versions
- **Auth matrix must match the actual implementation** — verify against `dab-config.json` and Bicep
- **Keep it under 120 lines** — concise is better

---

## Consistency Between Quickstarts

The quickstarts form a progressive series. Each one adds complexity:

| QS | Auth Pattern | Delta from Previous |
|----|-------------|-------------------|
| 1 | SQL Auth everywhere | Baseline |
| 2 | Managed Identity (API→SQL) | Replaces SQL Auth on the DB hop |
| 3 | Entra ID infrastructure | Adds app registrations, no user login yet |
| 4 | User login + DAB policy | Adds frontend auth, per-user filtering |
| 5 | Row-Level Security | Moves filtering into SQL |

**Cross-quickstart rules:**
- Folder structure must be **identical** across all quickstarts
- Folder names must match (if you rename in one, rename in all)
- README format must be consistent
- `database/` SQL Database Project is the single source of truth for schema
- Each quickstart is **self-contained** — can be deployed independently

---

## Validation Checklist (Before Demo)

Run through this before any presentation or PR:

### Build Validation

```powershell
cd quickstart<N>
dotnet tool restore
dotnet build aspire-apphost/Aspire.AppHost.csproj
```

Must complete with 0 errors, 0 warnings.

### Structure Validation

```powershell
# Verify all expected folders exist
$expected = @('aspire-apphost', 'data-api', 'database', 'mcp-inspector', 'web-app', 'azure-infra')
$expected | ForEach-Object { if (!(Test-Path $_)) { Write-Warning "Missing: $_" } }
```

### File Validation

```powershell
# Verify critical files exist
$files = @(
    'azure.yaml',
    'quickstart<N>.sln',
    'README.md',
    '.gitignore',
    'data-api/dab-config.json',
    'data-api/Dockerfile',
    'database/database.sqlproj',
    'aspire-apphost/Aspire.AppHost.csproj',
    'aspire-apphost/Program.cs',
    'azure-infra/main.bicep',
    'azure-infra/resources.bicep',
    'azure-infra/post-provision.ps1'
)
$files | ForEach-Object { if (!(Test-Path $_)) { Write-Warning "Missing: $_" } }
```

### Cross-Reference Validation

```powershell
# Check for stale folder references
$staleNames = @('Aspire.AppHost', '/api/', '/web/', '/azure/', '/inspector/')
$staleNames | ForEach-Object {
    $hits = Get-ChildItem -Recurse -Include *.cs,*.yaml,*.sln,*.ps1,*.csproj | Select-String -Pattern $_ -SimpleMatch
    if ($hits) { Write-Warning "Stale reference to '$_' found:"; $hits | ForEach-Object { Write-Warning "  $_" } }
}
```

### .gitignore Validation

Before committing, verify `.gitignore` is correct and no build artifacts will leak into the repo.

**Required ignore patterns:**
```
.env
.azure-env
.azure/
dab-config.*.json
**/bin
**/obj
node_modules/
web-deploy-temp/
api-deploy-temp/
web-deploy.zip
```

> **CRITICAL:** Use `**/bin` and `**/obj` (not `bin/` and `obj/`) — the root-only pattern misses nested project folders like `aspire-apphost/bin/`.

**Count untracked files before committing:**
```powershell
# Show how many files git will add
$untracked = git ls-files --others --exclude-standard
Write-Host "Untracked files: $($untracked.Count)"
$untracked
```

Review the list — every file should be legitimate source. If you see `bin/`, `obj/`, `.env`, or deploy temp folders, fix `.gitignore` before committing. A typical quickstart has ~20-25 source files; significantly more suggests a missing ignore pattern.

---

## Common Pitfalls

### Folder rename breaks build
- **Cause:** `obj/` and `bin/` cache absolute paths from before the rename
- **Fix:** Delete `obj/` and `bin/`, rebuild

### `azd up` can't find Bicep
- **Cause:** `azure.yaml` still points to old `infra.path`
- **Fix:** Update `path` and `run` fields in `azure.yaml`

### Solution file won't load project
- **Cause:** `.sln` has old folder path in `Project(...)` line
- **Fix:** Update the path — keep the project GUID unchanged

### Post-provision script fails
- **Cause:** `Copy-Item` or file paths reference old folder names
- **Fix:** Search `post-provision.ps1` for all folder references

### Program.cs can't find dab-config.json
- **Cause:** `Path.Combine(root, "api", ...)` still uses old path
- **Fix:** Update all `Path.Combine` calls in `Program.cs`

### Web app shows stale content
- **Cause:** `config.js` wasn't regenerated after Azure deployment changes
- **Fix:** Re-run post-provision or manually update `config.js`

---

## Peer Skills Reference

| Skill | Use For |
|-------|---------|
| `aspire-data-api-builder` | Local Aspire orchestration |
| `docker-data-api-builder` | Local Docker Compose orchestration |
| `azure-data-api-builder` | Azure deployment (Bicep, azd, ACR) |
| `data-api-builder-config` | DAB config file reference |
| `data-api-builder-cli` | DAB CLI commands |
| `data-api-builder-mcp` | MCP endpoint setup |
| `aspire-mcp-inspector` | Local MCP Inspector in Aspire |
| `azure-mcp-inspector` | Azure MCP Inspector deployment |
| `aspire-sql-commander` | Local SQL Commander in Aspire |
| `azure-sql-commander` | Azure SQL Commander deployment |
| `aspire-sql-projects` | SQL Database Projects in Aspire |
| `creating-agent-skills` | How to create new skills |
