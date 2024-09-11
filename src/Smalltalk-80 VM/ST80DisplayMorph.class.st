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
