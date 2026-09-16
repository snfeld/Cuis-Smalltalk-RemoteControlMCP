# RemoteControlMCP – Anleitung (Deutsch)

Diese Anleitung beschreibt, wie **RemoteControlMCP** geladen, gestartet und verwendet wird.
Weitere Sprachen: [English](Anleitung-EN.md), [Español](Anleitung-ES.md), [Français](Anleitung-FR.md),
[中文](Anleitung-ZH.md), [日本語](Anleitung-JA.md).

## 1. Überblick

`RemoteControlMCP` ist ein Model-Context-Protocol-Server (Spezifikation `2025-06-18`), der einen
laufenden Cuis-Smalltalk-Image über **Streamable HTTP** (JSON-RPC 2.0) für LLMs und Agenten zugänglich macht.
Er stellt elf Tools bereit (Code ausführen, Methoden kompilieren, Screenshots, Introspection,
Methodensource und Selektoren), eine Ressource (`image://status`) und einen Prompt (`develop-in-cuis`).

**Das Paket ist eigenständig** – es baut auf `WebClient` (WebServer, WebUtils-JSON) und
`Graphics-Files-Additional` (PNGReadWriter für Screenshots) auf und benötigt **kein** separates
JSON-Paket und keine `RemoteControl`-Brücke.

## 2. Installation

Voraussetzungen: Cuis 7.8 mit den Packages **WebClient** und **Graphics-Files-Additional**.
Das Paket `RemoteControlMCP.pck.st` deklariert diese Abhängigkeiten (`!requires:`); bei einem
interaktiven file-in werden sie automatisch in der richtigen Reihenfolge geladen.

Paket einlesen (im Image):

```smalltalk
ChangeSet fileIn: '/workspace/RemoteControlMCP-clean/packages/RemoteControlMCP.pck.st' asFileEntry.
ChangeSet fileIn: '/workspace/RemoteControlMCP-clean/packages/Tests-RemoteControlMCP.pck.st' asFileEntry.  "optional: Tests"
```

Enthalten ist auch der Fix für den WebUtils-JSON-Parser (`jsonMapFrom:` verschluckt bei leerem `{}`
Folge-Keys). Der Fix steckt direkt im Hauptpaket; als eigenständige Datei liegt er zusätzlich unter
`packages/WebUtils-jsonMapFrom-Fix.pck.st`.

Alternativ über die GUI: **Open… → Package Manager → Install**, die `.pck.st`-Dateien wählen.

## 3. Starten und Stoppen

### Schnellstart (Default-Instanz, Port 2357, nur localhost, ohne Authentifizierung)

```smalltalk
RemoteControlMCP start.        "startet die Default-Instanz und liefert sie zurück"
RemoteControlMCP stop.         "stoppt sie wieder"
```

### Eigene Instanz mit Konfiguration

```smalltalk
| server |
server := RemoteControlMCP new.
server port: 2357.                       "Port, Default 2357"
server interfaceAddress: '127.0.0.1'.    "Bind-Adresse, Default Loopback"
server token: 'mein-geheimer-token'.     "Bearer-Token; nil schaltet Auth aus"
server evalTimeout: 30.                  "Sync-Eval-Timeout in Sekunden, Default 30"
server start.
```

Status prüfen: `server isRunning` (true/false). Stoppen: `server stop`. Neu starten: `server restart`.

## 4. Konfiguration

| Methode | Default | Bedeutung |
|---------|---------|-----------|
| `port:` | `2357` | TCP-Port (`defaultPort` in der Klassenmethode) |
| `interfaceAddress:` | `'127.0.0.1'` | Netzwerk-Interface, an das gebunden wird |
| `token:` | `nil` (keine Auth) | Optionaler Bearer-Token; ohne/`nil` keine Authentifizierung |
| `evalTimeout:` | `30` | Timeout für synchrone Evals in Sekunden |
| `endpointPath:` | `'/mcp'` | HTTP-Pfad des MCP-Endpunkts |
| `corsAllowedOrigin:` | `nil` (kein CORS) | Erlaubter CORS-Origin für Browser-Clients (z. B. `'*'` oder `'http://localhost:8080'`); aktiviert CORS-Header + OPTIONS-Preflight (siehe 5.1) |
| `tlsCertificateFile:` | `nil` (kein TLS) | Pfad zu einer PEM-Datei mit Zertifikat + Private Key; wenn gesetzt, dient der Server über HTTPS (siehe 5.2) |

## 5. Endpunkt und Authentifizierung

