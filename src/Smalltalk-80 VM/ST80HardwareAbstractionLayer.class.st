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
	#name : 'ST80HardwareAbstractionLayer',
	#superclass : 'Object',
	#instVars : [
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
		'cursorLink',
		'scheduledSemaphore',
		'blueEmulated',
		'scheduledTime',
		'pasteProcess',
		'wakeUpSemaphore'
	],
	#classVars : [
		'AbsoluteTime',
		'AlphaLockKey',
		'AltGrKeyMap',
		'BackspaceKey',
		'BlueButton',
		'ControlKey',
		'ConvertAssignmentOnPaste',
		'DeleteKey',
		'DeltaTime',
		'DeviceOff',
		'DeviceOn',
		'EscapeKey',
		'KeyMap',
		'LeftShiftKey',
		'LineFeedKey',
		'RedButton',
		'ReturnKey',
		'RightShiftKey',
		'SDLK_CAPSLOCK',
		'SDLK_DELETE',
		'SDLK_LALT',
		'SDLK_LCTRL',
		'SDLK_LGUI',
		'SDLK_LSHIFT',
		'SDLK_RALT',
		'SDLK_RCTRL',
		'SDLK_RGUI',
		'SDLK_RSHIFT',
		'ShiftKeyMap',
		'SpaceKey',
		'TabKey',
		'XLocation',
		'YLocation',
		'YellowButton'
	],
	#category : 'Smalltalk-80 VM',
	#package : 'Smalltalk-80 VM'
}

{ #category : 'clipboard' }
ST80HardwareAbstractionLayer class >> convertAssignmentOnPaste [
	"Not BB code. True (the default) if pasting text replaces the Pharo assignment := by the Smalltalk-80 one: _ "

	^ ConvertAssignmentOnPaste ifNil: [ true ]
]

{ #category : 'clipboard' }
ST80HardwareAbstractionLayer class >> convertAssignmentOnPaste: aBoolean [
	"Not BB code. Set to false to paste the text of the clipboard as it is. Can be changed at any time, even while a VM is running."

	ConvertAssignmentOnPaste := aBoolean
]

{ #category : 'class initialization' }
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
	
   "Bi-state devices parameters. ERROR in BB p. 650"
	RedButton    := 130.
	YellowButton := 129.
	BlueButton   := 128.

	"Morph keyboard 	events doesn't always provide the 
	proper ASCII code for some keys. Fix this with the 
	mapping below.
	TODO: Add your own keyboard layout below if needed"

	KeyMap := Dictionary newFrom: { 
	'FR' -> (0 to: 127) asArray.
	'FRmap' -> {
		$0 -> $a. $1 -> $&. $2 -> $e. $3 -> $".
		$4 -> $'. $5 -> $(. $6 -> $-. $7 -> $e.
	   $8 ->$_. $9 -> $c. } asDictionary.
	
	'US' ->(0 to: 127) asArray.
	'USmap' -> { } asDictionary.
	}.
	(KeyMap at: 'FRmap') keysAndValuesDo: [ :k :v | 
		KeyMap at: 'FR' at: (k asInteger + 1) put: v ].
	
	

	ShiftKeyMap := Dictionary newFrom: { 
	'FR' -> (0 to: 127) asArray.
	'FRmap' -> { 
		$a -> $A. $b -> $B. $c -> $C. $d -> $D.
		$e -> $E. $f -> $F. $g -> $G. $h -> $H.
		$i -> $I. $j -> $J. $k -> $K. $l -> $L.
		$m -> $M. $n -> $N. $o -> $O. $p -> $P.
		$q -> $Q. $r -> $R. $s -> $S. $t -> $T.
		$u -> $U. $v -> $V. $w -> $W. $x -> $X.
		$y -> $Y. $z -> $Z.
		$< -> $>. $, -> $?. $; -> $.. $: -> $/.
		$= -> $+.
		} asDictionary.
		
	'US' ->(0 to: 127) asArray.
	'USmap' -> { 
		$a -> $A. $b -> $B. $c -> $C. $d -> $D.
		$e -> $E. $f -> $F. $g -> $G. $h -> $H.
		$i -> $I. $j -> $J. $k -> $K. $l -> $L.
		$m -> $M. $n -> $N. $o -> $O. $p -> $P.
		$q -> $Q. $r -> $R. $s -> $S. $t -> $T.
		$u -> $U. $v -> $V. $w -> $W. $x -> $X.
		$y -> $Y. $z -> $Z.	
		$` -> $~. $1 -> $!. $2 -> $@. $3 -> $#.
		$4 -> $$. $5 -> $%. $6 -> $^. $7 -> $&.
		$8 -> $*. $9 -> $(. $0 -> $). $- -> $_.
		$= -> $+. $[ -> ${. $] -> $}. $; -> $:.
		$\ -> $|. $' -> $". $, -> $<. $. -> $>.
		$/ -> $?. } asDictionary.
	}.
	(ShiftKeyMap at: 'FRmap') keysAndValuesDo: [ :k :v | 
		ShiftKeyMap at: 'FR' at: (k asInteger + 1) put: v ].
	(ShiftKeyMap at: 'USmap') keysAndValuesDo: [ :k :v | 
		ShiftKeyMap at: 'US' at: (k asInteger + 1) put: v ].


	AltGrKeyMap := Dictionary newFrom: { 
	'FR' -> (0 to: 127) asArray.
	'US' ->(0 to: 127) asArray.
	'FRmap' -> { 
		$0 -> $@.	 $2 -> $~. $3 -> $#.
		$4 -> ${. $5 -> $[. $6 -> $|. $7 -> $`.
		$8 -> $\. $9 -> $^. $) -> $]. $= -> $}.
		} asDictionary.
	'USmap' -> { } asDictionary.
	}.
	(AltGrKeyMap at: 'FRmap') keysAndValuesDo: [ :k :v | 
		AltGrKeyMap at: 'FR' at: (k asInteger + 1) put: v ].
	(AltGrKeyMap at: 'USmap') keysAndValuesDo: [ :k :v | 
		AltGrKeyMap at: 'US' at: (k asInteger + 1) put: v ].

	"The SDL Constants used in the HAL.
	Note: those constants are already defined in 
	the SDL2Constants class but there is no accessor
	defined"
	SDLK_CAPSLOCK := 57.  "Caps Lock"
	SDLK_DELETE   := 127. "Delete"
	SDLK_LCTRL    := 224. "Left Control"
	SDLK_LSHIFT   := 225. "Left Shift"
	SDLK_LALT     := 226. "Left Alt"
	SDLK_LGUI     := 227. "Left Windows, Command (Apple), Meta (linux)..."
	SDLK_RCTRL    := 228. "Right Control"
	SDLK_RSHIFT   := 229. "Right Shift"
	SDLK_RALT     := 230. "Right Alt"
	SDLK_RGUI     := 231. "Right Windows, Command (Apple), Meta (linux)..."

]

