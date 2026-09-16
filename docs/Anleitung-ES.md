# RemoteControlMCP – Manual 

Este manual describe cómo cargar, iniciar y usar **RemoteControlMCP**. La versión en alemán está en
[Anleitung.md](Anleitung.md), en inglés en [Anleitung-EN.md](Anleitung-EN.md), en francés en
[Anleitung-FR.md](Anleitung-FR.md), en chino en [Anleitung-ZH.md](Anleitung-ZH.md) y en japonés en
[Anleitung-JA.md](Anleitung-JA.md).

## 1. Resumen

`RemoteControlMCP` es un servidor del Model Context Protocol (especificación `2025-06-18`) que hace
accesible una imagen Cuis-Smalltalk en ejecución a LLMs y agentes a través de **HTTP transmisible**
(JSON-RPC 2.0). Proporciona once herramientas (ejecutar código, compilar métodos, capturas de
pantalla, introspección, fuente de métodos y uso de selectores), un recurso (`image://status`) y un
prompt (`develop-in-cuis`).

**El paquete es autónomo** – se basa en `WebClient` (WebServer, WebUtils JSON) y
`Graphics-Files-Additional` (PNGReadWriter para capturas de pantalla) y **no** necesita un paquete
JSON separado ni el puente `RemoteControl`.

## 2. Instalación

Requisitos: Cuis 7.8 con los paquetes **WebClient** y **Graphics-Files-Additional**. El archivo
`RemoteControlMCP.pck.st` declara estas dependencias con `!requires:`; un file-in interactivo las
resuelve automáticamente en el orden correcto.

Cargar el paquete (en la imagen):

```smalltalk
ChangeSet fileIn: '/workspace/RemoteControlMCP-clean/packages/RemoteControlMCP.pck.st' asFileEntry.
ChangeSet fileIn: '/workspace/RemoteControlMCP-clean/packages/Tests-RemoteControlMCP.pck.st' asFileEntry.  "opcional: pruebas"
```

El paquete incluye también la corrección del analizador JSON de WebUtils (`jsonMapFrom:` se tragaba
las claves siguientes tras un objeto vacío `{}`). La corrección va dentro del paquete principal; está
disponible además como archivo independiente en `packages/WebUtils-jsonMapFrom-Fix.pck.st`.

Alternativamente desde la GUI: **Open… → Package Manager → Install**, elegir los archivos `.pck.st`.

## 3. Iniciar y detener

### Inicio rápido (instancia predeterminada, puerto 2357, solo localhost, sin autenticación)

```smalltalk
RemoteControlMCP start.        "inicia la instancia predeterminada y la devuelve"
RemoteControlMCP stop.         "la detiene de nuevo"
```

### Instancia propia con configuración

```smalltalk
| server |
server := RemoteControlMCP new.
server port: 2357.                       "puerto, predeterminado 2357"
server interfaceAddress: '127.0.0.1'.    "dirección de enlace, predeterminada loopback"
server token: 'mi-token-secreto'.        "token bearer; nil desactiva la autenticación"
server evalTimeout: 30.                  "tiempo de espera de eval síncrono en segundos, predeterminado 30"
server start.
```

Comprobar el estado: `server isRunning` (true/false). Detener: `server stop`. Reiniciar: `server restart`.

## 4. Configuración

| Método | Predeterminado | Significado |
|--------|----------------|-------------|
| `port:` | `2357` | Puerto TCP (`defaultPort` en el método de clase) |
| `interfaceAddress:` | `'127.0.0.1'` | Interfaz de red a la que se enlaza |
| `token:` | `nil` (sin autenticación) | Token bearer opcional; sin/`nil` no hay autenticación |
| `evalTimeout:` | `30` | Tiempo de espera para evals síncronos, en segundos |
| `endpointPath:` | `'/mcp'` | Ruta HTTP del punto final MCP |
| `corsAllowedOrigin:` | `nil` (sin CORS) | Origen CORS permitido para clientes de navegador (p. ej. `'*'` o `'http://localhost:8080'`); activa las cabeceras CORS + preflight OPTIONS (ver 5.1) |
| `tlsCertificateFile:` | `nil` (sin TLS) | Ruta a un archivo PEM con certificado + clave privada; si se establece, el servidor atiende solo por HTTPS (ver 5.2) |

## 5. Punto final y autenticación

