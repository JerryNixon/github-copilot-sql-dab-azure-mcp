---
name: aspire-mcp-inspector
description: Add MCP Inspector to a .NET Aspire AppHost for debugging MCP servers like Data API Builder. Use when asked to inspect MCP traffic, debug MCP connections, or add MCP Inspector to Aspire.
---

# MCP Inspector in .NET Aspire

Add the MCP Inspector as an Aspire-managed resource so it auto-starts alongside your MCP server (e.g., Data API Builder), appears in the dashboard, and is accessible in the browser without manual setup.

For Azure deployment, see the `azure-mcp-inspector` skill.

## Documentation references

- https://github.com/CommunityToolkit/Aspire/blob/main/src/CommunityToolkit.Aspire.Hosting.McpInspector/README.md
- https://github.com/modelcontextprotocol/inspector
- https://modelcontextprotocol.io/docs/tools/inspector

---

## Package

```xml
<PackageReference Include="CommunityToolkit.Aspire.Hosting.McpInspector" Version="13.1.1" />
```

---

## Canonical Program.cs Pattern

```csharp
var mcpInspector = builder
    .AddMcpInspector("mcp-inspector", options =>
    {
        options.InspectorVersion = "0.20.0";   // always pin — default version has known StreamableHTTP bugs
    })
    .WithMcpServer(dabServer, transportType: McpTransportType.StreamableHttp)
    .WithParentRelationship(dabServer)          // groups under the MCP server in the dashboard
    .WithEnvironment("DANGEROUSLY_OMIT_AUTH", "true")  // removes token prompt for local dev
    .WaitFor(dabServer);
```

---

## Transport Type

Always use `McpTransportType.StreamableHttp` for DAB and most modern MCP servers.

- DAB exposes MCP at `/mcp` via Streamable HTTP — **not SSE**
- `McpTransportType.Sse` will produce a "Connection Error" against DAB

---

## Inspector Version

**Always pin `InspectorVersion` explicitly.** The version bundled in the NuGet package (`0.17.2`) has a crash on StreamableHTTP:

```
TypeError [ERR_INVALID_STATE]: Invalid state: Controller is already closed
```

Use `0.20.0` or later. Check https://www.npmjs.com/package/@modelcontextprotocol/inspector for the current release.

---

## Auth

For local development, set `DANGEROUSLY_OMIT_AUTH=true`. This eliminates the "Proxy Authentication Required" dialog. It is safe because the inspector only binds to `localhost`.

Without this, the token-embedded URL is shown in the Aspire dashboard — the user must click that specific link. Navigating directly to `http://localhost:6274` will trigger the auth prompt.

---

## How It Works (Local / Aspire)

The inspector is **not a container** — it runs as a Node.js process (`npx @modelcontextprotocol/inspector@<version>`) on the host machine. The Aspire toolkit:

1. Writes a temp JSON config file at startup with the MCP server URL and transport type
2. Invokes `npx -y <package> --config <tempfile> --server <name>`
3. Starts two ports: `6274` (browser UI) and `6277` (proxy server)

The inspector UI will pre-select the configured server but **does not auto-connect** — the user must click **Connect** once in the browser.

---

## Inspector Architecture (Source-Level Reference)

The Inspector has two processes and a well-defined configuration chain. Understanding these internals is essential for containerization, Azure deployment, and debugging.

### Two-Process Model

| Process | Default Port | Source | Purpose |
|---------|-------------|--------|---------|
| React client (Vite dev server) | 6274 | `client/` | Browser UI — transport selector, connection controls, tool/resource/prompt tabs |
| Express proxy server | 6277 | `server/src/index.ts` | Proxies browser requests to the actual MCP server; handles transport creation, auth, sessions |

The browser never talks directly to the MCP server. All traffic flows: **Browser → Proxy (6277) → MCP Server**.

Override ports via `options.ClientPort` / `options.ServerPort` (Aspire) or env vars `CLIENT_PORT` / `SERVER_PORT`.

### Proxy Server CLI Args (`server/src/index.ts`)

The proxy server uses Node's `parseArgs` to accept startup configuration:

```
npx @modelcontextprotocol/inspector@0.20.0 \
  --transport streamable-http \
  --server-url https://example.com/mcp \
  --command "node" \
  --args "server.js" \
  --env '{"KEY":"value"}'
```

