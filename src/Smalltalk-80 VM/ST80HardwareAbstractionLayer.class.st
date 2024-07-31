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

{ #category : #'display access' }
ST80HardwareAbstractionLayer >> displayWidth: width displayHeight: height [

	| newDisplayMorph |

	"If same dimensions do nothing and return"
	(displayWidth = width and: displayHeight = height) ifTrue: [ ^ true ].
	
	displayWidth := width.
	displayHeight := height.
	
	"A form cannot be resized so create
	a new one with proper dimensions even when
	a form was previously created"
	displayForm := Form extent: width@height depth: 2.
	displayForm fill: (0@0 extent: displayForm extent) rule: Form over fillColor: Color white.
	newDisplayMorph := displayForm asMorph.
	
	window
		ifNotNil: [ 
			"Replace display morph in existing window"
			window removeMorph: displayMorph.
			window addMorph: newDisplayMorph frame: (0@0 corner: 1@1).
			window extent: displayWidth@displayHeight.
			]
		ifNil: [ 
			"First time display is set so create the host window"
			window := newDisplayMorph openInWindowLabeled: 'Smalltalk-80'.
		 ].
	displayMorph := newDisplayMorph.
	^ true.
	
	

]

{ #category : #initialization }
ST80HardwareAbstractionLayer >> initialize [

	"Initial Screen dimensions can be found
	in the Xerox ST80 Virtual Image Booklet p. 3"
	displayWidth := 640.
	displayHeight := 480.
	display := nil.
	
]
