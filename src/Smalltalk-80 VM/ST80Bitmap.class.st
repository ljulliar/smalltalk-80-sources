"
Proxy Bitmap class to bitmaps in ST80 VM
"
Class {
	#name : #ST80Bitmap,
	#superclass : #ST80Object,
	#instVars : [
		'index',
		'bitsArray'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #'instance creation' }
ST80Bitmap class >> fromObject: objectPointer memory: objectMemory [
   "the code below follows the Seaside Object initialization conventions"
	^ (super fromObject: objectPointer memory: objectMemory)
		initializeFromObject: objectPointer memory: objectMemory;
		yourself
]

{ #category : #converting }
ST80Bitmap >> asArray [
  "Return the bitmap as an array of 16-bit integer values. Create
	the array the first time this message is received."
	| wm bitsStartIndex |
	^ bitsArray ifNil: [  
		wm := memory wordMemory.
		bitsStartIndex := self addressOfFirstWord.
		bitsArray := wm copyFrom: bitsStartIndex to: (bitsStartIndex + self bitsSize - 1)
		]
]

{ #category : #accessing }
ST80Bitmap >> at: wordIndex [
   self bitsSize = 16 ifTrue: [ 
   "Transcript show: 'Bitmap at: '; nextPutAll: wordIndex printString; cr" ].
	^ memory fetchWord: (wordIndex - 1) ofObject: oop
	"FIXME: Faster DMA version to be tested
	^wordMemory at: (baseAddress + wordIndex - 1)"
]

{ #category : #accessing }
ST80Bitmap >> at: wordIndex put: value [
	memory storeWord: (wordIndex - 1) ofObject: oop  withValue: value
	"FIXME: Faster DMA version to be tested
	^wordMemory at: (baseAddress + wordIndex - 1) put: value"
]

{ #category : #accessing }
ST80Bitmap >> bitsSize [
	^ self wordLength
]

{ #category : #initialization }
ST80Bitmap >> initializeFromObject: objectPointer memory: objectMemory [
	"initialize a proxy Bitmap object based on the
	attributes of the Form coming from the ST80 VM"
	"bits := ST80BitmapArray fromObject: objectPointer memory: memory."
	super initializeFromObject: objectPointer memory: objectMemory.
]
