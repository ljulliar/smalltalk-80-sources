"
This is the super class of some the ST80 proxy classes representing ST80 
internal objects (e.g. STForm, STBitBlt, STCursor, ...)

This class a number of instance variables representing features that ST80 
internal objects have in common such as object pointer, object size, etc...
"
Class {
	#name : #ST80Object,
	#superclass : #Object,
	#instVars : [
		'oop',
		'size',
		'wordLength',
		'addressOfObject',
		'addressOfFirstWord',
		'memory'
	],
	#classVars : [
		'HeaderSize'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #'instance creation' }
ST80Object class >> fromObject: objectPointer memory: memory [
	^ self basicNew initializeFromObject: objectPointer memory: memory; yourself.
]

{ #category : #accessing }
ST80Object >> addressOfFirstWord [
	^  addressOfFirstWord ifNil: [ addressOfFirstWord := self memory addressOfWord: oop ]
]

{ #category : #accessing }
ST80Object >> addressOfObject [
	^  addressOfObject ifNil: [ addressOfObject := self memory addressOfObject: oop ]
]

{ #category : #initialization }
ST80Object >> initializeFromObject: objectPointer memory: aMemory [

	oop := objectPointer.
	memory := aMemory.
	
	"Explicitely initialize those instance variable to nil 
	just as a reminder that the initialization is actually happening
	on the fly if the corresponding get accessor is used"
	size := nil.
	wordLength := nil.
	addressOfObject := nil.
	addressOfFirstWord := nil.

]

{ #category : #accessing }
ST80Object >> memory [
	^ memory
]

{ #category : #accessing }
ST80Object >> oop [
	^ oop
]

{ #category : #accessing }
ST80Object >> size [
	^ size ifNil: [ size := self memory sizeBitsOf: oop ]
]

{ #category : #accessing }
ST80Object >> wordLength [
	^ wordLength ifNil: [ wordLength := self memory fetchWordLengthOf: oop ]
]
