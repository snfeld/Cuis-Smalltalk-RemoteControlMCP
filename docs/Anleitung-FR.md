# RemoteControlMCP – Guide (Français)

Ce guide décrit comment charger, démarrer et utiliser **RemoteControlMCP**. La version allemande se
trouve dans [Anleitung.md](Anleitung.md), la version anglaise dans [Anleitung-EN.md](Anleitung-EN.md),
en espagnol dans [Anleitung-ES.md](Anleitung-ES.md), en chinois dans [Anleitung-ZH.md](Anleitung-ZH.md)
et en japonais dans [Anleitung-JA.md](Anleitung-JA.md).

## 1. Vue d'ensemble

`RemoteControlMCP` est un serveur du Model Context Protocol (spécification `2025-06-18`) qui rend une
image Cuis-Smalltalk en cours d'exécution accessible aux LLM et agents via **Streamable HTTP**
(JSON-RPC 2.0). Il fournit onze outils (exécuter du code, compiler des méthodes, captures d'écran,
introspection, source de méthodes et usage de sélecteurs), une ressource (`image://status`) et un
prompt (`develop-in-cuis`).

**Le package est autonome** – il s'appuie sur `WebClient` (WebServer, WebUtils JSON) et
`Graphics-Files-Additional` (PNGReadWriter pour les captures d'écran) et ne nécessite **aucun** package
JSON séparé ni le pont `RemoteControl`.

## 2. Installation

Prérequis : Cuis 7.8 avec les packages **WebClient** et **Graphics-Files-Additional**. Le fichier
`RemoteControlMCP.pck.st` déclare ces dépendances avec `!requires:` ; un file-in interactif les
résout automatiquement dans le bon ordre.

Charger le package (dans l'image) :

```smalltalk
ChangeSet fileIn: '/workspace/RemoteControlMCP-clean/packages/RemoteControlMCP.pck.st' asFileEntry.
ChangeSet fileIn: '/workspace/RemoteControlMCP-clean/packages/Tests-RemoteControlMCP.pck.st' asFileEntry.  "optionnel : tests"
```

Le package inclut aussi la correction du parseur JSON de WebUtils (`jsonMapFrom:` avalait les clés
suivantes après un objet vide `{}`). La correction est incluse dans le package principal ; elle est
aussi disponible en fichier autonome sous `packages/WebUtils-jsonMapFrom-Fix.pck.st`.

Autrement via l'interface graphique : **Open… → Package Manager → Install**, choisir les fichiers
`.pck.st`.

## 3. Démarrer et arrêter

### Démarrage rapide (instance par défaut, port 2357, uniquement localhost, sans authentification)

```smalltalk
RemoteControlMCP start.        "démarre l'instance par défaut et la retourne"
RemoteControlMCP stop.         "l'arrête à nouveau"
```

### Instance propre avec configuration

```smalltalk
| server |
server := RemoteControlMCP new.
server port: 2357.                       "port, défaut 2357"
server interfaceAddress: '127.0.0.1'.    "adresse de liaison, défaut loopback"
server token: 'mon-token-secret'.        "token bearer ; nil désactive l'authentification"
server evalTimeout: 30.                  "délai d'évaluation synchrone en secondes, défaut 30"
server start.
```

Vérifier l'état : `server isRunning` (true/false). Arrêter : `server stop`. Redémarrer : `server restart`.

## 4. Configuration

| Méthode | Défaut | Signification |
|---------|--------|---------------|
| `port:` | `2357` | Port TCP (`defaultPort` dans la méthode de classe) |
| `interfaceAddress:` | `'127.0.0.1'` | Interface réseau à laquelle se lier |
| `token:` | `nil` (pas d'auth) | Token bearer optionnel ; sans/`nil` pas d'authentification |
| `evalTimeout:` | `30` | Délai pour les évaluations synchrones, en secondes |
| `endpointPath:` | `'/mcp'` | Chemin HTTP du point de terminaison MCP |
| `corsAllowedOrigin:` | `nil` (pas de CORS) | Origine CORS autorisée pour les clients navigateur (p. ex. `'*'` ou `'http://localhost:8080'`) ; active les en-têtes CORS + pré-vol OPTIONS (voir 5.1) |
| `tlsCertificateFile:` | `nil` (pas de TLS) | Chemin vers un fichier PEM contenant certificat + clé privée ; s'il est défini, le serveur sert uniquement en HTTPS (voir 5.2) |

## 5. Point de terminaison et authentification

- URL : `POST http://127.0.0.1:2357/mcp` (adapter le port/chemin configuré)
- Content-Type : `application/json`
- Si un token est défini, chaque requête doit envoyer :
  `Authorization: Bearer <token>`
- Token manquant ou incorrect → le serveur répond HTTP `401`.

### 5.1 CORS pour l'accès navigateur

Les clients MCP qui s'exécutent dans le navigateur (p. ex. un outil MCP web qui accède via `fetch`
depuis une page web) ont besoin des en-têtes CORS du serveur – sinon le navigateur bloque la réponse
avec une `erreur CORS`. Les en-têtes CORS sont **désactivés** par défaut. Activez-les via
`corsAllowedOrigin:` :

```smalltalk
server corsAllowedOrigin: '*'.                       "autoriser toutes les origines"
"ou seulement une origine précise :"
server corsAllowedOrigin: 'http://localhost:8080'.
```

Une fois une origine configurée, le serveur répond aux requêtes de pré-vol OPTIONS et ajoute à toutes
les réponses les en-têtes `Access-Control-Allow-Origin`, `-Allow-Methods: POST, OPTIONS`,
`-Allow-Headers: Content-Type, Authorization` et `Access-Control-Max-Age: 86400`.

**Sécurité :** avec `corsAllowedOrigin: '*'` et sans token, toute page web que vous ouvrez dans le
navigateur peut exécuter du Smalltalk arbitraire dans l'image. Par conséquent, avec `'*'`, utilisez
toujours un token bearer et/ou maintenez le serveur lié à `127.0.0.1`. Une origine précise est plus
sûre que `'*'`.

### 5.2 HTTPS/TLS

Par défaut, le serveur parle **HTTP** (sans TLS). Pour des connexions chiffrées, définissez
`tlsCertificateFile:` sur le chemin d'un fichier PEM contenant le certificat **et** la clé privée. Une
fois défini, le serveur n'accepte que les connexions HTTPS.

**Démarrage rapide sans OpenSSL :** un certificat exemple auto-signé (valable 100 ans) est fourni dans
`packages/example-cert/server.pem` – utilisez-le simplement ainsi :

```smalltalk
server tlsCertificateFile: 'packages/example-cert/server.pem'.
server start.
```

Ou générez vous-même le certificat avec OpenSSL (auto-signé, pour des besoins locaux/de test) :

```bash
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes \
  -subj '/CN=localhost'
cat cert.pem key.pem > server.pem
```

Activer :

```smalltalk
server tlsCertificateFile: '/chemin/vers/server.pem'.
server start.
```

Le point de terminaison est alors `https://127.0.0.1:2357/mcp`.

**Remarques :**
- Le `packages/example-cert/server.pem` fourni est destiné uniquement aux **tests locaux** et est
  distribué volontairement. Les certificats que vous générez contiennent la clé privée et ne doivent
  **pas** être ajoutés au dépôt – stockez-les lisibles uniquement par le processus du serveur
  (p. ex. `chmod 600`).
- Les clients sans configuration d'ancre de confiance n'acceptent pas le certificat auto-signé comme
  valide. Pour la production, utilisez un certificat d'une vraie autorité de certification
  (p. ex. Let's Encrypt).
- Sans `tlsCertificateFile:` le serveur reste en HTTP – le développement et les configurations
  existantes ne sont pas affectés.
- `curl -k` (ignorer la vérification) ou `curl --cacert server.pem` (faire confiance au fichier
  auto-signé).

## 6. Utilisation avec curl

Le cycle de vie MCP commence toujours par `initialize`, suivi de la notification
`notifications/initialized`. Ensuite, tous les outils, ressources et prompts sont disponibles.

### 6.1 initialize

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize",
       "params":{"protocolVersion":"2025-06-18","capabilities":{},
                 "clientInfo":{"name":"curl","version":"1.0"}}}'
```

Réponse (abrégée) :

```json
{"jsonrpc":"2.0","id":1,"result":{
  "protocolVersion":"2025-06-18",
  "capabilities":{"tools":{"listChanged":true},
                  "resources":{"listChanged":true},
                  "prompts":{"listChanged":true}},
  "serverInfo":{"name":"RemoteControlMCP","version":"0.1"},
  "instructions":"Use tools/eval ..."}}
```

### 6.2 Notification `initialized` et ping

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized","params":{}}'   # réponse 200 vide
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":2,"method":"ping"}'                              # {"result":{}}
```

### 6.3 tools/list

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}'
```

### 6.4 tools/call – eval (synchrone)

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":4,"method":"tools/call",
       "params":{"name":"eval","arguments":{"source":"7 * 8"}}}'
```

Réponse :

```json
{"jsonrpc":"2.0","id":4,"result":{"content":[{"text":"56","type":"text"}]}}
```

Arguments optionnels : `timeout` (secondes) et `async`. Une évaluation en erreur (p. ex. `1/0`) est
répondue avec `isError: true` et le message d'erreur.

### 6.5 tools/call – eval (asynchrone, interrogation de tâche)

Lancez les longues évaluations avec `"async":true`. Réponse : un `jobId` immédiat.

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":5,"method":"tools/call",
       "params":{"name":"eval","arguments":{"source":"[1 to: 1000000 do:[:i| i*i]] value. 42","async":true}}}'
