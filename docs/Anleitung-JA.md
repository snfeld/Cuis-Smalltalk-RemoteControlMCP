# RemoteControlMCP – 使用ガイド

このガイドでは、**RemoteControlMCP** の読み込み、起動、使用方法を説明します。他言語版：
[Deutsch（ドイツ語）](Anleitung.md)・[English（英語）](Anleitung-EN.md)・
[Español（スペイン語）](Anleitung-ES.md)・[Français（フランス語）](Anleitung-FR.md)・
[中文（中国語）](Anleitung-ZH.md)。

## 1. 概要

`RemoteControlMCP` は Model Context Protocol（MCP）サーバー（仕様 `2025-06-18`）であり、実行中の
Cuis-Smalltalk イメージを **Streamable HTTP**（JSON-RPC 2.0）経由で LLM やエージェントに公開します。
コードの評価、メソッドのコンパイル、スクリーンショット、イントロスペクション、メソッドソースと
セレクタの利用状況などの 11 のツール、1 つのリソース（`image://status`）、1 つのプロンプト
（`develop-in-cuis`）を提供します。

**このパッケージは完全に自己完結型です** – `WebClient`（WebServer・WebUtils JSON）と
`Graphics-Files-Additional`（スクリーンショット用の PNGReadWriter）に依存し、別個の JSON パッケージや
`RemoteControl` ブリッジは**不要**です。

## 2. インストール

前提条件：パッケージ **WebClient** と **Graphics-Files-Additional** を備えた Cuis 7.8。ファイル
`RemoteControlMCP.pck.st` は `!requires:` でこれらの依存関係を宣言しており、対話的な file-in では
正しい順序で自動的に解決されます。

イメージにパッケージを読み込む：

```smalltalk
ChangeSet fileIn: '/workspace/RemoteControlMCP-clean/packages/RemoteControlMCP.pck.st' asFileEntry.
ChangeSet fileIn: '/workspace/RemoteControlMCP-clean/packages/Tests-RemoteControlMCP.pck.st' asFileEntry.  "任意：テスト"
```

このパッケージには WebUtils JSON パーサーの修正（空のオブジェクト `{}` の後に後続キーを飲み込んでしまう
`jsonMapFrom:` の不具合）も含まれています。修正はメインパッケージに内包されていますが、独立ファイルとして
`packages/WebUtils-jsonMapFrom-Fix.pck.st` にも同梱されています。

または GUI から：**Open… → Package Manager → Install** で `.pck.st` ファイルを選択します。

## 3. 起動と停止

### クイックスタート（デフォルトインスタンス、ポート 2357、localhost のみ、認証なし）

```smalltalk
RemoteControlMCP start.        "デフォルトインスタンスを起動して返す"
RemoteControlMCP stop.         "再び停止する"
```

### 設定付きの独自インスタンス

```smalltalk
| server |
server := RemoteControlMCP new.
server port: 2357.                       "ポート、デフォルト 2357"
server interfaceAddress: '127.0.0.1'.    "バインド先アドレス、デフォルトはループバック"
server token: '私の秘密トークン'.          "ベアラートークン；nil で認証を無効化"
server evalTimeout: 30.                  "同期 eval のタイムアウト（秒）、デフォルト 30"
server start.
```

状態の確認：`server isRunning`（true/false）。停止：`server stop`。再起動：`server restart`。

## 4. 設定

| メソッド | デフォルト | 意味 |
|----------|------------|------|
| `port:` | `2357` | TCP ポート（クラスメソッド内の `defaultPort`） |
| `interfaceAddress:` | `'127.0.0.1'` | バインドするネットワークインターフェイス |
| `token:` | `nil`（認証なし） | オプションのベアラートークン；なし/`nil` は認証なし |
| `evalTimeout:` | `30` | 同期 eval のタイムアウト（秒） |
| `endpointPath:` | `'/mcp'` | MCP エンドポイントの HTTP パス |
| `corsAllowedOrigin:` | `nil`（CORS なし） | ブラウザクライアント向けに許可する CORS オリジン（例 `'*'` または `'http://localhost:8080'`）；CORS ヘッダー + OPTIONS プリフライトを有効化（5.1 参照） |
| `tlsCertificateFile:` | `nil`（TLS なし） | 証明書 + 秘密鍵を含む PEM ファイルのパス；設定すると HTTPS 専用（5.2 参照） |

