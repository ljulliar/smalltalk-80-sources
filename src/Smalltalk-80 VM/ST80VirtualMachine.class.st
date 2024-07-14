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
		'displayWidth',
		'displayHeight',
		'vmImageFile',
		'vmSourcesFile',
		'vmChangesFile',
		'vmImagePath',
		'interpreter'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #initialization }
ST80VirtualMachine >> initialize [
   "Not BB code"
	"Initialize a new ST80 VM"
	
	| snapshot |
	"Initial Screen dimensions can be found
	 in the Xerox ST80 Virtual Image Booklet p. 3"
	displayWidth := 640.
	displayHeight := 480.
	vmImagePath := '/misc/applications/Smalltalk/ST80_Image/'.
	vmImageFile := vmImagePath, 'Smalltalk-80.image'.
	vmSourcesFile := vmImagePath, 'Smalltalk-80.sources'.
	vmChangesFile := vmImagePath, 'Smalltalk-80.changes'.
	
	"Open snapshot stream"
	snapshot := vmImageFile asFileReference binaryReadStream.
	interpreter := Interpreter withSnapshot: snapshot debug: true.
	
	"run the Smalltalk-80 VM loaded in memory"
	interpreter interpret.


]
