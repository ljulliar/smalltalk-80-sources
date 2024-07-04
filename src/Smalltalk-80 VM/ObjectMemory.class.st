"
The function of the object memory is to create, store, and destroy objects and to provide access to their fields.

This is a real-memory implementation meaning that all the objects in the environment reside in primary memory that is directly addressable by the program (as opposed to virtual memory)
"
Class {
	#name : #ObjectMemory,
	#superclass : #Object,
	#instVars : [
		'currentSegment',
		'wordMemory',
		'rootObjectPointers'
	],
	#classVars : [
		'BigSize',
		'FirstFreeChunkList',
		'FirstHeapSegment',
		'FreePointerList',
		'HeaderSize',
		'HeapSegmentCount',
		'HeapSpaceStop',
		'HugeSize',
		'IntegerClass',
		'LastFreeChunkList',
		'LastHeapSegment',
		'MethodClass',
		'NilPointer',
		'NonPointer',
		'ObjectTableSegment',
		'ObjectTableSize',
		'ObjectTableStart'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #'class initialization' }
ObjectMemory class >> initialize [ 
	"Initialize memory parameters. Note all idex in Memory
	management are assumed to start at 0 whether, word, byte
	or bit indices"

   "Heap Related constants (BB p. 658)"
	"----------------------------------"

	"All segments minus one used by the Object Table"
	HeapSegmentCount := 16-1.
	"Start at the first segment"
	FirstHeapSegment := 0.
	"Last segment occupied by Object Table (see below)"
	LastHeapSegment := (FirstHeapSegment + HeapSegmentCount - 1). 
	"Reserve the last Bigsize words of each segment for Free chunk list heads"
	HeapSpaceStop := 65535 - (BigSize + 1).
	"An object header is 2-word size"
	HeaderSize := 2.
	
	"Object Table Related Constants (BB p.661)"
	"-----------------------------------------"
	"Object Table occupies last memory segment"
	ObjectTableSegment := 15.
	"First word reserved for head of free pointer list"
	ObjectTableStart := 0.
	"64K minus the 2 reserved words at the end (e.g. one for FreePointerList, one spare)"
	HugeSize := 256.
	ObjectTableSize := 65534.
	"Definition of NilPointer BB p. 576, p. 661" 
	NilPointer := 2.

	"Free Space Related Constants (BB p. 664)"
	"----------------------------------------"
   "Head of free pointer list stored in last word of Object Table segment"
	FreePointerList := 65535.
	"All free chunks of size 20 and below are kept in a linked list"
	BigSize := 21.
	FirstFreeChunkList := HeapSpaceStop + 1.
	LastFreeChunkList := FirstFreeChunkList + BigSize.
	NonPointer := 65535.
	
	"Interface to the bytecode interpreter"
	"----------------------------------------"
	"object pointer of IntegerClass"
   "BB p. 687  and Xerox VM Image Booklet p. 6"
	IntegerClass := 12.
   "object pointer of CompiledMethod"
	"BB p. 686 and Xerox VM Image Booklet p. 6"
	MethodClass := 22.

]

