"Description: Fix fuer WebUtils class >> jsonMapFrom: (leeres JSON-Objekt {} verschluckte Folge-Keys des Eltern-Objekts). Einziger Unterschied zur Original-Methode: die Zeile 'stream peek = $} ifTrue:[stream next. ^map]'. Details + Unit-Tests: docs/WebUtils-jsonMapFrom-Bug.md und Tests-RemoteControlMCP.pck.st"!

!WebUtils class methodsFor: 'json' stamp: 'H9 14/Aug/2026 18:30:00'!
jsonMapFrom: stream
	"Decodes a JSON {key:value, *} object from the stream.
	FIX (2026-08-14): ein leeres Objekt {} muss auch sein schliessendes } konsumieren
	(stream next), sonst frisst der Eltern-Parser dieses } als sein eigenes Ende und
	verschluckt alle Folge-Keys des Eltern-Objekts. Siehe docs/WebUtils-jsonMapFrom-Bug.md."

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
