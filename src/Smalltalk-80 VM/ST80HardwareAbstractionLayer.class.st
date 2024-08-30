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
		'displayForm',
		'cursor',
		'inputSemaphore',
		'inputQueue'
	],
	#classVars : [
		'AbsoluteTime',
		'AlphaLockKey',
		'BackspaceKey',
		'ButtonCenter',
		'ButtonLeft',
		'ButtonRight',
		'ControlKey',
		'DeleteKey',
		'DeltaTime',
		'DeviceOff',
		'DeviceOn',
		'EscapeKey',
		'LeftShiftKey',
		'LineFeedKey',
		'ReturnKey',
		'RightShiftKey',
		'SpaceKey',
		'TabKey',
		'XLocation',
		'YLocation'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #'class initialization' }
ST80HardwareAbstractionLayer class >> initialize [
	"Not BB code"

	"Input Event type values as expected by the ST80 VM. See BB p. 649"
	DeltaTime    := 0.
	XLocation    := 1.
	YLocation    := 2.
	DeviceOn     := 3.
	DeviceOff    := 4.
	AbsoluteTime := 5.
	
	"Special char keys parameters. See BB p. 650"
	BackspaceKey := 8.
	TabKey       := 9.
	LineFeedKey  := 10.
	ReturnKey    := 13.
	EscapeKey    := 27.
	SpaceKey     := 32.
	DeleteKey    := 127.
	
	"Meta keys parameters (undecoded keyboard)"
	LeftShiftKey  := 136.
	RightShiftKey := 137.
	ControlKey    := 138.
	AlphaLockKey  := 139.
	
   "Bi-state devices parameters. See BB p. 650"
	ButtonLeft   := 130.
	ButtonCenter := 131.
	ButtonRight  := 132.
]

{ #category : #'cursor access' }
ST80HardwareAbstractionLayer >> cursor: aCursor [
	"This message receives a pointer to a 16x16 Proxy ST80 Form
	to use as the current cursor on the display screen"
	
	"Convert the ST80 cursor form to a native Form.
	No cropping here as we want the entire cursor form of course"
	cursor := aCursor asNativeFormCropped: (Rectangle origin: 0@0 extent: aCursor extent).
	
	"TODO: add some display logic here. Like if the mouse pointer
	is in the display window then the cursor must be updated on screen"
	
	^ true
]

{ #category : #'display access' }
ST80HardwareAbstractionLayer >> displayWidth: width displayHeight: height [

	| newDisplayMorph |

	"If same dimensionsas current display do nothing and return"
	(displayWidth = width and: displayHeight = height) ifTrue: [ ^ true ].
	
	displayWidth := width.
	displayHeight := height.
	
	"A form cannot be resized so create
	a new one with proper dimensions even when
	a form was previously created"
	displayForm := Form extent: width@height depth: 1.
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
	
	"Install Morph UI handlers to capture the input events
	that we will forward to the ST80 VM"
	displayMorph on: #MouseEnter send: #mouseEnterST80Morph to: self.
	displayMorph on: #MouseLeave send: #mouseLeaveST80Morph to: self.
	displayMorph on: #MouseDown  send: #mouseDownST80Morph to: self.
	displayMorph on: #MouseUp    send: #mouseUpST80Morph to: self.
	displayMorph on: #MouseMove  send: #mouseUpST80Morph to: self.	
	displayMorph on: #keyStroke  send: #mouseKeyStrokeST80Morph to: self. 
	
	^ true.
	
	

]

{ #category : #initialization }
ST80HardwareAbstractionLayer >> initialize [

	"Make sure to initialize class variables"
	self class initialize.
	
	"Initial Screen dimensions can be found
	in the Xerox ST80 Virtual Image Booklet p. 3.
	The original ST80 VM will set them up at start time
	at 640x480"
	displayWidth := nil.
	displayHeight := nil.
	display := nil.
	
	"I/O Device (keyboard, mouse, location,...) 
	Input event queue"
	inputQueue := OrderedCollection new.
	
]

{ #category : #'as yet unclassified' }
ST80HardwareAbstractionLayer >> inputSemaphore: aSemaphore [
	"keep track of the semaphore to signal when input event occur"	
	inputSemaphore = aSemaphore.
	

]

{ #category : #'as yet unclassified' }
ST80HardwareAbstractionLayer >> mouseDownST80Morph: event [
	"One of the mouse buttons was clicked down"
	self halt.
]

{ #category : #'as yet unclassified' }
ST80HardwareAbstractionLayer >> mouseEnterST80Morph: event [
	"The mouse pointer is entering the ST80 Morph"
	Transcript show: 'Mouse enters ST80 Morph'.
]

{ #category : #'as yet unclassified' }
ST80HardwareAbstractionLayer >> mouseLeaveST80Morph: event [
	"The mouse pointer is leaving the ST80 Morph"
	Transcript show: 'Mouse leaves ST80 Morph'.
]

{ #category : #'as yet unclassified' }
ST80HardwareAbstractionLayer >> nextInputWord [
	"Pick the next 16 bit word event from the event queue"
	inputQueue isEmpty 
		ifTrue: [ ^ nil ]
		ifFalse: [ ^ inputQueue removeFirst ]

]

{ #category : #'display access' }
ST80HardwareAbstractionLayer >> updateDisplayRect: rectangle fromForm: sourceForm [
	"Not BB code"
	"Create a native bitBlt operation to update the dirty rectangle
	on the display screen."
		
	| bitBlt nativeSourceForm align16Rectangle |
	
	"Adjust Rectangle left side to nearest lower 16 bits multiple 
	and the Rectangle right side to the nearest upper 16 bit multiple
	so as to copy the entire native form created"
	align16Rectangle := rectangle left: rectangle left // 16 * 16.
	align16Rectangle := align16Rectangle right: (align16Rectangle right + 15) // 16 * 16.
	nativeSourceForm := sourceForm asNativeFormCropped: align16Rectangle.
	"nativeForm := Form extent: align16Rectangle extent depth: 1 fromArray: (sourceForm bits) offset: 0@0."
	
	bitBlt := BitBlt destForm: displayForm sourceForm: nativeSourceForm halftoneForm: nil 
					combinationRule: 3	 destOrigin: align16Rectangle origin sourceOrigin: 0@0
					extent: nativeSourceForm extent clipRect: (Rectangle origin: 0@0 extent: displayForm extent ).
	
	"asNativeSourceForm := ST80AsNativeForm fromForm: sourceForm.
	bitBlt := BitBlt destForm: displayForm sourceForm: asNativeSourceForm halftoneForm: nil 
					combinationRule: 3	 destOrigin: rectangle origin sourceOrigin: rectangle origin
					extent: rectangle extent clipRect: rectangle."
	bitBlt copyBits.
	displayMorph changed.
	"Transcript clear."

	"read as array directly from real world memory"
	"form := Form extent: 640@480 depth: 1 fromArray: sourceForm bits offset: 0@0.
	morph := form asMorph.
	window removeMorph: displayMorph.
	window addMorph: morph frame: (0@0 corner: 1@1).
	displayMorph := morph.
	displayForm := form."
]