{ #category : #'vm image loading' }
ObjectMemory class >> readUInt16From: stream [
	"Read next 4 bytes from stream and return an
	unsigned 16-bit integer"

	^ (stream next) + (stream next bitShift: 8).
]

{ #category : #'vm image loading' }
ObjectMemory class >> readUInt32From: stream [
	"Read next 4 bytes from stream and return an
	unsigned 32-bit integer"

	^ (stream next) + (stream next bitShift: 8) + (stream next bitShift: 16) + (stream next bitShift: 24).
]

{ #category : #'private - compaction' }
ObjectMemory >> abandonFreeChunksInSegment: segment [
	"Computes lowWaterMark and also finds all deallocated chunks, recycles their object table entries onto the list of free pointers using the subroutine releasePointer:, and changes their class fields to the distinguished value NonPointer. During the subsequent sweep, when the compacter encounters objects so marked it can recognize them as deallocated chunks."

	| lowWaterMark objectPointer nextPointer |
	lowWaterMark := HeapSpaceStop.	"first assume that no chunk is free"
	HeaderSize to: BigSize do: [ :size | 
		"for each free-chunk list"
		objectPointer := self headOfFreeChunkList: size inSegment: segment.
		[ objectPointer = NonPointer ]
			whileFalse: [ lowWaterMark := lowWaterMark
					min: (self locationBitsOf: objectPointer).
				nextPointer := self classBitsOf: objectPointer.	"link to next free chunk"
				self classBitsOf: objectPointer put: NonPointer.	"distinguish for sweep"
				self releasePointer: objectPointer.	"add entry to free-pointer list"
				objectPointer := nextPointer ].
		self resetFreeChunkList: size inSegment: segment ].
	^ lowWaterMark
]

{ #category : #'private - allocation' }
ObjectMemory >> allocate: size odd: oddBit pointer: pointerBit extra: extraWord class: classPointer [
	"Memory allocation to store objects. The way memory is allocated depends on the pointer-fields bit of the object table entry:
	when that bit is 1, the data consist of object pointers; 
	when that bit is 0, the data consist of positive 8- or 16-bit integers. 
	When there are an odd number of bytes of data in a nonpointer object, the final byte of the last word is 0 (a slight waste of space), and the odd-length bit of the object table entry, which is normally 0, is set to 1. To support nonpointer objects, the allocator needs two additional parameters, pointerBit and oddBit. In the case of a nonpointer object (pointerBit = 0), the default initial value of the elements is 0 instead of nil."

	| objectPointer default |
	self countUp: classPointer.
	objectPointer := self allocateChunk: size + extraWord.
	self oddBitOf: objectPointer put: oddBit.
	self pointerBitOf: objectPointer put: pointerBit.
	self classBitsOf: objectPointer put: classPointer.
	default := pointerBit = 0
		ifTrue: [ 0 ]
		ifFalse: [ NilPointer ].
	HeaderSize to: size - 1 do: [ :i | self heapChunkOf: objectPointer word: i put: default ].
	self sizeBitsOf: objectPointer put: size.
	^ objectPointer
]

{ #category : #'private - allocation' }
ObjectMemory >> allocateChunk: size [
	"Allocate a chunk of memory and Attempts a marking collection if compaction of all segments has failed to yield enough space to satisfy an allocation request."

	| objectPointer |
	objectPointer := self attemptToAllocateChunk: size.
	objectPointer isNil
		ifFalse: [ ^ objectPointer ].
	self reclaimInaccessibleObjects.	"garbage collect and try again"
	objectPointer := self attemptToAllocateChunk: size.
	objectPointer isNil
		ifFalse: [ ^ objectPointer ].
	self outOfMemoryError	"give up"
]

{ #category : #'private - allocation' }
ObjectMemory >> attemptToAllocateChunk: size [
	"First tries to allocate chunk in currentSegment, the segment currently targeted for allocations. 
If it fails (returns nil), then the routine compacts the next segment and retries the allocation there. This procedure continues until the original segment has been compacted and searched. If no space can be found anywhere, the routine returns nil. "

	| objectPointer |
	objectPointer := self attemptToAllocateChunkInCurrentSegment: size.
	objectPointer isNil
		ifFalse: [ ^ objectPointer ].
	1 to: HeapSegmentCount do: [ :i | 
		currentSegment := currentSegment + 1.
		currentSegment > LastHeapSegment
			ifTrue: [ currentSegment := FirstHeapSegment ].
		self compactCurrentSegment.
		objectPointer := self attemptToAllocateChunkInCurrentSegment: size.
		objectPointer isNil
			ifFalse: [ ^ objectPointer ] ].
	^ nil
]

{ #category : #'private - allocation' }
ObjectMemory >> attemptToAllocateChunkInCurrentSegment: size [
	"Searches the current heap segment's free-chunk lists for the first chunk that is the right size or that can be subdivided to yield a chunk of the right size"

	| objectPointer predecessor next availableSize excessSize newPointer |
	objectPointer := nil.
	size < BigSize
		ifTrue: [ objectPointer := self removeFromFreeChunkList: size ].
	objectPointer notNil
		ifTrue: [ ^ objectPointer ].	"small chunk of exact size handy so use it"
	predecessor := NonPointer.	"remember predecessor of chunk under consideration"
	objectPointer := self	headOfFreeChunkList: BigSize inSegment: currentSegment.
	"the search loop stops when the end of the linked list is encountered"
	[ objectPointer = NonPointer ] whileFalse:
      [ availableSize := self sizeBitsOf: objectPointer.
			availableSize = size
				ifTrue: "exact fit -- remove from free chunk list and return"
				   [ next := self classBitsOf: objectPointer.	"the link to the next chunk"
					predecessor = NonPointer
						ifTrue: "it was the head of the list; make the next item the head"
							[ self headOfFreeChunkList: BigSize inSegment: currentSegment put: next ]
						ifFalse: "it was between two chunks; link them together"
						   [ self classBitsOf: predecessor put: next ].
					^ objectPointer ].
			"this chunk was either too big or too small; inspect the amount of variance"
			excessSize := availableSize - size.
			excessSize >= HeaderSize
				ifTrue: [ "obtain an object table entry for the second part"
					"can be broken into two usable parts: return the second part"
					newPointer := self
						obtainPointer: size
						location: (self locationBitsOf: objectPointer) + excessSize.
					newPointer isNil
						ifTrue: [ ^ nil ].
					"correct the size of the first part (which remains on the free list)"
					self sizeBitsOf: objectPointer put: excessSize.
					^ newPointer ]
				ifFalse: [ "not big enough to use; try the next chunk on the list"
					predecessor := objectPointer.
					objectPointer := self classBitsOf: objectPointer ] ].
	^ nil	"the end of the linked list was reached and no fit was found"
]

{ #category : #'private - object pointers' }
ObjectMemory >> cantBeIntegerObject: objectPointer [
	"object-access routine requires that its object pointer argument really be an object table index. This routine is used to trap erroneous calls"

	(self isIntegerObject: objectPointer)
	   "ERROR: Sensor and notify: not defined"
		ifTrue: [ Sensor notify: 'A small integer has no object table entry' ]
]

{ #category : #'private - object table entries' }
ObjectMemory >> classBitsOf: objectPointer [
	^ self heapChunkOf: objectPointer word: 1
]

{ #category : #'private - object table entries' }
ObjectMemory >> classBitsOf: objectPointer put: value [
	^ self heapChunkOf: objectPointer word: 1 put: value
]

{ #category : #'private - compaction' }
ObjectMemory >> compactCurrentSegment [
	"invokes the other compaction routines in the proper order and then creates the single free chunk at the top of the heap segment"

	| lowWaterMark bigSpace |
	lowWaterMark := self abandonFreeChunksInSegment: currentSegment.
	lowWaterMark < HeapSpaceStop
		ifTrue: [ self reverseHeapPointersAbove: lowWaterMark.
			bigSpace := self sweepCurrentSegmentFrom: lowWaterMark.
			self
				deallocate:
					(self obtainPointer: HeapSpaceStop + 1 - bigSpace location: bigSpace) ]
]

{ #category : #'private - object table entries' }
ObjectMemory >> countBitsOf: objectPointer [
	^ self ot: objectPointer bits: 0 to: 7
]

{ #category : #'private - object table entries' }
ObjectMemory >> countBitsOf: objectPointer put: value [
	^ self ot: objectPointer bits: 0 to: 7 put: value
]

{ #category : #'private - ref count gc' }
ObjectMemory >> countDown: rootObjectPointer [
	"Simple garbage collector method to increase reference count (BB p. 677)"

	| count |
	(self isIntegerObject: rootObjectPointer)
		ifTrue: [ ^ rootObjectPointer ]
		ifFalse: [ "this is a pointer, so decrement its reference count"
			^ self
				  forAllObjectsAccessibleFrom: rootObjectPointer
				  suchThat: [ :objectPointer | "the predicate decrements the count and tests for zero"
					  count := (self countBitsOf: objectPointer) - 1.
					  count < 127 ifTrue: [
						  self countBitsOf: objectPointer put: count ].
					  count = 0 ]
				  do: [ :objectPointer | "the action zeroes the count and deallocates the object"
					  self countBitsOf: objectPointer put: 0.
					  self deallocate: objectPointer ] ]
]

{ #category : #'private - ref count gc' }
ObjectMemory >> countUp: objectPointer [
	"Simple garbage collector method to increase reference count (BB p. 677)"
	| count |
	(self isIntegerObject: objectPointer)
		ifFalse: [count := (self countBitsOf: objectPointer) + 1.
	count < 129 ifTrue: [self countBitsOf: objectPointer put: count]].
	^objectPointer
]

{ #category : #'private - deallocation' }
ObjectMemory >> deallocate: objectPointer [
	"chunk is recycled on a free-chunk list. The following routine expects the count field to have been reset to zero by a higher-level routine. deallocated objects have no provision for an extra word not counted in the size field."

	| space |
	space := self spaceOccupiedBy: objectPointer.
	self sizeBitsOf: objectPointer put: space.
	self toFreeChunkList: (space min: BigSize) add: objectPointer
]

{ #category : #'reference counting' }
ObjectMemory >> decreaseReferencesTo: objectPointer [
	"Substract one to the reference count of the object whose object pointer is ObjectPointer"
	self countDown: objectPointer
]

{ #category : #'byte access' }
ObjectMemory >> fetchByte: byteIndex ofObject: objectPointer [
	"Return the 8 bit numerical value found in the byte numbered byteIndex of the object associated with ObjectPointer"

	^ self heapChunkOf: objectPointer byte: HeaderSize * 2 + byteIndex
]

{ #category : #'length access' }
ObjectMemory >> fetchByteLengthOf: objectPointer [
	^ (self fetchWordLengthOf: objectPointer) * 2 - (self oddBitOf: objectPointer)
]

{ #category : #'class pointer access' }
ObjectMemory >> fetchClassOf: objectPointer [
	"Return the object pointer of the class-describing object for the object associated with objectPointer"
	(self isIntegerObject: objectPointer)
		ifTrue: [^ IntegerClass] "Constant is defined in ObjectMemory class << initialize"
		ifFalse: [^ self classBitsOf: objectPointer]
]

{ #category : #'object pointer access' }
ObjectMemory >> fetchPointer: fieldIndex ofObject: objectPointer [
	"Return the object pointer found in the field numbered fieldIndex of the object associated with ObjectPointer"
	^self heapChunkOf: objectPointer word: HeaderSize + fieldIndex
]

{ #category : #'word access' }
ObjectMemory >> fetchWord: wordIndex ofObject: objectPointer [
	"Return the 16 bit numerical value found in the word numbered fieldIndex of the object associated with ObjectPointer"

	^ self heapChunkOf: objectPointer word: HeaderSize + wordIndex
]

{ #category : #'length access' }
ObjectMemory >> fetchWordLengthOf: objectPointer [
	^ (self sizeBitsOf: objectPointer) - HeaderSize
]

{ #category : #'private - ref count gc' }
ObjectMemory >> forAllObjectsAccessibleFrom: objectPointer suchThat: predicate do: action [
	"BB p. 578"
	(predicate value: objectPointer) ifTrue: [
		^ self
			  forAllOtherObjectsAccessibleFrom: objectPointer
			  suchThat: predicate
			  do: action ]
]

{ #category : #'private - ref count gc' }
ObjectMemory >> forAllOtherObjectsAccessibleFrom: objectPointer suchThat: predicate do: action [
	"Space-efficient traversal algorithm for reference counting garbage collector"
	"BB p. 578"
	| prior current offset size next |
	"compute prior, current, offset, and size to begin processing objectPointer"
	prior := NonPointer.
	current := objectPointer.
	offset := size := self lastPointerOf: objectPointer.
	[ true ] whileTrue: [ "for all pointers in all objects traversed"
		(offset := offset - 1) > 0
			ifTrue: [ "the class field hasn't been passed yet"
				next := self heapChunkOf: current word: offset. "one of the pointers"
				((self isIntegerObject: next) == false and: [
					 predicate value: next ]) ifTrue: [ "reverse the pointer chain""it's a non-immediate object and it should be processed"
					self heapChunkOf: current word: offset put: prior.
					"save the offset either in the count field or in the extra word"
					size < HugeSize
						ifTrue: [ self countBitsOf: current put: offset ]
						ifFalse: [ self heapChunkOf: current word: size put: offset ].
					"compute prior, current, offset, and size to begin processing next"
					prior := current.
					current := next.
					offset := size := self lastPointerOf: current ] ]
			ifFalse: [ " all pointers have been followed; now perform the action""decrement the field index"
				action value: current.
				"did we get here from another object?"
				prior = NonPointer ifTrue: [ "this was the root object, so we are done"
					^ objectPointer ].
				"restore next, current, and size to resume processing prior"
				next := current.
				current := prior.
				size := self lastPointerOf: current.
				"restore offset either from the count field or from the extra word"
				size < HugeSize
					ifTrue: [ offset := self countBitsOf: current ]
					ifFalse: [ offset := self heapChunkOf: current word: size + 1 ].
				"restore prior from the reversed pointer chain"
				prior := self heapChunkOf: current word: offset.
				"restore (unreverse) the pointer chain"
				self heapChunkOf: current word: offset put: next ] ]
]

{ #category : #'private - object table entries' }
ObjectMemory >> freeBitOf: objectPointer [
	^ self ot: objectPointer bits: 10 to: 10
]

{ #category : #'private - object table entries' }
ObjectMemory >> freeBitOf: objectPointer put: value [
	^ self ot: objectPointer bits: 10 to: 10 put: value
]

{ #category : #'private - object table entries' }
ObjectMemory >> headOfFreeChunkList: size inSegment: segment [
	"Get the head of free chunk list in segment"
	^ wordMemory segment: segment word: FirstFreeChunkList + size
]

{ #category : #'private - object table entries' }
ObjectMemory >> headOfFreeChunkList: size inSegment: segment put: objectPointer [
	"Set the head of free chunk list in segment"
	^ wordMemory
		segment: segment
		word: FirstFreeChunkList + size
		put: objectPointer
]

{ #category : #'private - object table entries' }
ObjectMemory >> headOfFreePointerList [
	"Load the head of head of the free pointer list headed at FreePointerList in segment ObjectTableSegment"
	^ wordMemory segment: ObjectTableSegment word: FreePointerList
]

{ #category : #'private - object table entries' }
ObjectMemory >> headOfFreePointerListPut: objectPointer [
	"Store value in the head of the free pointer list headed at FreePointerList in segment ObjectTableSegment"
	^ wordMemory
		segment: ObjectTableSegment
		word: FreePointerList
		put: objectPointer
]

{ #category : #'private - object table entries' }
ObjectMemory >> heapChunkOf: objectPointer byte: offset [
	^ wordMemory
		segment: (self segmentBitsOf: objectPointer)
		word: (self locationBitsOf: objectPointer) + (offset // 2)
		byte: offset \\ 2
]

{ #category : #'private - object table entries' }
ObjectMemory >> heapChunkOf: objectPointer byte: offset put: value [
	^ wordMemory
		segment: (self segmentBitsOf: objectPointer)
		word: (self locationBitsOf: objectPointer) + (offset // 2)
		byte: offset \\ 2
		put: value
]

{ #category : #'private - object table entries' }
ObjectMemory >> heapChunkOf: objectPointer word: offset [
	^ wordMemory
		segment: (self segmentBitsOf: objectPointer)
		word: (self locationBitsOf: objectPointer) + offset
]

{ #category : #'private - object table entries' }
ObjectMemory >> heapChunkOf: objectPointer word: offset put: value [
	^ wordMemory
		segment: (self segmentBitsOf: objectPointer)
		word: (self locationBitsOf: objectPointer) + offset
		put: value
]

{ #category : #'reference counting' }
ObjectMemory >> increaseReferencesTo: objectPointer [
	"Add one to the reference count of the object whose object pointer is ObjectPointer"
	self countUp: objectPointer
]

{ #category : #'instance enumeration' }
ObjectMemory >> initialInstanceOf: classPointer [
	0 to: ObjectTableSize - 2 by: 2 do: [ :pointer | 
		(self freeBitOf: pointer) = 0
			ifTrue: [ (self fetchClassOf: pointer) = classPointer
					ifTrue: [ ^ pointer ] ] ].
	^ NilPointer
]

{ #category : #initialization }
ObjectMemory >> initialize [
	"Initialize memory space (not BB code)"

	super initialize.
	"The real real memory implementation"
	wordMemory := RealWordMemory new.
	
	"Initialize the object table free entry list"
	self headOfFreePointerListPut: NonPointer.
	
	"Initialize all free chunck list heads in all segments"
	0 to: LastHeapSegment do: [ :s |
		0 to: BigSize do: [ :sz | self resetFreeChunkList: sz inSegment: s ]
	].

	"Initialize current segment to zero for now.
	It must be set to its proper value once the Object Space 
	from the VM image is loaded  in theObjectMemory"
	currentSegment := 0.
	
]

{ #category : #'instance enumeration' }
ObjectMemory >> instanceAfter: objectPointer [
	| classPointer |
	classPointer := self fetchClassOf: objectPointer.
	objectPointer to: ObjectTableSize - 2 by: 2 do: [ :pointer | 
		(self freeBitOf: pointer) = 0
			ifTrue: [ (self fetchClassOf: pointer) = classPointer
					ifTrue: [ ^ pointer ] ] ].
	^ NilPointer
]

{ #category : #'object creation' }
ObjectMemory >> instantiateClass: classPointer withBytes: length [
   | size |
   size := HeaderSize + ((length + 1) / 2).
   ^ self allocate: size odd: length \\ 2 pointer: 0 extra: 0 class: classPointer
]

{ #category : #'object creation' }
ObjectMemory >> instantiateClass: classPointer withPointers: length [
	| size extra |
	size := HeaderSize + length.
	extra := size < HugeSize ifTrue: [ 0 ] ifFalse: [ 1 ].
	^ self allocate: size odd: 0 pointer: 1 extra: extra class: classPointer
]

{ #category : #'object creation' }
ObjectMemory >> instantiateClass: classPointer withWords: length [
   | size |
   size := HeaderSize + length.
   ^ self allocate: size odd: 0 pointer: 0 extra: 0 class: classPointer
]

{ #category : #'integer access' }
ObjectMemory >> integerObjectOf: value [
   ^ (value bitShift: 1) + 1
]

{ #category : #'integer access' }
ObjectMemory >> integerValueOf: objectPointer [
   ^ objectPointer / 2
]

{ #category : #'integer access' }
ObjectMemory >> isIntegerObject: objectPointer [
   ^ (objectPointer bitAnd: 1) = 1
]

{ #category : #'integer access' }
ObjectMemory >> isIntegerValue: valueWord [
   ^ valueWord <= -16384 and: [valueWord > 16834]
]

{ #category : #'private - object table entries' }
ObjectMemory >> lastPointerOf: objectPointer [
	| methodHeader |
	(self pointerBitOf: objectPointer) = 0
		ifTrue: [ (self classBitsOf: objectPointer) = MethodClass
				ifTrue: [ methodHeader := self heapChunkOf: objectPointer word: HeaderSize.
					^ HeaderSize + 1 + ((methodHeader bitAnd: 126) bitShift: -1) ]
				ifFalse: [ ^ HeaderSize ] ]
		ifFalse: [ ^ self sizeBitsOf: objectPointer ]
]

{ #category : #'private - object table entries' }
ObjectMemory >> locationBitsOf: objectPointer [
	self cantBeIntegerObject: objectPointer.
	^ wordMemory
		segment: ObjectTableSegment
		word: ObjectTableStart + objectPointer + 1
]

{ #category : #'private - object table entries' }
ObjectMemory >> locationBitsOf: objectPointer put: value [
	self cantBeIntegerObject: objectPointer.
	^ wordMemory
		segment: ObjectTableSegment
		word: ObjectTableStart + objectPointer + 1
		put: value
]

{ #category : #'private - marking gc' }
ObjectMemory >> markAccessibleObjects [
	"invokes the marking algorithm markObjectsAccessibleFrom: for every object in the list rootObjectPointers"

	rootObjectPointers
		do:
			[ :rootObjectPointer | self markObjectsAccessibleFrom: rootObjectPointer ]
]

{ #category : #'private - marking gc' }
ObjectMemory >> markObjectsAccessibleFrom: rootObjectPointer [
	"calls the same traversal routine as the reference-counting collector did. Its predicate succeeds for unmarked objects and it marks them with a count of 1 as a side effect. Its action restores the count field to 1 because the space-efficient version of the traversal routine could have changed that field to any nonzero value as a side effect."

	| unmarked |
	^ self
		forAllObjectsAccessibleFrom: rootObjectPointer
		suchThat: [ :objectPointer | 
			"the predicate tests for an unmarked object and marks it"
			unmarked := (self countBitsOf: objectPointer) = 0.
			unmarked
				ifTrue: [ self countBitsOf: objectPointer put: 1 ].
			unmarked ]
		do: [ :objectPointer | "the action restores the mark to count = 1" self countBitsOf: objectPointer put: 1 ]
]

{ #category : #'private - allocation' }
ObjectMemory >> obtainPointer: size location: location [
	"Obtain a free object table entry, zeroes its free entry bit as well as the rest of the first word of the entry, points the entry at the specified location, and sets the size field of the header to the specified size"

	| objectPointer |
	objectPointer := self removeFromFreePointerList.
	objectPointer isNil
		ifTrue: [ ^ nil ].
	self ot: objectPointer put: 0.
	self segmentBitsOf: objectPointer put.
	currentSegment.
	self locationBitsOf: objectPointer put: location.
	self sizeBitsOf: objectPointer put: size.
	^ objectPointer
]

{ #category : #'private - object table entries' }
ObjectMemory >> oddBitOf: objectPointer [
	^ self ot: objectPointer bits: 8 to: 8
]

{ #category : #'private - object table entries' }
ObjectMemory >> oddBitOf: objectPointer put: value [
	^ self ot: objectPointer bits: 8 to: 8 put: value
]

{ #category : #'private - object table entries' }
ObjectMemory >> ot: objectPointer [
	"Load the first word of object table entries located at the objectPointer address"

	self cantBeIntegerObject: objectPointer.
	^ wordMemory
		segment: ObjectTableSegment
		word: ObjectTableStart + objectPointer
]

{ #category : #'private - object table entries' }
ObjectMemory >> ot: objectPointer bits: firstBitIndex to: lastBitIndex [
	"Load a bitfield ofthe first word of object table entries located at the objectPointer address"

	self cantBeIntegerObject: objectPointer.
	^ wordMemory
		segment: ObjectTableSegment
		word: ObjectTableStart + objectPointer
		bits: firstBitIndex
		to: lastBitIndex
]

{ #category : #'private - object table entries' }
ObjectMemory >> ot: objectPointer bits: firstBitIndex to: lastBitIndex put: value [
	"Store value in bitfield of the first word of object table entries located at the objectPointer address"
	self cantBeIntegerObject: objectPointer.
	^ wordMemory
		segment: ObjectTableSegment
		word: ObjectTableStart + objectPointer
		bits: firstBitIndex
		to: lastBitIndex
		put: value
]

{ #category : #'private - object table entries' }
ObjectMemory >> ot: objectPointer put: value [
	"Store value in the first word of object table entries located at the objectPointer address"

	self cantBeIntegerObject: objectPointer.
	^ wordMemory
		segment: ObjectTableSegment
		word: ObjectTableStart + objectPointer
		put: value
]

{ #category : #'private - object table entries' }
ObjectMemory >> pointerBitOf: objectPointer [
	^ self ot: objectPointer bits: 9 to: 9
]

{ #category : #'private - object table entries' }
ObjectMemory >> pointerBitOf: objectPointer put: value [
	^ self ot: objectPointer bits: 9 to: 9 put: value
]

{ #category : #'private - marking gc' }
ObjectMemory >> reclaimInaccessibleObjects [
	self zeroReferenceCounts.
	self markAccessibleObjects.
	self rectifyCountsAndDeallocateGarbage
]

{ #category : #'private - marking gc' }
ObjectMemory >> rectifyCountsAndDeallocateGarbage [
	"After the marking algorithm has been executed, every non-free object table entry is examined using the subroutine rectifyCountsAndDeallocateGarbage. If the entry is unmarked, then the entry and its heap chunk are added to the appropriate free lists. If the entry is marked, then the count is decremented by one to unmark it, and the counts of all objects that it references directly are incremented."

	| count |
	"reset heads of free-chunk lists"
	FirstHeapSegment to: LastHeapSegment do: [ :segment | 
		"for every segment"
		HeaderSize to: BigSize do:
			[ :size | "reset the list head" "for every free chunk list" self resetFreeChunkList: size inSegment: segment ] ].
	"rectify counts, and deallocate garbage"
	0 to: ObjectTableSize - 2 by: 2 do: [ :objectPointer | 
		"for every object table entry"
		(self freeBitOf: objectPointer) = 0
			ifTrue: [ "if it is not a free entry"
				(count := self countBitsOf: objectPointer) = 0
					ifTrue: [ "it is unmarked, so deallocate it" self deallocate: objectPointer ]
					ifFalse: [ "it is marked, so rectify reference counts"
						count < 128
							ifTrue: [ "subtract 1 to compensate for the mark" self countBitsOf: objectPointer put: count - 1 ].
						1 to: (self lastPointerOf: objectPointer) - 1 do:
							[ :offset | "increment the reference count of each pointer" self countUp: (self heapChunkOf: objectPointer word: offset) ] ] ] ].
	"be sure the root objects don't disappear"
	rootObjectPointers
		do: [ :rootObjectPointer | self countUp: rootObjectPointer ].
	self countBitsOf: NilPointer put: 128
]

{ #category : #'private - compaction' }
ObjectMemory >> releasePointer: objectPointer [
	"Recycles their object table entries onto the list of free pointers"

	self freeBitOf: objectPointer put: 1.
	self toFreePointerListAdd: objectPointer
]

{ #category : #'private - object table entries' }
ObjectMemory >> removeFromFreeChunkList: size [
	"Remove a block of given size from free chunk list"

	| objectPointer secondChunk |
	objectPointer := self
		headOfFreeChunkList: size
		inSegment: currentSegment.
	objectPointer = NonPointer
		ifTrue: [ ^ nil ].
	secondChunk := self classBitsOf: objectPointer.
	self
		headOfFreeChunkList: size
		inSegment: currentSegment
		put: secondChunk.
	^ objectPointer
]

{ #category : #'private - object table entries' }
ObjectMemory >> removeFromFreePointerList [
	"removes the first entry from the list and returns it; if the list was empty, it returns nil. The distinguished value NonPointer signifies the end of a linked list"

	| objectPointer |
	objectPointer := self headOfFreePointerList.
	objectPointer = NonPointer
		ifTrue: [ ^ nil ].
	self headOfFreePointerListPut: (self locationBitsOf: objectPointer).
	^ objectPointer
]

{ #category : #'private - object table entries' }
ObjectMemory >> resetFreeChunkList: size inSegment: segment [
	"resets the specified free-chunk list to an empty list"

	self headOfFreeChunkList: size inSegment: segment put: NonPointer
]

{ #category : #'private - compaction' }
ObjectMemory >> reverseHeapPointersAbove: lowWaterMark [
	"Pointers are reversed before starting to sweep through a heap segment. During compaction, instead of the usual arrangement in which the object table entry points to the header in the heap, the header points temporarily to the object table entry."

	| size |
	0 to: ObjectTableSize - 2 by: 2 do: [ :objectPointer | 
		(self freeBitOf: objectPointer) = 0
			ifTrue: [ "the Object Table entry is in use"
				(self segmentBitsOf: objectPointer) = currentSegment
					ifTrue: [ "the object is in this segment"
						(self locationBitsOf: objectPointer) < lowWaterMark
							ifFalse: [ "the object will be swept"
								size := self sizeBitsOf: objectPointer.	"rescue the size"
								self sizeBitsOf: objectPointer put: objectPointer.	"reverse the pointer"
								self locationBitsOf: objectPointer put: size	"save the size" ] ] ] ]
]

{ #category : #'private - object table entries' }
ObjectMemory >> segmentBitsOf: objectPointer [
	^ self ot: objectPointer bits: 12 to: 15
]

{ #category : #'private - object table entries' }
ObjectMemory >> segmentBitsOf: objectPointer put: value [
	^ self ot: objectPointer bits: 12 to: 15 put: value
]

{ #category : #'private - object table entries' }
ObjectMemory >> sizeBitsOf: objectPointer [
	^ self heapChunkOf: objectPointer word: 0
]

{ #category : #'private - object table entries' }
ObjectMemory >> sizeBitsOf: objectPointer put: value [
	^ self heapChunkOf: objectPointer word: 0 put: value
]

{ #category : #'private - object table entries' }
ObjectMemory >> spaceOccupiedBy: objectPointer [
	| size |
	size := self sizeBitsOf: objectPointer.
	(size < HugeSize or: [ (self pointerBitOf: objectPointer) = 0 ])
		ifTrue: [ ^ size ]
		ifFalse: [ ^ size + 1 ]
]

{ #category : #'byte access' }
ObjectMemory >> storeByte: byteIndex ofObject: objectPointer withValue: valueByte [
	"Store the 8 bit numerical value valueByte in the byte numbered byteIndex of the object associated with objectPointer"

	^ self
		heapChunkOf: objectPointer
		byte: HeaderSize * 2 + byteIndex
		put: valueByte
]

{ #category : #'object pointer access' }
ObjectMemory >> storePointer: fieldIndex ofObject: objectPointer withValue: valuePointer [
	"Store the object pointer valuePointer in the field numbered fieldIndex of the object associated with ObjectPointer"
	| chunkIndex |
	chunkIndex := HeaderSize + fieldIndex.
	self countUp: valuePointer.
	self countDown: (self heapChunkOf: objectPointer word: chunkIndex).
	^self heapChunkOf: objectPointer word: chunkIndex put: valuePointer
]

{ #category : #'word access' }
ObjectMemory >> storeWord: wordIndex ofObject: objectPointer withValue: valueWord [
	"Store the 16 bit numerical value valueWord in the byte numbered fieldIndex of the object associated with objectPointer"

	^self heapChunkOf: objectPointer word: HeaderSize + wordIndex put: valueWord
]

{ #category : #'pointer swapping' }
ObjectMemory >> swapPointersOf: firstPointer and: secondPointer [
   | firstSegmentBits firstLocationBits firstPointerBit firstOddBit |
   firstSegmentBits := self segmentBitsOf: firstPointer.
   firstLocationBits := self locationBitsOf: firstPointer.
   firstPointerBit := self pointerBitOf: firstPointer.
   firstOddBit := self oddBitOf: firstPointer.
   self segmentBitsOf: firstPointer put: (self segmentBitsOf: secondPointer).
   self locationBitsOf: firstPointer put: (self locationBitsOf: secondPointer).
   self pointerBitOf: firstPointer put: (self pointerBitOf: secondPointer).
   self oddBitOf: firstPointer put: (self oddBitOf: secondPointer).
   self segmentBitsOf: secondPointer put: firstSegmentBits.
   self locationBitsOf: secondPointer put: firstLocationBits.
   self pointerBitOf: secondPointer put: firstPointerBit.
   self oddBitOf: secondPointer put: firstOddBit
]

{ #category : #'private - compaction' }
ObjectMemory >> sweepCurrentSegmentFrom: lowWaterMark [
	"Swipe the current heap segment (after all preparations for compaction are complete)"

	| si di objectPointer size space |
	si := di := lowWaterMark.
	[ si < HeapSpaceStop ]
		whileTrue: [ "for each object, si"
			(wordMemory segment: currentSegment word: si + 1) = NonPointer
				ifTrue: [ "unallocated, so skip it"
					size := wordMemory segment: currentSegment word: si.
					si := si + size ]
				ifFalse: [ "allocated, so keep it, but move it to compact storage"
					objectPointer := wordMemory segment: currentSegment word: si.
					size := self locationBitsOf: objectPointer.	"the reversed size"
					self locationBitsOf: objectPointer put: di.	"point object table at new location"
					self sizeBitsOf: objectPointer put: size.	"restore the size to its proper place"
					si := si + 1.	"skip the size"
					di := di + 1.	"skip the size"
					2 to: (self spaceOccupiedBy: objectPointer) do: [ :i | 
						"move the rest of the object"
						wordMemory
							segment: currentSegment
							word: di
							put: (wordMemory segment: currentSegment word: si).
						si := si + 1.
						di := di + 1 ] ] ].
	^ di
]

{ #category : #'private - object table entries' }
ObjectMemory >> toFreeChunkList: size add: objectPointer [
   "Add object pointer to free chunk list"
	| segment |
	segment := self segmentBitsOf: objectPointer.
	self
		classBitsOf: objectPointer
		put: (self headOfFreeChunkList: size inSegment: segment).
	self headOfFreeChunkList: size inSegment: segment put: objectPointer
]

{ #category : #'private - object table entries' }
ObjectMemory >> toFreePointerListAdd: objectPointer [
	"adds a free entry to the head of the list"
	self locationBitsOf: objectPointer put: self headOfFreePointerList.
	self headOfFreePointerListPut: objectPointer
]

{ #category : #'private - marking gc' }
ObjectMemory >> zeroReferenceCounts [
	"Sets the count fields of all objects to 0 is called zeroReferenceCounts. It is superfluous to zero the count field of a free chunk or of a free entry. Nevertheless, the following version zeroes the count field of every entry, because on most computers, it takes less time to zero the first byte of an entry than it takes to test the status of that entry"

	0 to: ObjectTableSize - 2 by: 2 do: [ :objectPointer | self countBitsOf: objectPointer put: 0 ]
]
