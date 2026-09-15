'From Cuis7.8 [latest update: 7977] on 15 September 2026 at 6:45:00 pm'!
'Description Tests for the WebUtils jsonMapFrom: empty-object bug (leeres JSON-Objekt {} verschluckt Folge-Keys). Siehe docs/WebUtils-jsonMapFrom-Bug.md.'!
!provides: 'Tests-RemoteControlMCP' 1 1!
!requires: 'RemoteControlMCP' 1 0 nil!
SystemOrganization addCategory: #'Tests-RemoteControlMCP'!

!classDefinition: #WebUtilsJsonTest category: #'Tests-RemoteControlMCP'!
TestCase subclass: #WebUtilsJsonTest
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-RemoteControlMCP'!
!classDefinition: 'WebUtilsJsonTest class' category: #'Tests-RemoteControlMCP'!
WebUtilsJsonTest class
	instanceVariableNames: ''!

!WebUtilsJsonTest commentStamp: '<historical>' prior: 0!
Regression-Tests fuer den WebUtils jsonMapFrom:-Bug (2026-08-14): Beim Parsen
eines leeren JSON-Objekts {} wurde das schliessende } nicht konsumiert, wodurch
der Eltern-Parser Folge-Keys verschluckte (z. B. jsonrpc/id im MCP-initialize).
Voraussetzung: Fix geladen (WebUtils-jsonMapFrom-fix.st oder RemoteControlMCP.pck.st
mit der WebUtils-Klassen-Erweiterung).

Ausfuehren:  WebUtilsJsonTest runAll!

!WebUtilsJsonTest methodsFor: 'tests' stamp: 'sf 14/Aug/2026 18:45:00'!
testEmptyObjectDoesNotSwallowFollowingKeys
	"Kern des Bugs: auf {} muss die Parserschleife das schliessende } konsumieren,
	sonst verschwinden die Folge-Keys 'b'."

	| dict |
	dict := WebUtils jsonDecode: '{"a":{},"b":2}' readStream.
	self assert: dict size = 2.
	self assert: ((dict at: 'a') isKindOf: Dictionary).
	self assert: (dict at: 'a') isEmpty.
	self assert: (dict at: 'b') = 2! !

!WebUtilsJsonTest methodsFor: 'tests' stamp: 'sf 14/Aug/2026 18:45:00'!
testEmptyObjectAsLastValue
	"{} als letzter Wert duerfen keine Folge-Keys verschlucken."

	| dict |
	dict := WebUtils jsonDecode: '{"a":{}}' readStream.
	self assert: dict size = 1.
	self assert: (dict at: 'a') isEmpty! !

!WebUtilsJsonTest methodsFor: 'tests' stamp: 'sf 14/Aug/2026 18:45:00'!
testEmptyTopLevelObject
	"Ein einzelnes leeres Objekt."

	| dict |
	dict := WebUtils jsonDecode: '{}' readStream.
	self assert: dict isEmpty! !

!WebUtilsJsonTest methodsFor: 'tests' stamp: 'sf 14/Aug/2026 18:45:00'!
testNestedEmptyObjectsPreserveAllKeys
	"Exakt der MCP-initialize-Request, der den Bug ausgeloest hat (capabilities:{}).
	Ohne Fix gehen 'jsonrpc' und 'id' verloren und 'clientInfo' leakt nach aussen."

	| dict params |
	dict := WebUtils jsonDecode: '{"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"x","version":"1"}},"jsonrpc":"2.0","id":0}' readStream.
	self assert: dict size = 4.
	self assert: (dict at: 'jsonrpc') = '2.0'.
	self assert: (dict at: 'id') = 0.
	self assert: (dict at: 'method') = 'initialize'.
	params := dict at: 'params'.
	self assert: (params at: 'protocolVersion') = '2025-11-25'.
	self assert: ((params at: 'capabilities') isKindOf: Dictionary).
	self assert: (params at: 'capabilities') isEmpty.
	self assert: ((params at: 'clientInfo') at: 'name') = 'x'! !