# {"result":{"content":[{"text":"{\"jobId\": \"job-2\", \"status\": \"running\"}","type":"text"}]}}

curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":6,"method":"tools/call",
       "params":{"name":"eval_status","arguments":{"jobId":"job-2"}}}'
```

Tant que la tâche s'exécute : `{"jobId":"job-2","status":"running"}` – ensuite :

```json
{"jsonrpc":"2.0","id":6,"result":{"content":[
  {"text":"{\"jobId\": \"job-2\", \"status\": \"done\", \"result\": \"42\", \"error\": \"\"}","type":"text"}]}}
```

Si une tâche dépasse son délai, le watchdog la termine et `eval_status` signale
`"status":"timeout"`.

### 6.6 tools/call – eval_cancel (annuler une tâche)

Une tâche en cours (asynchrone ou encore active après un délai synchrone) peut être terminée avec
`eval_cancel` :

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":7,"method":"tools/call",
       "params":{"name":"eval_cancel","arguments":{"jobId":"job-2"}}}'
```

Réponse : l'état final de la tâche sous forme de texte JSON. Une tâche en cours est terminée et
répondue avec `{"jobId":"job-2","status":"cancelled"}` ; une tâche déjà terminée conserve son état
final. La tâche est ensuite retirée du registre.

### 6.7 tools/call – compile_method

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":8,"method":"tools/call",
       "params":{"name":"compile_method",
                 "arguments":{"className":"DocExample","source":"greeting\n\t^ 40 + 2","category":"accessing"}}}'