{ #category : 'class initialization' }
ST80HardwareAbstractionLayer class >> withVM: aVm [
	^ self basicNew initializeWithVM: aVm; yourself
]

{ #category : 'clipboard' }
ST80HardwareAbstractionLayer >> asST80Characters: aString [
	"Not BB code. Convert the text of the host clipboard into the codes of the keys to
	type in the guest: an Array of integers. The guest only knows 7 bit ASCII, so:
	- CR, LF and CRLF, whatever the host, are one Return (13)
	- Tab (9) and the printable characters (32 to 126) are kept
	- a few typographic characters are replaced by their ASCII look alike
	- everything else (control characters, accents, symbols,..) is dropped
	- when ConvertAssignmentOnPaste is true (see #convertAssignmentOnPaste:),
	  the Pharo assignment := is replaced by the Smalltalk-80 one: _ (underscore).
	  Note that the replacement is blind: it also changes := inside a string literal."

	| text codes previous |
	text := aString ifNil: [ '' ] ifNotNil: [ :string | string asString ].
	self class convertAssignmentOnPaste ifTrue: [
		text := text copyReplaceAll: ':=' with: '_' ].
	codes := OrderedCollection new: text size.
	previous := nil.
	text do: [ :each |
			| code |
			code := each asInteger.
			(code = 10 and: [ previous = 13 ])
				ifTrue: [ "second half of a CRLF: the Return was already sent" ]
				ifFalse: [
					(self st80CodeFor: each) ifNotNil: [ :st80Code |
						codes add: st80Code ] ].
			previous := code ].
	^ codes asArray
]

{ #category : 'clipboard' }
ST80HardwareAbstractionLayer >> cancelPaste [
	"Not BB code. Stop the paste that is running, if any: the characters that were not typed yet are forgotten"

	pasteProcess ifNotNil: [ :process |
			pasteProcess := nil.
			process terminate ]
]

{ #category : 'time management' }
ST80HardwareAbstractionLayer >> checkScheduledSemaphore [
	"Not BB code. Signal the Semaphore of the outstanding request (see #signal:atMilliseconds:) when its time has passed, and forget it: it is signaled only once. Called regularly by the interpreter."

	| semaphore |
	scheduledSemaphore ifNil: [ ^ self ].
	(self hasMillisecondClockReached: scheduledTime) ifFalse: [ ^ self ].
	semaphore := scheduledSemaphore.
	scheduledSemaphore := nil.
	vm interpreter asynchronousSignal: semaphore
]

{ #category : 'accessing' }
ST80HardwareAbstractionLayer >> cursor [

	^ cursor
]

{ #category : 'cursor access' }
ST80HardwareAbstractionLayer >> cursor: aCursorOop memory: memory [
	"This message receives a pointer to a 16x16 Proxy ST80 Form
	to use as the current cursor on the display screen"
	
	cursor := ST80Cursor fromObject: aCursorOop memory: memory.
	self currentHand showTemporaryCursor: cursor. 
	^ true
]

{ #category : 'cursor access' }
ST80HardwareAbstractionLayer >> cursorLink: aBoolean [
	"TODO ? Keep track of the boolean flag but we
	are not using it for now"
	cursorLink := aBoolean.
]

{ #category : 'cursor access' }
ST80HardwareAbstractionLayer >> cursorLocation: aPoint [
	"Place the cursor at the location given (position is relative
	to the upperleft corner of the ST80 display. This message is
	used by Interpreter#primitiveCursorLocPut"
	Transcript show: 'cursorLoc: '; nextPutAll: aPoint printString; cr; flush.
   self currentWorld activeHand position: (displayMorph position + aPoint).
]

{ #category : 'display access' }
ST80HardwareAbstractionLayer >> displayWidth: width displayHeight: height [

	| newDisplayMorph			
											
											 |

	"If same dimensions as current display do nothing and return"
	(displayWidth = width and: displayHeight = height) ifTrue: [ ^ true ].
	
	displayWidth := width.
	displayHeight := height.
	
	"ST80 Screen display changed. Create a new Display Morph on host"
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
	
	"Give keyboard focus to app morph if mouse over it"
	displayMorph checkHandPosition.

	^ true.
	
	

]

{ #category : 'event handling' }
ST80HardwareAbstractionLayer >> handleKeyboardEvent: anEvent way: way [
	"Receives keyboard events from the Display morph and	 turns it into a 
	keyboard input event well formatted for the ST80 VM. Events received here 
	comes from Pharo in the form of an undecoded keyboard meaning that any 
	keyboard key is reported independently  incl the 'meta' keys
	(Ctrl, Shift, Alt..). 
	
	Per BB p. 650:
	An undecoded keyboard is made up of independent keys with independent down and up
	transitions. A decoded keyboard consists of some independent keys and
	some 'meta'' keys (shift and escape) that cannot be detected on their
	own, but that change the value of the other keys. 
	
	The keys on a decoded keyboard only indicate their down transition, not their 
	up transition. On an undecoded keyboard, the standard keys produce parameters 
	that are the ASCII code of the character on the keytop without
	shift or control information (i.e,, the key with 'A' on it produces the
	ASCII for 'a'' and the key with '2' and '@' on it produces the ASCII
	for '2'"

	"ljulliard: here we apply a mixed strategy when it comes to keyboard
	event handling:
	  - Modifier states and special keys (down and up) such as CTRL, Caps Lock,...
	     are passed to the ST80 VM as is or in other words undecoded
     - All other ASCII chars including those shifted are decoded and sent
       as immediate device on/off input events."

	| eventType keyValue parameter mappedChar |
	eventType := way = #down
		             ifTrue: [ DeviceOn ]
		             ifFalse: [ DeviceOff ].
	keyValue := anEvent keyValue.

	"Extract valid key scan code or value upfront. Ignore keystroke if
	not valid for the ST-80 VM"
	(parameter := self keyValueFrom: anEvent) ifNil: [ ^ self ]. "Ignore if not a valid key"
	"Transcript show: 'parameter'; nextPutAll:  parameter printString; cr."

	"Not BB code: while a paste is running (see #pasteText:) the guest must not
	think that Control is held, or the pasted characters would be taken for 
	control characters (ctrl-c is the user interrupt !). The Control key that 
	was used for the paste shortcut (and any repeat of it) is not passed on."
	(self isPasting and: [
		 parameter = ControlKey and: [ eventType = DeviceOn ] ]) ifTrue: [
		^ self ].

	parameter < 128
		ifTrue: [ "For regular ASCII value we only process key down events (or DeviceOn in
			ST-80 VM parlance) as we transmit	decoded key values to the ST-80 VM. Key
			up events (or DeviceOff) are simply ignored.""Special undecoded key with value > 127 : Caps Lock, Ctrl,...
		sent as is to the ST-80 VM which handles them directly""FIXME: the Caps Lock input events transmitted to the ST800 VM
		has no effect. The reason seems to be that on the original Alto
		keyboard when you press the Caps Lock key down it stays down
		and only a down input event is sent to the ST80 VM. Then when 
		you later click on the Caps Lock key again, it would release it and
		generate a single up event. On modern keyboard the Caps Lock 
		is like any other key that generates an down+up transition 
		at once therefore nullifying the effect of the key from the
		point of view of the ST80-VM "
				eventType = DeviceOn ifTrue: [ "Shifted and AltGr'ed keys are treated as decoded keys right here 
				either because they do not match the shifted keys of the original 
				Alto keyboard (e.g. Shift-6 is ~ on the Alto keyboard or because
				an improper key value is received from keyDown: Morph handler events"
						anEvent shiftPressed ifTrue: [
								mappedChar := ((ShiftKeyMap at: vm keyboard) at: keyValue + 1)
									              asInteger ].
						anEvent altKeyPressed ifTrue: [ "Note: at this level we cannot distinguish between ALT_L and ALT_R
					so treat both as if they were AltGr. Regular ALT didn't exist anyway
					on the original Alto keyboard.
					See https://www.flickr.com/photos/walkingsf/31415192416"
								mappedChar := ((AltGrKeyMap at: vm keyboard) at: keyValue + 1)
									              asInteger ].

						"If still nil then it is a regular key that was typed wwith no modifiers"
						mappedChar ifNil: [
							mappedChar := ((KeyMap at: vm keyboard) at: keyValue + 1)
								              asInteger ].

						"Transcript show: '>> keyboard down+up ';
					nextPutAll: ' param: ';
					nextPutAll: mappedChar printString; cr; flush."
						self inputKeyCode: mappedChar ] ]
		ifFalse: [ "Transcript show: '>> Undecoded keyboard event type: ';
				nextPutAll: eventType printString; 
				nextPutAll: ' param: ';
				nextPutAll: parameter printString; cr; flush."
			self inputWordType: eventType parameter: parameter ]
]

{ #category : 'event handling' }
ST80HardwareAbstractionLayer >> handleMouseEvent: anEvent way: way [
	"ERROR in BB p. 650 the parameter values for the left and right
	buuttons are actuelly the other way around. So here is the
	proper naming and parameter numbering for a mouse configured 
	for a right handed user:
	
		Usual naming   | Xerox naming   | ST80 Parameter | Pharo event
		---------------+----------------+----------------+-------------
		Left button    | Red button     |   130          | click
		Middle button  | Yellow button  |   129          | right click
		Third button   | Blue button    |   128          | cmd/alt/ctrl + click

	The blue button opens the window menu (under, move, frame, collapse, close)."

	| eventType |
	eventType := way = #down
		             ifTrue: [ DeviceOn ]
		             ifFalse: [ DeviceOff ].

	(self isBlueButtonEvent: anEvent way: way) ifTrue: [
			self inputTimeWord.
			self inputWordType: eventType parameter: BlueButton.
			^ self ].
	anEvent redButtonChanged ifTrue: [
			self inputTimeWord.
			self inputWordType: eventType parameter: RedButton.
			^ self ].
	anEvent yellowButtonChanged ifTrue: [
			self inputTimeWord.
			self inputWordType: eventType parameter: YellowButton.
			^ self ].
	Error new signal:
		'Unknown mouse button: ' , anEvent whichButton printString
]

{ #category : 'time management' }
ST80HardwareAbstractionLayer >> hasMillisecondClockReached: aTime [
	"Not BB code. The millisecond clock of the ST80 VM is a 32 bit unsigned number that rolls over (every 49 days): aTime, a value of that clock, is reached when it is at most 2^31 milliseconds behind the clock (the same rule as SDL_TICKS_PASSED in the C++ VM)."

	^ (self millisecondsUptime - aTime bitAnd: 16rFFFFFFFF) < 16r80000000
]

{ #category : 'idle' }
ST80HardwareAbstractionLayer >> idleFor: requestedMilliseconds [
	"Not BB code. Called by the interpreter when it takes the guest for idle (see Interpreter>>noteProcessSwitch): put the interpreter to sleep, so as not to burn a CPU for nothing, until the first of:
	- the time asked for, at most #maximumIdleMilliseconds
	- the time of the outstanding timer request (see #signal:atMilliseconds:)
	- an input word (see #inputWord:), which signals the wake up Semaphore.
	The old signals of the wake up Semaphore are dropped first, then the interpreter is looked at: an input word that comes in after that leaves a signal, so the wait ends at once and no word is missed. The timer is checked when the interpreter wakes up."

	| milliseconds |
	self wakeUpSemaphore consumeAllSignals.
	vm interpreter hasBufferedSignals ifFalse: [
			milliseconds := self idleMillisecondsFor: requestedMilliseconds.
			milliseconds > 0 ifTrue: [
				self wakeUpSemaphore waitTimeoutMilliseconds: milliseconds ] ].
	self checkScheduledSemaphore
]

{ #category : 'idle' }
ST80HardwareAbstractionLayer >> idleMillisecondsFor: requestedMilliseconds [
	"Not BB code. How long the interpreter may sleep when asking for requestedMilliseconds: at most that long (and #maximumIdleMilliseconds), and not past the time of the outstanding timer request (see #signal:atMilliseconds:), whose Semaphore the guest waits for. 0 when that time has passed."

	| milliseconds |
	milliseconds := (requestedMilliseconds max: 0) min:
		                self maximumIdleMilliseconds.
	scheduledSemaphore ifNil: [ ^ milliseconds ].
	(self hasMillisecondClockReached: scheduledTime) ifTrue: [ ^ 0 ].
	^ milliseconds min:
		  (scheduledTime - self millisecondsUptime bitAnd: 16rFFFFFFFF)
]

{ #category : 'initialization' }
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

	"I/O Device (keyboard, mouse, location,...) 
	Input event queue"
	inputQueue := OrderedCollection new.

	"Set the initial mouse position to the upper left corner
	as we are sure that this position exists whatever the size 
	of the ST780 display is"
	mousePosition := 0 @ 0.

	"Initialize last input event time to zero"
	lastEventTime := 0.

	"Outstanding timer request (see #signal:atMilliseconds:): the guest 
	Semaphore to signal, and the millisecond clock time to signal it at.
	None to start with"
	scheduledSemaphore := nil.
	scheduledTime := 0
]

{ #category : 'event handling' }
ST80HardwareAbstractionLayer >> inputKeyCode: aCode [
	"Not BB code. Type a key of a decoded keyboard in the guest: the code is the
	one of the character (see BB p. 650), sent as a time word followed by the 
	immediate down and up transitions of the key. Used for the keys typed on the 
	host keyboard and for the characters pasted from the host clipboard."

	self inputTimeWord.
	self inputWordType: DeviceOn parameter: aCode.
	self inputWordType: DeviceOff parameter: aCode
]

{ #category : 'event handling' }
ST80HardwareAbstractionLayer >> inputSemaphore [
	^ inputSemaphore
]

{ #category : 'event handling' }
ST80HardwareAbstractionLayer >> inputSemaphore: aSemaphore [
	"keep track of the semaphore to signal when input events occur. nil stops the signalling (BB p. 648)"

	inputSemaphore := aSemaphore
]

{ #category : 'event handling' }
ST80HardwareAbstractionLayer >> inputTimeWord [
  "As per BB p. 649:
   A type 0 word will be used if the number of milliseconds since the last
   event can be represented in 12 bits. Otherwise, a type 5 event is used 
   followed by two words representing the absolute time. 
   Absolute time is a 32-bit unsigned number that is the absolute value of
   the millisecond clock) "

	| now elapsedTime |
	now := Time millisecondClockValue.
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

{ #category : 'event handling' }
ST80HardwareAbstractionLayer >> inputWord: aValue [
	"Push a 16 bit value in the input event queue
	and signal the input semaphore. BB p. 648.
	Not BB code: with no input semaphore (not set yet, or reset to nil by 
	the guest) nobody listens: the word is dropped, as the C++ VM does.
	An interpreter that sleeps because the guest is idle (see #idleFor:) is woken up."

	self assert: (aValue between: 0 and: 16rFFFF).
	inputSemaphore ifNil: [ ^ self ].
	inputQueue add: aValue.
	vm interpreter asynchronousSignal: inputSemaphore.
	self wakeUpSemaphore signal
]

{ #category : 'event handling' }
ST80HardwareAbstractionLayer >> inputWordType: anEventType parameter: aParameter [
	"For a description of the format for input event words see
	BB p. 649"
	
	"Make sure type and parameter values are correct"
	self assert: (aParameter between: 0 and: 4095).
	self assert: (anEventType between: 0 and: 5).
	self inputWord: (anEventType << 12) | (aParameter & 16rFFF).
]

{ #category : 'event handling' }
ST80HardwareAbstractionLayer >> isBlueButtonEvent: anEvent way: way [
	"Not BB code. Hosts rarely have three buttons, so the blue button is also 
	emulated by clicking the primary button while holding Command, Alt or Control.
	The modifier may be released before the button, so the button released is
	the one that was pressed."

	anEvent blueButtonChanged ifTrue: [ ^ true ].
	anEvent redButtonChanged ifFalse: [ ^ false ].
	way = #down ifFalse: [ ^ blueEmulated ifNil: [ false ] ].
	blueEmulated := anEvent commandKeyPressed or: [
		                anEvent altKeyPressed or: [
			                anEvent controlKeyPressed ] ].
	^ blueEmulated
]

{ #category : 'event handling' }
ST80HardwareAbstractionLayer >> isInputEventDriven [
	"If set to False, the ST80 interpreter will poll the mouse 
	position at every cycle which is very time consuming and 
	unnecessary as the event	driven approach works well in this HAL"
	^ true
]

{ #category : 'clipboard' }
ST80HardwareAbstractionLayer >> isPasting [
	"Not BB code. True while the characters of a paste are being typed in the guest (see #pasteText:)"

	^ pasteProcess isNotNil
]

{ #category : 'event handling' }
ST80HardwareAbstractionLayer >> keyValueFrom: anEvent [
	"Map native key scan code to valid values for ST80 keyboard 
	input parameters"
	
	| kv |
	anEvent scanCode = SDLK_DELETE ifTrue: [ ^ DeleteKey ].
	anEvent scanCode = SDLK_CAPSLOCK ifTrue: [ ^ AlphaLockKey ].
	
	"Note: ST80 doesn't differentiate Control left from Control right"
	anEvent scanCode = SDLK_LCTRL ifTrue: [ ^ ControlKey ].
	anEvent scanCode = SDLK_RCTRL ifTrue: [ ^ ControlKey ].
	
	"Note: Shift modifier is processed at the Pharo level. Not sent to ST-80 VM"
	anEvent scanCode = SDLK_LSHIFT ifTrue: [ ^ nil ].
	anEvent scanCode = SDLK_RSHIFT ifTrue: [ ^ nil ].
	
	"Note: ALT modifier is processed at the Pharo level. Not sent to ST-80 VM"
	anEvent scanCode = SDLK_LALT  ifTrue: [ ^ nil ].
	anEvent scanCode = SDLK_RALT  ifTrue: [ ^ nil ].

	((kv := anEvent keyValue) between: 1 and: 127) ifTrue: [ ^ kv ] ifFalse: [ ^nil ].
	
	"Should not be reached but just in case..."
	^ nil
]

{ #category : 'idle' }
ST80HardwareAbstractionLayer >> maximumIdleMilliseconds [
	"Not BB code. The longest the interpreter sleeps in one go, whatever it asks for"

	^ 1000
]

{ #category : 'time management' }
ST80HardwareAbstractionLayer >> millisecondsUptime [
	"number of ticks of the millisecond clock (since it 
	last was reset or rolled over)"
	^ Time millisecondClockValue.
]

{ #category : 'event handling' }
ST80HardwareAbstractionLayer >> mouseMove: position [
	"Process the mouse move events received from the host Smalltalk
	environment and feed it into the ST80 input events queue.
	According to BB p. 649 We only have to send time word once for any 
	number of type 1 and 2 events that follows"
	
	"When the mouse moves the end point of the move is using float for x and y
	position. Convert them to integer as expected by the ST80 source code"
	mousePosition := position asIntegerPoint.
	self inputTimeWord.
	self inputWordType: 1 parameter: mousePosition x.
	self inputWordType: 2 parameter: mousePosition y.
]

{ #category : 'cursor access' }
ST80HardwareAbstractionLayer >> mousePosition [
	"returns the current mouse position"
	Transcript show: 'MousePt: '; nextPutAll: mousePosition printString; 
	nextPutAll: Time now printString; cr; flush.
	^ mousePosition
	"^ displayMorph cursorPoint"
]

{ #category : 'event handling' }
ST80HardwareAbstractionLayer >> nextInputWord [
	"Pick the next 16 bit word event from the event queue"
	inputQueue isEmpty 
		ifTrue: [ ^ nil ]
		ifFalse: [ ^ inputQueue removeFirst ]

]

{ #category : 'clipboard' }
ST80HardwareAbstractionLayer >> pasteBatchSize [
	"Not BB code. Number of characters typed in the guest at once when pasting. Each one makes about 
	3 input words (a time word and 2 key transitions) and each word signals the input semaphore, 
	while the interpreter buffers 4096 signals: 64 characters is about 200 signals."

	^ 64
]

{ #category : 'clipboard' }
ST80HardwareAbstractionLayer >> pasteCodes: anArray [
	"Not BB code. Type the keys of anArray (see #asST80Characters:) in the guest, #pasteBatchSize at 
	a time. Between two batches wait for the guest to read the input events (see 
	#waitForGuestToReadInput). Give up if it does not: the guest is not running."

	| start |
	start := 1.
	[ start <= anArray size ] whileTrue: [
			| stop |
			stop := start + self pasteBatchSize - 1 min: anArray size.
			start to: stop do: [ :index |
			self inputKeyCode: (anArray at: index) ].
			self waitForGuestToReadInput ifFalse: [ ^ self ].
			start := stop + 1 ]
]

{ #category : 'clipboard' }
ST80HardwareAbstractionLayer >> pasteText: aString [
	"Not BB code. Type the text of the host clipboard in the guest, as if it was typed on the keyboard, 
	where the cursor of the guest is. Called by the display morph for the paste shortcut (Ctrl-V, 
	Cmd-V), which is not sent to the guest: only the characters are (see #asST80Characters:).
	- The guest is told that Control is released: the user holds it for the shortcut, and the guest
	  would take every pasted character for a control character (ctrl-c is its user interrupt).
	  The Control key is not passed on while the paste runs (see #handleKeyboardEvent:way:).
	- The characters are fed by a process, a few at a time (see #pasteCodes:), so that a long text 
	  does not overflow the buffer of semaphores of the interpreter. A new paste replaces the 
	  one that is still running.
	- Nothing is done when the guest does not listen to the input events (no input semaphore)."

	| codes |
	inputSemaphore ifNil: [ ^ self ].
	codes := self asST80Characters: aString.
	codes ifEmpty: [ ^ self ].
	self cancelPaste.
	self inputWordType: DeviceOff parameter: ControlKey.
	pasteProcess := [
	                [ self pasteCodes: codes ] ensure: [
		                pasteProcess := nil ] ] forkAt:
		                Processor userSchedulingPriority
]

{ #category : 'protocol' }
ST80HardwareAbstractionLayer >> quit [
	"message sent by primitiveQuit"
	window close.
	vm terminate.
]

{ #category : 'accessing' }
ST80HardwareAbstractionLayer >> sampleInterval: anInterval [
	"For now we accept the intrnval value from primitiveSampleInterval 
	but we actually don't do anything with it"
	
	Transcript show: 'Sample Interval: '; nextPutAll: anInterval printString ; cr; flush.
	sampleInterval := anInterval.
]

{ #category : 'time management' }
ST80HardwareAbstractionLayer >> secondsSinceSmalltalkEpoch [
	"number of seconds since the midnight previous to 
	January 1, 1901"
	^ Time totalSeconds.
]

{ #category : 'time management' }
ST80HardwareAbstractionLayer >> signal: aST80Semaphore atMilliseconds: time [
	"This is called by the ST80 primitiveSignalAtTick primitive.
	From BB p 652: If a new call is made on it before the last timer
	value has been reached the lastSemaphore will not be signaled.
	If the first argument is not a Semaphore (nil here) any currently
	waiting Semaphore is forgotten: the request is cancelled.
	If the time has already passed, the Semaphore is signaled immediately.

	Not BB code, following the same design as the C++ VM from dbanay: there 
	is only one outstanding request, kept as a Semaphore and a time, that a new 
	request replaces. The interpreter polls it (see #checkScheduledSemaphore), 
	so no host process is needed and a cancelled request can never reach the 
	interpreter semaphore buffer.
	The time is a 32 bit unsigned number, as stored by primitiveTickWordsInto."

	scheduledSemaphore := aST80Semaphore.
	scheduledTime := time.
	aST80Semaphore ifNotNil: [ self checkScheduledSemaphore ]
]

{ #category : 'clipboard' }
ST80HardwareAbstractionLayer >> st80CodeFor: aCharacter [
	"Not BB code. The code of the key that types aCharacter in the guest, or nil if the guest can not type it (see #asST80Characters:)"

	| code |
	code := aCharacter asInteger.
	(#( 10 13 ) includes: code) ifTrue: [ ^ ReturnKey ].
	code = 9 ifTrue: [ ^ TabKey ].
	(code between: 32 and: 126) ifTrue: [ ^ code ].
	"Typographic look alikes"
	(#( 16r2018 16r2019 16r2032 ) includes: code) ifTrue: [ ^ 39 ].
	(#( 16r201C 16r201D ) includes: code) ifTrue: [ ^ 34 ].
	(code between: 16r2010 and: 16r2015) ifTrue: [ ^ 45 ].
	code = 16r2212 ifTrue: [ ^ 45 ].
	(#( 16rA0 16r2007 16r202F ) includes: code) ifTrue: [ ^ SpaceKey ].
	^ nil
]

{ #category : 'settings' }
ST80HardwareAbstractionLayer >> supportedKeyboardLayouts [
	^ (KeyMap  keys) select: [ :eachKey |
			"Check if the key is a String AND its size is 2"
			(eachKey isString) and: [ eachKey size = 2 ]
		].
]

{ #category : 'display access' }
ST80HardwareAbstractionLayer >> updateDisplayRect: rectangle fromForm: sourceForm [
	"Not BB code"
	"Create a native bitBlt operation to update the dirty rectangle
	on the display screen."
		
	| bitBlt nativeSourceForm align16Rectangle |

	"Guard: the ST80 system shrinks the display bitmap height to 100 before
	writing a snapshot (to reduce image size). Any display update at that
	point would access the bitmap at a row index beyond the shrunken height,
	causing an out-of-bounds assertion in fetchWord:ofObject:. Skip the update —
	the display will be restored to full size after the snapshot is written.
	(Mirrors dbanay's 'if (height <= 100) return' guard in updateDisplay())"
	sourceForm height <= 100 ifTrue: [ ^ self ].

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

{ #category : 'accessing' }
ST80HardwareAbstractionLayer >> vm [
	"Return the ST80VirtualMachine instance that owns this HAL.
	Used by the Interpreter to reach host-side VM operations such as saveSnapshot."
	^ vm
]

{ #category : 'clipboard' }
ST80HardwareAbstractionLayer >> waitForGuestToReadInput [
	"Not BB code. Wait until the guest has read all the input words queued so far. Answer false if it
	did not after 5 seconds (the guest does not run, or has stopped listening): the paste is given up."

	| deadline |
	deadline := Time millisecondClockValue + 5000.
	[ inputQueue isEmpty ] whileFalse: [
			inputSemaphore ifNil: [ ^ false ].
			Time millisecondClockValue > deadline ifTrue: [ ^ false ].
			(Delay forMilliseconds: 5) wait ].
	^ true
]

{ #category : 'idle' }
ST80HardwareAbstractionLayer >> wakeUpSemaphore [
	"Not BB code. Signaled when something happens that the sleeping interpreter must see (an input word, see #inputWord:)"

	^ wakeUpSemaphore ifNil: [ wakeUpSemaphore := Semaphore new ]
]
