"
Proxy class to ST80 SmallIntegers (15 bit signed integers)
"
Class {
	#name : #ST80SmallInteger,
	#superclass : #ST80Object,
	#category : #'Smalltalk-80 VM'
}

{ #category : #accessing }
ST80SmallInteger class >> maxVal [
	^ 16383
]

{ #category : #accessing }
ST80SmallInteger class >> minVal [
	^ -16384
]
