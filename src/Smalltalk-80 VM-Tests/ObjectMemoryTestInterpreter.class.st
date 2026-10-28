"
Minimal stand-in for the Interpreter, used by ObjectMemoryTest. It registers its roots with the memory at each collection, as the real Interpreter does through prepareForCollection and addRoot:, and counts the completed collections.
"
Class {
	#name : 'ObjectMemoryTestInterpreter',
	#superclass : 'Object',
	#instVars : [
		'collectionCount',
		'memory',
		'roots'
	],
	#category : 'Smalltalk-80 VM-Tests',
	#package : 'Smalltalk-80 VM-Tests'
}

{ #category : 'garbage collection' }
ObjectMemoryTestInterpreter >> collectionCompleted [

	collectionCount := self collectionCount + 1
]

{ #category : 'accessing' }
ObjectMemoryTestInterpreter >> collectionCount [

	^ collectionCount ifNil: [ 0 ]
]

{ #category : 'accessing' }
ObjectMemoryTestInterpreter >> memory: anObjectMemory [

	memory := anObjectMemory
]

{ #category : 'garbage collection' }
ObjectMemoryTestInterpreter >> prepareForCollection [
	"Register our roots, as Interpreter does at each collection"

	self roots do: [ :root | memory addRoot: root ]
]

{ #category : 'accessing' }
ObjectMemoryTestInterpreter >> roots [

	^ roots ifNil: [ roots := OrderedCollection new ]
]