```

Réponse : le nom du sélecteur compilé (`"greeting"`). Arguments optionnels : `isClassSide`
(true/false), `category` (défaut `as yet unclassified`). Attention : cela modifie l'image en cours
d'exécution de façon permanente.

Remarque sur le quoting du shell : si le code source de la méthode doit contenir un littéral de chaîne
Smalltalk, le faire directement dans `curl -d '…'` est sujet à erreur (les deux apostrophes du littéral
de chaîne Smalltalk entrent en collision avec le quoting du shell). Il est plus propre d'utiliser un
fichier de payload :

```bash
cat > /tmp/compile.json <<'EOF'
{"jsonrpc":"2.0","id":8,"method":"tools/call",
 "params":{"name":"compile_method",
           "arguments":{"className":"DocExample","source":"greeting\n\t^ 'Bonjour !'","category":"accessing"}}}
EOF
curl -s -X POST http://127.0.0.1:2357/mcp --data @/tmp/compile.json
```

### 6.8 tools/call – screenshot

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":9,"method":"tools/call",
       "params":{"name":"screenshot","arguments":{}}}'
```

Réponse : `content[0].data` contient les données PNG encodées en Base64 (`"type":"image"`,
`"mimeType":"image/png"`). Recadrage optionnel sur une classe de morph : `{"morph":"SystemWindow","pad":8}`.

### 6.9 tools/call – method_source

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":10,"method":"tools/call",
       "params":{"name":"method_source","arguments":{"className":"RemoteControlMCP","selector":"serverVersion"}}}'
```

Réponse : `Class >> selector`, catégorie et code source. Avec `"includeSuperclasses":true`, la classe
définissante la plus proche dans l'ancêtre est nommée si la classe ne définit pas le sélecteur.

### 6.10 tools/call – selector_usage

```bash
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":11,"method":"tools/call",
       "params":{"name":"selector_usage","arguments":{"selector":"serverVersion"}}}'
```

Réponse : qui implémente et qui envoie le sélecteur, une ligne `Class >> selector` par entrée.

### 6.11 tools/call – introspection

```bash
# Toutes les classes (une par ligne)
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":12,"method":"tools/call","params":{"name":"list_classes","arguments":{}}}'

