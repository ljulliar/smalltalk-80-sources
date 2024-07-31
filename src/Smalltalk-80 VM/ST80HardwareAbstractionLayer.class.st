"
This class provides the mapping between the ST80 primitves and the underlying 
hardware (display, mouse, UI events, etc...) layer of the host Smalltalk environment.

Internal Representation and Key Implementation Points.

Instance Variables
- display:	the display object in the host environment
- height:		display height (in pixels)
- width:		display width (in pixels)

Implementation Points
"
Class {
	#name : #ST80HardwareAbstractionLayer,
	#superclass : #Object,
	#instVars : [
		'display',
		'displayWidth',
		'displayHeight',
		'window',
		'displayMorph',
		'displayForm'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #initialization }
ST80HardwareAbstractionLayer >> initialize [

	"Initial Screen dimensions can be found
	in the Xerox ST80 Virtual Image Booklet p. 3"
	displayWidth := 640.
	displayHeight := 480.
	display := nil.
	
]
