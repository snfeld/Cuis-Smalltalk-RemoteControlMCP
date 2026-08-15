# Ist-Analyse: RemoteControl (Version 1.4)

Stand: **2026-08-13** · Quelle: `Packages/Tools/Cuis-RemoteControl-main/RemoteControl.pck.st`
(Stand 3. Juli 2026, `!provides: 'RemoteControl' 1 4!`, `!requires: 'WebClient' 1 nil 1!` +
`Graphics-Files-Additional`).

## Aufbau

- **Klassen-Singleton:** Alle Methoden sind Klassenmethoden; Zustand in **Klassenvariablen**
  `Port`, `Server`. Es gibt **keine Instanzvariablen** und keine Instanzen.
- **Kategorien:** `config` (port/port:), `accessing` (isRunning/server), `lifecycle` (start/stop),
  `handlers` (handleEval:, handleScreenshot:, errorReportFor:), `private` (cropRectFor:pad:in:,
  rectFromQuery:in:).
- **Endpunkte:** `POST /eval` (Smalltalk-Quelltext als Body, Antwort = `printString`),
  `GET /screenshot` (PNG der Welt, Cropping über `?morph=`/`?id=`/`?x&y&w&h`/`?pad=`/`?raw=1`).
- **Extension:** `ClassDescription >> safelyCompile:classified:` (Kategorie `*RemoteControl`).
- **Dokumentierter Sicherheitshinweis:** `/eval` = Remote-Code-Ausführung ohne Auth; nur localhost.

## Stärken (beibehalten)

- Gutes Fehlerprotokoll: 400 bei `UndeclaredVariableReference`, 500 mit Stacktrace
  (getrimmt am DoIt-Frame, max. 15 Frames), Notification-Auto-Resume.
- Korrekte UTF-8-Behandlung (Byte-/Char-Längen-Falle dokumentiert und umgangen).
- `safelyCompile:classified:` ist ein durchdachtes, sicheres Kompilier-Primitiv.
- Screenshot-Cropping flexibel (Morph/ID/Koordinaten + Pad).

## Befunde (gemäß cuis-code-rules) und Verbesserungsvorschläge

### B1 – Architektur: Klassen-Singleton → instanzbasiert
`RemoteControl` ist reine Klassenlogik mit Klassenvariablen `Port`/`Server`.
Konsequenzen: globaler Zustand, nicht testbar mit Mocks, keine zwei Server im selben Image,
kein sauberer Lebenszyklus pro Server.
**Vorschlag:** `RemoteControlMCP` als **Objekt** (Instanz mit `port`, `server`, `token`, `session`),
mit einer bequemen Klassen-Fassade `default`/`start`/`stop` als Delegation auf die Default-Instanz.
Kompatibel zur bisherigen Nutzung (`RemoteControlMCP start`), aber testbar und erweiterbar.

### B2 – `handleEval:`: dreifach verschachtelte Exception-Handler
Drei Ebenen `[[[ ... ] on: ... ] on: ... ] on: ...]` sind schwer lesbar und verletzen die
Abstraktionsebene (cuis-code-rules §1). Zudem antwortet der Erfolgsfall `text/plain` mit dem
`printString`, obwohl der Kommentar „JSON response“ sagt.
**Vorschlag:** Evaluierung in benannte Methoden zerlegen (z. B. `evaluateSource:`,
`evaluateErrorReportFor:`), je eine Verantwortung; Erfolgs-Format als Konfiguration
(`printString` oder JSON-`printString`). Für MCP wird Eval ohnehin ein **Tool** (`tools/call eval`),
das eine strukturierte JSON-Antwort liefert.

### B3 – Duplikation in der Fehlerbeschreibung
`handleScreenshot:` baut `ex class name, ': ', messageText` inline; `errorReportFor:` hat eine
ähnliche Kopfzeile. **Vorschlag:** gemeinsames `errorDescriptionFor: anException`.

### B4 – Duplizierte Query-Parsierung im Screenshot-Handler
`handleScreenshot:` parst die Query einmal für `raw`, `rectFromQuery:in:` parst sie erneut.
**Vorschlag:** Query genau einmal parsen und als `Dictionary` durchreichen
(`rectFromParams:in:`).

### B5 – Sicherheit: keine Authentifizierung, keine Interface-Bindung
`WebServer new listenOn:` bindet auf allen Interfaces; kein Auth.
**Vorschlag:** optionaler **Bearer-Token** (`Authorization: Bearer <token>`), konfigurierbare
Interface-Bindung (`listenOn:port:interface:`), Default localhost. Offen bleiben alle Requests
ohne Token nur, wenn kein Token konfiguriert ist (Entwicklungsmodus).