# Hiérarchie d'une classe (ascendance + arbre descendant indenté)
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":13,"method":"tools/call","params":{"name":"class_hierarchy","arguments":{"className":"RemoteControlMCP"}}}'

# Résumé d'une classe
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":14,"method":"tools/call","params":{"name":"class_summary","arguments":{"name":"RemoteControlMCP"}}}'

# État de l'image
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":15,"method":"tools/call","params":{"name":"image_status","arguments":{}}}'
```

### 6.12 Prompts

```bash
curl -s -X POST http://127.0.0.1:2357/mcp -d '{"jsonrpc":"2.0","id":16,"method":"prompts/list","params":{}}'
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":17,"method":"prompts/get","params":{"name":"develop-in-cuis"}}'
```

### 6.13 Ressources

```bash
curl -s -X POST http://127.0.0.1:2357/mcp -d '{"jsonrpc":"2.0","id":18,"method":"resources/list","params":{}}'
curl -s -X POST http://127.0.0.1:2357/mcp \
  -d '{"jsonrpc":"2.0","id":19,"method":"resources/read","params":{"uri":"image://status"}}'
```

## 7. Codes d'erreur et codes de statut

| HTTP | Signification |
|------|---------------|
| `200` | Réponse JSON-RPC (aussi réponse vide pour les notifications) |
| `401` | Token manquant ou incorrect |
| `405` | Mauvaise méthode HTTP (POST uniquement) |

| Code JSON-RPC | Signification |
|---------------|---------------|
| `-32700` | Erreur d'analyse (JSON invalide) |
| `-32600` | Requête invalide |
| `-32601` | Méthode introuvable |
| `-32602` | Paramètres invalides |
| `-32603` | Erreur interne |

## 8. Utilisation depuis un client MCP

Exemple de configuration pour un client MCP HTTP (p. ex. Claude Desktop) :

```json
{
  "mcpServers": {
    "cuis": {
      "type": "http",
      "url": "http://127.0.0.1:2357/mcp",
      "headers": { "Authorization": "Bearer mon-token-secret" }
    }
  }
}
```

Sans token, on omet l'entrée `headers`. Le client exécute lui-même `initialize` et peut alors appeler
`tools/call`, `prompts/get` et `resources/read`.

### OpenCode

OpenCode se connecte via un serveur MCP distant. Enregistrez le serveur dans le fichier `opencode.json`
dans le répertoire du projet (ou globalement sous `~/.config/opencode/opencode.json`) :

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "cuis": {
      "type": "remote",
      "url": "http://127.0.0.1:2357/mcp",
      "enabled": true,
      "headers": { "Authorization": "Bearer mon-token-secret" }
    }
  }
}
```

Remarques :

