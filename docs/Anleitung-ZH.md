# RemoteControlMCP – 使用指南（中文）

本指南介绍如何加载、启动和使用 **RemoteControlMCP**。德文版见 [Anleitung.md](Anleitung.md)，
英文版见 [Anleitung-EN.md](Anleitung-EN.md)，西班牙文版见 [Anleitung-ES.md](Anleitung-ES.md)，
法文版见 [Anleitung-FR.md](Anleitung-FR.md)，日文版见 [Anleitung-JA.md](Anleitung-JA.md)。

## 1. 概述

`RemoteControlMCP` 是一个模型上下文协议（MCP）服务器（规范 `2025-06-18`），通过
**流式 HTTP**（Streamable HTTP，JSON-RPC 2.0）将运行中的 Cuis-Smalltalk 镜像开放给大语言模型
和智能体使用。它提供十一个工具（执行代码、编译方法、截屏、内省、方法源码与选择符用法）、一个
资源（`image://status`）和一个提示词（`develop-in-cuis`）。

**该包完全自包含**——它基于 `WebClient`（WebServer、WebUtils JSON）和
`Graphics-Files-Additional`（用于截屏的 PNGReadWriter），**无需**单独的 JSON 包，也不需要
`RemoteControl` 桥。

## 2. 安装

前置条件：Cuis 7.8 及包 **WebClient** 和 **Graphics-Files-Additional**（文件
`RemoteControlMCP.pck.st` 通过 `!requires:` 声明了这些依赖；交互式 file-in 会自动按正确顺序加载）。

在镜像中读取包：

```smalltalk
ChangeSet fileIn: '/workspace/RemoteControlMCP-clean/packages/RemoteControlMCP.pck.st' asFileEntry.
ChangeSet fileIn: '/workspace/RemoteControlMCP-clean/packages/Tests-RemoteControlMCP.pck.st' asFileEntry.  "可选：测试"
```

该包还包含 WebUtils JSON 解析器的修复（`jsonMapFrom:` 在空对象 `{}` 之后吞掉了后续键）。修复已内置
在主包中；此外也可作为独立文件使用，位于 `packages/WebUtils-jsonMapFrom-Fix.pck.st`。

或者通过图形界面：**Open… → Package Manager → Install**，选择 `.pck.st` 文件。

## 3. 启动与停止

### 快速启动（默认实例，端口 2357，仅限 localhost，无认证）

```smalltalk
RemoteControlMCP start.        "启动默认实例并返回它"
RemoteControlMCP stop.         "再次停止它"
```

### 带配置的自建实例

```smalltalk
| server |
server := RemoteControlMCP new.
server port: 2357.                       "端口，默认 2357"
server interfaceAddress: '127.0.0.1'.    "绑定地址，默认回环地址"
server token: '我的机密令牌'.             "bearer 令牌；nil 关闭认证"
server evalTimeout: 30.                  "同步 eval 超时（秒），默认 30"
server start.
```

检查状态：`server isRunning`（true/false）。停止：`server stop`。重启：`server restart`。

## 4. 配置

| 方法 | 默认值 | 含义 |
|------|--------|------|
| `port:` | `2357` | TCP 端口（类方法中的 `defaultPort`） |
| `interfaceAddress:` | `'127.0.0.1'` | 绑定到的网络接口 |
| `token:` | `nil`（无认证） | 可选的 bearer 令牌；无/`nil` 表示不认证 |
| `evalTimeout:` | `30` | 同步 eval 的超时（秒） |
| `endpointPath:` | `'/mcp'` | MCP 端点的 HTTP 路径 |
| `corsAllowedOrigin:` | `nil`（无 CORS） | 允许的浏览器客户端 CORS 来源（如 `'*'` 或 `'http://localhost:8080'`）；启用 CORS 头 + OPTIONS 预检（见 5.1） |
| `tlsCertificateFile:` | `nil`（无 TLS） | 包含证书 + 私钥的 PEM 文件路径；设置后服务器仅通过 HTTPS 服务（见 5.2） |

## 5. 端点与认证

