"
This class represents the Morph used on the host side to display the
ST80 VM display screen.

Class instance is also responsible for capturing UI events and forward 
them to the ST80 VM.
"
Class {
	#name : #ST80DisplayMorph,
	#superclass : #ImageMorph,
	#instVars : [
		'displayForm',
		'hal',
		'vm'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #geometry }
ST80DisplayMorph class >> extent: extentPoint vm: aVm [
	"Return a new display morph for the ST80 VM with proper 
	display dimension"
	
	^ self basicNew initWithExtent: extentPoint vm: aVm; yourself.

]

{ #category : #announcements }
ST80DisplayMorph >> announceDeleted [ 

	"On closing App window, terminate the ST80 VM"
	vm terminate

]

{ #category : #'event handling' }
ST80DisplayMorph >> checkHandPosition [
	"Direct keyboard focus to this morph if the active hand
	is over it"
	| hand_position |
	hand_position := self currentWorld activeHand position - self position.
	(hand_position >= (0@0) and: hand_position <= self extent)
		 ifTrue: [
			self currentWorld activeHand newKeyboardFocus: self
		].
	
]

{ #category : #accessing }
ST80DisplayMorph >> displayForm [

	^ displayForm
]

{ #category : #'event handling' }
ST80DisplayMorph >> handlesKeyDown: anEvent [
	"Accept keyboard events only when the ST80 VM 
	input semaphore is set"
	"^ false"
	^ hal inputSemaphore notNil.
]

{ #category : #'event handling' }
ST80DisplayMorph >> handlesKeyUp: anEvent [
	"Accept keyboard events only when the ST80 VM 
	input semaphore is set"
	"^ false"
	^ hal inputSemaphore notNil.
	
]

{ #category : #'event handling' }
ST80DisplayMorph >> handlesKeyboard: anEvent [
	"Accept keyboard events only when the ST80 VM 
	input semaphore is set"
	"^ false"
	^ hal inputSemaphore notNil.
	
]

{ #category : #'event handling' }
ST80DisplayMorph >> handlesMouseDown: anEvent [
	"Accept mouseDown:, mouseMove:, mouseUp: event notifications"
	"but only when the ST80 VM input event handling is ready"
	^ hal inputSemaphore notNil.
]

{ #category : #'event handling' }
ST80DisplayMorph >> handlesMouseMove: anEvent [
	"Accept mouseMove: event notifications"
	"but only when the ST80 VM input event handling is ready"
	^ hal inputSemaphore notNil.
]

{ #category : #'event handling' }
ST80DisplayMorph >> handlesMouseOver: anEvent [
	"Accept mouseEnter: and mouseLeave: event notifications"
	"but only when the ST80 VM input event handling is ready"
	^ hal inputSemaphore notNil.
]

{ #category : #initialization }
ST80DisplayMorph >> initWithExtent: anExtentPoint vm: aVm [

	vm := aVm.
	hal := vm hal.
	displayForm := Form extent: anExtentPoint depth: 1.
	displayForm fill: (0@0 extent: anExtentPoint) rule: Form over fillColor: Color white.
	
	self initialize.
	self form: displayForm.

	

]

{ #category : #'event handling' }
ST80DisplayMorph >> keyDown: anEvent [
	"A key on the keyboard was clicked"
	Transcript show: 'Key down: '; nextPutAll: anEvent keyValue printString; 
		nextPutAll:  anEvent anyModifierKeyPressed printString;
		nextPutAll:  anEvent modifierString printString; 
		nextPutAll:  anEvent scanCode printString; 
		nextPutAll:  anEvent key name printString; 
		cr; flush.
		
	hal handleKeyboardEvent: anEvent way: #down.
]

{ #category : #'event handling' }
ST80DisplayMorph >> keyUp: anEvent [
	"A key on the keyboard was clicked"
	Transcript show: 'Key up '; nextPutAll: anEvent keyValue printString; 
		nextPutAll:  anEvent anyModifierKeyPressed printString;
		nextPutAll:  anEvent modifierString printString; 
		nextPutAll:  anEvent scanCode printString; 
		nextPutAll:  anEvent key name printString; 
		cr; flush.
		
	hal handleKeyboardEvent: anEvent way: #up.
]

{ #category : #'event handling' }
ST80DisplayMorph >> mouseDown: anEvent [
	"One of the mouse buttons was clicked down"
	"Which button: 
		- 4 is the primary button (= left button on right handed mouse)
		- 2 is the secondary button (= right button on )
	TODO: I couldn't make the middle button work so far. It is always intercepted by
	the display morph halo"

	Transcript show: 'Mouse Down'; show: anEvent whichButton; cr; flush.
	hal handleMouseEvent: anEvent way: #down.
]

{ #category : #'event handling' }
ST80DisplayMorph >> mouseEnter: anEvent [
	"The mouse pointer is entering the ST80 Morph"
	Transcript show: 'Mouse enters ST80 Morph'; cr; flush.
	"Get keyboard attention"
	anEvent hand newKeyboardFocus: self.
	"Set the mouse cursor to the current ST80 cursor"
	"self world currentCursor: hal cursor."
]

{ #category : #'event handling' }
ST80DisplayMorph >> mouseLeave: anEvent [
	"The mouse pointer is leaving the ST80 Morph"
	Transcript show: 'Mouse leaves ST80 Morph'; cr; flush.
	"Release keyboard attention"
	anEvent hand newKeyboardFocus: nil.
	"Return the mouse cursor to normal"
	self currentHand showTemporaryCursor: nil.
]

{ #category : #'event handling' }
ST80DisplayMorph >> mouseMove: anEvent [
	"One of the mouse buttons was clicked down"

	| relative_position |
	
	"Make sure the relative position has no negative coordinates or is beyond
	the display form boudary It may happen while moving the mouse after opening
	a context menu"
	relative_position := (anEvent endPoint - self position) min: displayForm extent max: 0@0.
	"Transcript show: 'Mouse Move'; show: relative_position ; cr; flush."
	hal mouseMove: relative_position 
]

{ #category : #'event handling' }
ST80DisplayMorph >> mouseUp: anEvent [
	"One of the mouse buttons was clicked down"

	Transcript show: 'Mouse Up'; show: anEvent whichButton; cr; flush.
	hal handleMouseEvent: anEvent way: #up.
]
