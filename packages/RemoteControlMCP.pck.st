'From Cuis7.8 [latest update: #7977] on 15 September 2026 at 9:08:12 am'!
'Description '!
!provides: 'RemoteControlMCP' 1 3!
!requires: 'WebClient' 1 38 nil!
!requires: 'Graphics-Files-Additional' 1 nil nil!
SystemOrganization addCategory: #RemoteControlMCP!
SystemOrganization addCategory: #'RemoteControlMCP-http'!


!classDefinition: #McpEvalJob category: #RemoteControlMCP!
Object subclass: #McpEvalJob
	instanceVariableNames: 'id source timeout state result errorDescription process done'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'RemoteControlMCP'!
!classDefinition: 'McpEvalJob class' category: #RemoteControlMCP!
McpEvalJob class
	instanceVariableNames: ''!

!classDefinition: #RemoteControlMCP category: #RemoteControlMCP!
Object subclass: #RemoteControlMCP
	instanceVariableNames: 'port interfaceAddress server token endpointPath messagesPath protocolVersion serverName serverVersion evalTimeout jobs jobCounter sessions sessionCounter methodRegistry toolRegistry corsAllowedOrigin tlsCertificateFile'
	classVariableNames: 'DefaultInstance'
	poolDictionaries: ''
	category: 'RemoteControlMCP'!
!classDefinition: 'RemoteControlMCP class' category: #RemoteControlMCP!
RemoteControlMCP class
	instanceVariableNames: ''!

!classDefinition: #McpWebServer category: #'RemoteControlMCP-http'!
WebServer subclass: #McpWebServer
	instanceVariableNames: 'mcpOwner'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'RemoteControlMCP-http'!
!classDefinition: 'McpWebServer class' category: #'RemoteControlMCP-http'!
McpWebServer class
	instanceVariableNames: ''!

!classDefinition: #McpSseSession category: #'RemoteControlMCP-http'!
Object subclass: #McpSseSession
	instanceVariableNames: 'id stream writeMutex open'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'RemoteControlMCP-http'!
!classDefinition: 'McpSseSession class' category: #'RemoteControlMCP-http'!
McpSseSession class
	instanceVariableNames: ''!

!classDefinition: #McpEvalRequestor category: #RemoteControlMCP!
Object subclass: #McpEvalRequestor
	instanceVariableNames: 'workspace'
	classVariableNames: ''
	poolDictionaries: ''
	category: 'RemoteControlMCP'!
!classDefinition: 'McpEvalRequestor class' category: #RemoteControlMCP!
McpEvalRequestor class
	instanceVariableNames: ''!


!McpEvalJob methodsFor: 'private' stamp: 'sf 13/Aug/2026 06:42:20'!
asStatusDictionary
	"Answer the JSON-safe status dictionary for this job."
	^ Dictionary newFromPairs: {
		'jobId'. id.
		'status'. state.
		'result'. result.
		'error'. errorDescription }! !

!McpEvalJob methodsFor: 'private' stamp: 'sf 06/Sep/2026'!
doEvaluate
	"Evaluate the source with interactive Workspace auto-binding semantics
	(fresh McpEvalRequestor per job, so no state leaks between evaluations).
	Set result / errorDescription / state; the surrounding evaluateSource still
	resumes stray Notifications and signals done in all cases."
	| requestor dict |
	requestor := McpEvalRequestor new.
	dict := requestor evaluate: source.
	(dict at: #ok) ifTrue: [
		self result: (dict at: #value).
		self state: 'done' ]
	ifFalse: [
		self errorDescription: (dict at: #error), (self formatStack: (dict at: #stack ifAbsent: [ '' ])).
		self state: 'error' ]! !

!McpEvalJob methodsFor: 'private' stamp: 'sf 13/Aug/2026 06:42:10'!
initialize
	super initialize.
	timeout := 30.
	state := 'running'.
	result := ''.
	errorDescription := ''.
	done := Semaphore new! !

!McpEvalJob methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:42:14'!
done
	^ done! !

!McpEvalJob methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:42:13'!
errorDescription
	^ errorDescription! !

!McpEvalJob methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:42:13'!
errorDescription: anObject
	errorDescription := anObject! !

!McpEvalJob methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:42:10'!
id
	^ id! !

!McpEvalJob methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:42:10'!
id: anObject
	id := anObject! !

!McpEvalJob methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:42:14'!
isRunning
	^ state = 'running'! !

!McpEvalJob methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:42:13'!
result
	^ result! !

!McpEvalJob methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:42:13'!
result: anObject
	result := anObject! !

!McpEvalJob methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:42:11'!
source
	^ source! !

!McpEvalJob methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:42:11'!
source: anObject
	source := anObject! !

!McpEvalJob methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:42:12'!
state
	^ state! !

!McpEvalJob methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:42:12'!
state: anObject
	state := anObject! !

!McpEvalJob methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:42:12'!
timeout
	^ timeout! !

!McpEvalJob methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:42:11'!
timeout: anObject
	timeout := anObject! !

!McpEvalJob methodsFor: 'private' stamp: 'AB 15/Sep/2026 14:15:00'!
formatStack: aString
	"Answer aString as a readable stack-trace suffix, or the empty string."
	aString isEmpty ifTrue: [ ^ '' ].
	^ String newLineString, String newLineString, 'Stack:', String newLineString, aString! !

!McpEvalJob methodsFor: 'control' stamp: 'sf 06/Sep/2026'!
evaluateSource
	"Evaluate the source. Resume harmless Notifications (the same ones
	`safelyCompile:` resumes: InMidstOfFileinNotification, UndeclaredVariableWarning,
	...) so the job cannot hang in a headless UI default-notifier; catch Errors
	and update state. Signal done in ALL cases so waiters never spin forever.
	The McpEvaluating flag (set/cleared by McpEvalRequestor) makes headless
	PopUpMenu confirm:/inform: auto-answer instead of spinning in a modal loop."
	[
		self doEvaluate
	] on: Notification do: [ :ex | ex resume: true ]
		on: Error do: [ :ex |
			self errorDescription: ex description, (self formatStack: (self class stackTraceFor: ex)).
			self state: 'error' ].
	self done signal! !

!McpEvalJob methodsFor: 'control' stamp: 'sf 13/Aug/2026 06:55:56'!
markTimedOutIfStillRunning
	"Mark a still-running job as timed out when the server is stopping."
	self isRunning ifTrue: [
		self terminate.
		self errorDescription: 'Server stopped' ]! !

!McpEvalJob methodsFor: 'control' stamp: 'sf 06/Sep/2026'!
run
	"Evaluate the source in a forked process. The process runs one priority below
	user so that a CPU-bound eval cannot starve the HTTP handler or the watchdog.
	Remember the process so a timeout can really terminate it.
	NOTE: Since Cuis 2022 forkAt: answers nil (by design, jmv). Use
	newProcess + resume, else `process` record and thus timeout-termination
	silently never works. No exclamation mark anywhere in this comment (chunk format)."
	process := [ self evaluateSource ] newProcess.
	process priority: Processor userSchedulingPriority - 1.
	process name: 'McpEval-', id.
	process resume! !

!McpEvalJob methodsFor: 'control' stamp: 'sf 06/Sep/2026'!
terminate
	"Terminate a still-running job process and mark it terminated."
	process ifNotNil: [ process terminate ].
	state := 'timedOut'! !

!McpEvalJob methodsFor: 'control' stamp: 'sf 06/Sep/2026'!
waitForCompletionUpTo: seconds
	"Wait until the job finishes or the deadline elapses. Terminate on deadline.
	Note: in Cuis waitTimeoutMSecs: answers true when the deadline expired."
	^ self waitForCompletionUpTo: seconds killOnTimeout: true! !

!McpEvalJob methodsFor: 'control' stamp: 'sf 06/Sep/2026'!
waitForCompletionUpTo: seconds killOnTimeout: shouldKill
	"Wait until the job finishes or the deadline elapses. When the deadline
	elapsed: if shouldKill, terminate the process and mark the job timed out;
	else leave the job running in the background (it stays registered and can be
	polled via eval_status). Answer job asStatusDictionary.
	Note: in Cuis waitTimeoutMSecs: answers true when the deadline expired."
	(done waitTimeoutMSecs: seconds * 1000) ifTrue: [
		shouldKill ifTrue: [
			self terminate.
			self state: 'timedOut'.
			self errorDescription: 'Timed out after ', seconds printString, ' seconds' ] ].
	^ self asStatusDictionary! !

!McpEvalJob class methodsFor: 'debugging' stamp: 'AB 15/Sep/2026 14:00:00'!
frameDescriptionOf: aContext
	"Answer one debugger line for aContext, e.g. 'Symbol >> #fooBarBaz', appending
	the receiver's class when it differs from the method's class (inherited code)."

	| method receiverClass |
	method := aContext method.
	^ String streamContents: [ :stream |
		stream nextPutAll: method methodClass name.
		stream nextPutAll: ' >> '.
		stream nextPutAll: (method selector ifNil: [ method methodClass name ] ifNotNil: [ method selector ]).
		receiverClass := [ aContext receiver class ] on: Error do: [ :ex | nil ].
		(receiverClass notNil and: [ receiverClass ~~ method methodClass ]) ifTrue: [
			stream nextPutAll: '   (receiver: '.
			stream nextPutAll: receiverClass name.
			stream nextPutAll: ')' ] ]! !

!McpEvalJob class methodsFor: 'debugging' stamp: 'AB 15/Sep/2026 14:00:00'!
stackTraceFor: anException
	"Answer a readable call trace for anException, one frame per line (first 30
	frames). Empty string when no signaler context is available."

	| context frames |
	context := anException signalerContext.
	context ifNil: [ ^ '' ].
	frames := context stack.
	^ String streamContents: [ :stream |
		(frames first: (frames size min: 30)) do: [ :each |
			stream nextPutAll: (self frameDescriptionOf: each).
			stream newLine ] ]! !