## 5. エンドポイントと認証

- URL：`POST http://127.0.0.1:2357/mcp`（設定に応じてポート/パスを調整）
- Content-Type：`application/json`
- トークンを設定している場合、すべてのリクエストで送信が必要：
  `Authorization: Bearer <token>`
- トークンの欠落または誤り → サーバーは HTTP `401` を返します。

### 5.1 ブラウザアクセスのための CORS

ブラウザ内で動作する MCP クライアント（例：Web ページから `fetch` でアクセスする Web ベースの MCP
ツール）にはサーバーからの CORS ヘッダーが必要です – そうしないとブラウザは `CORS エラー` で応答を
ブロックします。CORS ヘッダーはデフォルトで**無効**です。`corsAllowedOrigin:` で有効化します：

```smalltalk
server corsAllowedOrigin: '*'.                       "すべてのオリジンを許可"
"または特定のオリジンのみ："
server corsAllowedOrigin: 'http://localhost:8080'.
```

オリジンが設定されると、サーバーは OPTIONS プリフライトリクエストに応答し、すべてのレスポンスに
`Access-Control-Allow-Origin`、`-Allow-Methods: POST, OPTIONS`、`-Allow-Headers: Content-Type,
Authorization`、`Access-Control-Max-Age: 86400` のヘッダーを追加します。

**セキュリティ：** `corsAllowedOrigin: '*'` でトークンなしの場合、ブラウザで開いた任意の Web ページが
イメージ内で任意の Smalltalk を実行できます。`'*'` を使う場合は必ずベアラートークンを使用し、かつ/または
サーバーを `127.0.0.1` にバインドしたままにしてください。具体的なオリジンの方が `'*'` より安全です。

### 5.2 HTTPS/TLS

デフォルトではサーバーは **HTTP**（TLS なし）で通信します。暗号化接続には、証明書**と**秘密鍵を含む PEM
ファイルのパスを `tlsCertificateFile:` に設定します。設定すると HTTPS 接続のみを受け付けます。

**OpenSSL 不要のクイックスタート：** 既製の自己署名サンプル証明書（有効期間 100 年）が
`packages/example-cert/server.pem` に同梱されています – 次のように使うだけです：

```smalltalk
server tlsCertificateFile: 'packages/example-cert/server.pem'.
server start.
```

または OpenSSL で証明書を自分で生成（自己署名、ローカル/テスト用）：

```bash
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes \
  -subj '/CN=localhost'
cat cert.pem key.pem > server.pem
```

有効化：

```smalltalk
server tlsCertificateFile: '/パス/server.pem'.
server start.
```

エンドポイントは `https://127.0.0.1:2357/mcp` になります。

**注意：**
- 同梱の `packages/example-cert/server.pem` は**ローカルテストのみ**を目的として意図的に同梱されています。
  自分で生成した証明書は秘密鍵を含むため、リポジトリに**コミットしてはいけません** – サーバープロセスからのみ
  読み取り可能な場所に保管してください（例：`chmod 600`）。
- トラストストアを設定していないクライアントは自己署名証明書を有効と見なしません。本番では実在の CA
  （例：Let's Encrypt）の証明書を使用してください。
- `tlsCertificateFile:` を設定しない限りサーバーは HTTP のまま – 開発や既存の設定には影響しません。
- `curl -k`（検証スキップ）または `curl --cacert server.pem`（自己署名ファイルを信頼）。

## 6. curl での使用方法

MCP のライフサイクルは常に `initialize` から始まり、通知 `notifications/initialized` が続きます。
その後、すべてのツール・リソース・プロンプトが利用可能になります。

### 6.1 initialize

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize",
       "params":{"protocolVersion":"2025-06-18","capabilities":{},
                 "clientInfo":{"name":"curl","version":"1.0"}}}'
```

応答（抜粋）：

```json
{"jsonrpc":"2.0","id":1,"result":{
  "protocolVersion":"2025-06-18",
  "capabilities":{"tools":{"listChanged":true},
                  "resources":{"listChanged":true},
                  "prompts":{"listChanged":true}},
  "serverInfo":{"name":"RemoteControlMCP","version":"0.1"},
  "instructions":"Use tools/eval ..."}}
```

### 6.2 initialized 通知と ping

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'   # 空の 200 応答
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":2,"method":"ping"}'                              # {"result":{}}
```