### B6 – Fehlende Tests
RemoteControl hat **kein** Test-Package. (cuis-code-rules §6: Tests nie in der Klasse, separater
Ordner `Tests-<Klassenname>`.)
**Vorschlag:** `Tests-RemoteControlMCP` mit Offline-Tests (JSON-RPC-Dispatch, Tools, Fehlercodes)
und optionalen Live-Tests gegen den laufenden Server (Muster aus `Tests-ForgeClient`).

### B7 – Extensibilität / Service-Registrierung
Die zwei Endpunkte sind in `start` hartkodiert. Für MCP kommen viele Methoden
(`initialize`, `ping`, `tools/list`, `tools/call`, `resources/list`, `prompts/list`, `logging` …) hinzu.
**Vorschlag:** JSON-RPC-2.0-Dispatch über eine Methoden-Registry (Dictionary `method → Block`),
Endpunkt konfigurierbar (`/mcp` Default). Damit bleibt `start` klein und erweiterbar.

### B8 – Doku-Defizite
- `start`-Kommentar sagt „JSON response“, Antwort ist aber Text.
- Fehlerformat (400/500) nicht in README bei MCP-Nutzung beschrieben.
**Vorschlag:** Kommentare auf Vertragsebene; README/API-Referenz für MCP.

### B9 – Weitere kleine Punkte
- `port:` antwortet mit neuem Wert (ok), aber Setter im ImapClient-Stil antworten üblicherweise
  mit dem Argument; Konsistenz prüfen.
- `isRunning`/`server` fehlt die Dokumentation („Why“).
- Kein Request-Logging / Audit für `tools/call` (Security-Empfehlung des MCP-Spec).
- `safelyCompile:classified:` soll als Extension im MCP-Package erhalten bleiben (kann 1:1
  übernommen werden; ggf. mit zusätzlichem `compile_method`-Tool).

### B10 – Eval asynchron + Timeout (Nutzer-Vorgabe, D8)
Bekannter Befund aus der Praxis (cuis-code-rules „Image-Speichern“/„Save hängt“):
- Ein **hängenbleibender Eval** (oder Image-Save via `/eval`) blockiert den WebServer-Handler;
  der Request antwortet nicht mehr, und bei vielen solcher Anfragen kann sogar der
  Prozess-Scheduler verklemmt werden (geforte Prozesse mit Priorität 40 laufen nicht mehr).
**Lösung:** Evaluierungen nicht im Handler-Thread ausführen, sondern als **eigener geforkter
Prozess** starten, dessen Laufzeit durch einen **Timeout-Watchdog** begrenzt wird:
- Konfigurierbares Timeout (Default z. B. 30 s) pro Eval-Aufruf.
- Bei Überschreiten: Watchdog beendet den Evaluierungsprozess (terminate) und meldet
  `timed out` (Fehlerantwort, JSON-RPC `isError: true` bzw. HTTP-Fehlerstatus).
- Antwort/Status beim Aufrufer (D9): **Default synchron bis Timeout**; mit Argument
  `async: true` startet `eval` sofort und antwortet mit **jobId**, `eval_status` pollt
  das Ergebnis (Job-Polling). Watchdog terminiert Jobs nach Ablauf des Timeouts.
- Eigene Priorität des Evaluierungsprozesses (nicht Scheduler-kritisch), sauberes Logging.
Das hält den MCP-Handler jederzeit antwortfähig und verhindert das beschriebene Verklemmungs-Problem.

## Empfehlung für RemoteControlMCP

1. Instanzbasiertes `RemoteControlMCP` mit Klassen-Fassade (B1).
2. JSON-RPC-2.0-Dispatch mit Methoden-Registry (B7), MCP-Lebenszyklus.
3. MCP-Tools: `eval`, `compile_method`, `screenshot`, `list_classes`/`class_summary` (Introspection).
4. MCP-Ressourcen (z. B. `image://` Systeminfo) und ein Prompt-Template (Basis).
5. Transport: **Streamable HTTP** (`POST /mcp`, JSON-Antwort, optional SSE); stdio optional (OP3).
6. Auth: optionaler Bearer-Token, Default-Bindung localhost (B5).
7. Fehlerhandling/Evaluierung in benannte Methoden zerlegt (B2, B3), Query-Parsing vereinheitlicht (B4).
8. **Eval asynchron (gefort) mit Timeout/Watchdog** (B10) – Handler bleibt antwortfähig, kein Scheduler-Verklemmen.
9. Tests-Package (B6); Fileout mit `!provides:`/`!requires:`; lokales Git mit Commits pro Schritt.