!WebUtilsJsonTest methodsFor: 'tests' stamp: 'sf 14/Aug/2026 18:45:00'!
testDispatchJsonRpcWithEmptyCapabilities
	"End-to-End: ein initialize mit capabilities:{} muss ein RESULT (id gematcht)
	liefern und darf nicht mit -32600 Invalid Request / id null antworten."

	| mcp response |
	mcp := RemoteControlMCP new.
	response := mcp dispatchJsonRpcString: '{"method":"initialize","params":{"capabilities":{},"clientInfo":{"name":"t","version":"1"}},"jsonrpc":"2.0","id":7}'.
	self assert: (response at: 'id') = 7.
	self assert: (response includesKey: 'result').
	self assert: ((response at: 'result') includesKey: 'protocolVersion').
	self deny: (response includesKey: 'error')! !

!WebUtilsJsonTest methodsFor: 'tests' stamp: 'sf 14/Aug/2026 18:45:00'!
testRegressionUnfalsified
	"Guard: Ohne den WebUtils-Fix (stream peek = $} ifTrue:[stream next. ^map])
	schlaegt mindestens dieser Test fehl — hier der Nachweis, dass der Parser
	aktuell NICHT mehr das fehlerhafte Verhalten zeigt."

	| dict |
	dict := WebUtils jsonDecode: '{"capabilities":{},"jsonrpc":"2.0","id":0}' readStream.
	self assert: dict size = 3.
	self assert: (dict at: 'jsonrpc') = '2.0'.
	self assert: (dict at: 'id') = 0! !

!classDefinition: #McpEvalJobTest category: #'Tests-RemoteControlMCP'!
TestCase subclass: #McpEvalJobTest
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-RemoteControlMCP'!
!classDefinition: 'McpEvalJobTest class' category: #'Tests-RemoteControlMCP'!
McpEvalJobTest class
	instanceVariableNames: ''!

!McpEvalJobTest commentStamp: '<historical>' prior: 0!
Regression-Tests fuer McpEvalJob (Fix 2026-09-06): Der Job muss auch bei
Notifications terminieren und nicht im headlessen UI-Default-Notifier haengen
bleiben (fehlendes done-Signal → Request-Handler bis Timeout blockiert).
Ausfuehren:  McpEvalJobTest runAll!

!classDefinition: #RemoteControlMCPToolTest category: #'Tests-RemoteControlMCP'!
TestCase subclass: #RemoteControlMCPToolTest
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-RemoteControlMCP'!
!classDefinition: 'RemoteControlMCPToolTest class' category: #'Tests-RemoteControlMCP'!
RemoteControlMCPToolTest class
	instanceVariableNames: ''!

!RemoteControlMCPToolTest commentStamp: '<historical>' prior: 0!
Tests for the RemoteControlMCP introspection, usage, hierarchy tools and
the eval stack trace enhancement.
Ausfuehren:  RemoteControlMCPToolTest runAll!

!McpEvalJobTest methodsFor: 'tests' stamp: 'sf 06/Sep/2026'!
testNotificationInSourceDoesNotHang
	"Eine Notification im Eval-Source (wie die headlesse authorInitials-Prompt-
	Schleife) darf den Job NICHT ewig haengen lassen: done-Signal kommt, Status
	ist done (Notification wird resumed wie in safelyCompile:)."

	| job status |
	job := McpEvalJob new.
	job id: 't-notify'; source: 'InMidstOfFileinNotification new signal. 41 + 1'; timeout: 5.
	job run.
	job waitForCompletionUpTo: 5.
	status := job asStatusDictionary.
	self assert: (status at: 'status') = 'done'.
	self assert: (status at: 'result') = '42'! !