- URL: `POST http://127.0.0.1:2357/mcp` (ajustar puerto/ruta según configuración)
- Content-Type: `application/json`
- Si hay un token configurado, cada solicitud debe enviar:
  `Authorization: Bearer <token>`
- Sin token o con token incorrecto, el servidor responde con HTTP `401`.

### 5.1 CORS para acceso desde el navegador

Los clientes MCP que se ejecutan en el navegador (p. ej. una herramienta MCP basada en web que accede
mediante `fetch` desde una página web) necesitan cabeceras CORS del servidor – de lo contrario el
navegador bloquea la respuesta con un `CORS-Error`. Las cabeceras CORS están **desactivadas** por
defecto. Actívelas mediante `corsAllowedOrigin:`:

```smalltalk
server corsAllowedOrigin: '*'.                       "permitir todos los orígenes"
"o solo un origen concreto:"
server corsAllowedOrigin: 'http://localhost:8080'.
```

Si hay un origen configurado, el servidor responde a las solicitudes de preflight OPTIONS y añade a
todas las respuestas las cabeceras `Access-Control-Allow-Origin`,
`-Allow-Methods: POST, OPTIONS`, `-Allow-Headers: Content-Type, Authorization` y
`Access-Control-Max-Age: 86400`.

**Seguridad:** con `corsAllowedOrigin: '*'` y sin token, cualquier página web que abra en el navegador
puede ejecutar Smalltalk arbitrario en la imagen. Por eso, con `'*'` use siempre un token bearer y/o
mantenga el servidor enlazado a `127.0.0.1`. Un origen concreto es más seguro que `'*'`.

### 5.2 HTTPS/TLS

Por defecto el servidor habla **HTTP** (sin TLS). Para conexiones cifradas establezca
`tlsCertificateFile:` a la ruta de un archivo PEM que contenga el certificado **y** la clave privada.
Una vez configurado, el servidor solo acepta conexiones HTTPS.

**Inicio rápido sin OpenSSL:** un certificado de ejemplo autofirmado (válido 100 años) está incluido en
`packages/example-cert/server.pem` – úselo simplemente así:

```smalltalk
server tlsCertificateFile: 'packages/example-cert/server.pem'.
server start.
```

Alternativamente, generar el certificado usted mismo con OpenSSL (autofirmado, para fines
locales/de prueba):

```bash
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes \
  -subj '/CN=localhost'
cat cert.pem key.pem > server.pem
```

Activar:

```smalltalk
server tlsCertificateFile: '/ruta/hacia/server.pem'.
server start.
```

El punto final es entonces `https://127.0.0.1:2357/mcp`.

**Notas:**
- El `packages/example-cert/server.pem` incluido es solo para **pruebas locales** y se distribuye
  deliberadamente. Los certificados generados por usted contienen la clave privada y **no** deben
  incluirse en el repositorio – guárdelos legibles solo por el proceso del servidor (p. ej.
  `chmod 600`).
- Los clientes sin configuración de anclas de confianza no aceptan el certificado autofirmado como
  válido. Para uso en producción use un certificado de una CA real (p. ej. Let's Encrypt).
- Sin `tlsCertificateFile:` el servidor permanece en HTTP – el desarrollo y las configuraciones
  existentes no se ven afectados.
- `curl -k` (omitir verificación) o `curl --cacert server.pem` (confiar en el archivo autofirmado).

## 6. Uso con curl

El ciclo de vida MCP comienza siempre con `initialize`, seguido de la notificación
`notifications/initialized`. Después están disponibles todas las herramientas, recursos y prompts.

### 6.1 initialize

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize",
       "params":{"protocolVersion":"2025-06-18","capabilities":{},
                 "clientInfo":{"name":"curl","version":"1.0"}}}'
```

Respuesta (resumida):

```json
{"jsonrpc":"2.0","id":1,"result":{
  "protocolVersion":"2025-06-18",
  "capabilities":{"tools":{"listChanged":true},
                  "resources":{"listChanged":true},
                  "prompts":{"listChanged":true}},
  "serverInfo":{"name":"RemoteControlMCP","version":"0.1"},
  "instructions":"Use tools/eval ..."}}
```

### 6.2 Notificación `initialized` y ping

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'   # respuesta 200 vacía
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":2,"method":"ping"}'                              # {"result":{}}
```