- URL：`POST http://127.0.0.1:2357/mcp`（按配置调整端口/路径）
- Content-Type：`application/json`
- 如果设置了令牌，每个请求都必须发送：
  `Authorization: Bearer <token>`
- 缺少或错误的令牌 → 服务器返回 HTTP `401`。

### 5.1 浏览器访问的 CORS

在浏览器中运行的 MCP 客户端（例如通过 `fetch` 从网页访问的基于 Web 的 MCP 工具）需要服务器的
CORS 头——否则浏览器会以 `CORS 错误` 阻止响应。默认情况下 CORS 头**已禁用**。通过
`corsAllowedOrigin:` 启用：

```smalltalk
server corsAllowedOrigin: '*'.                       "允许所有来源"
"或者只允许某个具体来源："
server corsAllowedOrigin: 'http://localhost:8080'.
```

配置了来源后，服务器会应答 OPTIONS 预检请求，并在所有响应中加入 `Access-Control-Allow-Origin`、
`-Allow-Methods: POST, OPTIONS`、`-Allow-Headers: Content-Type, Authorization` 和
`Access-Control-Max-Age: 86400` 这些头。

**安全：** 使用 `corsAllowedOrigin: '*'` 且无令牌时，您在浏览器中打开的任何网页都可以在镜像中
执行任意 Smalltalk 代码。因此使用 `'*'` 时务必设置 bearer 令牌，并/或将服务器继续绑定到
`127.0.0.1`。具体来源比 `'*'` 更安全。

### 5.2 HTTPS/TLS

默认情况下服务器使用 **HTTP**（无 TLS）。如需加密连接，将 `tlsCertificateFile:` 设置为包含证书
**和**私钥的 PEM 文件路径。一旦设置，服务器将只接受 HTTPS 连接。

**无需 OpenSSL 的快速开始：** 仓库自带一个现成的自签名示例证书（有效期 100 年），位于
`packages/example-cert/server.pem`，直接这样使用：

```smalltalk
server tlsCertificateFile: 'packages/example-cert/server.pem'.
server start.
```

或者自行用 OpenSSL 生成证书（自签名，用于本地/测试）：

```bash
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes \
  -subj '/CN=localhost'
cat cert.pem key.pem > server.pem
```

启用：

```smalltalk
server tlsCertificateFile: '/路径/server.pem'.
server start.
```

端点随后为 `https://127.0.0.1:2357/mcp`。

**说明：**
- 随附的 `packages/example-cert/server.pem` 仅供**本地测试**，是有意提供的。自建证书因包含私钥，
  **不应**提交到仓库——请仅让服务器进程可读（例如 `chmod 600`）。
- 未配置信任锚的客户端不会将自签名证书视为有效。生产环境请使用真实 CA（例如 Let's Encrypt）
  的证书。
- 不设置 `tlsCertificateFile:` 时服务器保持 HTTP——开发和现有配置不受影响。
- `curl -k`（跳过验证）或 `curl --cacert server.pem`（信任该自签名文件）。

## 6. 使用 curl

MCP 生命周期总是以 `initialize` 开始，随后是通知 `notifications/initialized`。此后所有工具、
资源和提示词才可用。

### 6.1 initialize

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize",
       "params":{"protocolVersion":"2025-06-18","capabilities":{},
                 "clientInfo":{"name":"curl","version":"1.0"}}}'
```

响应（节选）：

```json
{"jsonrpc":"2.0","id":1,"result":{
  "protocolVersion":"2025-06-18",
  "capabilities":{"tools":{"listChanged":true},
                  "resources":{"listChanged":true},
                  "prompts":{"listChanged":true}},
  "serverInfo":{"name":"RemoteControlMCP","version":"0.1"},
  "instructions":"Use tools/eval ..."}}
```

### 6.2 initialized 通知和 ping

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'   # 空 200 响应
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":2,"method":"ping"}'                              # {"result":{}}
```

### 6.3 tools/list

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}'
```

### 6.4 tools/call – eval（同步）

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":4,"method":"tools/call",
       "params":{"name":"eval","arguments":{"source":"7 * 8"}}}'
```