!McpEvalJobTest methodsFor: 'tests' stamp: 'sf 06/Sep/2026'!
testTimeoutTerminatesJobProcess
	"Ein blockierender Eval (Delay auf Semaphore) muss nach dem Timeout den
	Jobprozess WIRKLICH beenden (frueher: state war 'timedOut', aber der Prozess
	blieb verwaist, weil `process` nie gemerkt wurde). Nach dem Timeout darf kein
	McpEval- Prozess mehr existieren."

	| job alives |
	job := McpEvalJob new.
	job id: 't-timeout'; source: '([ (Delay forMilliseconds: 3600000) wait ]) value'; timeout: 1.
	job run.
	job waitForCompletionUpTo: 3.
	self assert: (job asStatusDictionary at: 'status') = 'timedOut'.
	"AllInstances behaelt die beendete Prozess-Referenz bis zum GC, deshalb
	nur noch AKTIVE Prozesse als Fehlschlag werten."
	alives := Process allInstances select: [ :p |
		p isTerminated not and: [
			p name notNil and: [ p name = 'McpEval-t-timeout' ] ] ].
	self assert: alives isEmpty! !

!McpEvalJobTest methodsFor: 'tests' stamp: 'sf 06/Sep/2026'!
testDoneIsSignaledAfterError
	"Selbst nach einem Error im Source muss done signalisiert werden, damit
	waitForCompletionUpTo: sofort (nicht erst per Timeout) zurueckkehrt."

	| job status millis |
	job := McpEvalJob new.
	job id: 't-error'; source: '1 / 0'; timeout: 5.
	millis := Time millisecondsToRun: [
		job run.
		job waitForCompletionUpTo: 5 ].
	status := job asStatusDictionary.
	self assert: (status at: 'status') = 'error'.
	self assert: millis < 2000! !

!McpEvalJobTest methodsFor: 'tests' stamp: 'sf 06/Sep/2026'!
testUndeclaredVariableResolvesAsAutoBinding
	"Regression: `foo := 1. foo + 1` used to fail with
	MessageNotUnderstood: True>>assignmentCheck:at: because undeclared variables
	were evaluated with Compiler evaluate: (no Workspace context). The eval must
	now auto-declare the variable as a Workspace binding (interactive semantics)
	and evaluate to 2."
	| job status |
	job := McpEvalJob new.
	job id: 't-undecl'; source: 'fooX := 1. fooX + 1'; timeout: 5.
	job run.
	job waitForCompletionUpTo: 5.
	status := job asStatusDictionary.
	self assert: (status at: 'status') = 'done'.
	self assert: (status at: 'result') = '2'! !