### 6.3 tools/list

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}'
```

### 6.4 tools/call – eval（同期）

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":4,"method":"tools/call",
       "params":{"name":"eval","arguments":{"source":"7 * 8"}}}'
```

応答：

```json
{"jsonrpc":"2.0","id":4,"result":{"content":[{"text":"56","type":"text"}]}}
```

オプション引数：`timeout`（秒）と `async`。失敗する評価（例：`1/0`）は `isError: true` とエラーメッセージで
応答されます。

### 6.5 tools/call – eval（非同期、ジョブポーリング）

長い評価は `"async":true` で開始します。即座に `jobId` が返ります。

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":5,"method":"tools/call",
       "params":{"name":"eval","arguments":{"source":"[1 to: 1000000 do:[:i| i*i]] value. 42","async":true}}}'
# {"result":{"content":[{"text":"{\"jobId\": \"job-2\", \"status\": \"running\"}","type":"text"}]}}

curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":6,"method":"tools/call",
       "params":{"name":"eval_status","arguments":{"jobId":"job-2"}}}'
```

ジョブ実行中：`{"jobId":"job-2","status":"running"}` – その後：

```json
{"jsonrpc":"2.0","id":6,"result":{"content":[
  {"text":"{\"jobId\": \"job-2\", \"status\": \"done\", \"result\": \"42\", \"error\": \"\"}","type":"text"}]}}
```

ジョブがタイムアウトを超えると、ウォッチドッグが終了させ、`eval_status` は `"status":"timeout"` と報告します。

### 6.6 tools/call – eval_cancel（ジョブのキャンセル）

実行中のジョブ（非同期ジョブ、または同期タイムアウト後も実行中のジョブ）は `eval_cancel` で終了できます：

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":7,"method":"tools/call",
       "params":{"name":"eval_cancel","arguments":{"jobId":"job-2"}}}'
```

応答：ジョブの最終状態（JSON テキスト）。実行中ジョブは終了され `{"jobId":"job-2","status":"cancelled"}`
と応答されます。すでに終了しているジョブは最終状態を維持します。その後ジョブはレジストリから削除されます。

### 6.7 tools/call – compile_method

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":8,"method":"tools/call",
       "params":{"name":"compile_method",
                 "arguments":{"className":"DocExample","source":"greeting\n\t^ 40 + 2","category":"accessing"}}}'
```

応答：コンパイルされたセレクタ名（`"greeting"`）。オプション引数：`isClassSide`（true/false）、`category`
（デフォルト `as yet unclassified`）。注意：実行中のイメージを恒久的に変更します。

シェルのクォーティングについて：メソッドソースに Smalltalk の文字列リテラルを含める場合、`curl -d '…'`
に直接書くとエラーになりがちです（Smalltalk 文字列の 2 つのシングルクォートがシェルのクォーティングと衝突）。
payload ファイルを使う方が確実です：

```bash
cat > /tmp/compile.json <<'EOF'
{"jsonrpc":"2.0","id":8,"method":"tools/call",
 "params":{"name":"compile_method",
           "arguments":{"className":"DocExample","source":"greeting\n\t^ 'こんにちは！'","category":"accessing"}}}
EOF
curl -s -X POST http://127.0.0.1:2357/mcp --data @/tmp/compile.json
```

### 6.8 tools/call – screenshot

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":9,"method":"tools/call",
       "params":{"name":"screenshot","arguments":{}}}'
```

応答：`content[0].data` に Base64 エンコードされた PNG データが入ります（`"type":"image"`、
`"mimeType":"image/png"`）。morph クラスへのトリミング（オプション）：`{"morph":"SystemWindow","pad":8}`。

### 6.9 tools/call – method_source

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":10,"method":"tools/call",
       "params":{"name":"method_source","arguments":{"className":"RemoteControlMCP","selector":"serverVersion"}}}'
```

応答：`Class >> selector`、カテゴリ、ソースコード。クラス自体がメソッドを定義していない場合、
`"includeSuperclasses":true` を指定すると継承チェーン内で最も近い定義クラスが示されます。

### 6.10 tools/call – selector_usage

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":11,"method":"tools/call",
       "params":{"name":"selector_usage","arguments":{"selector":"serverVersion"}}}'
```

応答：セレクタを実装するクラスと送信するクラス。各エントリ 1 行ずつ `Class >> selector`。

### 6.11 tools/call – イントロスペクション

