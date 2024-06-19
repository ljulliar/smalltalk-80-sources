"
To access locations in the address space of the host machine, machine language implementations use load and store instructions.
In RealObjectMemory, the load and store instructions are symbolized by messages to an instance of RealWordMemory whose name is wordMemory. 
"
Class {
	#name : #RealWordMemory,
	#superclass : #Object,
	#instVars : [
		'realWordMemory'
	],
	#classVars : [
		'SegmentCount',
		'WordSegmentCount'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #'class initialization' }
RealWordMemory class >> initialize [
	"Real World memory parameters"

	"For values see BB p. 656"
	SegmentCount := 16.
	WordSegmentCount := 65536.
]

{ #category : #initialization }
RealWordMemory >> initialize [
	"Initialize the real world memory (not BB code)"

	"Since we do not add required parameters here simply calloutAPIClass super.
	(Follows the Seaside initialization convention"

	super initialize.

	"The Array below will ba made of SmallIntegers which are 32 bits log 
	on most modern architecture. This is twice the size that ST-80 needs 
	as it uses 16 bit words but we don't care compacting 2 ST-80 words
	in one SmallInteger for now."
	realWordMemory := Array new: (WordSegmentCount * SegmentCount)  withAll: 0
]

{ #category : #access }
RealWordMemory >> segment: s word: w [
	"Return word w of segment s."
	"ShouldBeImplemented signalFor: thisContext sender selector"
	
   "Not BB code"
	^ realWordMemory at: (s * WordSegmentCount + w + 1).

]

{ #category : #access }
RealWordMemory >> segment: s word: w bits: firstBitIndex to: lastBitIndex [
	"Return bits firstBitIndex to lastBitIndex of word w of segment s."
	"ShouldBeImplemented signalFor: thisContext sender selector"
	
	"Not BB code. For bit index see BB p. 657"
	|mask shift word|
	shift := (15 - lastBitIndex).
	mask  := (2**(lastBitIndex - firstBitIndex + 1) - 1) bitShift: shift.
	word  := self segment: s word: w.
	^ word bitAnd: mask;  bitShift: shift.
]

{ #category : #access }
RealWordMemory >> segment: s word: w bits: firstBitIndex to: lastBitIndex put: value [
	"Store value into bits firstBitIndex to lastBitIndex of word w of segment s; return value"
	"ShouldBeImplemented signalFor: thisContext sender selector"
	
	"Not BB code. For bit index see BB p. 657"
	|mask shift word|
	shift := (15 - lastBitIndex).
	mask  := (2**(lastBitIndex - firstBitIndex + 1) - 1) bitShift: shift.
	word  := (self segment: s word: w) bitAnd: ((mask bitInvert) bitOr: (value bitShift: shift)).
	^self segment: s word: s put: word 
]

{ #category : #access }
RealWordMemory >> segment: s word: w byte: byteNumber [
	"Return byte byteNumber of word w of segment s."
	"ShouldBeImplemented signalFor: thisContext sender selector"
	
	"Not BB code. For byte index see BB p. 657"
	|word byte|
	word := self segment: s word: w.
	byte := (byteNumber = 1)
		ifTrue: [ word bitAnd: 16rFF ] 
		ifFalse: [ word bitShift: 8 ].
	^ byte 
]

{ #category : #access }
RealWordMemory >> segment: s word: w byte: byteNumber put: value [
	"Store value into byte byteNumber of word w of segment s; return value."
	"ShouldBeImplemented signalFor: thisContext sender selector"
	
	"Not BB code. For byte indexing see BB p. 657"
	|word|
	word := self segment: s word: w.
	word := (byteNumber = 1)
		ifTrue: [ word bitAnd: 16rFF00; bitOr: value ] 
		ifFalse: [ word bitAnd: 16r00FF; bitOr: (value bitShift: -8) ].
	^ self segment: w word: w put: word.
	
]

{ #category : #access }
RealWordMemory >> segment: s word: w put: value [
	"Store value into word w of segment s; return value."
	"ShouldBeImplemented signalFor: thisContext sender selector"
	"Not BB code"
	^realWordMemory at: (s * WordSegmentCount + w) put: value
	
]
