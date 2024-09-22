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

{ #category : #accessing }
ST80DisplayMorph >> displayForm [

	^ displayForm
]

{ #category : #'event handling' }
ST80DisplayMorph >> handlesKeyboard: anEvent [
	"A key on the kayboard was clicked"
	^ true
]

{ #category : #'event handling' }
ST80DisplayMorph >> handlesMouseDown: anEvent [
	"Accept Mouse Down event notifications"
	^ true
]

{ #category : #'events - processing' }
ST80DisplayMorph >> handlesMouseMove: anEvent [
	"Accept Mouse move event notifications"
	^ true
]

{ #category : #'event handling' }
ST80DisplayMorph >> handlesMouseOver: anEvent [
	"Accept Mouse Enter/Leave event notifications"
	^ true
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
	"A key on the kayboard was clicked"
	Transcript show: anEvent keyValue; 
		show: anEvent anyModifierKeyPressed;
		show: anEvent modifierString; 
		cr; flush.
]

{ #category : #'event handling' }
ST80DisplayMorph >> mouseDown: anEvent [
	"One of the mouse buttons was clicked down"

	Transcript show: 'Mouse Down'; show: anEvent whichButton; cr; flush.
]

{ #category : #'event handling' }
ST80DisplayMorph >> mouseEnter: anEvent [
	"The mouse pointer is entering the ST80 Morph"
	Transcript show: 'Mouse enters ST80 Morph'; cr; flush.
	anEvent hand newKeyboardFocus: self.
]

{ #category : #'event handling' }
ST80DisplayMorph >> mouseLeave: anEvent [
	"The mouse pointer is leaving the ST80 Morph"
	Transcript show: 'Mouse leaves ST80 Morph'; cr; flush.
	anEvent hand newKeyboardFocus: nil.
]

{ #category : #'event handling' }
ST80DisplayMorph >> mouseMove: anEvent [
	"One of the mouse buttons was clicked down"

	| relative_position |
	relative_position := anEvent endPoint - self position.
	Transcript show: 'Mouse Move'; show: relative_position ; cr; flush.
	hal mouseMove: relative_position 
]

{ #category : #'event handling' }
ST80DisplayMorph >> mouseUp: anEvent [
	"One of the mouse buttons was clicked down"

	Transcript show: 'Mouse Up'; cr; flush.
]