```bash
# すべてのクラス（1 行に 1 つ）
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"list_classes","arguments":{}}}'

# クラスの階層（祖先 + インデント付き子孫ツリー）
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"class_hierarchy","arguments":{"className":"RemoteControlMCP"}}}'

# クラスの要約
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"class_summary","arguments":{"name":"RemoteControlMCP"}}}'

# イメージの状態
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":15,"method":"tools/call","params":{"name":"image_status","arguments":{}}}'
```

### 6.12 プロンプト

```bash
curl -s -X POST http://127.0.0.1:2357/mcp -d '{"jsonrpc":"2.0","id":16,"method":"prompts/list","params":{}}'
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":17,"method":"prompts/get","params":{"name":"develop-in-cuis"}}'
```

### 6.13 リソース

```bash
curl -s -X POST http://127.0.0.1:2357/mcp -d '{"jsonrpc":"2.0","id":18,"method":"resources/list","params":{}}'
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":19,"method":"resources/read","params":{"uri":"image://status"}}'
```

## 7. エラーコードとステータスコード

| HTTP | 意味 |
|------|------|
| `200` | JSON-RPC 応答（通知には空の応答も含む） |
| `401` | トークン欠落または誤り |
| `405` | HTTP メソッドが誤り（POST のみ） |

| JSON-RPC コード | 意味 |
|-----------------|------|
| `-32700` | パースエラー（JSON が無効） |
| `-32600` | 無効なリクエスト |
| `-32601` | メソッドが見つからない |
| `-32602` | 無効なパラメータ |
| `-32603` | 内部エラー |

## 8. MCP クライアントからの使用

MCP HTTP クライアント（例：Claude Desktop）の設定例：

```json
{
  "mcpServers": {
    "cuis": {
      "type": "http",
      "url": "http://127.0.0.1:2357/mcp",
      "headers": { "Authorization": "Bearer 私の秘密トークン" }
    }
  }
}
```

トークンなしの場合は `headers` エントリを省略します。クライアントが自分で `initialize` を実行し、
その後 `tools/call`・`prompts/get`・`resources/read` を呼び出せます。

### OpenCode

OpenCode はリモート MCP サーバー経由で接続します。プロジェクトディレクトリの `opencode.json`
（またはグローバルの `~/.config/opencode/opencode.json`）にサーバーを登録します：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "cuis": {
      "type": "remote",
      "url": "http://127.0.0.1:2357/mcp",
      "enabled": true,
      "headers": { "Authorization": "Bearer 私の秘密トークン" }
    }
  }
}
```

注意：

- `type` は `"remote"` である必要があります（HTTP/Streamable HTTP サーバーのみ対応；`command` エントリは
  ローカルの stdio サーバーでのみ有効）。
- トークンなしの場合は `headers` エントリを省略します。値は `{env:VAR}` と `{file:パス}` プレースホルダを
  サポートします（例：`"Authorization": "Bearer {env:CUIS_MCP_TOKEN}"`）。
- 設定は OpenCode の起動時にのみ読み込まれます – 変更後は OpenCode を再起動してください。
- 再起動後、サーバー（例 `/mcp`）がツール名前空間に現れ、`eval`・`compile_method`・`screenshot` などの
  ツールがエージェントで使用可能になります。

### llama.cpp（WebUI）を MCP クライアントとして

`llama-server` の WebUI には組み込みの MCP クライアントがあり、そこに RemoteControlMCP を MCP サーバー
として登録できます。MCP クライアントは**ブラウザ内**で実行されます – つまりリクエストはブラウザが
`llama-server` から読み込んだ Web ページから発信されます。ブラウザが別のオリジンから RemoteControlMCP に
アクセスする場合、CORS ルールが適用されます（5.1 節参照）。

**シナリオ：** マシン A が `llama.cpp` をサーバーとして実行（WebUI は `http://<マシンA>:8080`）。
マシン B はブラウザで WebUI を開き、同時に RemoteControlMCP（`http://127.0.0.1:2357/mcp`）を実行。
ブラウザは A の WebUI を読み込みますが、MCP リクエストは B 上のサーバーを対象とします – これはクロス
オリジンリクエストです。

**オプション 1 – 直接接続（推奨、CORS は RemoteControlMCP 内）：**

