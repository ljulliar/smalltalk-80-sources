"
Tests for RealWordMemory, the host word store used by ObjectMemory. Words are 16 bit values, grouped in 16 segments of 65536 words. Byte 0 of a word is its low byte, bit 0 is its most significant bit (Blue Book p. 657). The class side checksEnabled flag is saved in setUp and restored in tearDown so that no test leaves it changed.
"
Class {
	#name : 'RealWordMemoryTest',
	#superclass : 'TestCase',
	#instVars : [
		'memory',
		'savedChecksEnabled'
	],
	#category : 'Smalltalk-80 VM-Tests',
	#package : 'Smalltalk-80 VM-Tests'
}

{ #category : 'running' }
RealWordMemoryTest >> setUp [

	super setUp.
	savedChecksEnabled := RealWordMemory checksEnabled.
	RealWordMemory checksEnabled: false.
	memory := RealWordMemory new
]

{ #category : 'running' }
RealWordMemoryTest >> tearDown [

	RealWordMemory checksEnabled: savedChecksEnabled.
	super tearDown
]

{ #category : 'tests - words' }
RealWordMemoryTest >> testAtIsZeroBasedDirectAccess [

	memory segment: 1 word: 3 put: 99.
	self assert: (memory at: 65536 + 3) equals: 99.
	self assert: (memory at: 0) equals: 0
]

{ #category : 'tests - bits' }
RealWordMemoryTest >> testBitsPutAnswersTheValue [

	self
		assert: (memory
				 segment: 0
				 word: 1
				 bits: 4
				 to: 7
				 put: 9)
		equals: 9
]

{ #category : 'tests - bits' }
RealWordMemoryTest >> testBitsPutLeavesOtherBitsUntouched [

	memory segment: 0 word: 1 put: 16rFFFF.
	memory
		segment: 0
		word: 1
		bits: 4
		to: 7
		put: 0.
	self assert: (memory segment: 0 word: 1) equals: 16rF0FF
]

{ #category : 'tests - bits' }
RealWordMemoryTest >> testBitsPutThenReadRoundTrip [

	#( #( 0 3 5 ) #( 4 7 10 ) #( 8 15 200 ) #( 0 15 16rBEEF )
	   #( 7 7 1 ) #( 0 0 1 ) ) do: [ :each |
			memory segment: 0 word: 2 put: 0.
			memory
				segment: 0
				word: 2
				bits: each first
				to: each second
				put: each third.
			self
				assert: (memory
						 segment: 0
						 word: 2
						 bits: each first
						 to: each second)
				equals: each third ]
]

{ #category : 'tests - bits' }
RealWordMemoryTest >> testBitsReadBottomNibble [

	memory segment: 0 word: 1 put: 16rA5C3.
	self
		assert: (memory
				 segment: 0
				 word: 1
				 bits: 12
				 to: 15)
		equals: 16r3
]

{ #category : 'tests - bits' }
RealWordMemoryTest >> testBitsReadFullWord [

	memory segment: 0 word: 1 put: 16rA5C3.
	self
		assert: (memory
				 segment: 0
				 word: 1
				 bits: 0
				 to: 15)
		equals: 16rA5C3
]

{ #category : 'tests - bits' }
RealWordMemoryTest >> testBitsReadSingleBit [

	memory segment: 0 word: 1 put: 16r8001.
	self
		assert: (memory
				 segment: 0
				 word: 1
				 bits: 0
				 to: 0)
		equals: 1.
	self
		assert: (memory
				 segment: 0
				 word: 1
				 bits: 1
				 to: 1)
		equals: 0.
	self
		assert: (memory
				 segment: 0
				 word: 1
				 bits: 15
				 to: 15)
		equals: 1
]

{ #category : 'tests - bits' }
RealWordMemoryTest >> testBitsReadTopNibble [

	memory segment: 0 word: 1 put: 16rA5C3.
	self
		assert: (memory
				 segment: 0
				 word: 1
				 bits: 0
				 to: 3)
		equals: 16rA
]

{ #category : 'tests - sanity checks' }
RealWordMemoryTest >> testBitsValueTooWideFailsWhenChecksAreEnabled [

	self withChecksEnabledDo: [
			self
				should: [
						memory
							segment: 0
							word: 0
							bits: 0
							to: 3
							put: 16 ]
				raise: AssertionFailure ]
]

{ #category : 'tests - bytes' }
RealWordMemoryTest >> testByteBoundaryValues [

	memory
		segment: 2
		word: 9
		byte: 0
		put: 255.
	memory
		segment: 2
		word: 9
		byte: 1
		put: 255.
	self assert: (memory segment: 2 word: 9) equals: 16rFFFF.
	memory
		segment: 2
		word: 9
		byte: 0
		put: 0.
	memory
		segment: 2
		word: 9
		byte: 1
		put: 0.
	self assert: (memory segment: 2 word: 9) equals: 0
]

{ #category : 'tests - sanity checks' }
RealWordMemoryTest >> testByteNumberOutOfRangeFailsWhenChecksAreEnabled [

	self withChecksEnabledDo: [
			self
				should: [ memory segment: 0 word: 0 byte: 2 ]
				raise: AssertionFailure.
			self
				should: [
						memory
							segment: 0
							word: 0
							byte: 2
							put: 0 ]
				raise: AssertionFailure ]
]

{ #category : 'tests - bytes' }
RealWordMemoryTest >> testBytePutAnswersTheStoredWord [

	memory segment: 0 word: 7 put: 16r1200.
	self
		assert: (memory
				 segment: 0
				 word: 7
				 byte: 0
				 put: 16r34)
		equals: 16r1234
]

{ #category : 'tests - bytes' }
RealWordMemoryTest >> testBytePutOneOnlyChangesHighByte [

	memory segment: 0 word: 7 put: 16r1234.
	memory
		segment: 0
		word: 7
		byte: 1
		put: 16rCD.
	self assert: (memory segment: 0 word: 7) equals: 16rCD34
]

{ #category : 'tests - bytes' }
RealWordMemoryTest >> testBytePutZeroOnlyChangesLowByte [

	memory segment: 0 word: 7 put: 16r1234.
	memory
		segment: 0
		word: 7
		byte: 0
		put: 16rAB.
	self assert: (memory segment: 0 word: 7) equals: 16r12AB
]

{ #category : 'tests - bytes' }
RealWordMemoryTest >> testByteReadsLowAndHighBytes [

	memory segment: 0 word: 7 put: 16r1234.
	self assert: (memory segment: 0 word: 7 byte: 0) equals: 16r34.
	self assert: (memory segment: 0 word: 7 byte: 1) equals: 16r12
]

{ #category : 'tests - sanity checks' }
RealWordMemoryTest >> testByteValueOutOfRangeFailsWhenChecksAreEnabled [

	self withChecksEnabledDo: [
			self
				should: [
						memory
							segment: 0
							word: 0
							byte: 0
							put: 256 ]
				raise: AssertionFailure ]
]

{ #category : 'tests - initialization' }
RealWordMemoryTest >> testChecksEnabledRoundTrip [

	RealWordMemory checksEnabled: true.
	self assert: RealWordMemory checksEnabled.
	RealWordMemory checksEnabled: false.
	self deny: RealWordMemory checksEnabled
]

{ #category : 'tests - words' }
RealWordMemoryTest >> testCopyFromToIsZeroBasedAndInclusive [

	memory segment: 0 word: 0 put: 10.
	memory segment: 0 word: 1 put: 20.
	memory segment: 0 word: 2 put: 30.
	self assert: (memory copyFrom: 0 to: 2) equals: #( 10 20 30 ).
	self assert: (memory copyFrom: 1 to: 1) equals: #( 20 )
]

{ #category : 'tests - words' }
RealWordMemoryTest >> testLastWordOfLastSegment [

	memory segment: 15 word: 65535 put: 42.
	self assert: (memory segment: 15 word: 65535) equals: 42
]

{ #category : 'tests - words' }
RealWordMemoryTest >> testLastWordOfSegmentDoesNotOverlapNextSegment [

	memory segment: 0 word: 65535 put: 16rFFFF.
	self assert: (memory segment: 1 word: 0) equals: 0.
	memory segment: 1 word: 0 put: 16r1234.
	self assert: (memory segment: 0 word: 65535) equals: 16rFFFF
]

{ #category : 'tests - sanity checks' }
RealWordMemoryTest >> testNegativeSegmentFailsWhenChecksAreEnabled [

	self withChecksEnabledDo: [
		self should: [ memory segment: -1 word: 0 ] raise: AssertionFailure ]
]

{ #category : 'tests - initialization' }
RealWordMemoryTest >> testNewMemoryIsZeroFilled [

	self assert: (memory segment: 0 word: 0) equals: 0.
	self assert: (memory segment: 7 word: 12345) equals: 0.
	self assert: (memory segment: 15 word: 65535) equals: 0
]

{ #category : 'tests - sanity checks' }
RealWordMemoryTest >> testOutOfRangeValueIsNotCheckedWhenChecksAreDisabled [

	RealWordMemory checksEnabled: false.
	self
		shouldnt: [ memory segment: 0 word: 0 put: 65536 ]
		raise: AssertionFailure.
	self assert: (memory segment: 0 word: 0) equals: 65536
]

{ #category : 'tests - sanity checks' }
RealWordMemoryTest >> testSegmentOutOfRangeFailsWhenChecksAreEnabled [

	self withChecksEnabledDo: [
		self should: [ memory segment: 16 word: 0 ] raise: AssertionFailure ]
]

{ #category : 'tests - sanity checks' }
RealWordMemoryTest >> testWordOutOfRangeFailsWhenChecksAreEnabled [

	self withChecksEnabledDo: [
		self
			should: [ memory segment: 0 word: 65536 ]
			raise: AssertionFailure ]
]

{ #category : 'tests - words' }
RealWordMemoryTest >> testWordPutAnswersTheValue [

	self assert: (memory segment: 0 word: 5 put: 777) equals: 777
]

{ #category : 'tests - words' }
RealWordMemoryTest >> testWordPutThenGet [

	memory segment: 3 word: 100 put: 16rABCD.
	self assert: (memory segment: 3 word: 100) equals: 16rABCD
]

{ #category : 'tests - sanity checks' }
RealWordMemoryTest >> testWordValueOutOfRangeFailsWhenChecksAreEnabled [

	self withChecksEnabledDo: [
			self
				should: [ memory segment: 0 word: 0 put: 65536 ]
				raise: AssertionFailure.
			self
				should: [ memory segment: 0 word: 0 put: -1 ]
				raise: AssertionFailure ]
]

{ #category : 'tests - words' }
RealWordMemoryTest >> testWordsInDifferentSegmentsAreIndependent [

	memory segment: 0 word: 10 put: 1.
	memory segment: 1 word: 10 put: 2.
	self assert: (memory segment: 0 word: 10) equals: 1.
	self assert: (memory segment: 1 word: 10) equals: 2
]

{ #category : 'helpers' }
RealWordMemoryTest >> withChecksEnabledDo: aBlock [

	RealWordMemory checksEnabled: true.
	aBlock value
]