### 6.3 tools/list

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}'
```

### 6.4 tools/call – eval (síncrono)

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":4,"method":"tools/call",
       "params":{"name":"eval","arguments":{"source":"7 * 8"}}}'
```

Respuesta:

```json
{"jsonrpc":"2.0","id":4,"result":{"content":[{"text":"56","type":"text"}]}}
```

Argumentos opcionales: `timeout` (segundos) y `async`. Una evaluación con error (p. ej. `1/0`) se
responde con `isError: true` y el mensaje de error.

### 6.5 tools/call – eval (asíncrono, sondeo de trabajo)

Inicie evals largos con `"async":true`. Respuesta: un `jobId` inmediato.

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":5,"method":"tools/call",
       "params":{"name":"eval","arguments":{"source":"[1 to: 1000000 do:[:i| i*i]] value. 42","async":true}}}'
# {"result":{"content":[{"text":"{\"jobId\": \"job-2\", \"status\": \"running\"}","type":"text"}]}}

curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":6,"method":"tools/call",
       "params":{"name":"eval_status","arguments":{"jobId":"job-2"}}}'
```

Mientras el trabajo está en ejecución: `{"jobId":"job-2","status":"running"}` – después:

```json
{"jsonrpc":"2.0","id":6,"result":{"content":[
  {"text":"{\"jobId\": \"job-2\", \"status\": \"done\", \"result\": \"42\", \"error\": \"\"}","type":"text"}]}}
```

Si un trabajo excede su tiempo de espera, el watchdog lo termina y `eval_status` informa
`"status":"timeout"`.

### 6.6 tools/call – eval_cancel (cancelar un trabajo)

Un trabajo en ejecución (asíncrono o aún en marcha tras un timeout síncrono) puede terminarse con
`eval_cancel`:

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":7,"method":"tools/call",
       "params":{"name":"eval_cancel","arguments":{"jobId":"job-2"}}}'
```

Respuesta: el estado final del trabajo como texto JSON. Un trabajo en ejecución se termina y se
responde con `{"jobId":"job-2","status":"cancelled"}`; un trabajo ya terminado conserva su estado
final. Después, el trabajo se elimina del registro.

### 6.7 tools/call – compile_method

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":8,"method":"tools/call",
       "params":{"name":"compile_method",
                 "arguments":{"className":"DocExample","source":"greeting\n\t^ 40 + 2","category":"accessing"}}}'
```

Respuesta: el nombre del selector compilado (`"greeting"`). Argumentos opcionales: `isClassSide`
(true/false), `category` (predeterminado `as yet unclassified`). Atención: esto cambia la imagen en
ejecución de forma permanente.

Nota sobre el entrecomillado en el shell: si el código fuente del método debe contener un literal de
cadena Smalltalk, hacerlo directamente en `curl -d '…'` es propenso a errores (las dos comillas
simples del literal de cadena Smalltalk colisionan con el entrecomillado del shell). Es más limpio
usar un archivo de payload:

```bash
cat > /tmp/compile.json <<'EOF'
{"jsonrpc":"2.0","id":8,"method":"tools/call",
 "params":{"name":"compile_method",
           "arguments":{"className":"DocExample","source":"greeting\n\t^ '¡Hola!'","category":"accessing"}}}
EOF
curl -s -X POST http://127.0.0.1:2357/mcp --data @/tmp/compile.json
```

### 6.8 tools/call – screenshot

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":9,"method":"tools/call",
       "params":{"name":"screenshot","arguments":{}}}'
```

Respuesta: `content[0].data` contiene los datos PNG codificados en Base64 (`"type":"image"`,
`"mimeType":"image/png"`). Recorte opcional a una clase de morph: `{"morph":"SystemWindow","pad":8}`.

### 6.9 tools/call – method_source

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":10,"method":"tools/call",
       "params":{"name":"method_source","arguments":{"className":"RemoteControlMCP","selector":"serverVersion"}}}'
```

Respuesta: `Class >> selector`, categoría y código fuente. Con `"includeSuperclasses":true` se nombra
la clase definidora más próxima en la herencia si la clase no define el método.

### 6.10 tools/call – selector_usage

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":11,"method":"tools/call",
       "params":{"name":"selector_usage","arguments":{"selector":"serverVersion"}}}'
```

Respuesta: quién implementa y quién envía el selector, una línea `Class >> selector` por entrada.