1. CORS を有効にして RemoteControlMCP を起動（5.1 節）、例：

   ```smalltalk
   server := RemoteControlMCP new.
   server port: 2357.
   server token: '私の秘密トークン'.                        "'*' の場合は必須"
   server corsAllowedOrigin: '*'.                          "または：http://<マシンA>:8080"
   server start.
   ```

2. WebUI の **MCP Servers** でサーバーを追加：URL `http://127.0.0.1:2357/mcp`、トランスポートは
   **Streamable HTTP**（標準）。

3. **"use llama-server proxy"** トグルは**有効にしない**（オプション 2 専用）。

**オプション 2 – llama.cpp の CORS プロキシ経由：**

1. マシン A で `--ui-mcp-proxy` を付けて `llama-server` を起動（実験的、信頼できるネットワーク限定）。
   ブラウザは llama-server とだけ通信するようになります（CORS 問題なし）；llama-server が MCP リクエストを
   RemoteControlMCP に転送します。
2. WebUI で MCP サーバーの **"use llama-server proxy"** トグルを有効化。このトグルは既に作成済みのサーバーを
   編集したときだけ表示されます。
3. 前提条件：`llama-server`（マシン A）が RemoteControlMCP に到達できること。RemoteControlMCP が
   `127.0.0.1`（デフォルト）のみにバインドしている場合、プロキシ方式は両方が同じマシンで動いているときだけ
   機能します。それ以外は到達可能なインターフェイスにバインドし、トークンを設定してください。

注意：

- **`localhost` ではなく `127.0.0.1` を使う：** 複数のユーザーが `localhost` では接続が失敗し、
  `127.0.0.1` では成功すると報告しています。両方の表記を統一してください。
- `--webui-mcp-proxy` は `--ui-mcp-proxy` の古い（非推奨の）表記です。
- WebUI クライアントのトランスポート順序：WebSocket（明示設定時）→ Streamable HTTP（標準）→ SSE（フォールバック）。
  RemoteControlMCP は Streamable HTTP を話します。
- CORS プロキシは実験的です：**信頼できない環境では有効にしないでください**。
- 詳細と最新オプション：llama.cpp リポジトリの `tools/server/README.md`。

## 9. ツール一覧

| ツール | パラメータ（必須） | オプション | 応答 |
|--------|-------------------|------------|------|
| `eval` | `source` | `timeout`, `async` | 結果（同期）または `jobId`（非同期） |
| `eval_status` | `jobId` | – | 非同期ジョブの状態/結果 |
| `eval_cancel` | `jobId` | – | ジョブをキャンセル；最終状態 |
| `compile_method` | `className`, `source` | `isClassSide`, `category` | コンパイルされたセレクタ名 |
| `screenshot` | – | `morph`, `pad` | Base64 PNG（`type: image`） |
| `list_classes` | – | – | クラス一覧（1 行 1 クラス） |
| `class_summary` | `name` | – | クラスの JSON 要約 |
| `class_hierarchy` | `className` | – | 祖先 + 子孫ツリー |
| `method_source` | `className`, `selector` | `includeSuperclasses` | メソッドのソースコード |
| `selector_usage` | `selector` | – | 実装者/送信者、`Class >> selector` |
| `image_status` | – | – | イメージの JSON 状態 |

## 10. 注意事項

- eval は HTTP ハンドラより低い優先度の独立プロセスとして実行されます；ウォッチドッグが `evalTimeout`
  後に期限切れジョブを終了します。長い eval 中でも HTTP サーバーは応答性を保ちます。
- 長い eval には `async: true` を使い、`eval_status` で結果を取得します；実行中のジョブは `eval_cancel`
  でキャンセルできます。
- `compile_method` と `eval` は実行中のイメージを変更します。`Image save` で変更を保存するか、事前に
  スナップショットを作成してください。
- サーバーはデフォルトで `127.0.0.1` のみにバインド – 他のマシンからアクセスするには `interfaceAddress:`
  を変更します（その場合は必ずトークンを設定！）。
- CORS はデフォルトで無効です。ブラウザクライアントには `corsAllowedOrigin:` を設定 – `'*'` の場合は
  必ずベアラートークンを使用（5.1 参照）。
- このパッケージは自己完結型で、`RemoteControl` ブリッジや別個の JSON パッケージは不要；必要なのは
  `WebClient` と `Graphics-Files-Additional`（いずれも Cuis 7.8 ディストリビューションに同梱）のみです。