!McpEvalJobTest methodsFor: 'tests' stamp: 'sf 06/Sep/2026'!
testNoStateLeakBetweenFreshEvals
	"A fresh McpEvalRequestor per job must not carry workspace bindings over to the
	next job: an undeclared variable assigned in one eval is nil (a fresh auto
	binding) in the next. This keeps state from leaking between agent calls."
	| r1 r2 d1 d2 |
	r1 := McpEvalRequestor new.
	r2 := McpEvalRequestor new.
	d1 := r1 evaluate: 'leakVar := 99. leakVar'.
	d2 := r2 evaluate: 'leakVar isNil'.
	self assert: (d1 at: #ok).
	self assert: (d1 at: #value) = '99'.
	self assert: (d2 at: #ok).
	self assert: (d2 at: #value) = 'true'! !

!McpEvalJobTest methodsFor: 'tests' stamp: 'sf 06/Sep/2026'!
testSyntaxErrorReportsErrorInsteadOfNil
	"Regression: a syntax error (e.g. `1 +`) used to answer status done with
	result 'nil' because Compiler evaluate: swallowed the SyntaxErrorNotification.
	With the Workspace-based requestor it must answer a real error instead."
	| job status |
	job := McpEvalJob new.
	job id: 't-syntax'; source: '1 +'; timeout: 5.
	job run.
	job waitForCompletionUpTo: 5.
	status := job asStatusDictionary.
	self assert: (status at: 'status') = 'error'.
	self assert: ((status at: 'error') includesSubString: 'compile failure')! !

!McpEvalJobTest methodsFor: 'tests' stamp: 'sf 06/Sep/2026'!
testHeadlessConfirmAutomaticallyAnswered
	"Regression: an eval whose source triggers a modal confirm: dialog (PopUpMenu)
	used to hang the whole image for minutes (the headless notifier spins in
	`[(choice := menu startUpWithCaption:) isNil] whileTrue`). While an MCP eval
	runs, the McpEvaluating global makes PopUpMenu auto-answer non-destructively:
	a two-item confirm: menu answers the cancel choice, so `confirm:` must answer
	false promptly instead of hanging."
	| before result |
	before := Smalltalk at: #McpEvaluating ifAbsent: [ false ].
	Smalltalk at: #McpEvaluating put: true.
	result := PopUpMenu
		confirm: 'Unsaved package changes will be lost.'
		trueChoice: 'Continue'
		falseChoice: 'Cancel'.
	Smalltalk at: #McpEvaluating put: before.
	self assert: result = false! !

!McpEvalJobTest methodsFor: 'tests' stamp: 'sf 15/Sep/2026 13:00:00'!
testSyncTimeoutKeepsJobRunningAndPollable
	"A sync eval that outlives its timeout must NOT kill the job: it must answer
	status 'running' with a jobId, and the running job must later finish and be
	pollable via eval_status (tool answer). Long-running evals lose no work."
	| mcp outcome job status |
	mcp := RemoteControlMCP default.
	mcp registerTools.
	outcome := mcp evaluateSource: '[ (Delay forMilliseconds: 2000) wait. 42 ] value' timeout: 1.
	self assert: (outcome at: 'status') = 'running'.
	job := mcp jobs at: (outcome at: 'jobId').
	job waitForCompletionUpTo: 5.
	status := mcp evalStatusTool: ({ 'jobId' -> (outcome at: 'jobId') } asDictionary).
	self assert: (((status at: 1) at: 'text') includesSubString: 'done').
	self assert: (((status at: 1) at: 'text') includesSubString: '42')! !

!McpEvalJobTest methodsFor: 'tests' stamp: 'sf 15/Sep/2026 13:00:00'!
testCancelEvalTerminatesAndRemovesJob
	"eval_cancel must terminate a still-running job, report it as 'cancelled', and
	remove it from the jobs registry."
	| mcp outcome jobId statusRegistered status resultText removed |
	mcp := RemoteControlMCP default.
	mcp registerTools.
	outcome := mcp evaluateSource: '[ (Delay forMilliseconds: 3600000) wait. 42 ] value' timeout: 1.
	jobId := outcome at: 'jobId'.
	statusRegistered := mcp jobs includesKey: jobId.
	status := mcp cancelEvalTool: ({ 'jobId' -> jobId } asDictionary).
	resultText := (status at: 1) at: 'text'.
	removed := (mcp jobs includesKey: jobId) not.
	self assert: statusRegistered.
	self assert: (resultText includesSubString: 'cancelled').
	self assert: removed! !

!classDefinition: #RemoteControlMCPToolTest category: #'Tests-RemoteControlMCP'!
TestCase subclass: #RemoteControlMCPToolTest
	instanceVariableNames: ''
	classVariableNames: ''
	poolDictionaries: ''
	category: 'Tests-RemoteControlMCP'!
!classDefinition: 'RemoteControlMCPToolTest class' category: #'Tests-RemoteControlMCP'!
RemoteControlMCPToolTest class
	instanceVariableNames: ''!

!RemoteControlMCPToolTest commentStamp: '<historical>' prior: 0!
Tests for the RemoteControlMCP introspection and hierarchy tools.
Ausfuehren:  RemoteControlMCPToolTest runAll!

!RemoteControlMCPToolTest methodsFor: 'helpers' stamp: 'sf 15/Sep/2026 14:00:00'!
textOf: toolResult
	"Extract the text string from a success toolTextResult: (an Array of one textContent dict)."
	^ (toolResult first at: 'text')! !

!RemoteControlMCPToolTest methodsFor: 'helpers' stamp: 'sf 15/Sep/2026 14:00:00'!
errorTextOf: toolErrorResult
	"Extract the error text string from a toolErrorResult: (a Dictionary with isError)."
	^ (toolErrorResult at: 'content') first at: 'text'! !

!RemoteControlMCPToolTest methodsFor: 'tests' stamp: 'sf 15/Sep/2026 14:20:00'!
testMethodSourceFindOwn
	"String>>#asUppercase is defined on String itself."
	| mcp result |
	mcp := RemoteControlMCP new.
	result := mcp methodSourceTool: ({ 'className' -> 'String'. 'selector' -> 'asUppercase' } asDictionary).
	self assert: ((self textOf: result) includesSubString: 'String >> asUppercase').
	self assert: ((self textOf: result) includesSubString: '(defined in:') not! !

!RemoteControlMCPToolTest methodsFor: 'tests' stamp: 'sf 15/Sep/2026 14:20:00'!
testMethodSourceSuperclassWhenRequested
	"True>>#asString is inherited from Object; with includeSuperclasses the defining class is named."
	| mcp result |
	mcp := RemoteControlMCP new.
	result := mcp methodSourceTool: ({
		'className' -> 'True'.
		'selector' -> 'asString'.
		'includeSuperclasses' -> true } asDictionary).
	self assert: ((self textOf: result) includesSubString: '(defined in: Object)')! !

!RemoteControlMCPToolTest methodsFor: 'tests' stamp: 'sf 15/Sep/2026 14:20:00'!
testMethodSourceNotFoundWithoutSuperclasses
	"True does not define #asString; with includeSuperclasses:false an error is returned."
	| mcp result |
	mcp := RemoteControlMCP new.
	result := mcp methodSourceTool: ({ 'className' -> 'True'. 'selector' -> 'asString' } asDictionary).
	self assert: (result at: 'isError').
	self assert: ((self errorTextOf: result) includesSubString: 'No implementor')! !

!RemoteControlMCPToolTest methodsFor: 'tests' stamp: 'sf 15/Sep/2026 14:00:00'!
testSelectorUsage
	"#asString is both implemented and sent in the image."
	| mcp result |
	mcp := RemoteControlMCP new.
	result := mcp selectorUsageTool: ({ 'selector' -> 'asString' } asDictionary).
	self assert: ((self textOf: result) includesSubString: 'Implementors of #asString').
	self assert: ((self textOf: result) includesSubString: 'Senders of #asString')! !

!RemoteControlMCPToolTest methodsFor: 'tests' stamp: 'sf 15/Sep/2026 14:20:00'!
testClassHierarchy
	"True's ancestors include True, Boolean, Object, ProtoObject."
	| mcp result |
	mcp := RemoteControlMCP new.
	result := mcp classHierarchyTool: ({ 'className' -> 'True' } asDictionary).
	self assert: ((self textOf: result) includesSubString: 'Ancestry of True').
	self assert: ((self textOf: result) includesSubString: 'True').
	self assert: ((self textOf: result) includesSubString: 'Object')! !

!RemoteControlMCPToolTest methodsFor: 'tests' stamp: 'sf 15/Sep/2026 14:20:00'!
testEvalErrorIncludesStack
	"An eval error must carry a readable stack trace inside the error text."
	| job status |
	job := McpEvalJob new.
	job id: 't-stack'; source: '1/0'; timeout: 5.
	job run.
	job waitForCompletionUpTo: 5.
	status := job asStatusDictionary.
	self assert: (status at: 'status') = 'error'.
	self assert: ((status at: 'error') includesSubString: 'Stack:')! !

!RemoteControlMCPToolTest methodsFor: 'tests' stamp: 'sf 15/Sep/2026 14:00:00'!
testUnknownClassError
	"An unknown class name must produce an error."
	| mcp result |
	mcp := RemoteControlMCP new.
	result := mcp methodSourceTool: ({ 'className' -> 'ZZZUnknown123'. 'selector' -> 'foo' } asDictionary).
	self assert: (result at: 'isError').
	self assert: ((self errorTextOf: result) includesSubString: 'Unknown class')! !
