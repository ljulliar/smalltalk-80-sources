"
The real hardware abstraction layer, but with a millisecond clock that the tests set, to test the timer without waiting and across the roll over of the clock.
"
Class {
	#name : 'InterpreterTestClockHAL',
	#superclass : 'ST80HardwareAbstractionLayer',
	#instVars : [
		'uptime',
		'drainedWords',
		'drainCount'
	],
	#category : 'Smalltalk-80 VM-Tests',
	#package : 'Smalltalk-80 VM-Tests'
}

{ #category : 'paste' }
InterpreterTestClockHAL >> drainCount [

	^ drainCount ifNil: [ 0 ]
]

{ #category : 'paste' }
InterpreterTestClockHAL >> keysTyped [
	"The codes of the keys that went down in the guest, in order (the immediate down transitions of a decoded keyboard)"

	^ (self wordsOfType: 3) asArray
]

{ #category : 'time management' }
InterpreterTestClockHAL >> millisecondsUptime [

	^ uptime ifNil: [ 0 ]
]

{ #category : 'configuration' }
InterpreterTestClockHAL >> scheduledSemaphore [

	^ scheduledSemaphore
]

{ #category : 'configuration' }
InterpreterTestClockHAL >> uptime: milliseconds [

	uptime := milliseconds
]

{ #category : 'clipboard' }
InterpreterTestClockHAL >> waitForGuestToReadInput [
	"The guest of the test reads at once everything queued so far: keep what it read, and count the batches"

	drainedWords ifNil: [ drainedWords := OrderedCollection new ].
	drainCount := (drainCount ifNil: [ 0 ]) + 1.
	[ inputQueue isEmpty ] whileFalse: [
		drainedWords add: inputQueue removeFirst ].
	^ true
]

{ #category : 'paste' }
InterpreterTestClockHAL >> wordsOfType: aType [
	"The parameters of the input words of that type (BB p. 649) that the guest read so far (the words still queued are read first)"

	| words |
	words := (drainedWords ifNil: [ #(  ) ]) asOrderedCollection
		         addAll: inputQueue;
		         yourself.
	^ (words select: [ :each | each >> 12 = aType ]) collect: [ :each |
		  each bitAnd: 16rFFF ]
]

{ #category : 'paste' }
InterpreterTestClockHAL >> wordsRead [
	"How many input words the guest read so far, the words still queued included"

	^ (drainedWords ifNil: [ #(  ) ]) size + inputQueue size
]
