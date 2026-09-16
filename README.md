# RemoteControlMCP

**If you use Cuis 7.8, use the files in branch Cuis7.8! All fixes for 7.8 are included there.**

RemoteControlMCP was developed and tested in an Alipne-musl (with gcompat) docker container, with stock Cuis7.8, headless. No desktop, no X11, no framebuffer, but still screenshots.

A **Model Context Protocol (MCP) server** (specification `2025-06-18`) for a running
[Cuis-Smalltalk](https://github.com/Cuis-Smalltalk/Cuis-Smalltalk-Dev) 7.8 image. It exposes the image
to LLMs and agents over **Streamable HTTP** (JSON-RPC 2.0) on port **2357** — evaluate Smalltalk,
compile methods, take screenshots and introspect the running image.

This file is the short user-facing entry point. The full guides (installation, configuration,
authentication, CORS, TLS, all curl examples and every tool) are available in the `docs/` folder in
six languages (see below).

## Tools

| Tool | Description |
|------|-------------|
| `eval` | Evaluate Smalltalk source in the image. Synchronous until the timeout by default; `async: true` starts a background job (poll with `eval_status`, stop with `eval_cancel`). |
| `eval_status` | Poll the status/result of an asynchronous eval job. |
| `eval_cancel` | Terminate a running eval job (by `jobId`); answers the job's final status. |
| `compile_method` | Compile a Smalltalk method into a class (`safelyCompile:classified:`), optionally class-side, with a method category. |
| `screenshot` | Capture a PNG of the Cuis world (base64), optional crop to a morph class with a pad margin. |
| `list_classes` | List the names of all classes, one per line. |
| `class_summary` | JSON summary of a class: superclass, instance variables, method counts and method names. |
| `class_hierarchy` | A class's ancestry and an indented descendant tree. |
| `method_source` | Source of a method (`Class >> selector`), optionally searching superclasses. |
| `selector_usage` | Who implements and who sends a selector, one `Class >> selector` per line. |
| `image_status` | JSON summary of the running image: name, update level, VM and OS. |

The server also provides one resource (`image://status`) and one prompt (`develop-in-cuis`).

## Package files

- `packages/RemoteControlMCP.pck.st` – the server (includes the WebUtils `jsonMapFrom:` fix)
- `packages/WebUtils-jsonMapFrom-Fix.pck.st` – the JSON-parser fix as a standalone package (for use
  without the MCP server)
- `packages/Tests-RemoteControlMCP.pck.st` – unit tests (`WebUtilsJsonTest`, `McpEvalJobTest`,
  `RemoteControlMCPToolTest`)

Load order: the package declares `!requires: 'WebClient'` and
`!requires: 'Graphics-Files-Additional'` — an interactive file-in resolves these automatically.

## Quick start

```smalltalk
RemoteControlMCP start.        "starts the default instance on http://127.0.0.1:2357/mcp"
RemoteControlMCP stop.         "stops it again"
```

## Documentation (guides)

- [Deutsch](docs/Anleitung.md) — ausführliche Anleitung mit Beispielen
- [English](docs/Anleitung-EN.md) — detailed usage guide with examples
- [Español](docs/Anleitung-ES.md) — manual de uso con ejemplos
- [Français](docs/Anleitung-FR.md) — guide d'utilisation avec exemples
- [中文](docs/Anleitung-ZH.md) – 使用指南（带示例）
- [日本語](docs/Anleitung-JA.md) – 使用ガイド（例つき）

