# Cuis-Smalltalk-RemoteControlMCP

**If you use Cuis 7.8, use the files in branch Cuis7.8! All fixes for 7.8 are included there.**

RemoteControlMCP was developed and tested in an Alipne-musl (with gcompat) docker container, with stock Cuis7.8, headless. No desktop, no X11, no framebuffer, but still screenshots.

A **Model Context Protocol (MCP) server** (specification `2025-06-18`) for a running
[Cuis-Smalltalk](https://github.com/Cuis-Smalltalk/Cuis-Smalltalk-Dev) image. It is the successor to
the existing `RemoteControl` HTTP bridge (port 2347) and exposes the image to LLMs and agents over
**Streamable HTTP** (JSON-RPC 2.0) on port **2357**.

`RemoteControlMCP` lets an MCP client run Smalltalk code in the image, compile methods, take
screenshots and introspect the image – useful for developing Cuis-Smalltalk directly from an
LLM/agent environment (e.g. opencode, Claude Desktop, llama.cpp WebUI).

## Tools

| Tool | Description |
|------|-------------|
| `eval` | Evaluate Smalltalk source in the image. Synchronous until the timeout by default; `async: true` starts a background job (poll with `eval_status`). |
| `eval_status` | Poll the status/result of an asynchronous eval job. |
| `compile_method` | Compile a Smalltalk method into a class (`safelyCompile:classified:`), optionally class-side. |
| `screenshot` | Capture a PNG of the Cuis world (base64), optional crop to a morph class with a pad margin. |
| `list_classes` | List the names of all classes, one per line. |
| `class_summary` | JSON summary of a class: superclass, instance variables, method counts and method names. |
| `image_status` | JSON summary of the running image: name, update level, VM and OS. |

The server also provides one resource (`image://status`) and one prompt (`develop-in-cuis`).

## Quick start

```smalltalk
"Load the package (requires Cuis 7.8 with the WebClient and JSON packages), then:"
RemoteControlMCP start.        "starts the default instance on http://127.0.0.1:2357/mcp"
RemoteControlMCP stop.         "stops it again"
```

Packages:

- `packages/RemoteControlMCP.pck.st` – the server
- `packages/Tests-RemoteControlMCP.pck.st` – unit tests (`WebUtilsJsonTest`)
- `packages/WebUtils-jsonMapFrom-fix.st` – standalone fix for a Cuis `WebUtils` JSON bug
- `startup.st` – headless start script (RemoteControl 2347 + MCP 2357)

## Documentation

Detailed, up-to-date documentation is provided in several languages. Each guide covers installation,
configuration (port, interface, bearer-token auth, CORS, HTTPS/TLS), usage with `curl` and from MCP
clients (opencode, Claude Desktop, llama.cpp WebUI), all tools and the error/status codes:

- [Deutsch](docs/Anleitung.md) – ausführliche Anleitung mit Beispielen
- [English](docs/Anleitung-EN.md) – detailed usage guide with examples
- [Español](docs/Anleitung-ES.md) – manual de uso con ejemplos
- [Français](docs/Anleitung-FR.md) – guide d'utilisation avec exemples
- [中文](docs/Anleitung-ZH.md) – 使用指南（带示例）

Further references: `docs/MCP-Protokoll-Referenz.md` (MCP/JSON-RPC spec notes),
`docs/Analyse-RemoteControl.md` (analysis of the legacy RemoteControl class),
`docs/Cuis-Integration-Notizen.md` (Cuis-specific findings), `docs/Auftrag-Nutzer.md` (initial
user request) and `docs/WebUtils-jsonMapFrom-Bug.md` (a Cuis WebUtils JSON parser bug that was found
and fixed during the opencode integration; the fix is shipped as a class extension inside the
package and covered by `Tests-RemoteControlMCP`).
