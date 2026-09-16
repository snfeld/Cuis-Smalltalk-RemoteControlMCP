# RemoteControlMCP – Usage Guide (English)

This guide describes how to load, start and use **RemoteControlMCP**.
Other languages: [Deutsch](Anleitung.md), [Español](Anleitung-ES.md), [Français](Anleitung-FR.md),
[中文](Anleitung-ZH.md), [日本語](Anleitung-JA.md).

## 1. Overview

`RemoteControlMCP` is a Model Context Protocol server (specification `2025-06-18`) that exposes a
running Cuis-Smalltalk image to LLMs and agents over **Streamable HTTP** (JSON-RPC 2.0). It provides
eleven tools (evaluate code, compile methods, screenshots, introspection, method source and selector
usage), one resource (`image://status`) and one prompt (`develop-in-cuis`).

**The package is self-contained** – it builds on `WebClient` (WebServer, WebUtils JSON) and
`Graphics-Files-Additional` (PNGReadWriter for screenshots) and needs **no** separate JSON package and
no `RemoteControl` bridge.

## 2. Installation

Requirements: Cuis 7.8 with the packages **WebClient** and **Graphics-Files-Additional**.
The file `RemoteControlMCP.pck.st` declares these dependencies via `!requires:`; an interactive
file-in resolves them automatically in the correct order.

Load the package into the image:

```smalltalk
ChangeSet fileIn: '/workspace/RemoteControlMCP-clean/packages/RemoteControlMCP.pck.st' asFileEntry.
ChangeSet fileIn: '/workspace/RemoteControlMCP-clean/packages/Tests-RemoteControlMCP.pck.st' asFileEntry.  "optional: tests"
```

The package also includes the fix for the WebUtils JSON parser (`jsonMapFrom:` swallowed following
keys after an empty `{}`). The fix ships inside the main package; it is additionally available as a
standalone file under `packages/WebUtils-jsonMapFrom-Fix.pck.st`.

Alternatively use the GUI: **Open… → Package Manager → Install**, then pick the `.pck.st` files.

## 3. Starting and Stopping

### Quick start (default instance, port 2357, loopback only, no authentication)

```smalltalk
RemoteControlMCP start.        "starts the default instance and answers it"
RemoteControlMCP stop.         "stops it again"
```

### Custom instance with configuration

```smalltalk
| server |
server := RemoteControlMCP new.
server port: 2357.                       "port, default 2357"
server interfaceAddress: '127.0.0.1'.    "bind address, default loopback"
server token: 'my-secret-token'.         "bearer token; nil disables auth"
server evalTimeout: 30.                  "sync eval timeout in seconds, default 30"
server start.
```

Check status: `server isRunning` (true/false). Stop: `server stop`. Restart: `server restart`.

## 4. Configuration

| Method | Default | Meaning |
|--------|---------|---------|
| `port:` | `2357` | TCP port (`defaultPort` in the class method) |
| `interfaceAddress:` | `'127.0.0.1'` | Network interface to bind to |
| `token:` | `nil` (no auth) | Optional bearer token; without/`nil` no authentication |
| `evalTimeout:` | `30` | Timeout for synchronous evals, in seconds |
| `endpointPath:` | `'/mcp'` | HTTP path of the MCP endpoint |
| `corsAllowedOrigin:` | `nil` (no CORS) | Allowed CORS origin for browser clients (e.g. `'*'` or `'http://localhost:8080'`); enables CORS headers + OPTIONS preflight (see 5.1) |
| `tlsCertificateFile:` | `nil` (no TLS) | Path to a PEM file containing certificate + private key; when set, the server serves HTTPS only (see 5.2) |

## 5. Endpoint and Authentication

- URL: `POST http://127.0.0.1:2357/mcp` (adjust port/path as configured)
- Content-Type: `application/json`
- If a token is set, every request must send:
  `Authorization: Bearer <token>`
- Missing or wrong token results in HTTP `401`.

### 5.1 CORS for browser access

MCP clients running in a browser (e.g. a web-based MCP tool accessing via `fetch` from a web page)
need CORS headers from the server – otherwise the browser blocks the response with a `CORS error`.
CORS headers are **disabled by default**. Enable them via `corsAllowedOrigin:`:

```smalltalk
server corsAllowedOrigin: '*'.                       "allow all origins"
"or a specific origin:"
server corsAllowedOrigin: 'http://localhost:8080'.
```

Once an origin is configured, the server answers OPTIONS preflight requests and adds the headers
`Access-Control-Allow-Origin`, `-Allow-Methods: POST, OPTIONS`, `-Allow-Headers: Content-Type,
Authorization` and `Access-Control-Max-Age: 86400` to all responses.

