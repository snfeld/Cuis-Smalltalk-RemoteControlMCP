"Startup for the Cuis7.8-opencode image: install RemoteControlMCP from the
package file, then start the RemoteControl server (port 2347) and the MCP
server (port 2357) on the loopback interface. Progress and errors to stdout."

| out rcServer |
out := StdIOWriteStream stdout.
out nextPutAll: 'CUIS-START: loading RemoteControlMCP package...'; newLine; flush.
[
	CodePackageFile installPackage: '/workspace/remotemcp/packages/RemoteControlMCP.pck.st' asFileEntry.
	out nextPutAll: 'CUIS-START: package installed.'; newLine; flush.
	rcServer := WebServer new listenOn: RemoteControl port interface: #[127 0 0 1].
	rcServer addService: '/eval' action: [ :req | RemoteControl handleEval: req ] methods: #('POST').
	rcServer addService: '/screenshot' action: [ :req | RemoteControl handleScreenshot: req ] methods: #('GET').
	RemoteControl classVarNamed: 'Server' put: rcServer.
	out nextPutAll: 'CUIS-START: RemoteControl started on 2347.'; newLine; flush.
	RemoteControlMCP start.
	out nextPutAll: 'CUIS-START: RemoteControlMCP started on 2357.'; newLine; flush.
	out nextPutAll: 'CUIS-START-OK'; newLine; flush.
] on: Error do: [ :ex |
	out nextPutAll: 'CUIS-START-ERROR: ', ex description; newLine; flush.
	ex signalerContext ifNotNil: [ :c | c printStack: 50 on: out; flush ].
].
out flush.