!McpEvalRequestor methodsFor: 'private' stamp: 'sf 06/Sep/2026'!
initialize
	super initialize.
	workspace := Workspace new! !

!McpEvalRequestor methodsFor: 'compiling' stamp: 'sf 06/Sep/2026'!
bindingOf: aString
	"Called by the compiler when looking up variable names during do-it compilation.
	Delegates to a fresh Workspace so undeclared lowercase variables become
	workspace auto-bindings (the same as an interactive Workspace do-it), while a
	fresh Workspace per evaluation keeps state from leaking between jobs."
	^ workspace bindingOf: aString! !

!McpEvalRequestor methodsFor: 'compiling' stamp: 'sf 06/Sep/2026'!
evaluate: aString
	"Evaluate aString with interactive Workspace semantics: undeclared lowercase
	variables become workspace auto-bindings (resolved via bindingOf:), instead of
	being left as undeclared and tripping later assignment checks. Answer a
	Dictionary: #ok -> true + #value (printString), or #ok -> false + #error.
	While evaluating, set the global McpEvaluating flag so headless modal dialogs
	(PopUpMenu confirm:/inform:) auto-answer instead of hanging forever."
	| compiler methodNode method value |
	Smalltalk at: #McpEvaluating put: true.
^ [
			[ "evaluate the source now"
				compiler := Compiler new.
				methodNode := [
					compiler
						compileNoPattern: aString
						in: UndefinedObject
						context: nil
						notifying: self
						ifFail: [ ^ { #ok -> false. #error -> 'compile failure' } asDictionary ] ]
					on: UndeclaredVariableReference
					do: [ :ex | ex resume: ex defaultAction ].
				methodNode ifNil: [ ^ { #ok -> false. #error -> 'no method node' } asDictionary ].
				methodNode block returnLast.
				method := methodNode generate.
				method methodNode: methodNode.
				value := compiler
					evaluateMethod: method
					to: nil
					logged: false
					profiled: false.
				{ #ok -> true. #value -> (value ifNil: [ 'nil' ] ifNotNil: [ value printString ]) } asDictionary ]
				on: Error
				do: [ :ex |
					{ #ok -> false. #error -> ex description. #stack -> (McpEvalJob stackTraceFor: ex) }
						asDictionary ] ]
			ensure: [ Smalltalk at: #McpEvaluating put: false ]! !

!McpEvalRequestor methodsFor: 'editor interface' stamp: 'sf 06/Sep/2026'!
interactive
	^ true! !

!McpEvalRequestor methodsFor: 'editor interface' stamp: 'sf 06/Sep/2026'!
notify: aString at: anInteger in: aStream
	"Syntax error reporting without a UI: the compile fails via ifFail:/the
	UndeclaredVariableReference handler. No source editing is performed."
	^ self! !

!McpEvalRequestor methodsFor: 'editor interface' stamp: 'sf 06/Sep/2026'!
selectFrom: start to: stop
	^ self! !

!McpEvalRequestor methodsFor: 'editor interface' stamp: 'sf 06/Sep/2026'!
selectInvisiblyFrom: start to: stop
	^ self! !

!McpEvalRequestor methodsFor: 'editor interface' stamp: 'sf 06/Sep/2026'!
selectionInterval
	^ 1 to: 0! !

!McpEvalRequestor methodsFor: 'editor interface' stamp: 'sf 06/Sep/2026'!
text
	"Answer the source text for the current evaluation. Used by the Parser for
	temp-declaration error-correction (finding pipe characters in the source).
 Returning empty is safe: no pipe positions are found, no false removals."
	^ ''! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 13/Aug/2026 08:34:34'!
corsAllowedOrigin
	"Answer the allowed CORS origin, or nil when no CORS headers are sent."
	^ corsAllowedOrigin! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 13/Aug/2026 08:34:35'!
corsAllowedOrigin: aString
	"Set the allowed CORS origin, e.g. '*' or 'http://localhost:8080'.
	nil (the default) disables CORS: no Access-Control-* headers are sent.
	Intended for browser-based MCP clients. Use '*' only with a bearer token
	and a loopback-bound server, otherwise any website can drive the image."
	corsAllowedOrigin := aString! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 13/Aug/2026 06:39:55'!
endpointPath
	"Answer the HTTP path of the MCP endpoint."
	^ endpointPath! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 13/Aug/2026 06:39:56'!
endpointPath: aString
	"Set the HTTP path of the MCP endpoint. Takes effect on the next start."
	endpointPath := aString! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 14/Aug/2026 09:00:00'!
messagesPath
	"Answer the HTTP path of the SSE messages endpoint."
	^ messagesPath! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 14/Aug/2026 09:00:00'!
messagesPath: aString
	"Set the HTTP path of the SSE messages endpoint. Takes effect on the next start."
	messagesPath := aString! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 13/Aug/2026 06:39:59'!
evalTimeout
	"Answer the default eval timeout in seconds."
	^ evalTimeout! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 13/Aug/2026 06:40:00'!
evalTimeout: anInteger
	"Set the default eval timeout in seconds."
	evalTimeout := anInteger! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 13/Aug/2026 06:39:54'!
interfaceAddress
	"Answer the network interface address to bind. Defaults to the loopback address."
	^ interfaceAddress! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 13/Aug/2026 06:39:55'!
interfaceAddress: aString
	"Set the bind address (e.g. '127.0.0.1'). Takes effect on the next start."
	interfaceAddress := aString! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 13/Aug/2026 06:39:54'!
port
	"Answer the TCP port the MCP server listens on."
	^ port! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 13/Aug/2026 06:39:54'!
port: anInteger
	"Set the listen port. Takes effect on the next start."
	port := anInteger! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 13/Aug/2026 06:40:00'!
protocolVersion
	"Answer the supported MCP protocol version."
	^ protocolVersion! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 13/Aug/2026 06:40:00'!
serverName
	"Answer the server name reported during initialization."
	^ serverName! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 13/Aug/2026 06:40:01'!
serverVersion
	"Answer the server version reported during initialization."
	^ serverVersion! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 13/Aug/2026 09:01:29'!
tlsCertificateFile
	"Answer the path to a PEM file (certificate plus private key) used for TLS,
	or nil when the server speaks plain HTTP."
	^ tlsCertificateFile! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 13/Aug/2026 09:01:30'!
tlsCertificateFile: aPathOrNil
	"Set the path to a PEM file (certificate plus private key) used for TLS.
	nil (the default) keeps the server on plain HTTP. Takes effect on the next start.
	Generate a self-signed file with openssl, e.g.:
	openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes \
	  -subj '/CN=localhost'
	cat cert.pem key.pem > server.pem
	The PEM must contain both the certificate and the private key."
	tlsCertificateFile := aPathOrNil! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 13/Aug/2026 06:39:59'!
token
	"Answer the optional bearer token, or nil when authentication is disabled."
	^ token! !

!RemoteControlMCP methodsFor: 'config' stamp: 'sf 13/Aug/2026 06:39:59'!
token: aString
	"Set the bearer token required by the endpoint. nil disables authentication."
	token := aString! !

!RemoteControlMCP methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:40:04'!
isRunning
	"Answer whether the MCP server is currently listening."
	^ server notNil! !

!RemoteControlMCP methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:40:05'!
jobCounter
	"Answer the counter used to generate job ids."
	^ jobCounter! !

!RemoteControlMCP methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:40:05'!
jobs
	"Answer the dictionary of running/finished async eval jobs (jobId -> McpEvalJob)."
	^ jobs! !

!RemoteControlMCP methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:40:05'!
methodRegistry
	"Answer the registry mapping JSON-RPC/MCP method names to handler selectors."
	^ methodRegistry! !

!RemoteControlMCP methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:40:06'!
server
	"Answer the underlying WebServer, or nil when not running."
	^ server! !

!RemoteControlMCP methodsFor: 'accessing' stamp: 'sf 14/Aug/2026 09:00:00'!
sessions
	"Answer the dictionary of open SSE sessions (sessionId -> McpSseSession)."
	^ sessions! !

!RemoteControlMCP methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 06:40:06'!
toolRegistry
	"Answer the registry of MCP tools (name -> tool definition dictionary)."
	^ toolRegistry! !

!RemoteControlMCP methodsFor: 'lifecycle' stamp: 'sf 13/Aug/2026 06:40:11'!
restart
	"Stop and start the server. Answer self."
	self stop.
	^ self start! !

!RemoteControlMCP methodsFor: 'lifecycle' stamp: 'sf 14/Aug/2026 09:00:00'!
start
	"Start the MCP server on self port / interface. When tlsCertificateFile is set,
	the server speaks HTTPS. Answer self."
	| ws |
	self stop.
	ws := McpWebServer new.
	ws mcpOwner: self.
	ws listenOn: self port interface: self interfaceAddressBytes.
	ws addService: self endpointPath action: [ :req | self handleMcpRequest: req ] methods: #('POST' 'GET').
	ws addService: self messagesPath action: [ :req | self handleMessagesRequest: req ] methods: #('POST').
	ws errorHandler: [ :ex :request | self handleServerError: ex request: request ].
	self tlsCertificateFile ifNotNil: [ :cert | ws certName: cert ].
	server := ws.
	^ self! !

!RemoteControlMCP methodsFor: 'lifecycle' stamp: 'sf 14/Aug/2026 09:00:00'!
stop
	"Stop the server and terminate all running eval jobs and SSE sessions.
	Idempotent. Answer self."
	self terminateAllJobs.
	self terminateAllSessions.
	server ifNotNil: [ :ws |
		ws stopListener.
		ws destroyConnections.
		ws listenerSocket ifNotNil: [ :sock | sock destroy ] ].
	server := nil.
	^ self! !

!RemoteControlMCP methodsFor: 'lifecycle' stamp: 'sf 13/Aug/2026 06:40:11'!
terminateAllJobs
	"Terminate any still-running eval jobs and clear the job dictionary."
	jobs do: [ :job | job markTimedOutIfStillRunning ].
	jobs removeAll! !

!RemoteControlMCP methodsFor: 'handlers' stamp: 'sf 14/Aug/2026 09:00:00'!
applyCorsHeadersTo: aResponse
	"Add CORS headers to aResponse when corsAllowedOrigin is configured.
	Preflight requests are answered by McpWebServer; this covers the real
	requests (and their 401/405/500 variants)."
	| origin |
	origin := self corsAllowedOrigin.
	origin ifNil: [ ^ aResponse ].
	aResponse headerAt: 'access-control-allow-origin' put: origin.
	aResponse headerAt: 'access-control-allow-methods' put: 'GET, POST, OPTIONS'.
	aResponse headerAt: 'access-control-allow-headers' put: 'Content-Type, Authorization'.
	aResponse headerAt: 'access-control-max-age' put: '86400'.
	^ aResponse! !

!RemoteControlMCP methodsFor: 'handlers' stamp: 'sf 13/Aug/2026 06:51:25'!
authorizedFor: aRequest
	"Answer whether the request carries a valid bearer token. Without a configured
	token every request is authorized (development mode)."
	^ token isNil or: [ (aRequest headerAt: 'authorization') = ('Bearer ', token) ]! !

!RemoteControlMCP methodsFor: 'handlers' stamp: 'sf 14/Aug/2026 09:00:00'!
handleMcpRequest: aRequest
	"HTTP handler for the MCP endpoint: GET opens an SSE stream (legacy SSE
	transport), POST dispatches a JSON-RPC message. CORS headers are added when
	configured."
	(self authorizedFor: aRequest)
		ifFalse: [ ^ self unauthorizedResponseTo: aRequest ].
	aRequest method = 'GET'
		ifTrue: [ ^ self handleSseRequest: aRequest ].
	(aRequest method ~= 'POST')
		ifTrue: [
			^ aRequest sendResponseCode: 405
				content: 'Method Not Allowed'
				type: 'text/plain; charset=utf-8'
				do: [ :resp |
					resp headerAt: 'allow' put: 'POST'.
					self applyCorsHeadersTo: resp ] ].
	^ self respondToMcpRequest: aRequest! !

!RemoteControlMCP methodsFor: 'handlers' stamp: 'sf 13/Aug/2026 08:35:17'!
handleServerError: ex request: aRequest
	"WebServer-level error handler: answer a JSON-RPC internal error instead of HTML,
	with CORS headers when configured."
	^ aRequest sendResponseCode: 500
		content: (self jsonEncode: (self jsonRpcErrorCode: -32603 message: ex description id: nil)) asUtf8Bytes
		type: 'application/json; charset=utf-8'
		do: [ :resp | self applyCorsHeadersTo: resp ]! !

!RemoteControlMCP methodsFor: 'handlers' stamp: 'sf 13/Aug/2026 08:35:21'!
respondToMcpRequest: aRequest
	"Dispatch the request body as JSON-RPC and answer a JSON response. A notification
	answers with an empty 200. CORS headers are added when configured."
	| response |
	response := self dispatchJsonRpcString: aRequest content asString.
	response ifNil: [
		^ aRequest send200Response: '' contentType: 'application/json'
			do: [ :resp | self applyCorsHeadersTo: resp ] ].
	^ aRequest send200Response: (self jsonEncode: response) asUtf8Bytes
		contentType: 'application/json; charset=utf-8'
		do: [ :resp | self applyCorsHeadersTo: resp ]! !

!RemoteControlMCP methodsFor: 'handlers' stamp: 'sf 13/Aug/2026 08:35:16'!
unauthorizedResponseTo: aRequest
	^ aRequest sendResponseCode: 401
		content: 'Unauthorized' asUtf8Bytes
		type: 'text/plain; charset=utf-8'
		do: [ :resp |
			resp headerAt: 'Connection' put: 'close'.
			self applyCorsHeadersTo: resp ]! !

!RemoteControlMCP methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
closeSseSession: aSession
	"Remove the session from the registry and close its stream."
	self sessions removeKey: aSession id ifAbsent: [ nil ].
	aSession close! !

!RemoteControlMCP methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
handleMessagesRequest: aRequest
	"HTTP handler for the SSE messages endpoint: dispatch the JSON-RPC body and
	push the response over the session's event stream, answering HTTP 202."
	| session |
	(self authorizedFor: aRequest)
		ifFalse: [ ^ self unauthorizedResponseTo: aRequest ].
	session := self sessionForRequest: aRequest.
	session ifNil: [
		^ aRequest sendResponseCode: 404
			content: 'Unknown session'
			type: 'text/plain; charset=utf-8'
			do: [ :resp | self applyCorsHeadersTo: resp ] ].
	[ self pushDispatchForRequest: aRequest to: session ]
		on: Error do: [ :ex | self pushErrorTo: session error: ex description ].
	^ aRequest sendResponseCode: 202
		content: ''
		type: 'text/plain'
		do: [ :resp | self applyCorsHeadersTo: resp ]! !

!RemoteControlMCP methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
handleSseRequest: aRequest
	"Open an SSE stream for the request connection: write the HTTP headers and the
	endpoint event, then keep the stream alive until the client disconnects. Runs
	in the connection's process, which blocks here, so no response is sent
	afterwards."
	| session |
	session := McpSseSession new.
	session id: self newSseSessionId.
	session stream: aRequest stream.
	self sessions at: session id put: session.
	[ self writeSseHandshakeFor: session ]
		on: Error do: [ :ex | self closeSseSession: session ].
	session isOpen ifTrue: [ self runSseSession: session ].
	self closeSseSession: session.
	^ session! !

!RemoteControlMCP methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
messagesEndpointFor: aSessionId
	"Answer the relative endpoint URL the client POSTs JSON-RPC messages to."
	^ self messagesPath, '?sessionId=', aSessionId! !

!RemoteControlMCP methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
newSseSessionId
	"Answer a fresh SSE session id."
	sessionCounter := sessionCounter + 1.
	^ 'session-', sessionCounter printString! !

!RemoteControlMCP methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
pushDispatchForRequest: aRequest to: aSession
	"Dispatch the JSON-RPC request body and push the response (if any) as an SSE
	message event. Notifications produce no event."
	| response |
	response := self dispatchJsonRpcString: aRequest content asString.
	response ifNotNil: [ aSession sendMessageEvent: (self jsonEncode: response) ].
	^ aSession! !

!RemoteControlMCP methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
pushErrorTo: aSession error: aDescription
	"Push a JSON-RPC internal error event to the session."
	aSession sendMessageEvent:
		(self jsonEncode: (self jsonRpcErrorCode: -32603 message: aDescription id: nil)).
	^ aSession! !

!RemoteControlMCP methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
runSseSession: aSession
	"Keep the SSE stream alive with periodic comment frames until the session
	closes. Runs in the connection's process, which blocks here."
	[ aSession isOpen ] whileTrue: [
		aSession sendKeepAlive.
		(Delay forMilliseconds: 15000) wait ]! !

!RemoteControlMCP methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
sessionForRequest: aRequest
	"Answer the SSE session named in the request's sessionId query parameter,
	or nil when absent or unknown."
	^ self sessions
		at: (aRequest getFields at: 'sessionId' ifAbsent: [ nil ])
		ifAbsent: [ nil ]! !

!RemoteControlMCP methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
sseResponseHeaders
	"Answer the HTTP headers that open an SSE stream, including the CORS origin
	header when configured."
	| origin |
	origin := self corsAllowedOrigin.
	^ 'HTTP/1.1 200 OK', String crlfString,
		'Content-Type: text/event-stream; charset=utf-8', String crlfString,
		'Cache-Control: no-cache', String crlfString,
		'Connection: Keep-Alive', String crlfString,
		(origin ifNil: [ '' ] ifNotNil: [ 'Access-Control-Allow-Origin: ', origin, String crlfString ]),
		String crlfString! !

!RemoteControlMCP methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
terminateAllSessions
	"Close all open SSE sessions and clear the registry."
	self sessions do: [ :session | session close ].
	self sessions removeAll! !

!RemoteControlMCP methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
writeSseHandshakeFor: aSession
	"Write the HTTP 200 headers and the endpoint event that announces the messages
	endpoint for this session. Bytes are written as UTF-8, the same way regular
	responses are, keeping the stream in ascii mode."
	aSession stream nextPutAll: self sseResponseHeaders asUtf8Bytes.
	aSession sendEndpointEvent: (self messagesEndpointFor: aSession id).
	aSession stream flush! !

!RemoteControlMCP methodsFor: 'jsonrpc' stamp: 'sf 13/Aug/2026 06:40:38'!
dispatchJsonRpcMessage: message
	"Validate a parsed JSON-RPC request and dispatch it to the method registry.
	A missing id makes the message a notification, answered by nil."
	| method params id |
	(message at: 'jsonrpc' ifAbsent: [ nil ]) = '2.0'
		ifFalse: [ ^ self jsonRpcErrorCode: -32600 message: 'Invalid Request' id: (message at: 'id' ifAbsent: [ nil ]) ].
	method := message at: 'method' ifAbsent: [ nil ].
	method isString
		ifFalse: [ ^ self jsonRpcErrorCode: -32600 message: 'Invalid Request' id: (message at: 'id' ifAbsent: [ nil ]) ].
	params := message at: 'params' ifAbsent: [ Dictionary new ].
	(params isKindOf: Dictionary)
		ifFalse: [ ^ self jsonRpcErrorCode: -32602 message: 'Invalid params' id: (message at: 'id' ifAbsent: [ nil ]) ].
	id := message at: 'id' ifAbsent: [ nil ].
	id ifNil: [ ^ self handleNotification: method params: params ].
	^ self handleRequest: method params: params id: id! !

!RemoteControlMCP methodsFor: 'jsonrpc' stamp: 'sf 13/Aug/2026 06:40:23'!
dispatchJsonRpcString: aString
	"Parse a JSON-RPC message and answer the response dictionary, or nil for a
	notification. Parse errors answer a -32700 error response."
	| message |
	message := [ WebUtils jsonDecode: aString readStream ]
		on: Error do: [ ^ self jsonRpcErrorCode: -32700 message: 'Parse error' id: nil ].
	(message isKindOf: Dictionary) ifFalse: [ ^ self jsonRpcErrorCode: -32600 message: 'Invalid Request' id: nil ].
	^ self dispatchJsonRpcMessage: message! !

!RemoteControlMCP methodsFor: 'jsonrpc' stamp: 'sf 13/Aug/2026 06:40:27'!
handleNotification: method params: params
	"Perform a notification handler. Notifications never produce a response."
	| selector |
	selector := self methodRegistry at: method ifAbsent: [ ^ nil ].
	self perform: selector with: params.
	^ nil! !

!RemoteControlMCP methodsFor: 'jsonrpc' stamp: 'sf 13/Aug/2026 06:40:26'!
handleRequest: method params: params id: id
	"Look up the method handler and perform it, wrapping any error in a -32603 response."
	| selector |
	selector := self methodRegistry at: method ifAbsent: [ ^ self jsonRpcErrorCode: -32601 message: 'Method not found: ', method id: id ].
	^ [ self jsonRpcResult: (self perform: selector with: params) id: id ]
		on: Error do: [ :ex | self jsonRpcErrorCode: -32603 message: ex description id: id ]! !

!RemoteControlMCP methodsFor: 'jsonrpc' stamp: 'sf 13/Aug/2026 06:40:28'!
jsonRpcErrorCode: code message: aMessage id: id
	^ Dictionary newFromPairs: {
		'jsonrpc'. '2.0'.
		'error'. (Dictionary newFromPairs: { 'code'. code. 'message'. aMessage }).
		'id'. id }! !

!RemoteControlMCP methodsFor: 'jsonrpc' stamp: 'sf 13/Aug/2026 06:40:27'!
jsonRpcResult: result id: id
	^ Dictionary newFromPairs: { 'jsonrpc'. '2.0'. 'result'. result. 'id'. id }! !

!RemoteControlMCP methodsFor: 'jsonrpc' stamp: 'sf 13/Aug/2026 06:40:28'!
registerMethod: aName handler: aSelector
	"Register a JSON-RPC/MCP method name with its handler selector."
	methodRegistry at: aName put: aSelector.
	^ self! !

!RemoteControlMCP methodsFor: 'mcp' stamp: 'sf 13/Aug/2026 06:40:44'!
initializeWithParams: params
	"Answer the initialize result: negotiated protocol version, server capabilities
	and server info."
	^ Dictionary newFromPairs: {
		'protocolVersion'. self protocolVersion.
		'capabilities'. (Dictionary newFromPairs: {
			'tools'. (Dictionary newFromPairs: { 'listChanged'. true }).
			'resources'. (Dictionary newFromPairs: { 'listChanged'. true }).
			'prompts'. (Dictionary newFromPairs: { 'listChanged'. true }) }).
		'serverInfo'. (Dictionary newFromPairs: { 'name'. self serverName. 'version'. self serverVersion }).
		'instructions'. self instructions }! !

!RemoteControlMCP methodsFor: 'mcp' stamp: 'sf 13/Aug/2026 06:40:45'!
initializedNotification: params
	"Notification: the client has finished initialization. Nothing to do."
	^ nil! !

!RemoteControlMCP methodsFor: 'mcp' stamp: 'sf 13/Aug/2026 06:40:45'!
instructions
	"Answer short usage instructions sent to the client during initialization."
	^ 'Use tools/eval to run Smalltalk code, tools/compile_method to add methods, '
		, 'tools/screenshot to capture the world, and tools/list_classes / tools/class_summary '
		, '/ tools/image_status for introspection. Long evals: pass async:true and poll tools/eval_status.'! !

!RemoteControlMCP methodsFor: 'mcp' stamp: 'sf 13/Aug/2026 06:40:45'!
ping: params
	"Answer the empty result required by ping."
	^ Dictionary new! !

!RemoteControlMCP methodsFor: 'mcp' stamp: 'sf 13/Aug/2026 06:40:43'!
registerMethods
	"Register the JSON-RPC/MCP method names with their handler selectors."
	self
		registerMethod: 'initialize' handler: #initializeWithParams:;
		registerMethod: 'notifications/initialized' handler: #initializedNotification:;
		registerMethod: 'ping' handler: #ping:;
		registerMethod: 'tools/list' handler: #toolsList:;
		registerMethod: 'tools/call' handler: #toolsCall:;
		registerMethod: 'resources/list' handler: #resourcesList:;
		registerMethod: 'resources/read' handler: #resourcesRead:;
		registerMethod: 'prompts/list' handler: #promptsList:;
		registerMethod: 'prompts/get' handler: #promptsGet:! !

!RemoteControlMCP methodsFor: 'mcp' stamp: 'sf 13/Aug/2026 06:40:47'!
toolsCall: params
	"Invoke a tool. Success results are content arrays; tool errors carry isError."
	| name arguments result |
	name := params at: 'name' ifAbsent: [ nil ].
	name ifNil: [ ^ self toolErrorResult: 'Missing tool name' ].
	arguments := params at: 'arguments' ifAbsent: [ Dictionary new ].
	result := self callTool: name arguments: arguments.
	^ result isArray
		ifTrue: [ Dictionary newFromPairs: { 'content'. result } ]
		ifFalse: [ result ]! !

!RemoteControlMCP methodsFor: 'mcp' stamp: 'sf 13/Aug/2026 06:40:46'!
toolsList: params
	"Answer the list of available tools. Pagination is not needed for this small set."
	^ Dictionary newFromPairs: { 'tools'. self toolDefinitions }! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:40:54'!
callTool: aName arguments: arguments
	"Invoke a tool by name. Unknown tools answer a tool error result."
	| def |
	def := self toolDefinitionForName: aName.
	def ifNil: [ ^ self toolErrorResult: 'Unknown tool: ', aName ].
	^ [ self perform: (def at: 'implementation') with: arguments ]
		on: Error do: [ :ex | self toolErrorResult: ex description ]! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:41:19'!
classSummaryTool: arguments
	"Answer a JSON summary of a class."
	| name cls summary |
	name := arguments at: 'name' ifAbsent: [ nil ].
	name ifNil: [ ^ self toolErrorResult: 'Missing argument: name' ].
	cls := Smalltalk classNamed: name.
	cls ifNil: [ ^ self toolErrorResult: 'Unknown class: ', name ].
	summary := Dictionary newFromPairs: {
		'name'. cls name.
		'superclass'. cls superclass name.
		'instanceVariables'. cls instVarNames.
		'instanceMethodCount'. cls selectors size.
		'classMethodCount'. cls class selectors size.
		'methods'. (cls selectors asSortedCollection asArray) }.
	^ self toolTextResult: (WebUtils jsonEncode: summary)! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:41:15'!
compile: source into: aClass isClassSide: isClassSide category: aCategory
	| target |
	target := isClassSide ifTrue: [ aClass class ] ifFalse: [ aClass ].
	^ target safelyCompile: source classified: aCategory! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:41:15'!
compileMethodTool: arguments
	"Compile a method into a class. Answer the compiled selector."
	| className source target |
	className := arguments at: 'className' ifAbsent: [ nil ].
	source := arguments at: 'source' ifAbsent: [ nil ].
	className ifNil: [ ^ self toolErrorResult: 'Missing argument: className' ].
	source ifNil: [ ^ self toolErrorResult: 'Missing argument: source' ].
	target := Smalltalk classNamed: className.
	target ifNil: [ ^ self toolErrorResult: 'Unknown class: ', className ].
	^ [ self toolTextResult: (self compile: source into: target
			isClassSide: (arguments at: 'isClassSide' ifAbsent: [ false ])
			category: (arguments at: 'category' ifAbsent: [ 'as yet unclassified' ])) ]
		on: Error do: [ :ex | self toolErrorResult: ex description ]! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:41:13'!
evalStatusTool: arguments
	"Answer the JSON status dictionary of an async eval job."
	| jobId job |
	jobId := arguments at: 'jobId' ifAbsent: [ nil ].
	jobId ifNil: [ ^ self toolErrorResult: 'Missing argument: jobId' ].
	job := self jobs at: jobId ifAbsent: [ nil ].
	job ifNil: [ ^ self toolErrorResult: 'Unknown job: ', jobId ].
	^ self toolTextResult: (WebUtils jsonEncode: job asStatusDictionary)! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 06/Sep/2026'!
evalTool: arguments
	"Evaluate Smalltalk source. Synchronous until the timeout, or start a background
	job when async:true is given. On sync timeout the job keeps running in the
	background and the answer carries its jobId for eval_status polling."
	| source timeoutSeconds isAsync outcome |
	source := arguments at: 'source' ifAbsent: [ nil ].
	source ifNil: [ ^ self toolErrorResult: 'Missing argument: source' ].
	timeoutSeconds := arguments at: 'timeout' ifAbsent: [ self evalTimeout ].
	isAsync := arguments at: 'async' ifAbsent: [ false ].
	^ isAsync
		ifTrue: [ self toolTextResult: (WebUtils jsonEncode: (self startAsyncEval: source timeout: timeoutSeconds)) ]
		ifFalse: [
			outcome := self evaluateSource: source timeout: timeoutSeconds.
			(outcome at: 'status') caseOf: {
				[ 'done' ] -> [ self toolTextResult: (outcome at: 'result') ].
				[ 'running' ] -> [ self toolTextResult: 'Still running (jobId: ', (outcome at: 'jobId'), '). Poll with eval_status or abort with eval_cancel.' ] }
				otherwise: [ self toolErrorResult: (outcome at: 'error') ] ]! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:40:56'!
imageContent: base64String
	^ Dictionary newFromPairs: { 'type'. 'image'. 'data'. base64String. 'mimeType'. 'image/png' }! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:41:20'!
imageStatus
	"Answer a dictionary describing the running image."
	^ Dictionary newFromPairs: {
		'imageName'. Smalltalk imageName.
		'lastUpdate'. Smalltalk lastUpdateString.
		'vmVersion'. Smalltalk vmVersion.
		'os'. Smalltalk osVersion.
		'now'. DateAndTime now printString }! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:41:19'!
imageStatusTool: arguments
	"Answer a JSON summary of the running image."
	^ self toolTextResult: (WebUtils jsonEncode: self imageStatus)! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:41:18'!
listClassesTool: arguments
	"Answer all class names, one per line."
	| names |
	names := (Smalltalk allClasses collect: [ :c | c name ]) asSortedCollection asArray.
	^ self toolTextResult: (String newLineString join: names)! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:41:17'!
pngBase64Of: aForm
	"Answer the base64-encoded PNG bytes of aForm."
	| bytes |
	bytes := ByteArray streamContents: [ :s | PNGReadWriter putForm: aForm onStream: s ].
	^ (Base64MimeConverter mimeEncode: bytes readStream multiLine: false atStart: true) contents! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:41:07'!
registerClassSummaryTool
	self registerTool: 'class_summary'
		description: 'Answer a JSON summary of a class: superclass, instance variables, method counts and method names.'
		inputSchema: (Dictionary newFromPairs: {
			'type'. 'object'.
			'properties'. (Dictionary newFromPairs: {
				'name'. (self schemaStringProperty: 'Class name') }).
			'required'. #('name') })
		implementation: #classSummaryTool:! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:41:04'!
registerCompileMethodTool
	self registerTool: 'compile_method'
		description: 'Compile a Smalltalk method into a class, using safelyCompile:classified:. Answer the compiled selector.'
		inputSchema: (Dictionary newFromPairs: {
			'type'. 'object'.
			'properties'. (Dictionary newFromPairs: {
				'className'. (self schemaStringProperty: 'Name of the target class').
				'isClassSide'. (self schemaBooleanProperty: 'Compile on the class side (default false)').
				'category'. (self schemaStringProperty: 'Method category (default "as yet unclassified")').
				'source'. (self schemaStringProperty: 'Method source code without category header') }).
			'required'. #('className' 'source') })
		implementation: #compileMethodTool:! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:41:03'!
registerEvalStatusTool
	self registerTool: 'eval_status'
		description: 'Poll the status and result of an asynchronous eval job started with eval (async:true).'
		inputSchema: (Dictionary newFromPairs: {
			'type'. 'object'.
			'properties'. (Dictionary newFromPairs: {
				'jobId'. (self schemaStringProperty: 'Job id returned by eval with async:true') }).
			'required'. #('jobId') })
		implementation: #evalStatusTool:! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:41:02'!
registerEvalTool
	self registerTool: 'eval'
		description: 'Evaluate Smalltalk source code in the Cuis image. Synchronous until the timeout by default; pass async:true to start a background job and poll it with eval_status.'
		inputSchema: (Dictionary newFromPairs: {
			'type'. 'object'.
			'properties'. (Dictionary newFromPairs: {
				'source'. (self schemaStringProperty: 'Smalltalk source code to evaluate').
				'timeout'. (self schemaNumberProperty: 'Timeout in seconds (default 30)').
				'async'. (self schemaBooleanProperty: 'Run in background; poll with eval_status') }).
			'required'. #('source') })
		implementation: #evalTool:! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:41:07'!
registerImageStatusTool
	self registerTool: 'image_status'
		description: 'Answer a JSON summary of the running Cuis image: name, update level, VM and OS.'
		inputSchema: (Dictionary newFromPairs: { 'type'. 'object'. 'properties'. (Dictionary new). 'required'. #() })
		implementation: #imageStatusTool:! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:41:06'!
registerListClassesTool
	self registerTool: 'list_classes'
		description: 'List the names of all classes in the image, one per line.'
		inputSchema: (Dictionary newFromPairs: { 'type'. 'object'. 'properties'. (Dictionary new). 'required'. #() })
		implementation: #listClassesTool:! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:41:05'!
registerScreenshotTool
	self registerTool: 'screenshot'
		description: 'Capture a PNG of the Cuis world (base64-encoded image content). Optional morph crop by class name with a pad margin.'
		inputSchema: (Dictionary newFromPairs: {
			'type'. 'object'.
			'properties'. (Dictionary newFromPairs: {
				'morph'. (self schemaStringProperty: 'Class name of the morph to crop to').
				'pad'. (self schemaNumberProperty: 'Margin around the morph in pixels') }).
			'required'. #() })
		implementation: #screenshotTool:! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'AB 15/Sep/2026 14:00:00'!
registerMethodSourceTool
	self registerTool: 'method_source'
		description: 'Answer the source of a method (Class >> selector, category, code). With includeSuperclasses:true the nearest defining class in the ancestry is named.'
		inputSchema: (Dictionary newFromPairs: {
			'type'. 'object'.
			'properties'. (Dictionary newFromPairs: {
				'className'. (self schemaStringProperty: 'Class to look up').
				'selector'. (self schemaStringProperty: 'Method selector').
				'includeSuperclasses'. (self schemaBooleanProperty: 'Search superclasses when the class does not define it (default false)') }).
			'required'. #('className' 'selector') })
		implementation: #methodSourceTool:! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'AB 15/Sep/2026 14:00:00'!
registerSelectorUsageTool
	self registerTool: 'selector_usage'
		description: 'Answer who implements and who sends a selector, one Class >> selector per line.'
		inputSchema: (Dictionary newFromPairs: {
			'type'. 'object'.
			'properties'. (Dictionary newFromPairs: {
				'selector'. (self schemaStringProperty: 'Selector symbol to search for') }).
			'required'. #('selector') })
		implementation: #selectorUsageTool:! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'AB 15/Sep/2026 14:00:00'!
registerClassHierarchyTool
	self registerTool: 'class_hierarchy'
		description: 'Answer a class''s ancestry and an indented descendant tree.'
		inputSchema: (Dictionary newFromPairs: {
			'type'. 'object'.
			'properties'. (Dictionary newFromPairs: {
				'className'. (self schemaStringProperty: 'Class name') }).
			'required'. #('className') })
		implementation: #classHierarchyTool:! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'AB 15/Sep/2026 14:00:00'!
definingClassOf: aSelector in: aClass includeSuperclasses: includeSuperclasses
	"Answer the first class in aClass's hierarchy that defines aSelector, or nil."
	includeSuperclasses ifFalse: [
		^ (aClass includesSelector: aSelector) ifTrue: [ aClass ] ifFalse: [ nil ] ].
	^ aClass withAllSuperclasses
		detect: [ :each | each includesSelector: aSelector ]
		ifNone: [ nil ]! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'AB 15/Sep/2026 14:00:00'!
referenceListTextFor: aCollection
	"Answer the method references of aCollection as one 'Class >> selector' line per
	entry, capped at 40 lines."
	| max shown |
	max := 40.
	shown := 0.
	^ String streamContents: [ :stream |
		aCollection do: [ :each |
			(shown < max) ifTrue: [
				stream nextPutAll: each methodClass name.
				stream nextPutAll: ' >> '.
				stream nextPutAll: each selector.
				stream newLine.
				shown := shown + 1 ] ].
		(aCollection size > max) ifTrue: [
			stream nextPutAll: '... +'; print: aCollection size - max; nextPutAll: ' more'; newLine ] ]! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'AB 15/Sep/2026 14:00:00'!
descendantTreeTextFor: aClass
	"Answer an indented descendant tree using dashes for levels, capped at 300 entries."
	^ String streamContents: [ :stream |
		| shown |
		shown := 0.
		aClass allSubclassesWithLevelDo: [ :each :level |
			(shown < 300) ifTrue: [
				stream nextPutAll: ((String new: level + 1) atAllPut: $-; yourself).
				stream nextPutAll: each name.
				stream newLine.
				shown := shown + 1 ] ]
			startingLevel: 0.
		shown = 0 ifTrue: [ stream nextPutAll: '(none)'; newLine ] ]! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'AB 15/Sep/2026 14:00:00'!
methodSourceTool: arguments
	"Answer the source of a method. With includeSuperclasses: true the nearest
	defining class in the ancestry is named."
	| className selector includeSuperclasses cls definingClass reference |
	className := arguments at: 'className' ifAbsent: [ nil ].
	selector := arguments at: 'selector' ifAbsent: [ nil ].
	className ifNil: [ ^ self toolErrorResult: 'Missing argument: className' ].
	selector ifNil: [ ^ self toolErrorResult: 'Missing argument: selector' ].
	cls := Smalltalk classNamed: className.
	cls ifNil: [ ^ self toolErrorResult: 'Unknown class: ', className ].
	includeSuperclasses := arguments at: 'includeSuperclasses' ifAbsent: [ false ].
	definingClass := self definingClassOf: selector asSymbol in: cls includeSuperclasses: includeSuperclasses.
	definingClass ifNil: [
		^ self toolErrorResult: 'No implementor of #', selector, ' in ', className,
			(includeSuperclasses ifTrue: [ ' or its superclasses' ] ifFalse: [ '' ]) ].
	reference := MethodReference class: definingClass selector: selector asSymbol.
	^ self toolTextResult: (String streamContents: [ :stream |
		stream nextPutAll: cls name.
		stream nextPutAll: ' >> '.
		stream nextPutAll: selector.
		(definingClass ~~ cls) ifTrue: [
			stream nextPutAll: '   (defined in: '.
			stream nextPutAll: definingClass name.
			stream nextPutAll: ')' ].
		stream newLine.
		stream nextPutAll: '(category: '.
		stream nextPutAll: reference category asString.
		stream nextPutAll: ')'.
		stream newLine; newLine.
		stream nextPutAll: reference sourceCode ])! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'AB 15/Sep/2026 14:00:00'!
selectorUsageTool: arguments
	"Answer who implements and who sends a selector, one Class >> selector per line."
	| selector implementors senders |
	selector := arguments at: 'selector' ifAbsent: [ nil ].
	selector ifNil: [ ^ self toolErrorResult: 'Missing argument: selector' ].
	selector := selector asSymbol.
	implementors := Smalltalk allImplementorsOf: selector.
	senders := Smalltalk allCallsOn: selector.
	^ self toolTextResult: (String streamContents: [ :stream |
		stream nextPutAll: 'Implementors of #'.
		stream nextPutAll: selector.
		stream nextPutAll: ' ('.
		stream print: implementors size.
		stream nextPutAll: ')'.
		stream newLine.
		stream nextPutAll: (self referenceListTextFor: implementors).
		stream newLine.
		stream nextPutAll: 'Senders of #'.
		stream nextPutAll: selector.
		stream nextPutAll: ' ('.
		stream print: senders size.
		stream nextPutAll: ')'.
		stream newLine.
		stream nextPutAll: (self referenceListTextFor: senders) ])! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'AB 15/Sep/2026 14:00:00'!
classHierarchyTool: arguments
	"Answer ancestry plus an indented descendant tree for a class."
	| className cls |
	className := arguments at: 'className' ifAbsent: [ nil ].
	className ifNil: [ ^ self toolErrorResult: 'Missing argument: className' ].
	cls := Smalltalk classNamed: className.
	cls ifNil: [ ^ self toolErrorResult: 'Unknown class: ', className ].
	^ self toolTextResult: (String streamContents: [ :stream |
		stream nextPutAll: 'Ancestry of '.
		stream nextPutAll: cls name.
		stream nextPutAll: ' (self first):'.
		stream newLine.
		stream nextPutAll: '  '.
		stream nextPutAll: (String newLineString join: (cls withAllSuperclasses collect: [ :each | each name ])).
		stream newLine; newLine.
		stream nextPutAll: 'Descendants of '.
		stream nextPutAll: cls name.
		stream newLine.
		stream nextPutAll: (self descendantTreeTextFor: cls) ])! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:40:52'!
registerTool: aName description: aDescription inputSchema: schema implementation: aSelector
	"Register one tool definition together with its implementation selector."
	toolRegistry at: aName put: (Dictionary newFromPairs: {
		'name'. aName.
		'title'. aName.
		'description'. aDescription.
		'inputSchema'. schema.
		'implementation'. aSelector }).
	^ self! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 06/Sep/2026'!
cancelEvalTool: arguments
	"Terminate a running eval job (by jobId) started with eval async:true or still
	running after a sync timeout. Answer the job final status; a running job is
	reported as 'cancelled', a finished one stays as it was."
	| jobId job status |
	jobId := arguments at: 'jobId' ifAbsent: [ nil ].
	jobId ifNil: [ ^ self toolErrorResult: 'Missing argument: jobId' ].
	job := self jobs at: jobId ifAbsent: [ nil ].
	job ifNil: [ ^ self toolErrorResult: 'Unknown job: ', jobId ].
	job isRunning
		ifTrue: [ job terminate. job state: 'cancelled' ]
		ifFalse: [ job state: 'cancelled' ].
	self jobs removeKey: jobId ifAbsent: [ ].
	status := job asStatusDictionary.
	^ self toolTextResult: (WebUtils jsonEncode: status)! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 06/Sep/2026'!
registerCancelEvalTool
	self registerTool: 'eval_cancel'
		description: 'Terminate a running eval job (by jobId) started with eval async:true or still running after a sync timeout. Answers the job final status.'
		inputSchema: (Dictionary newFromPairs: {
			'type'. 'object'.
			'properties'. (Dictionary newFromPairs: {
				'jobId'. (self schemaStringProperty: 'Job id returned by eval with async:true') }).
			'required'. #('jobId') })
		implementation: #cancelEvalTool:! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 06/Sep/2026'!
registerTools
	"Register all MCP tools."
	self
		registerEvalTool;
		registerEvalStatusTool;
		registerCancelEvalTool;
		registerCompileMethodTool;
		registerScreenshotTool;
		registerListClassesTool;
		registerClassSummaryTool;
		registerImageStatusTool;
		registerMethodSourceTool;
		registerSelectorUsageTool;
		registerClassHierarchyTool! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:40:58'!
schemaBooleanProperty: aDescription
	^ Dictionary newFromPairs: { 'type'. 'boolean'. 'description'. aDescription }! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:40:57'!
schemaNumberProperty: aDescription
	^ Dictionary newFromPairs: { 'type'. 'number'. 'description'. aDescription }! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:40:57'!
schemaStringProperty: aDescription
	^ Dictionary newFromPairs: { 'type'. 'string'. 'description'. aDescription }! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:41:16'!
screenshotTool: arguments
	"Capture the world as a base64 PNG. Optional crop to the first morph of a class."
	| form rect |
	form := UISupervisor ui imageForm: 32.
	rect := self cropRectForMorphNamed: (arguments at: 'morph' ifAbsent: [ nil ])
		pad: (arguments at: 'pad' ifAbsent: [ 0 ])
		in: form boundingBox.
	rect ifNotNil: [ form := form copy: rect ].
	^ Array with: (self imageContent: (self pngBase64Of: form))! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:40:56'!
textContent: aString
	^ Dictionary newFromPairs: { 'type'. 'text'. 'text'. aString }! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:40:53'!
toolDefinitionForList: def
	^ Dictionary newFromPairs: {
		'name'. (def at: 'name').
		'title'. (def at: 'title').
		'description'. (def at: 'description').
		'inputSchema'. (def at: 'inputSchema') }! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:40:55'!
toolDefinitionForName: aName
	^ toolRegistry at: aName ifAbsent: [ nil ]! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:40:53'!
toolDefinitions
	"Answer the JSON-safe list of tool definitions (without the internal implementation key)."
	^ (toolRegistry values collect: [ :def | self toolDefinitionForList: def ]) asArray! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:40:56'!
toolErrorResult: aString
	"Answer an error tool result carrying isError."
	^ Dictionary newFromPairs: {
		'content'. (Array with: (self textContent: aString)).
		'isError'. true }! !

!RemoteControlMCP methodsFor: 'tools' stamp: 'sf 13/Aug/2026 06:40:55'!
toolTextResult: aString
	"Answer a success tool result with one text content item."
	^ Array with: (self textContent: aString)! !

!RemoteControlMCP methodsFor: 'eval' stamp: 'sf 06/Sep/2026'!
evaluateSource: aSource timeout: timeoutSeconds
	"Evaluate aSource in a forked process and wait for it up to timeoutSeconds.
	The job is registered from the start: on timeout it keeps running in the
	background (nothing is killed, no work is lost) and the caller receives a
	'running' status with the jobId, to poll via eval_status. Answer the job's
	status dictionary (status done/error/running)."
	| job |
	job := McpEvalJob new.
	job id: self newJobId; source: aSource; timeout: timeoutSeconds.
	self jobs at: job id put: job.
	job run.
	^ job waitForCompletionUpTo: timeoutSeconds killOnTimeout: false! !

!RemoteControlMCP methodsFor: 'eval' stamp: 'sf 13/Aug/2026 06:41:27'!
newJobId
	"Answer a fresh job id."
	jobCounter := jobCounter + 1.
	^ 'job-', jobCounter printString! !

!RemoteControlMCP methodsFor: 'eval' stamp: 'sf 13/Aug/2026 06:55:08'!
startAsyncEval: aSource timeout: timeoutSeconds
	"Start a background evaluation with a watchdog, and answer a status dictionary
	with the job id. The watchdog runs at user priority, above the eval process,
	so it can time out CPU-bound jobs."
	| job |
	job := McpEvalJob new.
	job id: self newJobId; source: aSource; timeout: timeoutSeconds.
	self jobs at: job id put: job.
	job run.
	[ job waitForCompletionUpTo: timeoutSeconds ]
		forkAt: Processor userSchedulingPriority named: 'McpEvalWatchdog-', job id.
	^ Dictionary newFromPairs: { 'jobId'. job id. 'status'. 'running' }! !

!RemoteControlMCP methodsFor: 'private' stamp: 'sf 13/Aug/2026 06:41:30'!
cropRectFor: morph pad: pad in: bigRect
	"World-coordinate crop rectangle for morph: its displayFullBounds expanded by pad
	on every side, then clamped to the form."
	| b |
	b := morph displayFullBounds.
	^ ((b origin - pad) corner: (b corner + pad)) intersect: bigRect! !

!RemoteControlMCP methodsFor: 'private' stamp: 'sf 13/Aug/2026 06:41:28'!
cropRectForMorphNamed: aName pad: pad in: bigRect
	"Answer the crop rectangle for the first morph of the named class, or nil when
	no morph name is given. Raises Error when the morph is not found."
	aName ifNil: [ ^ nil ].
	^ (self firstMorphOfClassNamed: aName)
		ifNil: [ self error: 'Morph not found: ', aName ]
		ifNotNil: [ :morph | self cropRectFor: morph pad: pad in: bigRect ]! !

!RemoteControlMCP methodsFor: 'private' stamp: 'sf 13/Aug/2026 06:41:29'!
firstMorphOfClassNamed: aName
	"Answer the first morph in the world whose class name matches, or nil."
	| found |
	found := nil.
	UISupervisor ui allMorphsDo: [ :m |
		(found isNil and: [ m class name asString = aName ]) ifTrue: [ found := m ] ].
	^ found! !

!RemoteControlMCP methodsFor: 'private' stamp: 'sf 14/Aug/2026 09:00:00'!
initialize
	super initialize.
	port := self class defaultPort.
	interfaceAddress := '127.0.0.1'.
	endpointPath := '/mcp'.
	messagesPath := '/messages'.
	protocolVersion := '2025-06-18'.
	serverName := 'RemoteControlMCP'.
	serverVersion := '0.1'.
	evalTimeout := 30.
	corsAllowedOrigin := nil.
	tlsCertificateFile := nil.
	jobs := Dictionary new.
	jobCounter := 0.
	sessions := Dictionary new.
	sessionCounter := 0.
	methodRegistry := Dictionary new.
	toolRegistry := Dictionary new.
	self registerMethods.
	self registerTools! !

!RemoteControlMCP methodsFor: 'private' stamp: 'sf 13/Aug/2026 06:46:00'!
interfaceAddressBytes
	"Answer the interface address as a 4-byte IPv4 ByteArray for the VM socket primitive."
	^ ((interfaceAddress findTokens: '.') collect: [ :part | Integer readFrom: part readStream ]) asByteArray! !

!RemoteControlMCP methodsFor: 'private' stamp: 'sf 13/Aug/2026 06:41:27'!
jsonDecode: aString
	^ WebUtils jsonDecode: aString readStream! !

!RemoteControlMCP methodsFor: 'private' stamp: 'sf 13/Aug/2026 06:41:27'!
jsonEncode: anObject
	^ WebUtils jsonEncode: anObject! !

!RemoteControlMCP methodsFor: 'resources' stamp: 'sf 13/Aug/2026 06:41:34'!
resourcesList: params
	"Answer the list of readable resources."
	^ Dictionary newFromPairs: { 'resources'. (Array with: self statusResourceDefinition) }! !

!RemoteControlMCP methodsFor: 'resources' stamp: 'sf 13/Aug/2026 06:41:35'!
resourcesRead: params
	"Read a resource by uri. Currently only image://status is supported."
	| uri |
	uri := params at: 'uri' ifAbsent: [ nil ].
	uri = 'image://status' ifFalse: [ self error: 'Unknown resource: ', uri asString ].
	^ Dictionary newFromPairs: { 'contents'. (Array with: self statusResourceContents) }! !

!RemoteControlMCP methodsFor: 'resources' stamp: 'sf 13/Aug/2026 06:41:36'!
statusResourceContents
	^ Dictionary newFromPairs: {
		'uri'. 'image://status'.
		'mimeType'. 'application/json'.
		'text'. (WebUtils jsonEncode: self imageStatus) }! !

!RemoteControlMCP methodsFor: 'resources' stamp: 'sf 13/Aug/2026 06:41:35'!
statusResourceDefinition
	^ Dictionary newFromPairs: {
		'uri'. 'image://status'.
		'name'. 'Cuis Image Status'.
		'mimeType'. 'application/json' }! !

!RemoteControlMCP methodsFor: 'prompts' stamp: 'sf 13/Aug/2026 06:41:38'!
developerPromptDefinition
	^ Dictionary newFromPairs: {
		'name'. 'develop-in-cuis'.
		'description'. 'Develop Smalltalk in the Cuis image'.
		'arguments'. (Array with: (Dictionary newFromPairs: {
			'name'. 'task'.
			'description'. 'What you want to build'.
			'required'. true })) }! !

!RemoteControlMCP methodsFor: 'prompts' stamp: 'sf 13/Aug/2026 06:41:38'!
promptsGet: params
	"Answer a prompt by name. Only 'develop-in-cuis' is provided."
	| name |
	name := params at: 'name' ifAbsent: [ nil ].
	name = 'develop-in-cuis' ifFalse: [ self error: 'Unknown prompt: ', name asString ].
	^ Dictionary newFromPairs: {
		'description'. 'Develop Smalltalk in the Cuis image'.
		'messages'. (Array with: (Dictionary newFromPairs: {
			'role'. 'user'.
			'content'. (Dictionary newFromPairs: {
				'type'. 'text'.
				'text'. 'You are a Cuis-Smalltalk developer. Use tools/eval to run code, tools/compile_method to add methods, and tools/screenshot to see the world.' }) })) }! !

!RemoteControlMCP methodsFor: 'prompts' stamp: 'sf 13/Aug/2026 06:41:36'!
promptsList: params
	"Answer the list of available prompts."
	^ Dictionary newFromPairs: { 'prompts'. (Array with: self developerPromptDefinition) }! !

!RemoteControlMCP class methodsFor: 'class' stamp: 'sf 13/Aug/2026 06:42:24'!
default
	"Answer the lazily created default instance."
	DefaultInstance ifNil: [ DefaultInstance := self new ].
	^ DefaultInstance! !

!RemoteControlMCP class methodsFor: 'class' stamp: 'sf 13/Aug/2026 06:42:25'!
defaultPort
	^ 2357! !

!RemoteControlMCP class methodsFor: 'class' stamp: 'sf 13/Aug/2026 06:42:24'!
start
	"Start the default instance's MCP server and answer it."
	^ self default start! !

!RemoteControlMCP class methodsFor: 'class' stamp: 'sf 13/Aug/2026 06:42:24'!
stop
	^ self default stop! !

!RemoteControlMCP class methodsFor: 'class initialization' stamp: 'AB 15/Sep/2026 13:30:00'!
registerForStartUp
	"Register this class in Smalltalk's startUp list, so the MCP server comes
	back up automatically after an image save/reboot. Answer self."
	Smalltalk addToStartUpList: self.
	^ self! !

!RemoteControlMCP class methodsFor: 'class initialization' stamp: 'AB 15/Sep/2026 13:30:00'!
startUp: isARealStartup
	"After a real image save/reboot, bring the MCP server back up in its own
	process, so the (busy) startup phase never blocks the server."
	isARealStartup ifFalse: [ ^ self ].
	(self default server isNil)
		ifTrue: [ [ self start ] forkAt: Processor userSchedulingPriority ]! !

!McpWebServer methodsFor: 'private' stamp: 'sf 13/Aug/2026 08:36:19'!
dispatchRequest: request url: dispatchUrl
	"Answer super's behavior, except that when CORS is configured the preflight
	OPTIONS and method-not-allowed responses are generated here with CORS headers.
	This is needed because WebServer answers those itself before dispatching to
	the registered service."
	| action |
	(request method = 'TRACE' or: [ mcpOwner isNil or: [ mcpOwner corsAllowedOrigin isNil ] ])
		ifTrue: [ ^ super dispatchRequest: request url: dispatchUrl ].
	action := self entryActionFor: dispatchUrl.
	(request method = 'OPTIONS')
		ifTrue: [ ^ self optionsResponseFor: request action: action ].
	(action notNil and: [ request method ~= 'HEAD' and: [ (action first includes: request method) not ] ])
		ifTrue: [ ^ self methodNotAllowedResponseTo: request action: action ].
	^ super dispatchRequest: request url: dispatchUrl! !

!McpWebServer methodsFor: 'private' stamp: 'sf 13/Aug/2026 08:36:21'!
entryActionFor: dispatchUrl
	"Answer the registered service entry {methods. action} for dispatchUrl, or nil.
	Mirrors WebServer's own entry point lookup."
	| entryUrl action |
	entryUrl := dispatchUrl percentEscapeUrl asLowercase.
	(entryUrl beginsWith: '/') ifFalse: [ entryUrl := '/', entryUrl ].
	mutex critical: [
		[ entryUrl notEmpty and: [ action == nil ] ] whileTrue: [
			action := entryPoints at: entryUrl ifAbsent: [ nil ].
			entryUrl := entryUrl copyUpToLast: $/ ].
		action ifNil: [ action := entryPoints at: '/' ifAbsent: [ nil ] ] ].
	^ action! !

!McpWebServer methodsFor: 'private' stamp: 'sf 13/Aug/2026 08:36:23'!
methodNotAllowedResponseTo: request action: action
	"Answer a CORS-enabled 405 response for a method not served by the endpoint."
	| allowedMethods resp |
	allowedMethods := self builtinHttpMethods, (action ifNil: [ self defaultHttpMethods ] ifNotNil: [ action first ]).
	resp := request newResponse protocol: 'HTTP/1.1' code: 405.
	resp headerAt: 'Content-Type' put: 'text/html; charset=utf-8'.
	resp headerAt: 'allow' put: (String streamContents: [ :s |
		allowedMethods do: [ :m | s nextPutAll: m ] separatedBy: [ s nextPut: $, ] ]).
	mcpOwner applyCorsHeadersTo: resp.
	^ request sendResponse: resp content: 'Method Not Allowed'! !

!McpWebServer methodsFor: 'private' stamp: 'sf 13/Aug/2026 08:36:22'!
optionsResponseFor: request action: action
	"Answer a CORS-enabled 200 OPTIONS (preflight) response. The 'allow' header
	lists the methods the server supports."
	| allowedMethods resp |
	allowedMethods := self builtinHttpMethods, (action ifNil: [ self defaultHttpMethods ] ifNotNil: [ action first ]).
	resp := request newResponse protocol: 'HTTP/1.1' code: 200.
	resp headerAt: 'allow' put: (String streamContents: [ :s |
		allowedMethods do: [ :m | s nextPutAll: m ] separatedBy: [ s nextPut: $, ] ]).
	mcpOwner applyCorsHeadersTo: resp.
	^ request sendResponse: resp content: ''! !

!McpWebServer methodsFor: 'private' stamp: 'sf 13/Aug/2026 08:34:30'!
optionsResponseFor: request at: dispatchUrl
	"Answer the CORS-enabled OPTIONS response. Mirrors WebServer's own lookup
	of the entry point so the 'allow' header matches the registered service."
	| entryUrl action allowed resp |
	entryUrl := dispatchUrl percentEscapeUrl asLowercase.
	(entryUrl beginsWith: '/') ifFalse: [ entryUrl := '/', entryUrl ].
	action := nil.
	mutex critical: [
		[ entryUrl notEmpty and: [ action == nil ] ] whileTrue: [
			action := entryPoints at: entryUrl ifAbsent: [ nil ].
			entryUrl := entryUrl copyUpToLast: $/ ].
		action ifNil: [ action := entryPoints at: '/' ifAbsent: [ nil ] ] ].
	allowed := self builtinHttpMethods, (action ifNil: [ self defaultHttpMethods ] ifNotNil: [ action first ]).
	resp := request newResponse protocol: 'HTTP/1.1' code: 200.
	resp headerAt: 'allow' put: (String streamContents: [ :s |
		allowed do: [ :m | s nextPutAll: m ] separatedBy: [ s nextPut: $, ] ]).
	mcpOwner applyCorsHeadersTo: resp.
	^ request sendResponse: resp content: ''! !

!McpWebServer methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 08:34:31'!
mcpOwner
	"Answer the RemoteControlMCP instance that owns this server."
	^ mcpOwner! !

!McpWebServer methodsFor: 'accessing' stamp: 'sf 13/Aug/2026 08:34:31'!
mcpOwner: aRemoteControlMCP
	"Set the RemoteControlMCP instance that owns this server."
	mcpOwner := aRemoteControlMCP! !

!McpSseSession methodsFor: 'accessing' stamp: 'sf 14/Aug/2026 09:00:00'!
id
	"Answer the session id."
	^ id! !

!McpSseSession methodsFor: 'accessing' stamp: 'sf 14/Aug/2026 09:00:00'!
id: aString
	id := aString! !

!McpSseSession methodsFor: 'accessing' stamp: 'sf 14/Aug/2026 09:00:00'!
isOpen
	"Answer whether the event stream can still be written to."
	^ open! !

!McpSseSession methodsFor: 'accessing' stamp: 'sf 14/Aug/2026 09:00:00'!
stream
	"Answer the underlying socket stream."
	^ stream! !

!McpSseSession methodsFor: 'accessing' stamp: 'sf 14/Aug/2026 09:00:00'!
stream: aStream
	stream := aStream! !

!McpSseSession methodsFor: 'initialization' stamp: 'sf 14/Aug/2026 09:00:00'!
initialize
	super initialize.
	open := true.
	writeMutex := Semaphore forMutualExclusion! !

!McpSseSession methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
close
	"Close the event stream. Idempotent."
	open := false! !

!McpSseSession methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
sendEndpointEvent: anEndpointUrl
	"Announce the messages endpoint URL to the client."
	self sendEvent: 'endpoint' data: anEndpointUrl! !

!McpSseSession methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
sendEvent: anEventName data: aDataString
	"Write one named SSE event frame."
	self sendFrame: 'event: ', anEventName, String crlfString,
		'data: ', aDataString, String crlfString, String crlfString! !

!McpSseSession methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
sendFrame: aFrame
	"Write one SSE frame to the stream as UTF-8 bytes, guarded by the write
	mutex. A failed write closes the session."
	writeMutex critical: [
		self isOpen ifTrue: [
			[ self stream nextPutAll: aFrame asUtf8Bytes.
			  self stream flush ]
				on: Error do: [ :ex | self close ] ] ]! !

!McpSseSession methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
sendKeepAlive
	"Send a comment frame so proxies and clients see a live connection."
	self sendFrame: ': keep-alive', String crlfString, String crlfString! !

!McpSseSession methodsFor: 'sse' stamp: 'sf 14/Aug/2026 09:00:00'!
sendMessageEvent: aJsonString
	"Send one JSON-RPC response as an SSE message event."
	self sendEvent: 'message' data: aJsonString! !

!WebUtils class methodsFor: 'json' stamp: 'sf 14/Aug/2026 18:30:00'!
jsonMapFrom: stream
	"Decodes a JSON {key:value, *} object from the stream.
	FIX: an empty object {} must also consume its closing } so the parent map
	does not swallow following keys. See docs/WebUtils-jsonMapFrom-Bug.md"

	| map ch key value |
	map := Dictionary new.
	(ch := stream next) = ${ ifFalse:[^self error: 'JSON Object expected'].
	stream skipSeparators.
	stream peek = $} ifTrue:[stream next. ^map].

	["Decode the next key:value pair"
	stream skipSeparators.
	key := self jsonStringFrom: stream.
	stream skipSeparators.
	stream next = $: ifFalse:[^self error: 'Key-value pair expected'].
	value := self jsonDecode: stream.
	map at: key put: value.
	stream skipSeparators.
	(ch := stream next) = $}] whileFalse:[
		ch = $, ifFalse:[^self error: 'Comma expected'].
	].

	^map! !

!ClassDescription methodsFor: '*RemoteControlMCP' stamp: 'ML 13/May/2026 07:31:26'!
safelyCompile: source classified: aCategory
	"Compile one method, with the three things bridge callers always want:
	  - Noisy Notifications (InMidstOfFileinNotification, UndeclaredVariableWarning, ...)
	    are resumed so they don't poison the compile.
	  - The method is stamped via Utilities changeStamp.
	  - Smalltalk forceChangesToDisk runs so #authorAndStamp is readable immediately.
	Returns the compiled selector. Errors propagate.

	   Dock safelyCompile: 'foo ^ 42' classified: 'misc'
	   Dock class safelyCompile: 'hi ^ ''hello''' classified: 'misc'
	"
	| selector |
	[
		selector := self
			compile: source
			classified: aCategory
			withStamp: Utilities changeStamp
			notifying: nil
	] on: Notification do: [:ex | ex resume: true].
	Smalltalk forceChangesToDisk.
	^ selector! !

!PopUpMenu methodsFor: '*RemoteControlMCP' stamp: 'sf 06/Sep/2026'!
 startUpWithCaption: captionOrNil at: location allowKeyboard: aBoolean
	"Headless guard: while an MCP eval runs, modal menus can never be answered
	(no user, no UI event loop). Auto-answer so evals that trigger dialog code do
	not spin forever in the `[(choice := menu startUpWithCaption:) isNil] whileTrue`
	loop. Never auto-confirm: single-item menus (inform: ' OK ') answer 1, but any
	two-item menu (confirm:, {trueChoice. falseChoice}) answers 0, i.e. the cancel
	choice, so that a destructive action guarded by a confirm: (e.g. an install
	that would discard unsaved package changes) is never silently confirmed."
	(Smalltalk at: #McpEvaluating ifAbsent: [ false ])
		ifTrue: [ ^ self labelString lineCount <= 1 ifTrue: [ 1 ] ifFalse: [ 0 ] ].
	^ self mcpPopUpNormalStartUpWithCaption: captionOrNil at: location allowKeyboard: aBoolean! !

!PopUpMenu methodsFor: '*RemoteControlMCP' stamp: 'sf 06/Sep/2026'!
mcpPopUpNormalStartUpWithCaption: captionOrNil at: location allowKeyboard: aBoolean
	"Original behavior of #startUpWithCaption:at:allowKeyboard:. Display the menu,
	with caption if supplied. Wait for the mouse button to go down, then track the
	selection as long as the button is pressed. Answer the index of the current
	selection, or zero if the mouse is not released over any menu item."
	| maxHeight |
	maxHeight := Display height * 3 // 4.
	self frameHeight > maxHeight
		ifTrue: [
			^self
				startUpSegmented: maxHeight
				withCaption: captionOrNil
				at: location
				allowKeyboard: aBoolean].
	^(MVCMenuMorph from: self title: captionOrNil)
		invokeAt: location
		allowKeyboard: aBoolean! !