**Security:** With `corsAllowedOrigin: '*'` and no token, any web page you open in the browser can
run arbitrary Smalltalk in the image. Therefore with `'*'` always use a bearer token and/or keep the
server bound to `127.0.0.1`. A concrete origin is safer than `'*'`.

### 5.2 HTTPS/TLS

By default the server speaks **HTTP** (no TLS). For encrypted connections set `tlsCertificateFile:`
to the path of a PEM file that contains both the certificate **and** the private key. Once set, the
server only accepts HTTPS connections.

**Quick start without OpenSSL:** A ready-made, self-signed example certificate (valid 100 years)
ships in `packages/example-cert/server.pem` – just use it:

```smalltalk
server tlsCertificateFile: 'packages/example-cert/server.pem'.
server start.
```

Or generate a certificate with OpenSSL (self-signed, for local/testing purposes):

```bash
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes \
  -subj '/CN=localhost'
cat cert.pem key.pem > server.pem
```

Enable it:

```smalltalk
server tlsCertificateFile: '/path/to/server.pem'.
server start.
```

The endpoint then is `https://127.0.0.1:2357/mcp`.

**Notes:**
- The bundled `packages/example-cert/server.pem` is for **local testing** only and intentionally
  shipped. Self-generated certificates contain the private key and must **not** be committed to a
  repository – store them readable only by the server process (e.g. `chmod 600`).
- Self-signed certificates are not accepted by clients without trust-store configuration. For
  production use a certificate from a real CA (e.g. Let's Encrypt).
- Without `tlsCertificateFile:` the server stays on plain HTTP – development and existing
  configurations are unaffected.
- `curl -k` (skip verification) or `curl --cacert server.pem` (trust the self-signed file).

## 6. Usage with curl

The MCP lifecycle always starts with `initialize`, followed by the notification
`notifications/initialized`. After that all tools, resources and prompts are available.

### 6.1 initialize

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize",
       "params":{"protocolVersion":"2025-06-18","capabilities":{},
                 "clientInfo":{"name":"curl","version":"1.0"}}}'
```

Response (abridged):

```json
{"jsonrpc":"2.0","id":1,"result":{
  "protocolVersion":"2025-06-18",
  "capabilities":{"tools":{"listChanged":true},
                  "resources":{"listChanged":true},
                  "prompts":{"listChanged":true}},
  "serverInfo":{"name":"RemoteControlMCP","version":"0.1"},
  "instructions":"Use tools/eval ..."}}
```

### 6.2 initialized notification and ping

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'   # empty 200 response
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":2,"method":"ping"}'                              # {"result":{}}
```

### 6.3 tools/list

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}'
```

### 6.4 tools/call – eval (synchronous)

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":4,"method":"tools/call",
       "params":{"name":"eval","arguments":{"source":"7 * 8"}}}'
```

Response:

```json
{"jsonrpc":"2.0","id":4,"result":{"content":[{"text":"56","type":"text"}]}}
```

Optional arguments: `timeout` (seconds) and `async`. A failing evaluation (e.g. `1/0`) is answered
with `isError: true` and an error message.

### 6.5 tools/call – eval (asynchronous, job polling)

For long evaluations pass `"async":true`. The response returns an immediate `jobId`.

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":5,"method":"tools/call",
       "params":{"name":"eval","arguments":{"source":"[1 to: 1000000 do:[:i| i*i]] value. 42","async":true}}}'
# {"result":{"content":[{"text":"{\"jobId\": \"job-2\", \"status\": \"running\"}","type":"text"}]}}

curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":6,"method":"tools/call",
       "params":{"name":"eval_status","arguments":{"jobId":"job-2"}}}'
```

While the job runs: `{"jobId":"job-2","status":"running"}` – afterwards:

```json
{"jsonrpc":"2.0","id":6,"result":{"content":[
  {"text":"{\"jobId\": \"job-2\", \"status\": \"done\", \"result\": \"42\", \"error\": \"\"}","type":"text"}]}}
```

If a job exceeds its timeout, a watchdog terminates it and `eval_status` reports
`"status":"timeout"`.

### 6.6 tools/call – eval_cancel (cancel a job)

A running job (async or still running after a sync timeout) can be terminated with `eval_cancel`:

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":7,"method":"tools/call",
       "params":{"name":"eval_cancel","arguments":{"jobId":"job-2"}}}'
```

Response: the job's final status as JSON text. A running job is terminated and answered with
`{"jobId":"job-2","status":"cancelled"}`; a finished job keeps its final status. Afterwards the job is
removed from the registry.

