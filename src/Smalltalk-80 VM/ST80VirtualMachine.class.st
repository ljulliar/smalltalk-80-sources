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
		'debug'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #initialization }
ST80VirtualMachine >> initialize [
   "Not BB code"
	"Initialize a new ST80 VM"
	
	| snapshot |
	
	debug := true.
	
	Smalltalk globals at: #Logger put: ('/tmp/st80ljulliard.log' asFileReference writeStream).
	Logger truncate.

	vmImagePath := '/misc/applications/Smalltalk/ST80_Image/'.
	vmImageFile := vmImagePath, 'Smalltalk-80.image'.
	vmSourcesFile := vmImagePath, 'Smalltalk-80.sources'.
	vmChangesFile := vmImagePath, 'Smalltalk-80.changes'.
	vmClassOopsFile := vmImagePath, 'class.oops'.
	vmMethodOopsFile := vmImagePath, 'method.oops'.
	
	"Open snapshot stream"
	snapshot := vmImageFile asFileReference binaryReadStream.
	interpreter := Interpreter withSnapshot: snapshot 
						hal: ST80HardwareAbstractionLayer new
						fileSystem: ST80FIleSystem new
						debug: debug.
	
	"Load symbol tables if debug activated"
	debug ifTrue: [ 
		interpreter initializeMethodOopsWith: vmMethodOopsFile asFileReference readStream.
		interpreter initializeClassOopsWith: vmClassOopsFile asFileReference readStream.
		].
	
	"run the Smalltalk-80 VM loaded in memory"
	interpreter interpret.


]