响应：

```json
{"jsonrpc":"2.0","id":4,"result":{"content":[{"text":"56","type":"text"}]}}
```

可选参数：`timeout`（秒）和 `async`。出错的计算（如 `1/0`）会以 `isError: true` 和错误信息响应。

### 6.5 tools/call – eval（异步，任务轮询）

用 `"async":true` 启动长耗时计算。响应：立即返回 `jobId`。

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":5,"method":"tools/call",
       "params":{"name":"eval","arguments":{"source":"[1 to: 1000000 do:[:i| i*i]] value. 42","async":true}}}'
# {"result":{"content":[{"text":"{\"jobId\": \"job-2\", \"status\": \"running\"}","type":"text"}]}}

curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":6,"method":"tools/call",
       "params":{"name":"eval_status","arguments":{"jobId":"job-2"}}}'
```

任务运行期间：`{"jobId":"job-2","status":"running"}`——之后：

```json
{"jsonrpc":"2.0","id":6,"result":{"content":[
  {"text":"{\"jobId\": \"job-2\", \"status\": \"done\", \"result\": \"42\", \"error\": \"\"}","type":"text"}]}}
```

如果任务超过其超时时间，看门狗会终止它，`eval_status` 报告 `"status":"timeout"`。

### 6.6 tools/call – eval_cancel（取消任务）

正在运行的任务（异步任务，或同步超时后仍在运行的任务）可以用 `eval_cancel` 终止：

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":7,"method":"tools/call",
       "params":{"name":"eval_cancel","arguments":{"jobId":"job-2"}}}'
```

响应：任务的最终状态（JSON 文本）。运行中的任务被终止并回复 `{"jobId":"job-2","status":"cancelled"}`；
已结束的任务保持其最终状态。之后该任务被从注册表中移除。

### 6.7 tools/call – compile_method

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":8,"method":"tools/call",
       "params":{"name":"compile_method",
                 "arguments":{"className":"DocExample","source":"greeting\n\t^ 40 + 2","category":"accessing"}}}'
```

响应：编译后的选择器名（`"greeting"`）。可选参数：`isClassSide`（true/false）、`category`
（默认 `as yet unclassified`）。注意：这会永久修改正在运行的镜像。

关于 shell 引号的提示：如果方法源码要包含 Smalltalk 字符串字面量，直接在 `curl -d '…'` 中写容易出错
（Smalltalk 字符串的两个单引号与 shell 的引号冲突）。更干净的做法是使用 payload 文件：

```bash
cat > /tmp/compile.json <<'EOF'
{"jsonrpc":"2.0","id":8,"method":"tools/call",
 "params":{"name":"compile_method",
           "arguments":{"className":"DocExample","source":"greeting\n\t^ '你好！'","category":"accessing"}}}
EOF
curl -s -X POST http://127.0.0.1:2357/mcp --data @/tmp/compile.json
```

### 6.8 tools/call – screenshot

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":9,"method":"tools/call",
       "params":{"name":"screenshot","arguments":{}}}'
```

响应：`content[0].data` 包含 Base64 编码的 PNG 数据（`"type":"image"`、`"mimeType":"image/png"`）。
可选裁剪到某个 morph 类：`{"morph":"SystemWindow","pad":8}`。

### 6.9 tools/call – method_source

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":10,"method":"tools/call",
       "params":{"name":"method_source","arguments":{"className":"RemoteControlMCP","selector":"serverVersion"}}}'
```

响应：`Class >> selector`、类别和源码。使用 `"includeSuperclasses":true` 时，如果该类未定义该选择符，
则注明继承链中最近的定义类。

### 6.10 tools/call – selector_usage

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":11,"method":"tools/call",
       "params":{"name":"selector_usage","arguments":{"selector":"serverVersion"}}}'
```

响应：谁实现、谁发送该选择符，每个条目一行 `Class >> selector`。

### 6.11 tools/call – 内省

