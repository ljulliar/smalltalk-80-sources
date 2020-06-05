"
To access locations in the address space of the host machine, machine language implementations use load and store instructions.
In RealObjectMemory, the load and store instructions are symbolized by messages to an instance of RealWordMemory whose name is wordMemory. 
"
Class {
	#name : #RealWordMemory,
	#superclass : #Object,
	#category : #'Smalltalk-80 VM'
}

{ #category : #access }
RealWordMemory >> segment: s word: w [
	"Return word w of segment s."
	ShouldBeImplemented signalFor: thisContext sender selector
]

{ #category : #access }
RealWordMemory >> segment: s word: w bits: firstBitIndex to: lastBitIndex [
	"Return bits firstBitIndex to lastBitIndex of word w of segment s."
	ShouldBeImplemented signalFor: thisContext sender selector
]

{ #category : #access }
RealWordMemory >> segment: s word: w bits: firstBitIndex to: lastBitIndex put: value [
	"Store value into bits firstBitIndex to lastBitIndex of word w of segment s; return value"
	ShouldBeImplemented signalFor: thisContext sender selector
]

{ #category : #access }
RealWordMemory >> segment: s word: w byte: byteNumber [
	"Return byte byteNumber of word w of segment s."
	ShouldBeImplemented signalFor: thisContext sender selector
]

{ #category : #access }
RealWordMemory >> segment: s word: w byte: byteNumber put: value [
	"Store value into byte byteNumber of word w of segment s; return value."
	ShouldBeImplemented signalFor: thisContext sender selector
]

{ #category : #access }
RealWordMemory >> segment: s word: w put: value [
	"Store value into word w of segment s; return value."
	ShouldBeImplemented signalFor: thisContext sender selector
	
]