| Arg | Type | Purpose |
|-----|------|---------|
| `--transport` | `string` | Default transport type: `stdio`, `sse`, or `streamable-http` |
| `--server-url` | `string` | Default MCP server URL (for SSE/StreamableHTTP transports) |
| `--command` | `string` | Default command (for STDIO transport) |
| `--args` | `string` | Default args (for STDIO transport) |
| `--env` | `string` | JSON object merged into STDIO process environment |

These CLI args populate the **`GET /config`** endpoint response, which the React client fetches on mount.

### The `/config` Endpoint (Critical)

The proxy server exposes `GET /config` that returns defaults to the React UI:

```json
{
  "defaultEnvironment": { "HOME": "/root", "PATH": "..." },
  "defaultCommand": "",
  "defaultArgs": "",
  "defaultTransport": "streamable-http",
  "defaultServerUrl": "https://example.com/mcp"
}
```

- `defaultTransport` and `defaultServerUrl` come from `--transport` and `--server-url` CLI args
- `defaultCommand` and `defaultArgs` come from `--command` and `--args` CLI args
- `defaultEnvironment` merges `getDefaultEnvironment()` + JSON-parsed `MCP_ENV_VARS` env var

**This is the primary mechanism for preconfiguring the Inspector UI without query params.**

### React Client Configuration Chain (`client/src/`)

On startup, the React app resolves each field through this precedence chain:

**Transport type** (`getInitialTransportType` in `configUtils.ts`):
1. Query param `?transport=` → if present, wins
2. `localStorage.getItem("lastTransportType")` → if previously used
3. Falls back to `"stdio"`
4. **Then** overridden by `/config` response if `data.defaultTransport` is set

**Server URL** (`getInitialSseUrl` in `configUtils.ts`):
1. Query param `?serverUrl=` → if present, wins
2. `localStorage.getItem("lastSseUrl")` → if previously used
3. Falls back to `"http://localhost:3001/sse"`
4. **Then** overridden by `/config` response if `data.defaultServerUrl` is set

**Proxy address** (`getMCPProxyAddress` in `configUtils.ts`):
1. `config.MCP_PROXY_FULL_ADDRESS.value` from `InspectorConfig` → if set
2. Query param `?MCP_PROXY_PORT=` for custom proxy port
3. Falls back to `${window.location.protocol}//${window.location.hostname}:6277`

**CRITICAL:** The proxy address default appends `:6277` to the hostname. In production (Azure, Docker) where the proxy is behind nginx on the same origin (port 80/443), you **must** set `MCP_PROXY_FULL_ADDRESS` to the same origin. See the `azure-mcp-inspector` skill for the nginx `sub_filter` injection solution.

### InspectorConfig (localStorage key: `inspectorConfig_v1`)

The Inspector persists configuration in localStorage under key `inspectorConfig_v1`. Each entry is a `ConfigItem`:

```typescript
type ConfigItem = {
  value: string | number | boolean;
  label: string;
  description: string;
  is_session_item?: boolean;  // if true, stored in sessionStorage instead
};
```

Default keys in `DEFAULT_INSPECTOR_CONFIG` (`client/src/lib/constants.ts`):

| Key | Default | Purpose |
|-----|---------|---------|
| `MCP_SERVER_REQUEST_TIMEOUT` | `10000` | Per-request timeout (ms) |
| `MCP_REQUEST_TIMEOUT_RESET_ON_PROGRESS` | `true` | Reset timeout on progress notifications |
| `MCP_REQUEST_MAX_TOTAL_TIMEOUT` | `60000` | Max total timeout (ms) |
| `MCP_PROXY_FULL_ADDRESS` | `""` | Override proxy server address (critical for containerized deployments) |
| `MCP_PROXY_AUTH_TOKEN` | `""` | Bearer token for proxy auth (session item) |
| `MCP_TASK_TTL` | `30000` | Task TTL (ms) |

Query params matching any `InspectorConfig` key will override the stored value (via `getConfigOverridesFromQueryParams`).

### Additional localStorage Keys

The React app persists connection state independently of `InspectorConfig`:

