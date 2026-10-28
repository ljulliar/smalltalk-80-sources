"
Tests for ObjectMemory, the Smalltalk-80 object table and heap manager (Blue Book ch. 30). Each test runs on a small hand-built memory: a handful of free object table entries, a nil object at oop 2, a class object and one free chunk in segment 0. The interpreter is a stub. See setUp.
"
Class {
	#name : 'ObjectMemoryTest',
	#superclass : 'TestCase',
	#instVars : [
		'memory',
		'nilPointer',
		'interpreter',
		'classPointer',
		'methodClassPointer'
	],
	#category : 'Smalltalk-80 VM-Tests',
	#package : 'Smalltalk-80 VM-Tests'
}

{ #category : 'private' }
ObjectMemoryTest >> fillFirstSegment [
	"Allocate until segment 0 cannot hold an object of 6000 words any more. The objects are garbage, but no collection runs: a segment is only compacted when an allocation cannot be satisfied."

	3 timesRepeat: [
		memory instantiateClass: classPointer withPointers: 20000 ].
	self assert: (memory sizeBitsOf: (memory
				  headOfFreeChunkList: (ObjectMemory classVarNamed: 'BigSize')
				  inSegment: 0)) < 6002
]

{ #category : 'private' }
ObjectMemoryTest >> reloadedMemory [
	"Save the memory to a byte stream and load it in a new memory"

	| stream reloaded |
	stream := WriteStream on: ByteArray new.
	memory saveObjectsToStream: stream.
	reloaded := ObjectMemory withInterpreter: interpreter.
	reloaded
		loadWithSnapshot: (ReadStream on: stream contents)
		debug: false.
	^ reloaded
]

{ #category : 'running' }
ObjectMemoryTest >> setUp [

	super setUp.
	interpreter := ObjectMemoryTestInterpreter new.
	memory := ObjectMemory withInterpreter: interpreter.
	interpreter memory: memory.
	methodClassPointer := ObjectMemory classVarNamed: 'MethodClass'.
	self setUpObjectTable.
	self setUpSpecialObjects.
	self setUpFreeChunk.
	"A class for the test objects, referenced once (by us)"
	classPointer := memory instantiateClass: nilPointer withPointers: 0.
	memory countUp: classPointer.
	"Permanent roots of the collector: nil, the method class and our class"
	memory instVarNamed: 'rootObjectPointers' put: (OrderedCollection
			 with: nilPointer
			 with: methodClassPointer
			 with: classPointer)
]

{ #category : 'running' }
ObjectMemoryTest >> setUpFreeChunk [
	"One free chunk covering the rest of segment 0, starting right after the method class. The whole segment must be described: the compactor walks it up to HeapSpaceStop."

	| size |
	size := (ObjectMemory classVarNamed: 'HeapSpaceStop') + 1 - 4.
	memory
		toFreeChunkList: (ObjectMemory classVarNamed: 'BigSize')
		add: (memory obtainPointer: size location: 4).
	memory freeOopsLeft: memory freeOopsLeft - 1.
	memory freeWordsLeft: size
]

{ #category : 'private' }
ObjectMemoryTest >> setUpFreeChunkInSegment: segment [
	"Make the whole of a heap segment one free chunk, as the snapshot loader does for the space it does not use. The current segment is left unchanged."

	| current |
	current := memory instVarNamed: 'currentSegment'.
	memory instVarNamed: 'currentSegment' put: segment.
	memory
		toFreeChunkList: (ObjectMemory classVarNamed: 'BigSize')
		add: (memory
				 obtainPointer: (ObjectMemory classVarNamed: 'HeapSpaceStop') + 1
				 location: 0).
	memory instVarNamed: 'currentSegment' put: current
]

{ #category : 'running' }
ObjectMemoryTest >> setUpObjectTable [
	"Entries 2 to 40 are free and chained on the free pointer list, except the one of the method class. The other entries are free but not chained, so the garbage collector skips them."

	0 to: (ObjectMemory classVarNamed: 'ObjectTableSize') - 2 by: 2 do: [
	:oop | memory freeBitOf: oop put: 1 ].
	((2 to: 40 by: 2) copyWithout: methodClassPointer) reverseDo: [ :oop |
			memory ot: oop put: 0.
			memory freeBitOf: oop put: 1.
			memory toFreePointerListAdd: oop ].
	memory freeOopsLeft: 19
]

{ #category : 'running' }
ObjectMemoryTest >> setUpSpecialObjects [
	"Oop 2 is NilPointer: fields of new objects default to it, so it must be a real object. Its count is saturated (128) like in a real image: new objects point to nil without counting it. The method class is a header only object right after nil, also saturated: the garbage collector must know it to scan the literals of CompiledMethods."

	nilPointer := memory obtainPointer: 2 location: 0.
	memory countBitsOf: nilPointer put: 128.
	memory freeOopsLeft: memory freeOopsLeft - 1.
	memory ot: methodClassPointer put: 0.
	memory segmentBitsOf: methodClassPointer put: 0.
	memory locationBitsOf: methodClassPointer put: 2.
	memory sizeBitsOf: methodClassPointer put: 2.
	memory classBitsOf: methodClassPointer put: nilPointer.
	memory pointerBitOf: methodClassPointer put: 1.
	memory countBitsOf: methodClassPointer put: 128
]

{ #category : 'tests - accessors' }
ObjectMemoryTest >> testAddressOfObject [
	"The address of an object is its segment in the high bits and its location in the low 16 bits."

	| object |
	object := memory instantiateClass: classPointer withPointers: 1.

	self
		assert: (memory addressOfObject: object)
		equals: (memory locationBitsOf: object).
	self assert: (memory addressOfObject: object) < 65536
]

{ #category : 'tests - accessors' }
ObjectMemoryTest >> testAddressOfObjectInOtherSegment [
	"In segment 1 the address is 65536 plus the location."

	| object |
	self setUpFreeChunkInSegment: 1.
	self fillFirstSegment.
	object := memory instantiateClass: classPointer withPointers: 6000.

	self
		assert: (memory addressOfObject: object)
		equals: 65536 + (memory locationBitsOf: object)
]

{ #category : 'tests - accessors' }
ObjectMemoryTest >> testAddressOfWordSkipsTheHeader [
	"The first field of an object is HeaderSize words after the object."

	| object |
	object := memory instantiateClass: classPointer withPointers: 2.

	self
		assert: (memory addressOfWord: object)
		equals: (memory addressOfObject: object) + 2
]

{ #category : 'tests - allocation' }
ObjectMemoryTest >> testAllocationInOtherSegmentKeepsFirstSegmentChunk [
	"The free chunk of the segment that was too small is left alone."

	| bigSize sizeBefore |
	bigSize := ObjectMemory classVarNamed: 'BigSize'.
	self setUpFreeChunkInSegment: 1.
	self fillFirstSegment.
	sizeBefore := memory sizeBitsOf:
		              (memory headOfFreeChunkList: bigSize inSegment: 0).

	memory instantiateClass: classPointer withPointers: 6000.

	self
		assert:
		(memory sizeBitsOf:
			 (memory headOfFreeChunkList: bigSize inSegment: 0))
		equals: sizeBefore
]

{ #category : 'tests - allocation' }
ObjectMemoryTest >> testAllocationMovesToNextSegmentWhenFull [
	"When the current segment has no chunk big enough, the allocator moves to the next segment and allocates there, without any garbage collection."

	| object |
	self setUpFreeChunkInSegment: 1.
	self fillFirstSegment.

	object := memory instantiateClass: classPointer withPointers: 6000.

	self assert: (memory segmentBitsOf: object) equals: 1.
	self assert: (memory fetchWordLengthOf: object) equals: 6000.
	self assert: interpreter collectionCount equals: 0
]

{ #category : 'tests - free lists' }
ObjectMemoryTest >> testAllocationSplitsTheBigChunk [
	"Objects are cut from the end of the big free chunk, which shrinks accordingly."

	| chunk chunkSize chunkLocation object |
	chunk := memory
		         headOfFreeChunkList:
		         (ObjectMemory classVarNamed: 'BigSize')
		         inSegment: 0.
	chunkSize := memory sizeBitsOf: chunk.
	chunkLocation := memory locationBitsOf: chunk.

	object := memory instantiateClass: classPointer withPointers: 8.

	self assert: (memory sizeBitsOf: object) equals: 10.
	self assert: (memory sizeBitsOf: chunk) equals: chunkSize - 10.
	self assert: (memory locationBitsOf: chunk) equals: chunkLocation.
	self
		assert: (memory locationBitsOf: object)
		equals: chunkLocation + chunkSize - 10
]

{ #category : 'tests - field access' }
ObjectMemoryTest >> testBytesAndWordsShareStorage [
	"A byte object seen as words: the first byte of a word is its low byte (the VM runs on the LSB image format)."

	| object |
	object := memory instantiateClass: classPointer withBytes: 4.
	memory storeByte: 0 ofObject: object withValue: 16r12.
	memory storeByte: 1 ofObject: object withValue: 16r34.

	self assert: (memory fetchWord: 0 ofObject: object) equals: 16r3412
]

{ #category : 'tests - compaction' }
ObjectMemoryTest >> testCompactionKeepsFreeWordsCount [
	"Compaction moves free space around but does not change how much there is."

	| object wordsBefore |
	object := memory instantiateClass: classPointer withPointers: 5.
	memory countUp: object.
	memory instantiateClass: classPointer withPointers: 5.
	wordsBefore := memory freeWordsLeft.

	memory compactCurrentSegment.

	self assert: memory freeWordsLeft equals: wordsBefore
]

{ #category : 'tests - compaction' }
ObjectMemoryTest >> testCompactionMovesObjectsAndKeepsTheirContents [
	"Compacting a segment slides the live objects together towards the start of the segment, filling the holes. Oops, classes and contents stay valid."

	| first hole last locationBefore |
	first := memory instantiateClass: classPointer withPointers: 2.
	hole := memory instantiateClass: classPointer withPointers: 4.
	last := memory instantiateClass: classPointer withPointers: 3.
	memory countUp: first.
	memory countUp: hole.
	memory countUp: last.
	memory
		storePointer: 2
		ofObject: last
		withValue: (memory integerObjectOf: 99).
	memory countDown: hole.
	locationBefore := memory locationBitsOf: last.

	memory compactCurrentSegment.

	self assert: (memory hasObject: first).
	self assert: (memory hasObject: last).
	self deny: (memory hasObject: hole).
	self assert: (memory fetchClassOf: last) equals: classPointer.
	self assert: (memory fetchWordLengthOf: last) equals: 3.
	self
		assert:
		(memory integerValueOf: (memory fetchPointer: 2 ofObject: last))
		equals: 99.
	self assert: (memory locationBitsOf: last) < locationBefore.
	"the objects are contiguous: last (5 words) is followed by first"
	self
		assert: (memory locationBitsOf: first)
		equals: (memory locationBitsOf: last) + 5
]

{ #category : 'tests - reference counting' }
ObjectMemoryTest >> testCountDownFreesReferencedObjects [
	"Freeing an object also frees the objects only it referenced, recursively."

	| parent child grandChild |
	parent := memory instantiateClass: classPointer withPointers: 1.
	child := memory instantiateClass: classPointer withPointers: 1.
	grandChild := memory instantiateClass: classPointer withPointers: 0.
	memory storePointer: 0 ofObject: child withValue: grandChild.
	memory storePointer: 0 ofObject: parent withValue: child.
	memory countUp: parent.

	memory countDown: parent.

	self deny: (memory hasObject: parent).
	self deny: (memory hasObject: child).
	self deny: (memory hasObject: grandChild)
]

{ #category : 'tests - reference counting' }
ObjectMemoryTest >> testCountDownKeepsSharedObjects [
	"An object still referenced from elsewhere survives the freeing of one of its referrers."

	| first second shared |
	first := memory instantiateClass: classPointer withPointers: 1.
	second := memory instantiateClass: classPointer withPointers: 1.
	shared := memory instantiateClass: classPointer withPointers: 0.
	memory storePointer: 0 ofObject: first withValue: shared.
	memory storePointer: 0 ofObject: second withValue: shared.
	memory countUp: first.
	memory countUp: second.

	memory countDown: first.

	self deny: (memory hasObject: first).
	self assert: (memory hasObject: shared).
	self assert: (memory countBitsOf: shared) equals: 1
]

{ #category : 'tests - reference counting' }
ObjectMemoryTest >> testCountDownReleasesTheClass [
	"Freeing an instance drops its reference to the class."

	| object before |
	before := memory countBitsOf: classPointer.
	object := memory instantiateClass: classPointer withPointers: 1.
	memory countUp: object.

	memory countDown: object.

	self assert: (memory countBitsOf: classPointer) equals: before
]

{ #category : 'tests - reference counting' }
ObjectMemoryTest >> testCountDownToZeroFreesTheObject [
	"The last reference going away frees the object: its entry and its words are given back."

	| object oopsBefore wordsBefore |
	oopsBefore := memory freeOopsLeft.
	wordsBefore := memory freeWordsLeft.
	object := memory instantiateClass: classPointer withPointers: 2.
	memory countUp: object.

	memory countDown: object.

	self deny: (memory hasObject: object).
	self assert: memory freeOopsLeft equals: oopsBefore.
	self assert: memory freeWordsLeft equals: wordsBefore
]

{ #category : 'tests - reference counting' }
ObjectMemoryTest >> testCountSaturatesAt128 [
	"A count never goes above 128: such an object is never freed by counting, only by the marking collector."

	| object |
	object := memory instantiateClass: classPointer withPointers: 1.
	200 timesRepeat: [ memory countUp: object ].
	self assert: (memory countBitsOf: object) equals: 128.

	10 timesRepeat: [ memory countDown: object ].
	self assert: (memory countBitsOf: object) equals: 128.
	self assert: (memory hasObject: object)
]

{ #category : 'tests - reference counting' }
ObjectMemoryTest >> testCountUpAndDown [
	"countUp: and countDown: adjust the count of a referenced object by one."

	| object |
	object := memory instantiateClass: classPointer withPointers: 1.
	memory countUp: object.
	memory countUp: object.
	self assert: (memory countBitsOf: object) equals: 2.

	memory countDown: object.
	self assert: (memory countBitsOf: object) equals: 1.
	self assert: (memory hasObject: object)
]

{ #category : 'tests - free lists' }
ObjectMemoryTest >> testFreeOopsAreReusedAndCounted [
	"Each allocation takes an object table entry and each free gives it back."

	| before object |
	before := memory freeOopsLeft.
	object := memory instantiateClass: classPointer withPointers: 1.
	self assert: memory freeOopsLeft equals: before - 1.

	memory countUp: object.
	memory countDown: object.
	self assert: memory freeOopsLeft equals: before
]

{ #category : 'tests - free lists' }
ObjectMemoryTest >> testFreedChunkIsReused [
	"A freed object of a given size is reused, with its oop, by the next allocation of that size."

	| first second |
	first := memory instantiateClass: classPointer withPointers: 3.
	memory countUp: first.
	memory countDown: first.

	second := memory instantiateClass: classPointer withPointers: 3.

	self assert: second equals: first
]

{ #category : 'tests - free lists' }
ObjectMemoryTest >> testFreedChunkOfOtherSizeIsNotReused [
	"The exact fit lists are per size: a chunk of another size stays on its own list."

	| first second |
	first := memory instantiateClass: classPointer withPointers: 3.
	memory countUp: first.
	memory countDown: first.

	second := memory instantiateClass: classPointer withPointers: 4.

	self deny: second equals: first.
	self deny: (memory hasObject: first)
]

{ #category : 'tests - accessors' }
ObjectMemoryTest >> testGarbageCollectRunsTheMarkingCollector [
	"garbageCollect is the entry point of the garbage collect primitive: it frees unreachable objects and signals the end of the collection to the interpreter."

	| garbage |
	garbage := memory instantiateClass: classPointer withPointers: 1.

	memory garbageCollect.

	self deny: (memory hasObject: garbage).
	self assert: interpreter collectionCount equals: 1
]

{ #category : 'tests - instance enumeration' }
ObjectMemoryTest >> testInitialInstanceOfAnUnusedClassIsNil [
	"A class without instances answers nil."

	| unused |
	unused := memory instantiateClass: nilPointer withPointers: 0.
	memory countUp: unused.

	self assert: (memory initialInstanceOf: unused) equals: nilPointer
]

{ #category : 'tests - instance enumeration' }
ObjectMemoryTest >> testInitialInstanceOfFindsAnInstance [
	"The first instance of a class is its first live object in object table order."

	| first second |
	first := memory instantiateClass: classPointer withPointers: 1.
	second := memory instantiateClass: classPointer withPointers: 1.
	memory countUp: first.
	memory countUp: second.

	self
		assert: (memory initialInstanceOf: classPointer)
		equals: (first min: second)
]

{ #category : 'tests - instance enumeration' }
ObjectMemoryTest >> testInitialInstanceOfSkipsFreedObjects [
	"A freed object is no longer an instance."

	| freed kept |
	freed := memory instantiateClass: classPointer withPointers: 1.
	kept := memory instantiateClass: classPointer withPointers: 1.
	memory countUp: freed.
	memory countUp: kept.
	memory countDown: freed.

	self assert: (memory initialInstanceOf: classPointer) equals: kept
]

{ #category : 'tests - instance enumeration' }
ObjectMemoryTest >> testInstanceAfterIgnoresOtherClasses [
	"Only instances of the same class are enumerated."

	| otherClass mine other |
	otherClass := memory instantiateClass: nilPointer withPointers: 0.
	memory countUp: otherClass.
	mine := memory instantiateClass: classPointer withPointers: 1.
	other := memory instantiateClass: otherClass withPointers: 1.
	memory countUp: mine.
	memory countUp: other.

	self assert: (memory initialInstanceOf: otherClass) equals: other.
	self assert: (memory instanceAfter: other) equals: nilPointer
]

{ #category : 'tests - instance enumeration' }
ObjectMemoryTest >> testInstanceAfterSkipsFreeChunks [
	"A free chunk has an object table entry but is not an instance of anything, whatever its class field holds."

	| first last |
	first := memory instantiateClass: classPointer withPointers: 1.
	memory countUp: first.
	last := memory instanceAfter: first.

	self assert: last equals: nilPointer
]

{ #category : 'tests - instance enumeration' }
ObjectMemoryTest >> testInstanceAfterSkipsFreedChunks [
	"A freed chunk keeps its object table entry (free bit 0) and a class field that is a free list link. It must not be taken for an instance, even if that link happens to equal the class."

	| first freed |
	first := memory instantiateClass: classPointer withPointers: 1.
	freed := memory instantiateClass: classPointer withPointers: 1.
	memory countUp: first.
	memory countUp: freed.
	memory countDown: freed.
	memory classBitsOf: freed put: classPointer.

	self assert: (memory instanceAfter: first) equals: nilPointer
]

{ #category : 'tests - instance enumeration' }
ObjectMemoryTest >> testInstanceAfterWalksTheInstances [
	"instanceAfter: enumerates the live instances in object table order, then answers nil."

	| instances found next |
	instances := (1 to: 3) collect: [ :i |
		             memory instantiateClass: classPointer withPointers: 1 ].
	instances do: [ :each | memory countUp: each ].

	found := OrderedCollection new.
	next := memory initialInstanceOf: classPointer.
	[ next = nilPointer ] whileFalse: [
			found add: next.
			next := memory instanceAfter: next ].

	self
		assert: found asArray
		equals: instances asSortedCollection asArray
]

{ #category : 'tests - allocation' }
ObjectMemoryTest >> testInstantiateByteObjectOfEvenLength [
	"4 bytes take 2 words and do not set the odd bit."

	| object |
	object := memory instantiateClass: classPointer withBytes: 4.

	self assert: (memory pointerBitOf: object) equals: 0.
	self assert: (memory oddBitOf: object) equals: 0.
	self assert: (memory fetchWordLengthOf: object) equals: 2.
	self assert: (memory fetchByteLengthOf: object) equals: 4
]

{ #category : 'tests - allocation' }
ObjectMemoryTest >> testInstantiateByteObjectOfOddLength [
	"5 bytes take 3 words: the last byte is padding, flagged by the odd bit and hidden from the byte length."

	| object |
	object := memory instantiateClass: classPointer withBytes: 5.

	self assert: (memory oddBitOf: object) equals: 1.
	self assert: (memory fetchWordLengthOf: object) equals: 3.
	self assert: (memory fetchByteLengthOf: object) equals: 5.
	0 to: 4 do: [ :byte |
		self assert: (memory fetchByte: byte ofObject: object) equals: 0 ]
]

{ #category : 'tests - allocation' }
ObjectMemoryTest >> testInstantiateCountsTheClass [
	"Each instance holds a reference to its class."

	| before |
	before := memory countBitsOf: classPointer.
	memory instantiateClass: classPointer withPointers: 1.
	memory instantiateClass: classPointer withBytes: 2.
	self assert: (memory countBitsOf: classPointer) equals: before + 2
]

{ #category : 'tests - allocation' }
ObjectMemoryTest >> testInstantiateHugeObject [
	"An object of HugeSize words or more (header included) takes one extra word, used by the garbage collector while it traverses the object."

	| huge wordsBefore |
	huge := ObjectMemory classVarNamed: 'HugeSize'.
	wordsBefore := memory freeWordsLeft.

	"huge - 1 words: no extra word"
	memory instantiateClass: classPointer withPointers: huge - 3.
	self assert: memory freeWordsLeft equals: wordsBefore - (huge - 1).

	"huge words: one extra word"
	memory instantiateClass: classPointer withPointers: huge - 2.
	self
		assert: memory freeWordsLeft
		equals: wordsBefore - (huge - 1) - (huge + 1)
]

{ #category : 'tests - allocation' }
ObjectMemoryTest >> testInstantiatePointerObject [
	"A new pointer object has the requested class and length, its fields are nil,
	and the allocation uses one object table entry and header + length words."

	| object oopsBefore wordsBefore |
	oopsBefore := memory freeOopsLeft.
	wordsBefore := memory freeWordsLeft.

	object := memory instantiateClass: classPointer withPointers: 3.

	self assert: (memory fetchClassOf: object) equals: classPointer.
	self assert: (memory fetchWordLengthOf: object) equals: 3.
	self assert: (memory pointerBitOf: object) equals: 1.
	0 to: 2 do: [ :field |
			self
				assert: (memory fetchPointer: field ofObject: object)
				equals: nilPointer ].
	self assert: memory freeOopsLeft equals: oopsBefore - 1.
	"2 header words + 3 fields"
	self assert: memory freeWordsLeft equals: wordsBefore - 5
]

{ #category : 'tests - allocation' }
ObjectMemoryTest >> testInstantiateUsesDistinctMemory [
	"Two objects have different oops and do not overlap."

	| first second |
	first := memory instantiateClass: classPointer withPointers: 4.
	second := memory instantiateClass: classPointer withPointers: 4.

	self deny: first equals: second.
	self assert:
		((memory locationBitsOf: first) - (memory locationBitsOf: second))
			abs >= 6
]

{ #category : 'tests - allocation' }
ObjectMemoryTest >> testInstantiateWordObject [
	"A word object has no pointers, its words start at 0 and its byte length is twice its word length."

	| object |
	object := memory instantiateClass: classPointer withWords: 3.

	self assert: (memory pointerBitOf: object) equals: 0.
	self assert: (memory fetchWordLengthOf: object) equals: 3.
	self assert: (memory fetchByteLengthOf: object) equals: 6.
	0 to: 2 do: [ :word |
		self assert: (memory fetchWord: word ofObject: object) equals: 0 ]
]

{ #category : 'tests - integers' }
ObjectMemoryTest >> testIntegerClass [
	"The class of a SmallInteger is IntegerClass, whatever its value."

	self
		assert: (memory fetchClassOf: (memory integerObjectOf: 5))
		equals: (ObjectMemory classVarNamed: 'IntegerClass')
]

{ #category : 'tests - integers' }
ObjectMemoryTest >> testIntegerObjectEncoding [
	"A SmallInteger object pointer has its low bit set; an oop (object table index) is even."

	self assert: (memory integerObjectOf: 0) equals: 1.
	self assert: (memory integerObjectOf: 1) equals: 3.
	self assert: (memory integerObjectOf: -1) equals: 16rFFFF.
	self assert: (memory isIntegerObject: 1).
	self deny: (memory isIntegerObject: nilPointer).
	self deny: (memory isIntegerObject: classPointer)
]

{ #category : 'tests - integers' }
ObjectMemoryTest >> testIntegersAreNotCounted [
	"SmallIntegers are not objects: counting them up or down changes nothing."

	| integer |
	integer := memory integerObjectOf: 7.
	self assert: (memory countUp: integer) equals: integer.
	self assert: (memory countDown: integer) equals: integer
]

{ #category : 'tests - integers' }
ObjectMemoryTest >> testIsIntegerValueBoundaries [
	"Only the 15 bit signed range -16384 to 16383 fits in a SmallInteger."

	self assert: (memory isIntegerValue: -16384).
	self assert: (memory isIntegerValue: 16383).
	self deny: (memory isIntegerValue: -16385).
	self deny: (memory isIntegerValue: 16384)
]

{ #category : 'tests - accessors' }
ObjectMemoryTest >> testIsObjectNil [
	"Only the nil object pointer is nil."

	self assert: (memory isObjectNil: nilPointer).
	self deny: (memory isObjectNil: classPointer)
]

{ #category : 'tests - allocation' }
ObjectMemoryTest >> testNewObjectHasNoReference [
	"A new object has a count of 0 until something stores or holds its pointer."

	self
		assert: (memory countBitsOf:
				 (memory instantiateClass: classPointer withPointers: 1))
		equals: 0
]

{ #category : 'tests - allocation' }
ObjectMemoryTest >> testObjectsInOtherSegmentAreAccessible [
	"Fields, classes and counts work the same in any segment."

	| object other |
	self setUpFreeChunkInSegment: 1.
	self fillFirstSegment.
	object := memory instantiateClass: classPointer withPointers: 6000.
	other := memory instantiateClass: classPointer withPointers: 1.

	memory
		storePointer: 5999
		ofObject: object
		withValue: (memory integerObjectOf: 77).
	memory storePointer: 0 ofObject: other withValue: object.

	self assert: (memory segmentBitsOf: other) equals: 1.
	self
		assert:
		(memory integerValueOf: (memory fetchPointer: 5999 ofObject: object))
		equals: 77.
	self assert: (memory fetchClassOf: object) equals: classPointer.
	self assert: (memory countBitsOf: object) equals: 1
]

{ #category : 'tests - garbage collection' }
ObjectMemoryTest >> testReclaimDoesNotFollowBytes [
	"The words of a byte object are data, not pointers: they must not keep anything alive."

	| bytes garbage |
	garbage := memory instantiateClass: classPointer withPointers: 0.
	bytes := memory instantiateClass: classPointer withBytes: 4.
	memory storeWord: 0 ofObject: bytes withValue: garbage.
	interpreter roots add: bytes.

	memory reclaimInaccessibleObjects.

	self assert: (memory freeBitOf: bytes) equals: 0.
	self deny: (memory hasObject: garbage)
]

{ #category : 'tests - garbage collection' }
ObjectMemoryTest >> testReclaimFreesReferenceCycles [
	"What counting cannot free, the marking collector does."

	| first second |
	first := memory instantiateClass: classPointer withPointers: 1.
	second := memory instantiateClass: classPointer withPointers: 1.
	memory storePointer: 0 ofObject: first withValue: second.
	memory storePointer: 0 ofObject: second withValue: first.

	memory reclaimInaccessibleObjects.

	self deny: (memory hasObject: first).
	self deny: (memory hasObject: second)
]

{ #category : 'tests - garbage collection' }
ObjectMemoryTest >> testReclaimFreesUnreachableObjects [
	"The marking collector frees objects no root reaches, and keeps the others.
	A root registered by the interpreter keeps a count of 0 (the interpreter holds it without counting), so its free bit is checked, not hasObject:."

	| kept garbage |
	kept := memory instantiateClass: classPointer withPointers: 1.
	garbage := memory instantiateClass: classPointer withPointers: 1.
	interpreter roots add: kept.

	memory reclaimInaccessibleObjects.

	self assert: (memory freeBitOf: kept) equals: 0.
	self deny: (memory hasObject: garbage).
	self assert: interpreter collectionCount equals: 1
]

{ #category : 'tests - garbage collection' }
ObjectMemoryTest >> testReclaimKeepsMethodLiterals [
	"A CompiledMethod is a non pointer object whose literals are pointers: the collector must still mark them (regression: a wrong MethodClass freed the literals)."

	| method literal |
	method := memory instantiateClass: methodClassPointer withWords: 2.
	memory storeWord: 0 ofObject: method withValue: (1 bitShift: 1) + 1.
	literal := memory instantiateClass: classPointer withPointers: 0.
	memory storeWord: 1 ofObject: method withValue: literal.
	interpreter roots add: method.

	memory reclaimInaccessibleObjects.

	self assert: (memory freeBitOf: method) equals: 0.
	self assert: (memory freeBitOf: literal) equals: 0
]

{ #category : 'tests - garbage collection' }
ObjectMemoryTest >> testReclaimKeepsObjectsReachableFromRoots [
	"Reachability is transitive, through the fields of the objects."

	| root child grandChild |
	root := memory instantiateClass: classPointer withPointers: 1.
	child := memory instantiateClass: classPointer withPointers: 1.
	grandChild := memory instantiateClass: classPointer withPointers: 0.
	memory storePointer: 0 ofObject: child withValue: grandChild.
	memory storePointer: 0 ofObject: root withValue: child.
	interpreter roots add: root.

	memory reclaimInaccessibleObjects.

	self assert: (memory freeBitOf: root) equals: 0.
	self assert: (memory hasObject: child).
	self assert: (memory hasObject: grandChild)
]

{ #category : 'tests - garbage collection' }
ObjectMemoryTest >> testReclaimRectifiesReferenceCounts [
	"After a collection the counts are again the number of references: the mark is removed and the counts of referenced objects are rebuilt."

	| root child |
	root := memory instantiateClass: classPointer withPointers: 2.
	child := memory instantiateClass: classPointer withPointers: 0.
	memory storePointer: 0 ofObject: root withValue: child.
	memory storePointer: 1 ofObject: root withValue: child.
	interpreter roots add: root.

	memory reclaimInaccessibleObjects.

	self assert: (memory countBitsOf: child) equals: 2.
	self assert: (memory countBitsOf: nilPointer) equals: 128
]

{ #category : 'tests - reference counting' }
ObjectMemoryTest >> testReferenceCycleIsNotFreedByCounting [
	"Two objects referencing each other keep each other alive: only the marking collector reclaims cycles."

	| first second |
	first := memory instantiateClass: classPointer withPointers: 1.
	second := memory instantiateClass: classPointer withPointers: 1.
	memory storePointer: 0 ofObject: first withValue: second.
	memory storePointer: 0 ofObject: second withValue: first.
	memory countUp: first.

	memory countDown: first.

	self assert: (memory hasObject: first).
	self assert: (memory hasObject: second)
]

{ #category : 'tests - integers' }
ObjectMemoryTest >> testSmallIntegerRoundTrip [
	"A SmallInteger is encoded in the object pointer itself: value * 2 + 1.
	Check the extremes of the 15 bit range and a negative value."

	#( 0 1 -1 100 -100 16383 -16384 ) do: [ :value |
			| pointer |
			pointer := memory integerObjectOf: value.
			self assert: (memory isIntegerObject: pointer).
			self assert: (memory integerValueOf: pointer) equals: value ]
]

{ #category : 'tests - snapshot' }
ObjectMemoryTest >> testSnapshotDoesNotKeepFreeObjects [
	"Freed objects are not saved: their entries are free again in the reloaded memory."

	| kept freed reloaded |
	kept := memory instantiateClass: classPointer withPointers: 1.
	freed := memory instantiateClass: classPointer withPointers: 1.
	memory countUp: kept.
	memory countUp: freed.
	memory countDown: freed.

	reloaded := self reloadedMemory.

	self assert: (reloaded hasObject: kept).
	self deny: (reloaded hasObject: freed)
]

{ #category : 'tests - snapshot' }
ObjectMemoryTest >> testSnapshotRebuildsFreeSpace [
	"The reloaded memory has a free chunk and can allocate new objects, which do not overlap the loaded ones."

	| kept new reloaded |
	kept := memory instantiateClass: classPointer withPointers: 4.
	memory countUp: kept.
	memory
		storePointer: 3
		ofObject: kept
		withValue: (memory integerObjectOf: 1234).

	reloaded := self reloadedMemory.
	new := reloaded instantiateClass: classPointer withPointers: 10.
	reloaded
		storePointer: 0
		ofObject: new
		withValue: (reloaded integerObjectOf: 5).

	self assert: reloaded freeWordsLeft > 0.
	self deny: new equals: kept.
	self assert: (reloaded freeBitOf: new) equals: 0.
	self
		assert:
		(reloaded integerValueOf: (reloaded fetchPointer: 3 ofObject: kept))
		equals: 1234.
	self assert: (reloaded fetchWordLengthOf: kept) equals: 4
]

{ #category : 'tests - snapshot' }
ObjectMemoryTest >> testSnapshotRoundTrip [
	"Saving the objects and loading them in a fresh memory restores the same oops, classes, pointers, words and bytes."

	| parent bytes words reloaded |
	parent := memory instantiateClass: classPointer withPointers: 3.
	bytes := memory instantiateClass: classPointer withBytes: 5.
	words := memory instantiateClass: classPointer withWords: 2.
	memory countUp: parent.
	memory countUp: bytes.
	memory countUp: words.
	memory storePointer: 0 ofObject: parent withValue: bytes.
	memory storePointer: 1 ofObject: parent withValue: words.
	memory
		storePointer: 2
		ofObject: parent
		withValue: (memory integerObjectOf: -42).
	memory storeByte: 0 ofObject: bytes withValue: 200.
	memory storeByte: 4 ofObject: bytes withValue: 7.
	memory storeWord: 1 ofObject: words withValue: 16rBEEF.

	reloaded := self reloadedMemory.

	self assert: (reloaded hasObject: parent).
	self assert: (reloaded fetchClassOf: parent) equals: classPointer.
	self
		assert: (reloaded fetchPointer: 0 ofObject: parent)
		equals: bytes.
	self
		assert: (reloaded fetchPointer: 1 ofObject: parent)
		equals: words.
	self
		assert:
		(reloaded integerValueOf:
			 (reloaded fetchPointer: 2 ofObject: parent))
		equals: -42.
	self assert: (reloaded fetchByteLengthOf: bytes) equals: 5.
	self assert: (reloaded fetchByte: 0 ofObject: bytes) equals: 200.
	self assert: (reloaded fetchByte: 4 ofObject: bytes) equals: 7.
	self assert: (reloaded pointerBitOf: bytes) equals: 0.
	self assert: (reloaded fetchWord: 1 ofObject: words) equals: 16rBEEF
]

{ #category : 'tests - field access' }
ObjectMemoryTest >> testStoreAndFetchByte [
	"Bytes are 8 bit unsigned and independent from each other, including the two bytes of a word."

	| object |
	object := memory instantiateClass: classPointer withBytes: 5.

	memory storeByte: 0 ofObject: object withValue: 200.
	memory storeByte: 1 ofObject: object withValue: 1.
	memory storeByte: 4 ofObject: object withValue: 7.

	self assert: (memory fetchByte: 0 ofObject: object) equals: 200.
	self assert: (memory fetchByte: 1 ofObject: object) equals: 1.
	self assert: (memory fetchByte: 2 ofObject: object) equals: 0.
	self assert: (memory fetchByte: 4 ofObject: object) equals: 7
]

{ #category : 'tests - field access' }
ObjectMemoryTest >> testStoreAndFetchPointer [
	"A stored pointer is fetched back; integers are stored as is."

	| object other |
	object := memory instantiateClass: classPointer withPointers: 2.
	other := memory instantiateClass: classPointer withPointers: 0.

	memory storePointer: 0 ofObject: object withValue: other.
	memory
		storePointer: 1
		ofObject: object
		withValue: (memory integerObjectOf: 42).

	self assert: (memory fetchPointer: 0 ofObject: object) equals: other.
	self
		assert:
		(memory integerValueOf: (memory fetchPointer: 1 ofObject: object))
		equals: 42
]

{ #category : 'tests - field access' }
ObjectMemoryTest >> testStoreAndFetchWord [
	"Words are 16 bit unsigned."

	| object |
	object := memory instantiateClass: classPointer withWords: 3.

	memory storeWord: 0 ofObject: object withValue: 1.
	memory storeWord: 2 ofObject: object withValue: 16rFFFF.

	self assert: (memory fetchWord: 0 ofObject: object) equals: 1.
	self assert: (memory fetchWord: 1 ofObject: object) equals: 0.
	self assert: (memory fetchWord: 2 ofObject: object) equals: 16rFFFF
]

{ #category : 'tests - field access' }
ObjectMemoryTest >> testStorePointerCountsTheNewValue [
	"Storing a pointer in a field is a reference to its target."

	| object other |
	object := memory instantiateClass: classPointer withPointers: 2.
	other := memory instantiateClass: classPointer withPointers: 0.

	memory storePointer: 0 ofObject: object withValue: other.
	self assert: (memory countBitsOf: other) equals: 1.
	memory storePointer: 1 ofObject: object withValue: other.
	self assert: (memory countBitsOf: other) equals: 2
]

{ #category : 'tests - field access' }
ObjectMemoryTest >> testStorePointerReleasesTheOldValue [
	"Overwriting a field drops the reference to the old value, which is freed when it was the last one."

	| object old |
	object := memory instantiateClass: classPointer withPointers: 1.
	old := memory instantiateClass: classPointer withPointers: 0.
	memory storePointer: 0 ofObject: object withValue: old.

	memory storePointer: 0 ofObject: object withValue: nilPointer.

	self deny: (memory hasObject: old).
	self
		assert: (memory fetchPointer: 0 ofObject: object)
		equals: nilPointer
]

{ #category : 'tests - pointer swapping' }
ObjectMemoryTest >> testSwapPointers [
	"After a swap each oop designates the other object's contents, while the class and the counts stay with the oop."

	| first second |
	first := memory instantiateClass: classPointer withPointers: 1.
	second := memory instantiateClass: classPointer withWords: 3.
	memory
		storePointer: 0
		ofObject: first
		withValue: (memory integerObjectOf: 5).
	memory storeWord: 2 ofObject: second withValue: 9.

	memory swapPointersOf: first and: second.

	self assert: (memory fetchWordLengthOf: first) equals: 3.
	self assert: (memory fetchWord: 2 ofObject: first) equals: 9.
	self assert: (memory pointerBitOf: first) equals: 0.
	self assert: (memory fetchWordLengthOf: second) equals: 1.
	self
		assert:
		(memory integerValueOf: (memory fetchPointer: 0 ofObject: second))
		equals: 5.
	self assert: (memory pointerBitOf: second) equals: 1
]

{ #category : 'tests - pointer swapping' }
ObjectMemoryTest >> testSwapPointersTwiceRestores [
	"Swapping twice is the identity."

	| first second |
	first := memory instantiateClass: classPointer withPointers: 1.
	second := memory instantiateClass: classPointer withBytes: 5.

	memory swapPointersOf: first and: second.
	memory swapPointersOf: first and: second.

	self assert: (memory fetchWordLengthOf: first) equals: 1.
	self assert: (memory pointerBitOf: first) equals: 1.
	self assert: (memory fetchByteLengthOf: second) equals: 5.
	self assert: (memory oddBitOf: second) equals: 1
]
