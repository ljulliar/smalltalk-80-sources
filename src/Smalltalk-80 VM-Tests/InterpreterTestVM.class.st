"
Stand-in for ST80VirtualMachine in the tests of the snapshot primitive: it only counts the requests to save a snapshot (saveSnapshot), instead of writing the file, so that the test can check that the primitive asked for it.
"
Class {
	#name : 'InterpreterTestVM',
	#superclass : 'Object',
	#instVars : [
		'savedCount'
	],
	#category : 'Smalltalk-80 VM-Tests',
	#package : 'Smalltalk-80 VM-Tests'
}

{ #category : 'vm protocol' }
InterpreterTestVM >> saveSnapshot [
	"Count the request, as ST80VirtualMachine >> saveSnapshot is the one that writes the file"

	savedCount := self savedCount + 1.
	^ true
]

{ #category : 'vm protocol' }
InterpreterTestVM >> savedCount [

	^ savedCount ifNil: [ 0 ]
]