| Key | Example Value | Purpose |
|-----|--------------|---------|
| `lastSseUrl` | `https://example.com/mcp` | Last-used server URL |
| `lastTransportType` | `streamable-http` | Last-used transport |
| `lastCommand` | `node` | Last-used STDIO command |
| `lastArgs` | `server.js` | Last-used STDIO args |
| `lastConnectionType` | `proxy` | `"direct"` or `"proxy"` |
| `lastBearerToken` | `Bearer xyz` | Saved auth token |
| `lastHeaderName` | `Authorization` | Saved custom header name |
| `lastCustomHeaders` | `[{name,value,enabled}]` | Full custom headers array |
| `lastOauthClientId` | `my-client-id` | OAuth client ID |
| `lastOauthScope` | `openid profile` | OAuth scope |

### Proxy Server Environment Variables

| Variable | Purpose |
|----------|---------|
| `DANGEROUSLY_OMIT_AUTH` | Skip session token auth entirely |
| `MCP_PROXY_AUTH_TOKEN` | Use this fixed token instead of auto-generating one |
| `ALLOWED_ORIGINS` | Comma-separated list of allowed CORS origins (DNS rebinding protection) |
| `CLIENT_PORT` | Override React dev server port (default: `6274`) |
| `SERVER_PORT` | Override proxy server port (default: `6277`) |
| `HOST` | Bind address (default: `localhost`; use `0.0.0.0` in containers) |
| `MCP_AUTO_OPEN_ENABLED` | Set to `false` to prevent auto-opening browser |
| `MCP_ENV_VARS` | JSON object merged into default environment for STDIO processes |

### Proxy Server Routes

| Route | Method | Purpose |
|-------|--------|---------|
| `/config` | GET | Returns default configuration (CLI args + environment) |
| `/health` | GET | Returns `{"status":"ok"}` |
| `/mcp` | GET/POST/DELETE | StreamableHTTP transport proxy (session-based, supports WebSocket upgrade) |
| `/stdio` | GET | STDIO transport proxy (SSE session to browser, spawns child process) |
| `/sse` | GET | SSE transport proxy (deprecated, replaced by StreamableHTTP) |
| `/message` | POST | SSE message relay (for STDIO/SSE transports) |
| `/sandbox` | GET | MCP Apps sandbox HTML (rate-limited: 100 req/15min) |

### OAuth Support

The Inspector has built-in OAuth 2.1 support for MCP servers that require authentication:
- `/oauth/callback` — OAuth redirect handler for production flows
- `/oauth/callback/debug` — OAuth redirect handler for debug flows (Auth Debugger tab)
- The `useConnection` hook manages the full token exchange, refresh, and header injection
- Custom headers can be configured via the UI (Sidebar → Auth section)

---

## Common Issues and Fixes

### "Controller is already closed" crash
**Cause:** Default inspector version (0.17.2) bug with StreamableHTTP.  
**Fix:** Pin `options.InspectorVersion = "0.20.0"`.

### "Proxy Authentication Required" dialog
**Cause:** Browser navigated to `localhost:6274` directly instead of the token URL, or auth was not disabled.  
**Fix:** Add `.WithEnvironment("DANGEROUSLY_OMIT_AUTH", "true")`.

### "Connection Error — Check if your MCP server is running and proxy token is correct"
**Cause 1:** Wrong transport type (SSE instead of StreamableHTTP).  
**Fix:** Use `McpTransportType.StreamableHttp`.  
**Cause 2:** MCP server not yet healthy when inspector tried to connect.  
**Fix:** Ensure `.WaitFor(dabServer)` is present.

### Inspector shows STDIO fields instead of URL field
**Cause:** Transport defaulted to `stdio` because no `--transport` CLI arg or query param was provided.  
**Fix:** Pass `--transport streamable-http` via CLI args or use `?transport=streamable-http` query param.

### Browser can't reach proxy (connection refused on port 6277)
**Cause:** In containerized/cloud deployments, port 6277 is not exposed. The default `getMCPProxyAddress()` appends `:6277` to the hostname.  
**Fix:** Set `MCP_PROXY_FULL_ADDRESS` in the `inspectorConfig_v1` localStorage entry to the same origin. See the `azure-mcp-inspector` skill for the nginx `sub_filter` injection solution.

### Do not override `WithUrls`
The Aspire toolkit generates the token-embedded URL via its own `WithUrls` callback. Chaining another `WithUrls` that clears or replaces the URL list will break the dashboard link.

---

## Prerequisites

- Node.js 22+ installed on the host (`node --version`)
- npx available (`npx --version`)
- Docker running (for the MCP server container)