### 6.11 tools/call – introspección

```bash
# Todas las clases (una por línea)
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"list_classes","arguments":{}}}'

# Jerarquía de una clase (ascendencia + árbol descendiente sangrado)
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"class_hierarchy","arguments":{"className":"RemoteControlMCP"}}}'

# Resumen de una clase
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"class_summary","arguments":{"name":"RemoteControlMCP"}}}'

# Estado de la imagen
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":15,"method":"tools/call","params":{"name":"image_status","arguments":{}}}'
```

### 6.12 Prompts

```bash
curl -s -X POST http://127.0.0.1:2357/mcp -d '{"jsonrpc":"2.0","id":16,"method":"prompts/list","params":{}}'
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":17,"method":"prompts/get","params":{"name":"develop-in-cuis"}}'
```

### 6.13 Recursos

```bash
curl -s -X POST http://127.0.0.1:2357/mcp -d '{"jsonrpc":"2.0","id":18,"method":"resources/list","params":{}}'
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":19,"method":"resources/read","params":{"uri":"image://status"}}'
```

## 7. Códigos de error y de estado

| HTTP | Significado |
|------|-------------|
| `200` | Respuesta JSON-RPC (también respuesta vacía para notificaciones) |
| `401` | Token ausente o incorrecto |
| `405` | Método HTTP incorrecto (solo POST) |

| Código JSON-RPC | Significado |
|-----------------|-------------|
| `-32700` | Error de análisis (JSON no válido) |
| `-32600` | Solicitud no válida |
| `-32601` | Método no encontrado |
| `-32602` | Parámetros no válidos |
| `-32603` | Error interno |

## 8. Uso desde un cliente MCP

Ejemplo de configuración para un cliente MCP HTTP (p. ej. Claude Desktop):

```json
{
  "mcpServers": {
    "cuis": {
      "type": "http",
      "url": "http://127.0.0.1:2357/mcp",
      "headers": { "Authorization": "Bearer mi-token-secreto" }
    }
  }
}
```

Sin token se omite la entrada `headers`. El cliente ejecuta `initialize` por sí mismo y puede entonces
llamar a `tools/call`, `prompts/get` y `resources/read`.

### OpenCode

OpenCode se conecta a través de un servidor MCP remoto. Registre el servidor en el archivo
`opencode.json` en el directorio del proyecto (o globalmente en `~/.config/opencode/opencode.json`):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "cuis": {
      "type": "remote",
      "url": "http://127.0.0.1:2357/mcp",
      "enabled": true,
      "headers": { "Authorization": "Bearer mi-token-secreto" }
    }
  }
}
```

Notas:

- `type` debe ser `"remote"` (solo se admiten servidores HTTP/Streamable HTTP; una entrada `command`
  solo es válida para servidores stdio locales).
- Sin token se omite la entrada `headers`. Los valores admiten los marcadores de posición `{env:VAR}`
  y `{file:ruta}`, p. ej. `"Authorization": "Bearer {env:CUIS_MCP_TOKEN}"`.
- La configuración solo se carga al iniciar OpenCode – tras los cambios debe reiniciarse OpenCode.
- Tras el reinicio, el servidor (p. ej. `/mcp`) aparece en el espacio de nombres de herramientas y las
  herramientas `eval`, `compile_method`, `screenshot`, etc. están disponibles en el agente.

### llama.cpp (WebUI) como cliente MCP

La WebUI de `llama-server` incluye un cliente MCP integrado en el que puede registrar RemoteControlMCP
como servidor MCP. El cliente MCP se ejecuta **en el navegador** – las solicitudes, por tanto, parten
de la página web que el navegador ha cargado desde `llama-server`. Si el navegador accede a
RemoteControlMCP desde otro origen, se aplica la regla CORS (ver sección 5.1).

**Escenario:** el equipo A ejecuta `llama.cpp` como servidor (WebUI en `http://<equipo-A>:8080`).
El equipo B abre la WebUI en el navegador y además ejecuta RemoteControlMCP
(`http://127.0.0.1:2357/mcp`). El navegador carga la WebUI de A, pero las solicitudes MCP se dirigen al
servidor de B – se trata de una solicitud entre orígenes.

**Variante 1 – conexión directa (recomendada, CORS en RemoteControlMCP):**

