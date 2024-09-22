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
		'inputQueue',
		'sampleInterval',
		'vm',
		'mousePosition',
		'lastEventTime',
		'cursorLink'
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

{ #category : #'class initialization' }
ST80HardwareAbstractionLayer class >> withVM: aVm [
	^ self basicNew initializeWithVM: aVm; yourself
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

{ #category : #'cursor access' }
ST80HardwareAbstractionLayer >> cursorLink: aBoolean [
	"TODO ? Keep track of the boolean flag but we
	are not using it for now"
	cursorLink := aBoolean.
]

{ #category : #'as yet unclassified' }
ST80HardwareAbstractionLayer >> cursorLocation: aPoint [
	"Place the cursor at the location given (position is relative
	to the upperleft corner of the ST80 display. This message is
	used by Interpreter#primitiveCursorLocPut"
   self currentWorld activeHand position: (displayMorph position + aPoint).
]

{ #category : #'display access' }
ST80HardwareAbstractionLayer >> displayWidth: width displayHeight: height [

	| newDisplayMorph |

	"If same dimensions as current display do nothing and return"
	(displayWidth = width and: displayHeight = height) ifTrue: [ ^ true ].
	
	displayWidth := width.
	displayHeight := height.
	
	"ST80 Screen display chenged. Create a new Display Morph on host"
	newDisplayMorph := ST80DisplayMorph extent: displayWidth@displayHeight vm: vm.
	
	window
		ifNotNil: [ 
			"Replace existing display morph in app  window with 
			the new one"
			window removeMorph: displayMorph.
			window addMorph: newDisplayMorph frame: (0@0 corner: 1@1).
			window extent: displayWidth@displayHeight.
			]
		ifNil: [ 
			"First time display is set, so create the host app window"
			window := newDisplayMorph openInWindowLabeled: 'Smalltalk-80'.
		 ].
	displayMorph := newDisplayMorph.
	displayForm := displayMorph displayForm.
	
	^ true.
	
	

]

{ #category : #initialization }
ST80HardwareAbstractionLayer >> initializeWithVM: aVm [

	"Make sure to initialize class variables"
	self class initialize.
	
	vm := aVm.
	
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
	
	"Set the initial mouse position to the upper left corner
	as we are sure that this position exists whatever the size 
	of the ST780 display is"
	mousePosition := 0@0.
	
	"Initialize last input event time to now"
	lastEventTime := Time millisecondClockValue.
	
]

{ #category : #'event handling' }
ST80HardwareAbstractionLayer >> inputSemaphore: aSemaphore [
	"keep track of the semaphore to signal when input events occur"
	self assert: aSemaphore notNil.
	inputSemaphore := aSemaphore.
	

]

{ #category : #'as yet unclassified' }
ST80HardwareAbstractionLayer >> inputTimeWord [
  "As per BB p. 649:
   A type 0 word will be used if the number of milliseconds since the last
   event can be represented in 12 bits. Otherwise, a type 5 event is used 
   followed by two words representing the absolute time. 
   Absolute time is a 32-bit unsigned number that is the absolute value of
   the millisecond clock) "

	| now elapsedTime |
	now := Time  millisecondClockValue.
	elapsedTime := now - lastEventTime.
	
	(elapsedTime <= 4095)
		ifTrue: [ self inputWordType: 0 parameter: elapsedTime ]
		ifFalse: [ 
			self inputWordType: 5 parameter: 0.
			self inputWord: (now >> 16). "High bytes first"
			self inputWord: (now & 16rFFFF). "Low bytes second"
			].
		
	lastEventTime := now.
	
]

{ #category : #'as yet unclassified' }
ST80HardwareAbstractionLayer >> inputWord: aValue [
	"Push a 16 bit value in the input event queue
	and signal the input semaphore. BB p. 648"
	self assert: (aValue between: 0 and: 16rFFFF).
	inputQueue add: aValue.
	vm interpreter asynchronousSignal: inputSemaphore.

	
]

{ #category : #'as yet unclassified' }
ST80HardwareAbstractionLayer >> inputWordType: anEventType parameter: aParameter [
	"For a description of the format for input event words see
	BB p. 649"
	
	"Make sure type and parameter fit in their respective bit field"
	self assert: (aParameter between: 0 and: 4095).
	self assert: (anEventType between: 0 and: 5).
	self inputWord: (anEventType << 12) | (aParameter & 16rFFF).
]

{ #category : #'as yet unclassified' }
ST80HardwareAbstractionLayer >> millisecondsUptime [
	"number of ticks of the millisecond clock (since it 
	last was reset or rolled over)"
	^ Time millisecondClockValue.
]

{ #category : #'event handling' }
ST80HardwareAbstractionLayer >> mouseMove: position [
	"Process the mouse move events received from the host Smalltalk
	environment and feed it into the ST80 input events queue.
	According to BB p. 649 We only have to send time word once for any 
	number of type 1 and 2 events that follows"
	
	"When the mouse mocves the end point is using float for x and y
	position. Convert them to integer"
	mousePosition := position asIntegerPoint.
	self inputTimeWord.
	self inputWordType: 1 parameter: mousePosition x.
	self inputWordType: 2 parameter: mousePosition y.
]

{ #category : #'cursor access' }
ST80HardwareAbstractionLayer >> mousePosition [
	"returns the current mouse position"
	^ mousePosition
	"^ displayMorph cursorPoint"
]

{ #category : #'event handling' }
ST80HardwareAbstractionLayer >> mouseUpST80Morph: event [
	"One of the mouse buttons was clicked down"

	Transcript show: 'Mouse up'; cr.
]

{ #category : #'event handling' }
ST80HardwareAbstractionLayer >> nextInputWord [
	"Pick the next 16 bit word event from the event queue"
	inputQueue isEmpty 
		ifTrue: [ ^ nil ]
		ifFalse: [ ^ inputQueue removeFirst ]

]

{ #category : #accessing }
ST80HardwareAbstractionLayer >> sampleInterval: anInterval [
	"For now we accept the intrnval value from primitiveSampleInterval 
	but we actually don't do anything with it"
	sampleInterval := anInterval.
]

{ #category : #'time management' }
ST80HardwareAbstractionLayer >> secondsSinceSmalltalkEpoch [
	"number of seconds since the midnight previous to 
	January 1, 1901"
	^ Time totalSeconds.
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