```bash
# 所有类（每行一个）
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"list_classes","arguments":{}}}'

# 某个类的类层次（祖先 + 缩进的子类树）
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"class_hierarchy","arguments":{"className":"RemoteControlMCP"}}}'

# 某个类的摘要
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"class_summary","arguments":{"name":"RemoteControlMCP"}}}'

# 镜像状态
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":15,"method":"tools/call","params":{"name":"image_status","arguments":{}}}'
```

### 6.12 提示词

```bash
curl -s -X POST http://127.0.0.1:2357/mcp -d '{"jsonrpc":"2.0","id":16,"method":"prompts/list","params":{}}'
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":17,"method":"prompts/get","params":{"name":"develop-in-cuis"}}'
```

### 6.13 资源

```bash
curl -s -X POST http://127.0.0.1:2357/mcp -d '{"jsonrpc":"2.0","id":18,"method":"resources/list","params":{}}'
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":19,"method":"resources/read","params":{"uri":"image://status"}}'
```

## 7. 错误码与状态码

| HTTP | 含义 |
|------|------|
| `200` | JSON-RPC 响应（通知也返回空响应） |
| `401` | 令牌缺失或错误 |
| `405` | HTTP 方法错误（仅 POST） |

| JSON-RPC 代码 | 含义 |
|---------------|------|
| `-32700` | 解析错误（无效 JSON） |
| `-32600` | 无效请求 |
| `-32601` | 方法未找到 |
| `-32602` | 参数无效 |
| `-32603` | 内部错误 |

## 8. 从 MCP 客户端使用

MCP HTTP 客户端（例如 Claude Desktop）的示例配置：

```json
{
  "mcpServers": {
    "cuis": {
      "type": "http",
      "url": "http://127.0.0.1:2357/mcp",
      "headers": { "Authorization": "Bearer 我的机密令牌" }
    }
  }
}
```

无令牌时省略 `headers` 项。客户端自行执行 `initialize`，然后即可调用 `tools/call`、
`prompts/get` 和 `resources/read`。

### OpenCode

OpenCode 通过远程（remote）MCP 服务器连接。请在项目目录的 `opencode.json` 文件（或全局的
`~/.config/opencode/opencode.json`）中登记服务器：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "cuis": {
      "type": "remote",
      "url": "http://127.0.0.1:2357/mcp",
      "enabled": true,
      "headers": { "Authorization": "Bearer 我的机密令牌" }
    }
  }
}
```

说明：

- `type` 必须为 `"remote"`（仅支持 HTTP/流式 HTTP 服务器；`command` 项仅对本地 stdio 服务器有效）。
- 无令牌时省略 `headers` 项。值支持占位符 `{env:VAR}` 和 `{file:路径}`，例如
  `"Authorization": "Bearer {env:CUIS_MCP_TOKEN}"`。
- 配置仅在 OpenCode 启动时加载——修改后必须重启 OpenCode。
- 重启后，服务器（例如 `/mcp`）会出现在工具命名空间中，`eval`、`compile_method`、`screenshot`
  等工具在智能体中可用。

### llama.cpp（WebUI）作为 MCP 客户端

`llama-server` 的 WebUI 带有内置的 MCP 客户端，您可以将 RemoteControlMCP 注册为 MCP 服务器。
MCP 客户端**在浏览器中**运行——因此请求从浏览器加载 `llama-server` 网页的位置发起。如果浏览器从
其他来源访问 RemoteControlMCP，则适用 CORS 规则（见第 5.1 节）。

**场景：** 计算机 A 运行 `llama.cpp` 作为服务器（WebUI 在 `http://<计算机A>:8080`）。
计算机 B 在浏览器中打开 WebUI，同时运行 RemoteControlMCP（`http://127.0.0.1:2357/mcp`）。
浏览器加载来自 A 的 WebUI，但 MCP 请求指向 B 上的服务器——这是一个跨源请求。

**方案 1 – 直接连接（推荐，CORS 在 RemoteControlMCP 中）：**

