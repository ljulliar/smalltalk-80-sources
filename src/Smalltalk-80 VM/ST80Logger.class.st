"
Basic Logger class to write debug message in a file
"
Class {
	#name : #ST80Logger,
	#superclass : #ZnCharacterWriteStream,
	#category : #'Smalltalk-80 VM'
}

{ #category : #initialization }
ST80Logger class >> withFile: aFileReference [
	"^ self basicNew
		initializeWithFile: aFileReference;
		yourself"
	^ self on: aFileReference binaryWriteStream encoding: 'utf8'
		
	"binaryWriteStream"
	"Answer a buffered binary write stream on the receiver"

	"^ ZnBufferedWriteStream on: (filesystem binaryWriteStreamOn: self path)"
]

{ #category : #accessing }
ST80Logger >> cr [
	"redefine cr to send lf so that it works on Linux"
	self lf.
]
