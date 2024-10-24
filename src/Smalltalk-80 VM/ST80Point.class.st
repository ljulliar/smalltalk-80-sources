"
Proxy class to ST80 Point objects
"
Class {
	#name : #ST80Point,
	#superclass : #ST80Object,
	#instVars : [
		'point'
	],
	#classVars : [
		'ClassPointPointer',
		'ClassPointSize',
		'XIndex',
		'YIndex'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #'instance creation' }
ST80Point class >> fromObject: objectPointer memory: memory [
	"Make sure to initialize class variables"
	self initialize.
	
   "the code below follows the Seaside Object initialization conventions"
	^ (super fromObject: objectPointer memory: memory) 
		initializeFromObject: objectPointer memory: memory;
		yourself
]

{ #category : #'class initialization' }
ST80Point class >> initialize [

	" Point class oop in ST80"
	"FIXME: (?) Code duplicate of Interpreter#initializeGuaranteedPointers"
	ClassPointPointer := 26.
	
   "initialize indices of the Point Class."
	"FIXME: (?) Code duplicate of Interpreter#initializePointIndices"
    XIndex := 0.
    YIndex := 1.
    ClassPointSize := 2.
]

{ #category : #initialization }
ST80Point >> initializeFromObject: objectPointer memory: objectMemory [

	"First make sure it is a Point object we are pointing at"
	self assert: ((objectMemory fetchClassOf: objectPointer) = ClassPointPointer).
	
	"Good to go. Create the corresponding native point"
	oop := objectPointer.
	point := (objectMemory integerValueOf: (objectMemory fetchWord: XIndex ofObject: objectPointer)) @
	         (objectMemory integerValueOf: (objectMemory fetchWord: YIndex ofObject: objectPointer)).

]

{ #category : #accessing }
ST80Point >> point [
	^ point
]