- URL: `POST http://127.0.0.1:2357/mcp` (bzw. angepasster Port/Pfad)
- Content-Type: `application/json`
- Wenn ein Token gesetzt ist, muss jeder Request senden:
  `Authorization: Bearer <token>`
- Ohne oder mit falschem Token antwortet der Server mit HTTP `401`.

### 5.1 CORS für Browser-Zugriff

Für MCP-Clients im Browser (z. B. ein webbasiertes MCP-Tool, das per `fetch` aus einer Webseite
zugreift) braucht der Server CORS-Header – sonst blockiert der Browser die Antwort mit einem
`CORS-Error`. Standardmäßig sind CORS-Header **deaktiviert**. Aktivieren Sie CORS über
`corsAllowedOrigin:`:

```smalltalk
server corsAllowedOrigin: '*'.                       "alle Origins erlauben"
"oder nur eine konkrete Origin:"
server corsAllowedOrigin: 'http://localhost:8080'.
```

Ist ein Origin konfiguriert, beantwortet der Server OPTIONS-Preflight-Anfragen und liefert auf allen
Antworten die Header `Access-Control-Allow-Origin`, `-Allow-Methods: POST, OPTIONS`,
`-Allow-Headers: Content-Type, Authorization` und `Access-Control-Max-Age: 86400`.

**Sicherheit:** Mit `corsAllowedOrigin: '*'` und ohne Token kann jede Webseite, die Sie im Browser
öffnen, beliebigen Smalltalk im Image ausführen. Verwenden Sie bei `'*'` deshalb zwingend einen
Bearer-Token und/oder binden Sie den Server weiterhin nur an `127.0.0.1`. Am sichersten ist ein
konkreter Origin statt `'*'`.

### 5.2 HTTPS/TLS

Standardmäßig spricht der Server **HTTP** (kein TLS). Für verschlüsselte Verbindungen setzen Sie
`tlsCertificateFile:` auf den Pfad einer PEM-Datei, die Zertifikat **und** Private Key enthält.
Sobald gesetzt, stellt der Server ausschließlich HTTPS-Verbindungen her.

**Schnellstart ohne OpenSSL:** Ein fertiges, self-signed Beispiel-Zertifikat (100 Jahre gültig)
liegt unter `packages/example-cert/server.pem` – einfach so verwenden:

```smalltalk
server tlsCertificateFile: 'packages/example-cert/server.pem'.
server start.
```

Zertifikat alternativ selbst mit OpenSSL erzeugen (self-signed, für lokale/Testzwecke):

```bash
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes \
  -subj '/CN=localhost'
cat cert.pem key.pem > server.pem
```

Aktivieren:

```smalltalk
server tlsCertificateFile: '/pfad/zu/server.pem'.
server start.
```

Der Endpunkt ist dann `https://127.0.0.1:2357/mcp`.

**Hinweise:**
- Das mitgelieferte `packages/example-cert/server.pem` ist nur für **lokale Tests** gedacht und
  bewusst mitgeliefert. Selbst erzeugte Zertifikate gehören wegen des privaten Schlüssels **nicht**
  ins Repo – nur für den Serverprozess lesbar ablegen (z. B. `chmod 600`).
- Das self-signed Zertifikat wird von Clients ohne Vertrauensankerkonfiguration nicht als gültig
  akzeptiert. Für produktive Einsätze ein Zertifikat einer echten CA (z. B. Let's Encrypt) verwenden.
- Ohne `tlsCertificateFile:` bleibt der Server unverändert bei HTTP – Entwicklung und
  bestehende Konfigurationen sind davon nicht betroffen.
- `curl -k` bzw. `curl --cacert server.pem` verifizieren das self-signed Zertifikat nicht bzw.
  mit der PEM-Datei als Vertrauensanker.

## 6. Verwendung mit curl

Der MCP-Lifecycle beginnt immer mit `initialize`, gefolgt von der Notification
`notifications/initialized`. Danach stehen alle Tools, Ressourcen und Prompts bereit.

### 6.1 initialize

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize",
       "params":{"protocolVersion":"2025-06-18","capabilities":{},
                 "clientInfo":{"name":"curl","version":"1.0"}}}'
```

Antwort (gekürzt):

```json
{"jsonrpc":"2.0","id":1,"result":{
  "protocolVersion":"2025-06-18",
  "capabilities":{"tools":{"listChanged":true},
                  "resources":{"listChanged":true},
                  "prompts":{"listChanged":true}},
  "serverInfo":{"name":"RemoteControlMCP","version":"0.1"},
  "instructions":"Use tools/eval ..."}}
```

### 6.2 initialized-Notification und ping

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'   # leere 200-Antwort
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":2,"method":"ping"}'                              # {"result":{}}
```

