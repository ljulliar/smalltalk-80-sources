"
The real hardware abstraction layer, but with a millisecond clock that the tests set, to test the timer without waiting and across the roll over of the clock.
"
Class {
	#name : 'InterpreterTestClockHAL',
	#superclass : 'ST80HardwareAbstractionLayer',
	#instVars : [
		'uptime'
	],
	#category : 'Smalltalk-80 VM-Tests',
	#package : 'Smalltalk-80 VM-Tests'
}

{ #category : 'time management' }
InterpreterTestClockHAL >> millisecondsUptime [

	^ uptime ifNil: [ 0 ]
]

{ #category : 'configuration' }
InterpreterTestClockHAL >> scheduledSemaphore [

	^ scheduledSemaphore
]

{ #category : 'configuration' }
InterpreterTestClockHAL >> uptime: milliseconds [

	uptime := milliseconds
]
