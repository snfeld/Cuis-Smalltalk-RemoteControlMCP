'From Cuis7.8 [latest update: #xxxx] on 14 August 2026 at 6:45:00 pm'!
'Description Tests for the WebUtils jsonMapFrom: empty-object bug (leeres JSON-Objekt {} verschluckt Folge-Keys). Siehe docs/WebUtils-jsonMapFrom-Bug.md.'!
!provides: 'Tests-RemoteControlMCP' 1 0!
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

!WebUtilsJsonTest methodsFor: 'tests' stamp: 'H9 14/Aug/2026 18:45:00'!
testEmptyObjectDoesNotSwallowFollowingKeys
	"Kern des Bugs: auf {} muss die Parserschleife das schliessende } konsumieren,
	sonst verschwinden die Folge-Keys 'b'."

	| dict |
	dict := WebUtils jsonDecode: '{"a":{},"b":2}' readStream.
	self assert: dict size = 2.
	self assert: ((dict at: 'a') isKindOf: Dictionary).
	self assert: (dict at: 'a') isEmpty.
	self assert: (dict at: 'b') = 2! !

!WebUtilsJsonTest methodsFor: 'tests' stamp: 'H9 14/Aug/2026 18:45:00'!
testEmptyObjectAsLastValue
	"{} als letzter Wert duerfen keine Folge-Keys verschlucken."

	| dict |
	dict := WebUtils jsonDecode: '{"a":{}}' readStream.
	self assert: dict size = 1.
	self assert: (dict at: 'a') isEmpty! !

!WebUtilsJsonTest methodsFor: 'tests' stamp: 'H9 14/Aug/2026 18:45:00'!
testEmptyTopLevelObject
	"Ein einzelnes leeres Objekt."

	| dict |
	dict := WebUtils jsonDecode: '{}' readStream.
	self assert: dict isEmpty! !

!WebUtilsJsonTest methodsFor: 'tests' stamp: 'H9 14/Aug/2026 18:45:00'!
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

!WebUtilsJsonTest methodsFor: 'tests' stamp: 'H9 14/Aug/2026 18:45:00'!
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

!WebUtilsJsonTest methodsFor: 'tests' stamp: 'H9 14/Aug/2026 18:45:00'!
testRegressionUnfalsified
	"Guard: Ohne den WebUtils-Fix (stream peek = $} ifTrue:[stream next. ^map])
	schlaegt mindestens dieser Test fehl — hier der Nachweis, dass der Parser
	aktuell NICHT mehr das fehlerhafte Verhalten zeigt."

	| dict |
	dict := WebUtils jsonDecode: '{"capabilities":{},"jsonrpc":"2.0","id":0}' readStream.
	self assert: dict size = 3.
	self assert: (dict at: 'jsonrpc') = '2.0'.
	self assert: (dict at: 'id') = 0! !