### 6.3 tools/list

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}'
```

### 6.4 tools/call – eval (synchron)

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":4,"method":"tools/call",
       "params":{"name":"eval","arguments":{"source":"7 * 8"}}}'
```

Antwort:

```json
{"jsonrpc":"2.0","id":4,"result":{"content":[{"text":"56","type":"text"}]}}
```

Optionale Argumente: `timeout` (Sekunden) und `async`. Eine Fehlerauswertung (z. B. `1/0`) wird als
`isError: true` mit Fehlermeldung beantwortet.

### 6.5 tools/call – eval (asynchron, Job-Polling)

Lange Evals mit `"async":true` starten. Antwort: sofortiges `jobId`.

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":5,"method":"tools/call",
       "params":{"name":"eval","arguments":{"source":"[1 to: 1000000 do:[:i| i*i]] value. 42","async":true}}}'
# {"result":{"content":[{"text":"{\"jobId\": \"job-2\", \"status\": \"running\"}","type":"text"}]}}

curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":6,"method":"tools/call",
       "params":{"name":"eval_status","arguments":{"jobId":"job-2"}}}'
```

Solange der Job läuft: `{"jobId":"job-2","status":"running"}` – danach:

```json
{"jsonrpc":"2.0","id":6,"result":{"content":[
  {"text":"{\"jobId\": \"job-2\", \"status\": \"done\", \"result\": \"42\", \"error\": \"\"}","type":"text"}]}}
```

Läuft ein Job über sein Timeout hinaus, beendet ihn der Watchdog und `eval_status` meldet
`"status":"timeout"`.

### 6.6 tools/call – eval_cancel (Job abbrechen)

Ein laufender Job (asynchron oder nach Sync-Timeout) lässt sich mit `eval_cancel` abbrechen:

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":7,"method":"tools/call",
       "params":{"name":"eval_cancel","arguments":{"jobId":"job-2"}}}'
```

Antwort: der finale Jobstatus als JSON-Text. Ein laufender Job wird mit
`{"jobId":"job-2","status":"cancelled"}` beendet; ein bereits beendeter Job behält seinen
Endstatus. Danach ist der Job aus der Registry entfernt.

### 6.7 tools/call – compile_method

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":8,"method":"tools/call",
       "params":{"name":"compile_method",
                 "arguments":{"className":"DocExample","source":"greeting\n\t^ 40 + 2","category":"accessing"}}}'
```

Antwort: der kompilierte Selektorname (`"greeting"`). Optionale Argumente: `isClassSide` (true/false),
`category` (Default `as yet unclassified`). Achtung: das verändert den laufenden Image dauerhaft.

Hinweis zur Shell-Zitierung: Will der Methodenquelltext ein Smalltalk-Stringliteral enthalten, ist das
direkt in `curl -d '…'` fehleranfällig (die zwei Hochkommata des Smalltalk-Strings kollidieren mit der
Shell-Quotierung). Sauberer ist ein Payload-File:

```bash
cat > /tmp/compile.json <<'EOF'
{"jsonrpc":"2.0","id":8,"method":"tools/call",
 "params":{"name":"compile_method",
           "arguments":{"className":"DocExample","source":"greeting\n\t^ 'Hallo!'","category":"accessing"}}}
EOF
curl -s -X POST http://127.0.0.1:2357/mcp --data @/tmp/compile.json
```

### 6.8 tools/call – screenshot

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":9,"method":"tools/call",
       "params":{"name":"screenshot","arguments":{}}}'
```

Antwort: `content[0].data` enthält die Base64-kodierten PNG-Daten (`"type":"image"`,
`"mimeType":"image/png"`). Optional crop auf eine Morph-Klasse: `{"morph":"SystemWindow","pad":8}`.

### 6.9 tools/call – method_source

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":10,"method":"tools/call",
       "params":{"name":"method_source","arguments":{"className":"RemoteControlMCP","selector":"serverVersion"}}}'
```

Antwort: `Class >> selector`, Kategorie und Quelltext. Mit `"includeSuperclasses":true` wird die
nächste definierende Klasse in der Vererbungskette benannt, falls die Klasse die Methode selbst nicht
definiert.

### 6.10 tools/call – selector_usage

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":11,"method":"tools/call",
       "params":{"name":"selector_usage","arguments":{"selector":"serverVersion"}}}'
```

Antwort: wer implementiert und wer sendet den Selektor, eine `Class >> selector`-Zeile pro Eintrag.

### 6.11 tools/call – Introspection

