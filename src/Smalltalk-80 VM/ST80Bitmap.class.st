"
Proxy Bitmap class to bitmaps in ST80 VM
"
Class {
	#name : #ST80Bitmap,
	#superclass : #Object,
	#instVars : [
		'oop',
		'memory',
		'bits'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #'instance creation' }
ST80Bitmap class >> fromObject: objectPointer memory: objectMemory [
   "the code below follows the Seaside Object initialization conventions"
	^ self basicNew
		initializeFromObject: objectPointer memory: objectMemory;
		yourself
]

{ #category : #accessing }
ST80Bitmap >> at: wordIndex [
	^ bits at: wordIndex
]

{ #category : #accessing }
ST80Bitmap >> at: wordIndex put: value [
	bits at: wordIndex put: value
]

{ #category : #initialization }
ST80Bitmap >> initializeFromObject: objectPointer memory: objectMemory [
	"initialize a proxy Bitmap object based on the
	attributes of the Form coming from the ST80 VM"

	oop := objectPointer.
	memory := objectMemory.
	bits := ST80BitmapArray fromObject: objectPointer memory: memory.
]

{ #category : #accessing }
ST80Bitmap >> size [
   ^ memory fetchWordLengthOf: oop.
]
