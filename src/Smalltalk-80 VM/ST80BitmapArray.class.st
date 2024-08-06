"
Allows for direct access to words of ST80 Bitmaps 
"
Class {
	#name : #ST80BitmapArray,
	#superclass : #Object,
	#instVars : [
		'address',
		'wordMemory',
		'baseAddress',
		'oop',
		'memory'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #'instance creation' }
ST80BitmapArray class >> fromObject: objectPointer memory: objectMemory [
   "the code below follows the Seaside Object initialization conventions"
	^ self basicNew
		initializeFromObject: objectPointer memory: objectMemory;
		yourself
]

{ #category : #accessing }
ST80BitmapArray >> at: wordIndex [
   "Access Bitmaps words as an Array. Note that Bitmap
    array indices starts at one in the bitblt simulation
    code like for a regular Smalltalk array. So minus one here
    because the RealWorldMemory address method expect a zero
    based index"
	^ memory fetchWord: (wordIndex - 1) ofObject: oop. 
	"^ wordMemory at: (baseAddress + wordIndex - 1)"
]

{ #category : #accessing }
ST80BitmapArray >> at: wordIndex put: value [
	memory storeWord: (wordIndex - 1) ofObject: oop  withValue: value
]

{ #category : #initialization }
ST80BitmapArray >> initializeFromObject: objectPointer memory: objectMemory [
	"initialize a proxy BitmapArray object so that we can
	access bitmap words of ST80 Forms directly"

	oop := objectPointer.
	memory := objectMemory.
	baseAddress := objectMemory addressOf: objectPointer.
	wordMemory := objectMemory wordMemory.
]
