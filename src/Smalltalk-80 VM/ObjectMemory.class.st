"
The function of the object memroy is to create, store, and destroy objects and to provide access to their fields.

This is a real-memory implementation meaning that all the objects in the environment reside in primary memory that is directly addressable by the program (as opposed to virtual memory)
"
Class {
	#name : #ObjectMemory,
	#superclass : #Object,
	#instVars : [
		'currentSegment',
		'wordMemory'
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
	"A good value for NonPointer is 2^16 - 1, a value that is easily detected on most computers and that cannot be confused with an actual object table entry address because it is an odd number."
	NonPointer := 2**16 - 1
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
	objectPointer := self
		headOfFreeChunkList: BigSize
		inSegment: currentSegment.
	"the search loop stops when the end of the linked list is encountered"
	[ objectPointer = NonPointer ]
		whileFalse: [ availableSize := self sizeBitsOf: objectPointer.
			availableSize = size
				ifTrue: [ "exact fit -- remove from free chunk list and return"
					next := self classBitsOf: objectPointer.	"the link to the next chunk"
					predecessor = NonPointer
						ifTrue:
							[ "it was the head of the list; make the next item the head" self headOfFreeChunkList: BigSize inSegment: currentSegment put: next ]
						ifFalse: [ "it was between two chunks; link them together" self classBitsOf: predecessor put: next ].
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

{ #category : #'class pointer access' }
ObjectMemory >> fetchClassOf: objectPointer [
	"Return the object pointer of the class-describing object for the object associated with objectPointer"
	(self isIntegerObject: objectPointer)
		ifTrue: [^IntegerClass] "ERROR IntegerClass not defined"
		ifFalse: [^self classBitsOf: objectPointer]
]

{ #category : #'object pointer access' }
ObjectMemory >> fetchPointer: fieldIndex ofObject: objectPointer [
	"Return the object pointer found in the field numbered fieldIndex of the object associated with ObjectPointer"
	^self heapChunkOf: objectPointer word: HeaderSize + fieldIndex
]

{ #category : #'word access' }
ObjectMemory >> fetchWord: fieldIndex ofObject: objectPointer [
	"Return the 16 bit numerical value found in the word numbered fieldIndex of the object associated with ObjectPointer"
	^self heapChunkOf: objectPointer word: HeaderSize + fieldIndex
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

{ #category : #'private - object pointers' }
ObjectMemory >> isIntegerObject: objectPointer [
	"tests the low order bit of objectPointer to determine whether the rest of the pointer is an immediate integer value rather than an object table index"
	^(objectPointer bitAnd: 1) = 1
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
ObjectMemory >> storeWord: fieldIndex ofObject: objectPointer withValue: valueWord [
	"Store the 16 bit numerical value valueWord in the byte numbered fieldIndex of the object associated with objectPointer"

	^ self
		heapChunkOf: objectPointer
		word: HeaderSize + fieldIndex
		put: valueWord
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