1. 启用 CORS 后启动 RemoteControlMCP（第 5.1 节），例如：

   ```smalltalk
   server := RemoteControlMCP new.
   server port: 2357.
   server token: '我的机密令牌'.                          "使用 '*' 时必须设置"
   server corsAllowedOrigin: '*'.                        "或：http://<计算机A>:8080"
   server start.
   ```

2. 在 WebUI 的 **MCP Servers** 中添加一个服务器：URL `http://127.0.0.1:2357/mcp`，传输方式
   **Streamable HTTP**（标准）。

3. **不要**开启 **“use llama-server proxy”** 开关（仅用于方案 2）。

**方案 2 – 通过 llama.cpp 的 CORS 代理：**

1. 在计算机 A 上用 `--ui-mcp-proxy` 启动 `llama-server`（实验性，仅限可信网络）。浏览器随后只与
   llama-server 通信（不再有 CORS 问题）；llama-server 将 MCP 请求转发给 RemoteControlMCP。
2. 在 WebUI 中为 MCP 服务器开启 **“use llama-server proxy”** 开关。该开关只有在编辑已创建的服务器时
   才会出现。
3. 前提：`llama-server`（计算机 A）必须能访问 RemoteControlMCP。如果 RemoteControlMCP 只绑定
   `127.0.0.1`（默认），则代理方案只有在两者运行于同一台机器时才有效。否则请绑定到可达的接口并
   设置令牌。

说明：

- **使用 `127.0.0.1` 而不是 `localhost`：** 多位用户反馈使用 `localhost` 会连接失败，而使用
  `127.0.0.1` 可以。请保持两处写法一致。
- `--webui-mcp-proxy` 是 `--ui-mcp-proxy` 的旧（已废弃）写法。
- WebUI 客户端的传输顺序：WebSocket（如果显式配置）→ Streamable HTTP（标准）→ SSE（回退）。
  RemoteControlMCP 使用 Streamable HTTP。
- CORS 代理是实验性的：**请勿在不信任的环境中启用**。
- 详情与最新选项：llama.cpp 仓库中的 `tools/server/README.md`。

## 9. 工具一览

| 工具 | 参数（必填） | 可选参数 | 响应 |
|------|--------------|----------|------|
| `eval` | `source` | `timeout`, `async` | 结果（sync）或 `jobId`（async） |
| `eval_status` | `jobId` | – | 异步任务的状态/结果 |
| `eval_cancel` | `jobId` | – | 取消任务；任务的最终状态 |
| `compile_method` | `className`, `source` | `isClassSide`, `category` | 编译后的选择器名 |
| `screenshot` | – | `morph`, `pad` | Base64 PNG（`type: image`） |
| `list_classes` | – | – | 类列表（每行一个） |
| `class_summary` | `name` | – | 类的 JSON 摘要 |
| `class_hierarchy` | `className` | – | 祖先 + 子类树 |
| `method_source` | `className`, `selector` | `includeSuperclasses` | 方法源码 |
| `selector_usage` | `selector` | – | 实现者/发送者，`Class >> selector` |
| `image_status` | – | – | 镜像的 JSON 状态 |

## 10. 提示

- eval 作为独立进程运行，优先级低于 HTTP 处理器；看门狗会在 `evalTimeout` 之后终止超时任务。
  因此即使长计算期间，HTTP 服务器也保持可响应。
- 长计算请使用 `async: true`，并通过 `eval_status` 获取结果；运行中的任务可用 `eval_cancel` 取消。
- `compile_method` 和 `eval` 会修改正在运行的镜像。可用 `Image save` 保存更改，或事先创建快照。
- 服务器默认只绑定 `127.0.0.1`——如需从其他计算机访问，请相应修改 `interfaceAddress:`（此时务必
  设置令牌）。
- CORS 默认禁用。浏览器客户端请设置 `corsAllowedOrigin:`——使用 `'*'` 时务必使用 bearer 令牌
  （见 5.1）。
- 该包完全自包含，无需 `RemoteControl` 桥或单独的 JSON 包；只需要 `WebClient` 和
  `Graphics-Files-Additional`（均来自 Cuis 7.8 发行版）。
