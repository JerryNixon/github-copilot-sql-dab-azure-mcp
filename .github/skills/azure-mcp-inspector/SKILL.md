---
name: azure-mcp-inspector
description: Deploy MCP Inspector to Azure Container Apps with nginx reverse proxy for same-origin routing. Use when asked to deploy Inspector to Azure, containerize Inspector, or preconfigure Inspector UI for cloud.
---

# MCP Inspector — Azure Deployment

Deploy MCP Inspector to Azure Container Apps. Inspector requires two ports (6274 UI + 6277 proxy) but Azure Container Apps supports only one ingress port. Use a custom Docker image with nginx reverse proxy to combine both behind port 80.

## Documentation references

- https://github.com/modelcontextprotocol/inspector
- https://modelcontextprotocol.io/docs/tools/inspector
- See also: `aspire-mcp-inspector` skill for local Aspire usage and Inspector architecture internals

---

## The Two Problems to Solve

1. **Port merging** — Combine ports 6274 (UI) and 6277 (proxy) behind a single port 80
2. **Preconfiguration** — Auto-fill transport type and server URL so the user just clicks Connect at a plain URL (no query params)

---

## Architecture (Same-Origin Proxy)

nginx routes proxy API paths to port 6277 and everything else to port 6274. This puts the proxy at the **same origin** as the UI.

**Why same-origin matters:** The React client's `getMCPProxyAddress()` function defaults to `${protocol}//${hostname}:6277` when `MCP_PROXY_FULL_ADDRESS` is empty. In Azure Container Apps, only port 80/443 is exposed — the client would fail trying to reach 6277 directly. By routing proxy paths through nginx on the same origin, we solve this with a localStorage injection.

**Three mechanisms work together for zero-config preconfiguration:**

1. **nginx `sub_filter`** — Injects a `<script>` into the HTML `<head>` that sets `MCP_PROXY_FULL_ADDRESS` in localStorage (key: `inspectorConfig_v1`) to `location.origin`. This makes the React client fetch `/config` from the same origin instead of `:6277`.

2. **CLI args → `/config` endpoint** — The entrypoint passes `--transport streamable-http --server-url $MCP_SERVER_URL` to the Inspector. The proxy server exposes these via `GET /config` as `defaultTransport` and `defaultServerUrl`. The React client fetches this on mount and auto-fills the UI.

3. **nginx path routing** — All proxy routes (`/config`, `/mcp`, `/sse`, `/stdio`, `/message`, `/health`, `/sandbox`) are forwarded to 6277. The React UI at `/` comes from 6274.

---

## Full Request Flow

1. User navigates to `https://<inspector-fqdn>` (plain URL, no query params)
2. nginx serves the React HTML from port 6274
3. Injected `<script>` sets `MCP_PROXY_FULL_ADDRESS = location.origin` in localStorage
4. React initializes, reads proxy address from localStorage → same origin
5. React fetches `GET /config` → nginx proxies to 6277 → returns `{defaultTransport: "streamable-http", defaultServerUrl: "https://<dab-fqdn>/mcp"}`
6. `App.tsx` state setters fire: `setTransportType("streamable-http")`, `setSseUrl("https://<dab-fqdn>/mcp")`
7. UI auto-fills transport type and server URL
8. User clicks **Connect** → `POST /mcp` → nginx proxies to 6277 → proxy connects to DAB

---

## Dockerfile

```dockerfile
FROM node:22-alpine
RUN npm install -g @modelcontextprotocol/inspector@0.20.0
RUN apk add --no-cache nginx
COPY nginx.conf /etc/nginx/nginx.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENV DANGEROUSLY_OMIT_AUTH=true
ENV MCP_AUTO_OPEN_ENABLED=false
ENV HOST=0.0.0.0
EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]
```

---

## entrypoint.sh

```sh
#!/bin/sh
nginx
ARGS=""
if [ -n "$MCP_SERVER_URL" ]; then
  ARGS="--transport streamable-http --server-url $MCP_SERVER_URL"
fi
exec npx @modelcontextprotocol/inspector@0.20.0 $ARGS
```

---

## nginx.conf (same-origin proxy + auto-config)

```nginx
worker_processes 1;
events { worker_connections 1024; }
http {
  server {
    listen 80;

    # Proxy API routes → Inspector proxy server (port 6277)
    location = /config { proxy_pass http://127.0.0.1:6277; proxy_set_header Host $host; proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; proxy_set_header X-Forwarded-Proto $scheme; }
    location = /health { proxy_pass http://127.0.0.1:6277; proxy_set_header Host $host; }
    location = /sandbox { proxy_pass http://127.0.0.1:6277; proxy_set_header Host $host; }
    location = /message { proxy_pass http://127.0.0.1:6277; proxy_set_header Host $host; proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; proxy_set_header X-Forwarded-Proto $scheme; }
    location /mcp { proxy_pass http://127.0.0.1:6277; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; proxy_set_header X-Forwarded-Proto $scheme; proxy_buffering off; proxy_cache off; proxy_read_timeout 86400; }
    location /stdio { proxy_pass http://127.0.0.1:6277; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; proxy_set_header X-Forwarded-Proto $scheme; proxy_buffering off; proxy_cache off; proxy_read_timeout 86400; }
    location /sse { proxy_pass http://127.0.0.1:6277; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; proxy_set_header X-Forwarded-Proto $scheme; proxy_buffering off; proxy_cache off; proxy_read_timeout 86400; }

    # React UI with auto-config injection
    location / {
      proxy_pass http://127.0.0.1:6274;
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header Host $host;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_set_header Accept-Encoding "";
      sub_filter '</head>' '<script>(function(){var k="inspectorConfig_v1";try{var c=JSON.parse(localStorage.getItem(k)||"{}");if(!c.MCP_PROXY_FULL_ADDRESS||!c.MCP_PROXY_FULL_ADDRESS.value){c.MCP_PROXY_FULL_ADDRESS={value:location.origin,label:"MCP Proxy Full Address",description:"Full address of MCP proxy"};localStorage.setItem(k,JSON.stringify(c))}}catch(e){}})();</script></head>';
      sub_filter_once on;
    }
  }
}
```

