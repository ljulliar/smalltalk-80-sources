"
Proxy class that should simulate the original Sensor class used in the Blue
Book (e.g. mouse and keyboard events ...) but for now it only implements
the notify: method to preserve the original code of the cantBelntegerObject:
method of the ObjectMemory class. The mouse and keyboard events are currently
managed in the HAL class.
"
Class {
	#name : 'ST80Sensor',
	#superclass : 'Object',
	#category : 'Smalltalk-80 VM',
	#package : 'Smalltalk-80 VM'
}

{ #category : 'error handling' }
ST80Sensor class >> notify: aMessage [ 
	"Bridge low-level ST-80 VM notify calls to the host Pharo environment"

	Warning signal: aMessage
]
