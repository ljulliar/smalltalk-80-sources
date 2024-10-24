"
This is a proxy class to the Smalltalk 80 cursor object that is
passed over to the V through the primitiveBeCursor message.

It holds both a reference to the ST80 object and it also creates
a host native cursor object with the same size and shape that is used
by the VM application to reflect changes in the cursor shape on screen.
"
Class {
	#name : #ST80Cursor,
	#superclass : #Cursor,
	#instVars : [
		'oop'
	],
	#classVars : [
		'ST80Cursors'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #'instance creation' }
ST80Cursor class >> fromObject: objectPointer memory: memory [
   "Return the native cursor instance if it already exists,
	if not create it and store it in the Dictionary for future
	reuse"
	| cForm nativeCursor |
	
	"Make sure class variables are set"
	self initialize.
	
	(ST80Cursors includesKey: objectPointer)
		ifTrue: [ ^ ST80Cursors at: objectPointer ].
		
		cForm := ST80Form fromObject: objectPointer memory: memory. 
		nativeCursor := self extent: cForm extent fromArray: cForm bits asArray offset: cForm offset.
		"Transcript show: 'cursor offset: '; nextPutAll: cForm offset printString; cr; flush."
		"nativeCursor cursorForm: cForm."
		"nativeCursor asMorph openInWindowLabeled: 'Cursor'."
		^ nativeCursor initializeFromObject: objectPointer memory: memory; yourself.  

]

{ #category : #'class initialization' }
ST80Cursor class >> initialize [ 

	"Since ST80 cursors are in finite number (see BB p.398-399) store
	their host equivalent in a hash when they are created. Use the ST80
	cursor oop as the hash index as it never changes. This avoid creating
	host cursors again and again each time the ST80 source code invokes the
	BeCursor message"
	
	ST80Cursors ifNil: [ ST80Cursors := Dictionary new].
]

{ #category : #primitives }
ST80Cursor >> activateInCursorOwner: aCursorOwner [

	^ aCursorOwner activateCursor: self withMask: (CursorWithMask derivedFrom: self).
]

{ #category : #initialization }
ST80Cursor >> initializeFromObject: objectPointer memory: memory [

	oop := objectPointer.
	ST80Cursors at: objectPointer put: self.
]

{ #category : #accessing }
ST80Cursor >> oop [

	^ oop
]
