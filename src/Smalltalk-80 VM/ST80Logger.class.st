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

	^ self on: aFileReference binaryWriteStream encoding: 'utf8'

]

{ #category : #accessing }
ST80Logger >> cr [
	"redefine cr to send lf so that it works on Linux"
	self lf.
]
