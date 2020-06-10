"
The Interpreter define and manage:
  - objects used by the interpreter (incl. predefined pointers and objects)
  - compiled methods, contexts and classes
"
Class {
	#name : #Interpreter,
	#superclass : #Object,
	#instVars : [
		'memory',
		'activeContext',
		'homeContext',
		'receiver',
		'method',
		'instructionPointer',
		'stackPointer',
		'messageSelector',
		'newMethod',
		'primitiveIndex',
		'argumentCount'
	],
	#classVars : [
		'BlockArgumentCountIndex',
		'CallerIndex',
		'CannotReturnSelector',
		'CharacterTablePointer',
		'ClassArrayPointer',
		'ClassBlockContextPointer',
		'ClassCharacterPointer',
		'ClassCompiledMethod',
		'ClassDisplayScreenPointer',
		'ClassFloatPointer',
		'ClassLargePositiveintegerPointer',
		'ClassMessagePointer',
		'ClassMethodContextPointer',
		'ClassPointPointer',
		'ClassSemaphorePointer',
		'ClassSmallInteger',
		'ClassStringPointer',
		'ClassSymbolPointer',
		'ClassUndefinedObject',
		'DoesNotUnderstandSelector',
		'FalsePointer',
		'HeaderIndex',
		'HomeIndex',
		'InitialIPIndex',
		'InstanceSpecificationIndex',
		'InstructionPointerIndex',
		'LiteralStart',
		'MessageArgumentsIndex',
		'MessageDictionaryIndex',
		'MessageSelectorIndex',
		'MessageSize',
		'MethodArrayIndex',
		'MethodIndex',
		'MinusOnePointer',
		'MustBeBooleanSelector',
		'NilPointer',
		'OnePointer',
		'ReceiverIndex',
		'SchedulerAssociationPointer',
		'SelectorStart',
		'SenderIndex',
		'SpecialSelectorsPointer',
		'StackPointerIndex',
		'SuperclassIndex',
		'TempFrameStart',
		'TruePointer',
		'TwoPointer',
		'ZeroPointer'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #'compiled method header access' }
Interpreter >> fieldIndexOf: methodPointer [
	"The following routine returns the index of the field representing the instance variable to be returned in the case that the flag value is 6."

	^ self extractBits: 3 to: 7 of: (self headerOf: methodPointer)
]

{ #category : #'compiled method header access' }
Interpreter >> flagValueOf: methodPointer [
	"The flag value is used to encode the number of arguments a CompiledMethod takes and whether or not it has an associated primitive routine.
flag value	meaning
0-4         no primitive and 0 to 4 arguments 
5           primitive return of self (0 arguments)
6           primitive return of an instance variable (0 arguments)
7           a header extension contains the number of arguments and a primitive index"

	^ self extractBits: 0 to: 2 of: (self headerOf: methodPointer)
]

{ #category : #'compiled method access' }
Interpreter >> headerOf: methodPointer [
	"get the header field of CompiledMethod data structure "
	^ memory fetchPointer: HeaderIndex ofObject: methodPointer
]

{ #category : #'compiled method header access' }
Interpreter >> initialInstructionPointerOfMethod: methodPointer [
	"Returns the byte index of the first bytecode of a CompiledMethod."

	^ ((self literalCountOf: methodPointer) + LiteralStart) * 2 + 1
]

{ #category : #initialization }
Interpreter >> initializeGuaranteedPointers [
	"Definition of Object pointers known to the interpreter. It comes from the Blue Book p 576
	 with errata from the original Xerox ST-80 Manual p 7"
	
	"UndefinedObject and Booleans"
	NilPointer   := 2.  "the object nil"
	FalsePointer := 4.  "the object false"
	TruePointer  := 6.  "the object true"
	"Root"
	SchedulerAssociationPointer := 8.
	"Classes"
	ClassSmallInteger  := 12.
	ClassStringPointer := 14.
	ClassArrayPointer  := 16.
	ClassFloatPointer  := 20.
	ClassMethodContextPointer := 22.
	ClassBlockContextPointer  := 24.
	ClassPointPointer := 26.
	ClassLargePositiveintegerPointer := 28.
	ClassMessagePointer   := 32.
	ClassCompiledMethod   := 34.
	ClassSemaphorePointer := 38.
	ClassCharacterPointer := 40.
	ClassSymbolPointer    := 56.
   ClassDisplayScreenPointer := 834.
   ClassUndefinedObject := 25728. 
	"Selectors"
	DoesNotUnderstandSelector := 42.
	CannotReturnSelector      := 44.
	MustBeBooleanSelector     := 52.
	"Tables"
	SpecialSelectorsPointer := 48.
	CharacterTablePointer   := 50

]

{ #category : #initialization }
Interpreter >> initializeSmallIntegers [
	"SmallIntegers definition"

	MinusOnePointer := 65535.
	ZeroPointer := 1.
	OnePointer  := 3.
	TwoPointer  := 5
]

{ #category : #'compiled method header access' }
Interpreter >> largeContextFlagOf: methodPointer [
	"The large context flag indicates which of two sizes of MethodContext are needed. The flag indicates whether the sum of the maximum stack depth and the number of temporary variables needed is greater than twelve. The smaller MethodContexts have room for 12 and the larger have room for 32."

	^ self extractBits: 8 to: 8 of: (self headerOf: methodPointer)
]

{ #category : #'compiled method access' }
Interpreter >> literal: offset ofMethod: methodPointer [
	"The literal frame contains pointers to objects referred to by the bytecodes. These include the selectors of messages that the method sends, and shared variables and constants to which the method refers."

	^ memory fetchPointer: offset + LiteralStart ofObject: methodPointer
]

{ #category : #'compiled method header access' }
Interpreter >> literalCountOf: methodPointer [
	"The literal count indicates the size of the CompiledMethod's literal frame. This, in turn, indicates where the CompiledMethod's bytecodes start."

	^ self literalCountOfHeader: (self headerOf: methodPointer)
]

{ #category : #'compiled method header access' }
Interpreter >> literalCountOfHeader: headerPointer [
	"Extract the literal count header from the Header field (bits 9 to 14)"

	^ self extractBits: 9 to: 14 of: headerPointer
]

{ #category : #'compiled method header access' }
Interpreter >> temporaryCountof: methodPointer [
   "Temporary count field is encoded in bit 3 to 7 of the Header field. The temporary count indicates the number of temporary variables used by the CompiledMethod. This includes the number of arguments."
	^ self extractBits: 3 to: 7 of: (self headerOf: methodPointer)
]