```bash
# Alle Klassen (eine pro Zeile)
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"list_classes","arguments":{}}}'

# Klassenhierarchie einer Klasse (Ancestry + eingerückter Descendant-Baum)
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"class_hierarchy","arguments":{"className":"RemoteControlMCP"}}}'

# Zusammenfassung einer Klasse
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"class_summary","arguments":{"name":"RemoteControlMCP"}}}'

# Image-Status
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":15,"method":"tools/call","params":{"name":"image_status","arguments":{}}}'
```

### 6.12 Prompts

```bash
curl -s -X POST http://127.0.0.1:2357/mcp -d '{"jsonrpc":"2.0","id":16,"method":"prompts/list","params":{}}'
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":17,"method":"prompts/get","params":{"name":"develop-in-cuis"}}'
```

### 6.13 Ressourcen

```bash
curl -s -X POST http://127.0.0.1:2357/mcp -d '{"jsonrpc":"2.0","id":18,"method":"resources/list","params":{}}'
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":19,"method":"resources/read","params":{"uri":"image://status"}}'
```

## 7. Fehlercodes und Statuscodes

| HTTP | Bedeutung |
|------|-----------|
| `200` | JSON-RPC-Antwort (auch leere Antwort für Notifications) |
| `401` | Token fehlt oder falsch |
| `405` | Falsche HTTP-Methode (nur POST) |

| JSON-RPC-Code | Bedeutung |
|---------------|-----------|
| `-32700` | Parse error (kein gültiges JSON) |
| `-32600` | Invalid Request |
| `-32601` | Method not found |
| `-32602` | Invalid params |
| `-32603` | Internal error |

## 8. Verwendung aus einem MCP-Client

Beispiel-Konfiguration für einen MCP-HTTP-Client (z. B. Claude Desktop):

```json
{
  "mcpServers": {
    "cuis": {
      "type": "http",
      "url": "http://127.0.0.1:2357/mcp",
      "headers": { "Authorization": "Bearer mein-geheimer-token" }
    }
  }
}
```

Ohne Token entfällt der `headers`-Eintrag. Der Client führt selbst `initialize` durch und kann dann
`tools/call`, `prompts/get` und `resources/read` aufrufen.

### OpenCode

OpenCode verbindet sich über einen entfernten („remote“) MCP-Server. Tragen Sie den Server in der
Datei `opencode.json` im Projektverzeichnis (oder global unter `~/.config/opencode/opencode.json`) ein:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "cuis": {
      "type": "remote",
      "url": "http://127.0.0.1:2357/mcp",
      "enabled": true,
      "headers": { "Authorization": "Bearer mein-geheimer-token" }
    }
  }
}
```

Hinweise:

- `type` muss `"remote"` sein (nur HTTP/Streamable-HTTP-Server werden unterstützt; ein `command`-Eintrag
  ist nur für lokale stdio-Server gültig).
- Ohne Token entfällt der `headers`-Eintrag. Werte unterstützen die Platzhalter `{env:VAR}` und
  `{file:pfad}`, z. B. `"Authorization": "Bearer {env:CUIS_MCP_TOKEN}"`.
- Die Konfiguration wird nur beim Start von OpenCode geladen – nach Änderungen muss OpenCode
  neu gestartet werden.
- Nach dem Neustart erscheint der Server (z. B. `/mcp`) im Tool-Namensraum und die Tools
  `eval`, `compile_method`, `screenshot` usw. sind im Agenten verfügbar.

### llama.cpp (WebUI) als MCP-Client

Die WebUI von `llama-server` bringt einen eingebauten MCP-Client mit, in dem Sie RemoteControlMCP als
MCP-Server registrieren können. Der MCP-Client läuft dabei **im Browser** – die Anfragen starten also
in der Webseite, die der Browser von `llama-server` geladen hat. Greift der Browser aus einer anderen
Origin auf RemoteControlMCP zu, greift die CORS-Regel (siehe Abschnitt 5.1).

**Szenario:** Rechner A betreibt `llama.cpp` als Server (WebUI unter `http://<Rechner-A>:8080`).
Rechner B öffnet die WebUI im Browser und betreibt zugleich RemoteControlMCP
(`http://127.0.0.1:2357/mcp`). Der Browser lädt die WebUI von A, die MCP-Anfragen richten sich aber an
den Server auf B – das ist eine Cross-Origin-Anfrage.

**Variante 1 – direkte Verbindung (empfohlen, CORS in RemoteControlMCP):**

1. RemoteControlMCP mit aktiviertem CORS starten (Abschnitt 5.1), z. B.:

   ```smalltalk
   server := RemoteControlMCP new.
   server port: 2357.
   server token: 'mein-geheimer-token'.                          "zwingend bei '*'"
   server corsAllowedOrigin: '*'.                               "oder: http://<Rechner-A>:8080"
   server start.
   ```