### 6.7 tools/call – compile_method

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":8,"method":"tools/call",
       "params":{"name":"compile_method",
                 "arguments":{"className":"DocExample","source":"greeting\n\t^ 40 + 2","category":"accessing"}}}'
```

Response: the compiled selector name (`"greeting"`). Optional arguments: `isClassSide` (true/false),
`category` (default `as yet unclassified`). Note: this permanently modifies the running image.

Shell-quoting tip: if the method source contains a Smalltalk string literal, writing it directly inside
`curl -d '…'` is error-prone (the two single quotes of the Smalltalk string clash with the shell
quoting). A payload file is cleaner:

```bash
cat > /tmp/compile.json <<'EOF'
{"jsonrpc":"2.0","id":8,"method":"tools/call",
 "params":{"name":"compile_method",
           "arguments":{"className":"DocExample","source":"greeting\n\t^ 'Hello!'","category":"accessing"}}}
EOF
curl -s -X POST http://127.0.0.1:2357/mcp --data @/tmp/compile.json
```

### 6.8 tools/call – screenshot

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":9,"method":"tools/call",
       "params":{"name":"screenshot","arguments":{}}}'
```

Response: `content[0].data` holds the base64-encoded PNG (`"type":"image"`,
`"mimeType":"image/png"`). Optionally crop to a morph class: `{"morph":"SystemWindow","pad":8}`.

### 6.9 tools/call – method_source

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":10,"method":"tools/call",
       "params":{"name":"method_source","arguments":{"className":"RemoteControlMCP","selector":"serverVersion"}}}'
```

Response: `Class >> selector`, category and source code. With `"includeSuperclasses":true` the nearest
defining class in the ancestry is named if the class itself does not define the method.

### 6.10 tools/call – selector_usage

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":11,"method":"tools/call",
       "params":{"name":"selector_usage","arguments":{"selector":"serverVersion"}}}'
```

Response: who implements and who sends the selector, one `Class >> selector` line per entry.

### 6.11 tools/call – introspection

```bash
# All classes (one per line)
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"list_classes","arguments":{}}}'

# Class hierarchy (ancestry + indented descendant tree)
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"class_hierarchy","arguments":{"className":"RemoteControlMCP"}}}'

# Summary of a class
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"class_summary","arguments":{"name":"RemoteControlMCP"}}}'

# Image status
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":15,"method":"tools/call","params":{"name":"image_status","arguments":{}}}'
```

### 6.12 Prompts

```bash
curl -s -X POST http://127.0.0.1:2357/mcp -d '{"jsonrpc":"2.0","id":16,"method":"prompts/list","params":{}}'
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":17,"method":"prompts/get","params":{"name":"develop-in-cuis"}}'
```

### 6.13 Resources

```bash
curl -s -X POST http://127.0.0.1:2357/mcp -d '{"jsonrpc":"2.0","id":18,"method":"resources/list","params":{}}'
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":19,"method":"resources/read","params":{"uri":"image://status"}}'
```

## 7. Error and status codes

| HTTP | Meaning |
|------|---------|
| `200` | JSON-RPC response (also an empty response for notifications) |
| `401` | Missing or wrong token |
| `405` | Wrong HTTP method (POST only) |

| JSON-RPC code | Meaning |
|---------------|---------|
| `-32700` | Parse error (not valid JSON) |
| `-32600` | Invalid Request |
| `-32601` | Method not found |
| `-32602` | Invalid params |
| `-32603` | Internal error |

## 8. Usage from an MCP client

Example configuration for an MCP HTTP client (e.g. Claude Desktop):

```json
{
  "mcpServers": {
    "cuis": {
      "type": "http",
      "url": "http://127.0.0.1:2357/mcp",
      "headers": { "Authorization": "Bearer my-secret-token" }
    }
  }
}
```

Without a token, omit the `headers` entry. The client performs `initialize` itself and can then call
`tools/call`, `prompts/get` and `resources/read`.

### OpenCode