- `type` doit être `"remote"` (seuls les serveurs HTTP/Streamable HTTP sont pris en charge ; une entrée
  `command` n'est valable que pour les serveurs stdio locaux).
- Sans token, on omet l'entrée `headers`. Les valeurs prennent en charge les espaces réservés `{env:VAR}`
  et `{file:chemin}`, p. ex. `"Authorization": "Bearer {env:CUIS_MCP_TOKEN}"`.
- La configuration n'est chargée qu'au démarrage d'OpenCode – après des modifications, OpenCode doit
  être redémarré.
- Après le redémarrage, le serveur (p. ex. `/mcp`) apparaît dans l'espace de noms des outils et les
  outils `eval`, `compile_method`, `screenshot`, etc. sont disponibles dans l'agent.

### llama.cpp (WebUI) comme client MCP

La WebUI de `llama-server` dispose d'un client MCP intégré dans lequel vous pouvez enregistrer
RemoteControlMCP comme serveur MCP. Le client MCP s'exécute **dans le navigateur** – les requêtes
partent donc de la page web que le navigateur a chargée depuis `llama-server`. Si le navigateur accède
à RemoteControlMCP depuis une autre origine, la règle CORS s'applique (voir section 5.1).

**Scénario :** la machine A fait tourner `llama.cpp` comme serveur (WebUI sur
`http://<machine-A>:8080`). La machine B ouvre la WebUI dans le navigateur et fait aussi tourner
RemoteControlMCP (`http://127.0.0.1:2357/mcp`). Le navigateur charge la WebUI de A, mais les requêtes
MCP sont destinées au serveur de B – c'est une requête inter-origines.

**Variante 1 – connexion directe (recommandée, CORS dans RemoteControlMCP) :**

1. Démarrer RemoteControlMCP avec CORS activé (section 5.1), p. ex. :

   ```smalltalk
   server := RemoteControlMCP new.
   server port: 2357.
   server token: 'mon-token-secret'.                          "obligatoire avec '*'"
   server corsAllowedOrigin: '*'.                             "ou : http://<machine-A>:8080"
   server start.
   ```

2. Dans la WebUI, sous **MCP Servers**, ajouter un serveur : URL `http://127.0.0.1:2357/mcp`,
   transport **Streamable HTTP** (standard).

3. Ne **pas** activer l'interrupteur **"use llama-server proxy"** (uniquement pour la variante 2).

**Variante 2 – via le proxy CORS de llama.cpp :**

1. Démarrer `llama-server` sur la machine A avec `--ui-mcp-proxy` (expérimental, uniquement dans des
   réseaux de confiance). Le navigateur parle alors exclusivement avec llama-server (plus de problèmes
   de CORS) ; llama-server relaie les requêtes MCP vers RemoteControlMCP.
2. Dans la WebUI, activer l'interrupteur **"use llama-server proxy"** sur le serveur MCP. L'interrupteur
   n'apparaît que lors de la modification d'un serveur déjà créé.
3. Prérequis : le `llama-server` (machine A) doit pouvoir joindre RemoteControlMCP. Si RemoteControlMCP
   est lié uniquement à `127.0.0.1` (défaut), la variante proxy ne fonctionne que si les deux tournent
   sur la même machine. Sinon, se lier à une interface accessible et définir un token.

Remarques :

- **Utiliser `127.0.0.1` au lieu de `localhost` :** plusieurs utilisateurs signalent que les connexions
  avec `localhost` échouent, mais fonctionnent avec `127.0.0.1`. Garder les deux indications cohérentes.
- `--webui-mcp-proxy` est l'ancienne orthographe (obsolète) de `--ui-mcp-proxy`.
- Ordre des transports du client WebUI : WebSocket (si configuré explicitement) → Streamable HTTP
  (standard) → SSE (repli). RemoteControlMCP parle Streamable HTTP.
- Le proxy CORS est expérimental : **ne pas l'activer dans des environnements non fiables**.
- Détails et options actuelles : `tools/server/README.md` dans le dépôt llama.cpp.

## 9. Aperçu des outils

| Outil | Paramètres (obligatoires) | Paramètres optionnels | Réponse |
|-------|---------------------------|-----------------------|---------|
| `eval` | `source` | `timeout`, `async` | résultat (sync) ou `jobId` (async) |
| `eval_status` | `jobId` | – | état/résultat d'une tâche async |
| `eval_cancel` | `jobId` | – | annule une tâche ; état final |
| `compile_method` | `className`, `source` | `isClassSide`, `category` | nom du sélecteur compilé |
| `screenshot` | – | `morph`, `pad` | PNG en Base64 (`type: image`) |
| `list_classes` | – | – | liste des classes (une par ligne) |
| `class_summary` | `name` | – | résumé JSON de la classe |
| `class_hierarchy` | `className` | – | ascendance + arbre descendant |
| `method_source` | `className`, `selector` | `includeSuperclasses` | code source de la méthode |
| `selector_usage` | `selector` | – | implémenteurs/envoyeurs, `Class >> selector` |
| `image_status` | – | – | état JSON de l'image |

## 10. Remarques

- Les évaluations s'exécutent comme processus propres avec une priorité inférieure au gestionnaire
  HTTP ; un watchdog termine les tâches en retard après `evalTimeout`. Le serveur HTTP reste donc
  réactif même pendant de longues évaluations.
- Pour les longues évaluations, utilisez `async: true` et récupérez le résultat via `eval_status` ;
  les tâches en cours peuvent être annulées avec `eval_cancel`.
- `compile_method` et `eval` modifient l'image en cours d'exécution. Avec `Image save`, vous pouvez
  sauvegarder les modifications ou créer une instantané au préalable.
- Le serveur se lie par défaut uniquement à `127.0.0.1` – pour un accès depuis d'autres machines,
  modifier `interfaceAddress:` en conséquence (alors définir obligatoirement un token).
- CORS est désactivé par défaut. Pour les clients navigateur, définir `corsAllowedOrigin:` – avec `'*'`,
  utiliser absolument un token bearer (voir 5.1).
- Le package est autonome, sans pont `RemoteControl` ni package JSON séparé ; seuls `WebClient` et
  `Graphics-Files-Additional` (tous deux de la distribution Cuis 7.8) sont requis.