2. In der WebUI unter **MCP Servers** einen Server hinzufügen: URL
   `http://127.0.0.1:2357/mcp`, Transport **Streamable HTTP** (Standard).

3. Den Schalter **„use llama-server proxy“** **nicht** aktivieren (nur für Variante 2).

**Variante 2 – über den CORS-Proxy von llama.cpp:**

1. `llama-server` auf Rechner A mit `--ui-mcp-proxy` starten (experimentell, nur in vertrauten
   Netzwerken). Der Browser spricht dann ausschließlich mit dem llama-server (keine CORS-Probleme
   mehr); llama-server leitet die MCP-Anfragen an RemoteControlMCP weiter.
2. In der WebUI beim MCP-Server den Schalter **„use llama-server proxy“** aktivieren. Der Schalter
   erscheint erst beim Bearbeiten eines bereits angelegten Servers.
3. Voraussetzung: Der llama-server (Rechner A) muss RemoteControlMCP erreichen können. Bindet
   RemoteControlMCP nur an `127.0.0.1` (Standard), funktioniert die Proxy-Variante daher nur, wenn
   beide auf demselben Rechner laufen. Andernfalls auf ein erreichbares Interface binden und einen
   Token setzen.

Hinweise:

- **`127.0.0.1` statt `localhost` verwenden:** Mehrere Nutzer berichten, dass Verbindungen mit
  `localhost` fehlschlagen, mit `127.0.0.1` aber funktionieren. Beide Angaben konsistent halten.
- `--webui-mcp-proxy` ist die alte (veraltete) Schreibweise von `--ui-mcp-proxy`.
- Transport-Reihenfolge des WebUI-Clients: WebSocket (falls explizit konfiguriert) → Streamable HTTP
  (Standard) → SSE (Fallback). RemoteControlMCP spricht Streamable HTTP.
- Der CORS-Proxy ist experimentell: **nicht in unvertrauten Umgebungen aktivieren**.
- Details und aktuelle Optionen: `tools/server/README.md` im llama.cpp-Repository.

## 9. Tool-Übersicht

| Tool | Parameter (erforderlich) | Optionale Parameter | Antwort |
|------|--------------------------|---------------------|---------|
| `eval` | `source` | `timeout`, `async` | Ergebnis (sync) oder `jobId` (async) |
| `eval_status` | `jobId` | – | Status/Ergebnis eines async-Jobs |
| `eval_cancel` | `jobId` | – | Bricht Job ab; finaler Jobstatus |
| `compile_method` | `className`, `source` | `isClassSide`, `category` | kompilierter Selektorname |
| `screenshot` | – | `morph`, `pad` | Base64-PNG (`type: image`) |
| `list_classes` | – | – | Klassenliste (eine pro Zeile) |
| `class_summary` | `name` | – | JSON-Zusammenfassung der Klasse |
| `class_hierarchy` | `className` | – | Ancestry + Descendant-Baum |
| `method_source` | `className`, `selector` | `includeSuperclasses` | Quelltext der Methode |
| `selector_usage` | `selector` | – | Implementierer/Sender, `Class >> selector` |
| `image_status` | – | – | JSON-Status des Images |

## 10. Hinweise

- Evals laufen als eigene Prozesse mit Priorität unterhalb des HTTP-Handlers; ein Watchdog beendet
  überfällige Jobs nach `evalTimeout`. Der HTTP-Server bleibt dadurch auch bei langen Evals ansprechbar.
- Für lange Evals `async: true` verwenden und das Ergebnis über `eval_status` abholen; laufende Jobs
  lassen sich mit `eval_cancel` abbrechen.
- `compile_method` und `eval` verändern den laufenden Image. Mit `Image save` können Sie Änderungen
  sichern oder vorher einen Snapshot anlegen.
- Der Server bindet standardmäßig nur an `127.0.0.1` – für Zugriff von anderen Rechnern
  `interfaceAddress:` entsprechend ändern (dann zwingend ein Token setzen).
- CORS ist standardmäßig deaktiviert. Für Browser-Clients `corsAllowedOrigin:` setzen – bei `'*'`
  unbedingt einen Bearer-Token verwenden (siehe 5.1).
- Das Paket steht eigenständig ohne `RemoteControl`-Brücke und ohne separates JSON-Paket; einzig
  `WebClient` und `Graphics-Files-Additional` (beide aus der Cuis-7.8-Distribution) werden benötigt.