OpenCode connects via a remote MCP server. Add the server to `opencode.json` in the project directory
(or globally in `~/.config/opencode/opencode.json`):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "cuis": {
      "type": "remote",
      "url": "http://127.0.0.1:2357/mcp",
      "enabled": true,
      "headers": { "Authorization": "Bearer my-secret-token" }
    }
  }
}
```

Notes:

- `type` must be `"remote"` (only HTTP/Streamable-HTTP servers are supported; a `command` entry is only
  valid for local stdio servers).
- Without a token, omit the `headers` entry. Values support the `{env:VAR}` and `{file:path}`
  placeholders, e.g. `"Authorization": "Bearer {env:CUIS_MCP_TOKEN}"`.
- The configuration is loaded only when opencode starts – restart opencode after changing it.
- After the restart the server (e.g. `/mcp`) appears in the tool namespace and the tools
  `eval`, `compile_method`, `screenshot` etc. are available to agents.

### llama.cpp (WebUI) as MCP client

The `llama-server` WebUI ships with a built-in MCP client where you can register RemoteControlMCP as
an MCP server. The MCP client runs **in the browser** – the requests originate from the page the
browser loaded from `llama-server`. If the browser reaches RemoteControlMCP from a different origin,
the CORS rule applies (see section 5.1).

**Scenario:** machine A runs `llama.cpp` as a server (WebUI at `http://<machine-A>:8080`). Machine B
opens the WebUI in a browser and also runs RemoteControlMCP (`http://127.0.0.1:2357/mcp`). The browser
loads the WebUI from A, but the MCP requests target the server on B – a cross-origin request.

**Option 1 – direct connection (recommended, CORS in RemoteControlMCP):**

1. Start RemoteControlMCP with CORS enabled (section 5.1), e.g.:

   ```smalltalk
   server := RemoteControlMCP new.
   server port: 2357.
   server token: 'my-secret-token'.                             "mandatory with '*'"
   server corsAllowedOrigin: '*'.                               "or: http://<machine-A>:8080"
   server start.
   ```

2. In the WebUI under **MCP Servers**, add a server: URL `http://127.0.0.1:2357/mcp`, transport
   **Streamable HTTP** (default).

3. Do **not** enable the **"use llama-server proxy"** toggle (only for option 2).

**Option 2 – via the llama.cpp CORS proxy:**

1. Start `llama-server` on machine A with `--ui-mcp-proxy` (experimental, trusted networks only). The
   browser then only talks to the llama-server (no more CORS issues); the llama-server forwards the
   MCP requests to RemoteControlMCP.
2. In the WebUI, enable the **"use llama-server proxy"** toggle for the MCP server. The toggle only
   appears when editing an already-created server.
3. Prerequisite: the llama-server (machine A) must be able to reach RemoteControlMCP. If
   RemoteControlMCP binds only to `127.0.0.1` (default), the proxy option only works when both run on
   the same machine. Otherwise bind to a reachable interface and set a token.

Notes:

- **Use `127.0.0.1` instead of `localhost`:** several users report connections that fail with
  `localhost` but succeed with `127.0.0.1`. Keep both forms consistent.
- `--webui-mcp-proxy` is the old (deprecated) spelling of `--ui-mcp-proxy`.
- The WebUI client transport order is: WebSocket (if explicitly configured) → Streamable HTTP
  (default) → SSE (fallback). RemoteControlMCP speaks Streamable HTTP.
- The CORS proxy is experimental: **do not enable in untrusted environments**.
- Details and current options: `tools/server/README.md` in the llama.cpp repository.

## 9. Tool overview

| Tool | Parameters (required) | Optional parameters | Response |
|------|-----------------------|---------------------|----------|
| `eval` | `source` | `timeout`, `async` | result (sync) or `jobId` (async) |
| `eval_status` | `jobId` | – | status/result of an async job |
| `eval_cancel` | `jobId` | – | cancels a job; final job status |
| `compile_method` | `className`, `source` | `isClassSide`, `category` | compiled selector name |
| `screenshot` | – | `morph`, `pad` | base64 PNG (`type: image`) |
| `list_classes` | – | – | class list (one per line) |
| `class_summary` | `name` | – | JSON summary of the class |
| `class_hierarchy` | `className` | – | ancestry + descendant tree |
| `method_source` | `className`, `selector` | `includeSuperclasses` | method source code |
| `selector_usage` | `selector` | – | implementors/senders, `Class >> selector` |
| `image_status` | – | – | JSON status of the image |

## 10. Notes

- Evals run as separate processes with a priority below the HTTP handler; a watchdog terminates
  overdue jobs after `evalTimeout`. The HTTP server stays responsive even during long evals.
- For long evals use `async: true` and fetch the result via `eval_status`; running jobs can be
  cancelled with `eval_cancel`.
- `compile_method` and `eval` modify the running image. Use `Image save` to persist changes, or take a
  snapshot first.
- The server binds to `127.0.0.1` by default – to reach it from other machines change
  `interfaceAddress:` accordingly (and set a token!).
- CORS is disabled by default. For browser clients set `corsAllowedOrigin:` – with `'*'` always use a
  bearer token (see 5.1).
- The package is self-contained without a `RemoteControl` bridge and without a separate JSON package;
  only `WebClient` and `Graphics-Files-Additional` (both from the Cuis 7.8 distribution) are required.
