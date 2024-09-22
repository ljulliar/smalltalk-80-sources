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
		'vmProcess'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #running }
ST80VirtualMachine class >> run [
	"Launch the VM in a separate process"
	^ self basicNew initializeRun; yourself.
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
ST80VirtualMachine >> initialize [
   "Not BB code"
	"Initialize a new ST80 VM"
	
	| snapshot |
	
	debug := false.
	
	Smalltalk globals at: #Logger put: (ST80Logger withFile: '/tmp/st80ljulliard.log' asFileReference).
	Logger truncate.

	vmImagePath := '/misc/applications/Smalltalk/ST80_Image/'.
	vmImageFile := vmImagePath, 'Smalltalk-80.image'.
	vmSourcesFile := vmImagePath, 'Smalltalk-80.sources'.
	vmChangesFile := vmImagePath, 'Smalltalk-80.changes'.
	vmClassOopsFile := vmImagePath, 'class.oops'.
	vmMethodOopsFile := vmImagePath, 'method.oops'.
	
	"Open snapshot stream"
	hal := ST80HardwareAbstractionLayer withVM: self.
	fs := ST80FileSystem new.
	snapshot := vmImageFile asFileReference binaryReadStream.
	interpreter := Interpreter withSnapshot: snapshot 
						hal: hal fileSystem: fs
						debug: debug.
	
	"Load symbol tables if debug activated"
	debug ifTrue: [ 
		interpreter initializeMethodOopsWith: vmMethodOopsFile asFileReference readStream.
		interpreter initializeClassOopsWith: vmClassOopsFile asFileReference readStream.
		].
	
	"run the Smalltalk-80 VM loaded in memory"
	interpreter interpret.


]

{ #category : #initialization }
ST80VirtualMachine >> initializeRun [
	
	"Fork the VM process at a standard User priority"
	vmProcess := [ 
		[ self initialize  ] forkAt: Processor userSchedulingPriority ] 
		ensure: [  Logger flush ]
]

{ #category : #accessing }
ST80VirtualMachine >> interpreter [

	^ interpreter
]

{ #category : #'debugging actions' }
ST80VirtualMachine >> terminate [
	vmProcess terminate.
]
