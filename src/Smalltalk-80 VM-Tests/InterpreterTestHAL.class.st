"
Stand-in for ST80HardwareAbstractionLayer in the tests of the input and output primitives of the Interpreter. It answers canned values (mouse position, input queue, clocks), accepts every display and cursor request, and records each call in calls, as an association from the selector to its arguments, so that a test can check what the primitive asked the host to do. It opens no window.
"
Class {
	#name : 'InterpreterTestHAL',
	#superclass : 'Object',
	#instVars : [
		'eventDriven',
		'mousePosition',
		'inputQueue',
		'calls',
		'uptime',
		'seconds',
		'displayAccepted',
		'vm'
	],
	#category : 'Smalltalk-80 VM-Tests',
	#package : 'Smalltalk-80 VM-Tests'
}

{ #category : 'configuration' }
InterpreterTestHAL >> calls [
	"What the primitives asked of the host, oldest first: associations from a selector to its arguments"

	^ calls
]

{ #category : 'configuration' }
InterpreterTestHAL >> callsTo: aSelector [
	"The arguments of each request of that selector, oldest first, as an Array of Arrays"

	^ (calls
		   select: [ :each | each key = aSelector ]
		   thenCollect: [ :each | each value ]) asArray
]

{ #category : 'hal protocol' }
InterpreterTestHAL >> checkScheduledSemaphore [

	calls add: #checkScheduledSemaphore -> #(  )
]

{ #category : 'hal protocol' }
InterpreterTestHAL >> cursor: anOop memory: aMemory [

	calls add: #cursor:memory: -> { anOop }.
	^ true
]

{ #category : 'hal protocol' }
InterpreterTestHAL >> cursorLink: aBoolean [

	calls add: #cursorLink: -> { aBoolean }
]

{ #category : 'hal protocol' }
InterpreterTestHAL >> cursorLocation: aPoint [

	calls add: #cursorLocation: -> { aPoint }
]

{ #category : 'configuration' }
InterpreterTestHAL >> displayAccepted: aBoolean [
	"What displayWidth:displayHeight: answers: false is a host that cannot show a display of that size"

	displayAccepted := aBoolean
]

{ #category : 'hal protocol' }
InterpreterTestHAL >> displayWidth: width displayHeight: height [

	calls add: #displayWidth:displayHeight: -> {
			width.
			height }.
	^ displayAccepted
]

{ #category : 'configuration' }
InterpreterTestHAL >> eventDriven: aBoolean [
	"When true the Interpreter does not poll the mouse: primitiveMousePoint fails"

	eventDriven := aBoolean
]

{ #category : 'initialization' }
InterpreterTestHAL >> initialize [

	super initialize.
	eventDriven := false.
	mousePosition := 0 @ 0.
	inputQueue := OrderedCollection new.
	calls := OrderedCollection new.
	uptime := 0.
	seconds := 0.
	displayAccepted := true
]

{ #category : 'hal protocol' }
InterpreterTestHAL >> inputSemaphore: aSemaphore [

	calls add: #inputSemaphore: -> { aSemaphore }
]

{ #category : 'hal protocol' }
InterpreterTestHAL >> isInputEventDriven [

	^ eventDriven
]

{ #category : 'hal protocol' }
InterpreterTestHAL >> millisecondsUptime [

	^ uptime
]

{ #category : 'hal protocol' }
InterpreterTestHAL >> mousePosition [

	^ mousePosition
]

{ #category : 'configuration' }
InterpreterTestHAL >> mousePosition: aPoint [

	mousePosition := aPoint
]

{ #category : 'hal protocol' }
InterpreterTestHAL >> nextInputWord [

	^ inputQueue isEmpty
		  ifTrue: [ nil ]
		  ifFalse: [ inputQueue removeFirst ]
]

{ #category : 'configuration' }
InterpreterTestHAL >> queueInputWord: aWord [
	"Put a word in the input queue, as the host does for each event"

	inputQueue add: aWord
]

{ #category : 'hal protocol' }
InterpreterTestHAL >> quit [

	calls add: #quit -> #(  )
]

{ #category : 'hal protocol' }
InterpreterTestHAL >> sampleInterval: anInteger [

	calls add: #sampleInterval: -> { anInteger }
]

{ #category : 'configuration' }
InterpreterTestHAL >> seconds: aNumber [

	seconds := aNumber
]

{ #category : 'hal protocol' }
InterpreterTestHAL >> secondsSinceSmalltalkEpoch [

	^ seconds
]

{ #category : 'hal protocol' }
InterpreterTestHAL >> signal: aSemaphore atMilliseconds: time [

	calls add: #signal:atMilliseconds: -> {
			aSemaphore.
			time }
]

{ #category : 'hal protocol' }
InterpreterTestHAL >> updateDisplayRect: aRectangle fromForm: aForm [

	calls add: #updateDisplayRect:fromForm: -> { aRectangle }
]

{ #category : 'configuration' }
InterpreterTestHAL >> uptime: milliseconds [

	uptime := milliseconds
]

{ #category : 'configuration' }
InterpreterTestHAL >> vm [
	"The stand-in for the virtual machine, which the snapshot primitive asks to save the file"

	^ vm ifNil: [ vm := InterpreterTestVM new ]
]
