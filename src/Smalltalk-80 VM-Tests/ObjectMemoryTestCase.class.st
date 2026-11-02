"
Abstract fixture of the VM tests: a small hand built ObjectMemory, with a few free object table entries, the nil object at oop 2, the method class, a class object for the test objects and one free chunk covering the rest of segment 0. Subclasses answer the interpreter the memory reports to (newInterpreter, connectInterpreter) and can place more objects at fixed oops (reservedOops, setUpGuaranteedObjects).
"
Class {
	#name : 'ObjectMemoryTestCase',
	#superclass : 'TestCase',
	#instVars : [
		'memory',
		'interpreter',
		'nilPointer',
		'classPointer',
		'methodClassPointer',
		'nextLocation',
		'cleanups'
	],
	#category : 'Smalltalk-80 VM-Tests',
	#package : 'Smalltalk-80 VM-Tests'
}

{ #category : 'running' }
ObjectMemoryTestCase >> classPointerSize [
	"Number of fields of the class of the test objects: none by default, since the memory tests never look at them"

	^ 0
]

{ #category : 'private' }
ObjectMemoryTestCase >> installObject: oop size: size [
	"Give a fixed oop a pointer object of size words (header included) at the next free location of segment 0. Its fields are nil and its count is saturated, as for the objects the real image guarantees."

	memory ot: oop put: 0.
	memory segmentBitsOf: oop put: 0.
	memory locationBitsOf: oop put: nextLocation.
	memory sizeBitsOf: oop put: size.
	memory classBitsOf: oop put: nilPointer.
	memory pointerBitOf: oop put: 1.
	memory countBitsOf: oop put: 128.
	2 to: size - 1 do: [ :word |
	memory heapChunkOf: oop word: word put: nilPointer ].
	nextLocation := nextLocation + size
]

{ #category : 'running' }
ObjectMemoryTestCase >> newInterpreter [
	"The interpreter the memory reports to. The memory is already built when this is sent."

	^ ObjectMemoryTestInterpreter new
		  memory: memory;
		  yourself
]

{ #category : 'running' }
ObjectMemoryTestCase >> onTearDown: aBlock [
	"Evaluate aBlock at the end of the test, whether it passes or not"

	(cleanups ifNil: [ cleanups := OrderedCollection new ]) add: aBlock
]

{ #category : 'running' }
ObjectMemoryTestCase >> reservedOops [
	"The oops that have a fixed meaning for the code under test, in the order they sit at the start of segment 0. They are never allocated by the tests, and are roots of the garbage collector."

	^ {
		  nilPointer.
		  methodClassPointer }
]

{ #category : 'running' }
ObjectMemoryTestCase >> setUp [

	super setUp.
	memory := ObjectMemory withInterpreter: nil.
	interpreter := self newInterpreter.
	memory instVarNamed: 'interpreter' put: interpreter.
	nilPointer := ObjectMemory classVarNamed: 'NilPointer'.
	methodClassPointer := ObjectMemory classVarNamed: 'MethodClass'.
	self setUpObjectTable.
	self setUpSpecialObjects.
	self setUpFreeChunk.
	"A class for the test objects, referenced once (by us)"
	classPointer := memory
		                instantiateClass: nilPointer
		                withPointers: self classPointerSize.
	memory countUp: classPointer.
	"Permanent roots of the collector: the reserved objects and our class"
	memory
		instVarNamed: 'rootObjectPointers'
		put: (self reservedOops asOrderedCollection
				 add: classPointer;
				 yourself)
]

{ #category : 'running' }
ObjectMemoryTestCase >> setUpFreeChunk [
	"One free chunk covering the rest of segment 0, right after the reserved objects. The whole segment must be described: the compactor walks it up to HeapSpaceStop."

	| size |
	size := (ObjectMemory classVarNamed: 'HeapSpaceStop') + 1
	        - nextLocation.
	memory
		toFreeChunkList: (ObjectMemory classVarNamed: 'BigSize')
		add: (memory obtainPointer: size location: nextLocation).
	memory freeOopsLeft: memory freeOopsLeft - 1.
	memory freeWordsLeft: size
]

{ #category : 'running' }
ObjectMemoryTestCase >> setUpObjectTable [
	"Entries 2 to 1200 are free and chained on the free pointer list, except the reserved ones. The other entries are free but not chained, so the garbage collector skips them."

	| chain reserved |
	reserved := self reservedOops.
	0 to: (ObjectMemory classVarNamed: 'ObjectTableSize') - 2 by: 2 do: [
	:oop | memory freeBitOf: oop put: 1 ].
	chain := (2 to: 1200 by: 2) reject: [ :oop | reserved includes: oop ].
	chain reverseDo: [ :oop |
			memory ot: oop put: 0.
			memory freeBitOf: oop put: 1.
			memory toFreePointerListAdd: oop ].
	memory freeOopsLeft: chain size
]

{ #category : 'running' }
ObjectMemoryTestCase >> setUpSpecialObjects [
	"The reserved objects sit at their fixed oops, at the start of segment 0. Oop 2 is NilPointer: fields of new objects default to it, so it must be a real object. Its count is saturated (128) like in a real image: new objects point to nil without counting it. The method class comes next: the garbage collector must know it to scan the literals of CompiledMethods."

	nextLocation := 0.
	self reservedOops do: [ :oop |
		self installObject: oop size: (self sizeOfReservedOop: oop) ]
]

{ #category : 'running' }
ObjectMemoryTestCase >> sizeOfReservedOop: oop [
	"Size in words, header included, of the reserved object at oop. A header only object by default."

	^ 2
]

{ #category : 'running' }
ObjectMemoryTestCase >> tearDown [
	"Run the cleanups registered by the test, in the reverse order: the last thing set up is the first one undone"

	cleanups ifNotNil: [ cleanups reverseDo: [ :each | each value ] ].
	super tearDown
]