**Key nginx details:**
- `proxy_set_header Accept-Encoding ""` disables upstream compression so `sub_filter` can modify the HTML response
- `sub_filter_once on` ensures the script is injected only once per page
- `/mcp`, `/stdio`, `/sse` need `proxy_http_version 1.1` + WebSocket upgrade headers for streaming
- `proxy_read_timeout 86400` (24h) prevents nginx from closing long-lived connections
- `proxy_buffering off` and `proxy_cache off` are essential for SSE/streaming responses

---

## Required Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `DANGEROUSLY_OMIT_AUTH` | `true` | Disable session token auth (safe behind Azure auth/network) |
| `MCP_AUTO_OPEN_ENABLED` | `false` | Don't try to open a browser inside the container |
| `HOST` | `0.0.0.0` | Bind to all interfaces (required in containers) |
| `MCP_SERVER_URL` | `https://<dab-fqdn>/mcp` | Passed as `--server-url` CLI arg → populates `/config` response |
| `ALLOWED_ORIGINS` | `https://<inspector-fqdn>` | DNS rebinding protection (origin validation middleware) |

---

## Bicep Resource Example

```bicep
var mcpInspectorName = 'mcp-inspector-${resourceToken}'
var mcpInspectorOrigin = 'https://${mcpInspectorName}.${cae.properties.defaultDomain}'

resource mcpInspector 'Microsoft.App/containerApps@2024-03-01' = {
  name: mcpInspectorName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: cae.id
    configuration: {
      ingress: { external: true, targetPort: 80 }
      registries: [{ server: acr.properties.loginServer, username: acr.listCredentials().username, passwordSecretRef: 'acr-password' }]
      secrets: [{ name: 'acr-password', value: acr.listCredentials().passwords[0].value }]
    }
    template: {
      containers: [{
        name: 'mcp-inspector'
        image: '${acr.properties.loginServer}/mcp-inspector:latest'
        resources: { cpu: json('0.5'), memory: '1Gi' }
        env: [
          { name: 'DANGEROUSLY_OMIT_AUTH', value: 'true' }
          { name: 'MCP_AUTO_OPEN_ENABLED', value: 'false' }
          { name: 'HOST', value: '0.0.0.0' }
          { name: 'MCP_SERVER_URL', value: 'https://${dabApp.properties.configuration.ingress.fqdn}/mcp' }
          { name: 'ALLOWED_ORIGINS', value: mcpInspectorOrigin }
        ]
      }]
      scale: { minReplicas: 0, maxReplicas: 1 }
    }
  }
}
```

---

## Building and Pushing the Image

```powershell
# Create ACR (if not exists)
az acr create --name <acr-name> --resource-group <rg> --sku Basic --admin-enabled true

# Build and push from the inspector/ directory
az acr build --registry <acr-name> --image mcp-inspector:latest ./inspector/
```

---

## Alternative: Query Param Fallback

If you cannot modify the Docker image (e.g., using a prebuilt Inspector image with a simple `/proxy/` nginx config), you can still preconfigure via query params:

```
https://<inspector-fqdn>/?transport=streamable-http&serverUrl=https://<dab-fqdn>/mcp&MCP_PROXY_FULL_ADDRESS=https://<inspector-fqdn>/proxy
```

This works but produces an unwieldy URL. The same-origin approach above is preferred.

---

## Common Issues and Fixes

### Inspector UI shows but can't reach proxy
**Cause:** `MCP_PROXY_FULL_ADDRESS` not set — client tries port 6277 directly.
**Fix:** The nginx `sub_filter` injection handles this automatically. Verify the `location /` block includes the `sub_filter` directive.

### `/config` returns STDIO defaults
**Cause:** `MCP_SERVER_URL` env var not set, so entrypoint doesn't pass `--transport` or `--server-url`.
**Fix:** Set `MCP_SERVER_URL` in Bicep env vars.

### Connection timeout after clicking Connect
**Cause:** DAB `/mcp` endpoint not reachable from the Inspector container.
**Fix:** Verify DAB ingress is `external: true` and the FQDN in `MCP_SERVER_URL` is correct. Test with `curl https://<dab-fqdn>/health` from the container.

### nginx 502 Bad Gateway
**Cause:** Inspector processes haven't started yet when nginx tries to proxy.
**Fix:** The entrypoint starts nginx first, then the Inspector. Brief 502s during startup are normal — wait a few seconds and retry.

---

## Prerequisites

- Azure Container Registry (ACR) for the custom image
- Azure Container Apps Environment
- DAB deployed and accessible (for the MCP server URL)
- Inspector files: `Dockerfile`, `entrypoint.sh`, `nginx.conf` in an `inspector/` directory
