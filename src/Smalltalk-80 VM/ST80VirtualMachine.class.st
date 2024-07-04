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
		'objectMemory'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #actions }
ST80VirtualMachine >> init [
	"load the VirtualMachine image file in memory"

]

{ #category : #initialization }
ST80VirtualMachine >> initialize [
	"Initialize a new ST80 VM"

	"Initial Screen dimensions can be found
	 in the Xerox ST80 Virtual Image Booklet p. 3"
	displayWidth := 640.
	displayHeight := 480.
	vmImagePath := '/misc/applications/Smalltalk/ST80_Image/'.
	vmImageFile := vmImagePath, 'Smalltalk-80.image'.
	vmSourcesFile := vmImagePath, 'Smalltalk-80.sources'.
	vmChangesFile := vmImagePath, 'Smalltalk-80.changes'.
	
	objectMemory := ObjectMemory new.
   self load; run

]

{ #category : #actions }
ST80VirtualMachine >> load [
	"load the VM files
	 IMPORTANT NOTE : the loaded image file are assumed to follow 
	 the LSB format. The original image file from the Xerox Parc ST80 tape
	 follows the MSB format and must reformated before it can be used here"

   | objectSpaceLength objectTableLength vmImageFormat|
	"Load the image file and extract "
	vmImageFile asFileReference binaryReadStreamDo: [ :stream |
		
		"See Xerox Virtual Image Booklet p. 2 for details on VM image file format"
		"First 4 bytes is the Object Space length - 32 bit integer
		 and the next 4 bytes are the Object Table Length"
		 objectSpaceLength := (stream next) + (stream next bitShift: 8) + (stream next bitShift: 16) + (stream next bitShift: 24).
	    objectTableLength := (stream next) + (stream next bitShift: 8) + (stream next bitShift: 16) + (stream next bitShift: 24).
	
		"Read the next 2 byte word and make sure it is 0 (VM Interchange format)"
		vmImageFormat := (stream next) + (stream next bitShift: 8).
		(vmImageFormat = 0) ifFalse: [ Exception signal: 'VM Image is not Interchange format' ].
	
		"Now skip to position 513 where Object space starts"
		stream position: 512.
		
		 ]
	
	"Populate the VM memory"
]

{ #category : #running }
ST80VirtualMachine >> run [
	"run a Smalltalk-80 VM"

	
]
