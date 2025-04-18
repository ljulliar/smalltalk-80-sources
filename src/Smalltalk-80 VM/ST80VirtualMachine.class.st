"
This class is to instantiate, intialize and run a Smalltalk-80 VM

Instance Variables
	displayHeight:		<Integer> 808 by default
	displayWidth:		<Intege>  606 by default
   vmImageFile:       <String>  path to the VM image 


Implementation Points
"
Class {
	#name : #ST80VirtualMachine,
	#superclass : #Object,
	#instVars : [
		'vmImageFile',
		'vmSourcesFile',
		'vmChangesFile',
		'vmImagePath',
		'vmClassOopsFile',
		'vmMethodOopsFile',
		'interpreter',
		'directory',
		'debug',
		'fs',
		'hal',
		'vmProcess',
		'keyboard'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #initialization }
ST80VirtualMachine class >> runWithImagePath: imagePath keyboard: keyboardLayout [
	"Launch the VM in a separate process"
	^ self basicNew initializeRunWithImagePath: imagePath keyboard: keyboardLayout; yourself.
]

{ #category : #accessing }
ST80VirtualMachine >> fs [

	^ fs
]

{ #category : #accessing }
ST80VirtualMachine >> hal [

	^ hal
]

{ #category : #initialization }
ST80VirtualMachine >> initializeRunWithImagePath: imagePath keyboard: keyboardLayout [
	
	"Fork the VM process at standard User priority"
	vmProcess := [ 
		[ self initializeWithImagePath: imagePath keyboard: keyboardLayout ] forkAt: Processor userSchedulingPriority ] 
		ensure: [ Logger flush ]
]

{ #category : #initialization }
ST80VirtualMachine >> initializeWithImagePath: imagePath keyboard: keyboardLayout [
   "Not BB code"
	"Initialize a new ST80 VM"
	
	| snapshot imagePathRef |
	
	debug := false.
	
	Smalltalk globals at: #Logger put: (ST80Logger withFile: '/tmp/st80_vm.log' asFileReference).
	Logger truncate.
	
	"Check image path and image file exist"
	"TODO: use snapshot.im first if it exists (image snapshot created
	by the ST-80 VM"
   (imagePathRef := imagePath asFileReference) exists
		ifFalse: [ 
			Transcript show: 'ERROR: Path to image folder incorrect. Exiting'; cr.
			self terminate 
		].
	
	" Replace the directory below with your own"
	vmImageFile := imagePathRef / 'Smalltalk-80.image'.
	vmSourcesFile := imagePathRef / 'Smalltalk-80.sources'.
	vmChangesFile := imagePathRef /  'Smalltalk-80.changes'.
	vmClassOopsFile := imagePathRef / 'class.oops'.
	vmMethodOopsFile := imagePathRef /  'method.oops'.
	
	"Open snapshot stream"
	hal := ST80HardwareAbstractionLayer withVM: self.
	fs := ST80FileSystem new.
	snapshot := vmImageFile asFileReference binaryReadStream.
	interpreter := Interpreter withSnapshot: snapshot 
						hal: hal fileSystem: fs
						debug: debug.
	
	"Check that keyboard layout exists"
	(hal supportedKeyboardLayouts includes: keyboardLayout)
		ifTrue: [ keyboard := keyboardLayout ]
		ifFalse: [ 
			keyboard := 'US'.
			Transcript show: '!! WARNING !!: Unsupported Keyboard layout: '; 
				nextPutAll: keyboardLayout printString; 
				nextPutAll: '. Defaulting to ''';
				nextPutAll: keyboard; nextPutAll:''''; cr.
			 ].
	
	"Load symbol tables if debug activated"
	debug ifTrue: [ 
		interpreter initializeMethodOopsWith: vmMethodOopsFile asFileReference readStream.
		interpreter initializeClassOopsWith: vmClassOopsFile asFileReference readStream.
		].
	
	"run the Smalltalk-80 VM loaded in memory"
	interpreter interpret.


]

{ #category : #accessing }
ST80VirtualMachine >> interpreter [

	^ interpreter
]

{ #category : #accessing }
ST80VirtualMachine >> keyboard [
	^keyboard 
]

{ #category : #'debugging actions' }
ST80VirtualMachine >> terminate [
	vmProcess terminate.
]