1. Iniciar RemoteControlMCP con CORS activado (sección 5.1), p. ej.:

   ```smalltalk
   server := RemoteControlMCP new.
   server port: 2357.
   server token: 'mi-token-secreto'.                          "obligatorio con '*'"
   server corsAllowedOrigin: '*'.                            "o: http://<equipo-A>:8080"
   server start.
   ```

2. En la WebUI, en **MCP Servers**, añadir un servidor: URL `http://127.0.0.1:2357/mcp`, transporte
   **Streamable HTTP** (estándar).

3. **No** activar el conmutador **"use llama-server proxy"** (solo para la variante 2).

**Variante 2 – mediante el proxy CORS de llama.cpp:**

1. Iniciar `llama-server` en el equipo A con `--ui-mcp-proxy` (experimental, solo en redes de
   confianza). El navegador habla entonces exclusivamente con llama-server (sin más problemas de
   CORS); llama-server reenvía las solicitudes MCP a RemoteControlMCP.
2. En la WebUI, en el servidor MCP, activar el conmutador **"use llama-server proxy"**. El conmutador
   solo aparece al editar un servidor ya creado.
3. Requisito: el `llama-server` (equipo A) debe poder alcanzar a RemoteControlMCP. Si RemoteControlMCP
   se enlaza solo a `127.0.0.1` (predeterminado), la variante con proxy solo funciona si ambos se
   ejecutan en el mismo equipo. De lo contrario, enlazar a una interfaz accesible y configurar un
   token.

Notas:

- **Usar `127.0.0.1` en lugar de `localhost`:** varios usuarios informan de que las conexiones con
  `localhost` fallan, pero con `127.0.0.1` funcionan. Mantener ambas indicaciones consistentes.
- `--webui-mcp-proxy` es la forma antigua (obsoleta) de `--ui-mcp-proxy`.
- Orden de transporte del cliente WebUI: WebSocket (si se configura explícitamente) → Streamable HTTP
  (estándar) → SSE (respaldo). RemoteControlMCP habla Streamable HTTP.
- El proxy CORS es experimental: **no activarlo en entornos no confiables**.
- Detalles y opciones actuales: `tools/server/README.md` en el repositorio de llama.cpp.

## 9. Resumen de herramientas

| Herramienta | Parámetros (obligatorios) | Parámetros opcionales | Respuesta |
|-------------|---------------------------|-----------------------|-----------|
| `eval` | `source` | `timeout`, `async` | resultado (sync) o `jobId` (async) |
| `eval_status` | `jobId` | – | estado/resultado de un trabajo async |
| `eval_cancel` | `jobId` | – | cancela un trabajo; estado final |
| `compile_method` | `className`, `source` | `isClassSide`, `category` | nombre del selector compilado |
| `screenshot` | – | `morph`, `pad` | PNG en Base64 (`type: image`) |
| `list_classes` | – | – | lista de clases (una por línea) |
| `class_summary` | `name` | – | resumen JSON de la clase |
| `class_hierarchy` | `className` | – | ascendencia + árbol descendiente |
| `method_source` | `className`, `selector` | `includeSuperclasses` | código fuente del método |
| `selector_usage` | `selector` | – | implementadores/envíos, `Class >> selector` |
| `image_status` | – | – | estado JSON de la imagen |

## 10. Notas

- Los evals se ejecutan como procesos propios con prioridad inferior al manejador HTTP; un watchdog
  termina los trabajos vencidos después de `evalTimeout`. El servidor HTTP sigue respondiendo incluso
  durante evals largos.
- Para evals largos use `async: true` y recoja el resultado con `eval_status`; los trabajos en
  ejecución pueden cancelarse con `eval_cancel`.
- `compile_method` y `eval` modifican la imagen en ejecución. Con `Image save` puede guardar los
  cambios o crear una instantánea antes.
- El servidor se enlaza por defecto solo a `127.0.0.1` – para acceder desde otros equipos cambie
  `interfaceAddress:` en consecuencia (entonces configure obligatoriamente un token).
- CORS está desactivado por defecto. Para clientes de navegador establezca `corsAllowedOrigin:` – con
  `'*'` use sin falta un token bearer (ver 5.1).
- El paquete es autónomo, sin puente `RemoteControl` ni paquete JSON separado; solo se necesitan
  `WebClient` y `Graphics-Files-Additional` (ambos de la distribución Cuis 7.8).
