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
		'ValueIndex',
		'ZeroPointer'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #'compiled method header access' }
Interpreter >> argumentCountOf: methodPointer [
	"If the method header flag value is 7, the next to last literal is a header extension, 
	which is another SmallInteger. The header extension includes two bit fields that encode
	the argument count and primitive index of the CompiledMethod. This routine returns the
	argument count. (BB 580)"

	| flagValue |
	flagValue := self flagValueOf: methodPointer.
	flagValue < 5
		ifTrue: [ ^ flagValue ].
	flagValue < 7
		ifTrue: [ ^ 0 ]
		ifFalse: [ ^ self extractBits: 2 to: 6 of: (self headerExtensionOf: methodPointer) ]
]

{ #category : #contexts }
Interpreter >> argumentCountOfBlock: blockPointer [
	"A BlockContext stores the number of block arguments it expects in one of its fields. (BB 583)"

	^ self fetchInteger: BlockArgumentCountIndex ofObject: blockPointer
]

{ #category : #contexts }
Interpreter >> caller [
	"This routine fetch the caller field from contexts needed by the interpreter. Access is infrequent
enough that it is not cached in registers. The caller is the context to be returned to when a 
BlockContext returns a value (at the end of the block) (BB 586)."

	^ memory fetchPointer: SenderIndex ofObject: activeContext
]

{ #category : #classes }
Interpreter >> createActualMessage [
   "The interpreter needs to do something out of the ordinary when a message is sent to an object 
whose class and superclasses do not contain a CompiledMethod associated with the message selector. 
In keeping with the philosophy of Smalltalk, the interpreter sends a message. A CompiledMethod for 
this message is guaranteed to be found. The interpreter packages up the original message in an 
instance of class Message and then looks for a CompiledMethod associated with the selector 
doesNotUnderstand:. The Message becomes the single argument for the doesNotUnderstand: message. 
The doesNotUnderstand: message is defined in Object with a CompiledMethod that notifies the user. 
This CompiledMethod can be overridden in a user-defined class to do something else. 
Because of this, the lookupMethodInClass: routine will always complete by storing a pointer 
to a CompiledMethod in the newMethod register. (BB 589)"
| argumentArray message |
argumentArray := memory instantiateClass: ClassArrayPointer
withPointers: argumentCount.
message := memory instantiateClass: ClassMessagePointer
withPointers: MessageSize.
memory storePointer: MessageSelectorIndex
   ofObject: message
   withValue: messageSelector.
memory storePointer: MessageArgumentsIndex
   ofObject: message
   withValue: argumentArray.
self transfer: argumentCount
      fromIndex: stackPointer - (argumentCount - 1)
      ofObject: activeContext
      toIndex: 0
      ofObject: argumentArray.
self pop: argumentCount.
self push: message.
argumentCount := 1
]

{ #category : #'field access' }
Interpreter >> extractBits: firstBitIndex to: lastBitIndex of: anInteger [
	"Generic routine that extract a bit field from a integer value (BB 575)"

	^ (anInteger bitShift: lastBitIndex - 15)
		bitAnd: (2 raisedTo: lastBitIndex - firstBitIndex + 1) - 1
]

{ #category : #contexts }
Interpreter >> fetchContextRegisters [
"The context that represents the CompiledMethod or block currently being executed is called the active context. 
The interpreter caches in its registers the contents of the parts of the active context it uses most often. 
These Context-related Registers of the Interpreter are:
 
- activeContext	       This is the active context itself. It is either a MethodContext or a BlockContext. 
- homeContext	       If the active context is a MethodContext, the home context is the same context. If 
	                   the active context is a BlockContext, the home context is the contents of the home
	                   field of the active context. This will always be a MethodContext. 
- methodThis          is the CompiledMethod that contains the bytecodes the interpreter is executing. 
- receiver	          This is the object that received the message that invoked the home context's method. 
- instructionPointer  This is the byte index of the next bytecode of the method to be executed. 
- stackPointer        This is the index of the field of the active context containing the top of the stack.
    
Whenever the active context changes (when a new CompiledMethod is invoked, when a CompiledMethod returns
or when a process switch occurs), all of these registers must be updated using this routine.
(BB 583)"

(self isBlockContext: activeContext)
ifTrue: [homeContext := memory fetchPointer: HomeIndex
       ofObject: activeContext]
ifFalse: [homeContext := activeContext].
receiver := memory fetchPointer: ReceiverIndex ofObject: homeContext.
method := memory fetchPointer: MethodIndex
         ofObject: homeContext.
instructionPointer := (self instructionPointerOfContext: activeContext) - 1.
stackPointer := (self stackPointerOfContext: activeContext) + TempFrameStart - 1
]

{ #category : #'field access' }
Interpreter >> fetchInteger: fieldIndex ofObject: objectPointer [
	"Stores the pointer of the SmallInteger with specified value in the specified field. 
	The primitiveFail routine is implemented in the section on primitive routines (BB 574)"

	| integerPointer |
	integerPointer := memory	fetchPointer: fieldIndex	ofObject: objectPointer.
	(memory isIntegerObject: integerPointer)
		ifTrue: [ ^ memory integerValueOf: integerPointer ]
		ifFalse: [ ^ self primitiveFail ]
]

{ #category : #'compiled method header access' }
Interpreter >> fieldIndexOf: methodPointer [
	"The following routine returns the index of the field representing the instance 
	variable to be returned in the case that the flag value is 6. (BB 579)"

	^ self extractBits: 3 to: 7 of: (self headerOf: methodPointer)
]

{ #category : #instances }
Interpreter >> fixedFieldsOf: classPointer [
   "(BB 591)"
   ^ self extractBits: 4 to: 14
          of: (self instanceSpecificationOf: classPointer)
]

{ #category : #'compiled method header access' }
Interpreter >> flagValueOf: methodPointer [
	"The flag value is used to encode the number of arguments a CompiledMethod takes and whether or not it has an associated primitive routine.
flag value	meaning
0-4         no primitive and 0 to 4 arguments 
5           primitive return of self (0 arguments)
6           primitive return of an instance variable (0 arguments)
7           a header extension contains the number of arguments and a primitive index

(BB 578)"

	^ self extractBits: 0 to: 2 of: (self headerOf: methodPointer)
]

{ #category : #classes }
Interpreter >> hash: objectPointer [
	"The selectors are instances of Symbol, so they may be tested for equality by testing 
their object pointers for equality. Since the object pointers of Symbols determine equality, 
the hash function may be a function of the object pointer. Since object pointers are allocated 
quasirandomly, the object pointer itself is a reasonable hash function. The pointer shifted 
right one bit will produce a better hash function, since all object pointers other t
han SmallIntegers are even. (BB 587)"

	^ objectPointer bitShift: -1
]

{ #category : #'compiled method header access' }
Interpreter >> headerExtensionOf: methodPointer [
	"If the method header flag value is 7, the next to last literal is a header extension, 
	which is another SmallInteger. The header extension includes two bit fields that encode
	the argument count and primitive index of the CompiledMethod. (BB 580)"

	| literalCount |
	literalCount := self literalCountOf: methodPointer.
	^ self literal: literalCount - 2 ofMethod: methodPointer
]

{ #category : #'compiled method access' }
Interpreter >> headerOf: methodPointer [
	"Get the header field of CompiledMethod data structure (BB 577)"
	^ memory fetchPointer: HeaderIndex ofObject: methodPointer
]

{ #category : #'field access' }
Interpreter >> highByteOf: anInteger [
	"Extract high byte value from integer. (Note: the high-order bit with index 0 and 
	 the low-order bit with index 15) (BB 575)"

	^ self extractBits: 0 to: 7 of: anInteger
]

{ #category : #'compiled method header access' }
Interpreter >> initialInstructionPointerOfMethod: methodPointer [
	"Returns the byte index of the first bytecode of a CompiledMethod. (BB 578)"

	^ ((self literalCountOf: methodPointer) + LiteralStart) * 2 + 1
]

{ #category : #initialization }
Interpreter >> initialize [
   "Initialize the Interpreter data structures and variables"
   super initialize.
	memory := ObjectMemory new.
	self
		initializeSmallIntegers;
		initializeGuaranteedPointers;
		initializeMethodIndices;
		initializeContextIndices;
		initializeMessageIndices;
		initializeClassIndices;
		initializeAssociationIndex
]

{ #category : #initialization }
Interpreter >> initializeAssociationIndex [
   ValueIndex := 1
]

{ #category : #initialization }
Interpreter >> initializeClassIndices [
"The interpreter finds the appropriate CompiledMethod to execute in response to a message 
by searching a message dictionary. The message dictionary is found in the class of the message 
receiver or one of the superclasses of that class. The structure of a class and its associated 
message dictionary is shown in Figure 27.7 p 587 (BB 587)"

	"Class Class"
	SuperclassIndex := 0.
	MessageDictionaryIndex := 1.
	InstanceSpecificationIndex := 2.
	"Fields of a message dictionary"
	MethodArrayIndex := 1.
	SelectorStart := 2
]

{ #category : #initialization }
Interpreter >> initializeContextIndices [
	"A BlockContext represents a block encountered in a CompiledMethod. 
A BlockContext refers to the MethodContext whose CompiledMethod contained the block 
it represents. This is called the BlockContext's home. 
Figure 27.6 p 582 of the Blue Book shows a BlockContext and its home. The indices 
used to access the fields of contexts are initialized here. (BB 581)"

	"Class MethodContext"

	SenderIndex := 0.
	InstructionPointerIndex := 1.
	StackPointerIndex := 2.
	MethodIndex       := 3.
	ReceiverIndex     := 5.
	TempFrameStart    := 6.
	"Class BlockContext"
	CallerIndex := 0.
	BlockArgumentCountIndex := 3.
	InitialIPIndex := 4.
	HomeIndex := 5
]

{ #category : #initialization }
Interpreter >> initializeGuaranteedPointers [
	"Definition of Object pointers known to the interpreter. It comes from the Blue Book p 576
	 with errata from the original Xerox ST-80 Manual p 7 (BB 576)"
	
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
Interpreter >> initializeMessageIndices [
	"initializes the indices used to access fields of a Message (BB 590)"

	MessageSelectorIndex := 0.
	MessageArgumentsIndex := 1.
	MessageSize := 2
]

{ #category : #initialization }
Interpreter >> initializeMethodIndices [
	"Indices pointing to fields of the CompiledMethod data structure. Figure 27.5 p 581 
	of the Blue Book shows a MethodContext and its CompiledMethod (BB 577)"

	HeaderIndex := 0.
	LiteralStart := 1
]

{ #category : #initialization }
Interpreter >> initializeSmallIntegers [
	"SmallIntegers definition (BB 575)"

	MinusOnePointer := 65535.
	ZeroPointer := 1.
	OnePointer  := 3.
	TwoPointer  := 5
]

{ #category : #instances }
Interpreter >> instanceSpecificationOf: classPointer [
	"The instance specification field of a class contains a SmallInteger pointer that
 encodes the following four pieces of information:
  1. Whether the instances' fields contain object pointers or numerical values
  2. Whether the instances' fields are addressed in word or byte quantities
  3. Whether the instances have indexable fields beyond their fixed fields
  4. The number of fixed fields the instances have
Figure 27.8 p 590 of the BB shows how this information is encoded in the instance specification.

The four pieces of information are not independent. If the instances' fields contain object pointers,
they will be addressed in word quantities. If the instances' fields contain numerical values, 
they will have indexable fields and no fixed fields (BB 590)"

	^ memory fetchPointer: InstanceSpecificationIndex ofObject: classPointer
]

{ #category : #contexts }
Interpreter >> instructionPointerOfContext: contextPointer [
	"Get the instruction pointer field of the home of a Block Context 
	(see Fig.27.6 p 582 of the Blue Book) (BB 582)"

	^ self fetchInteger: InstructionPointerIndex ofObject: contextPointer
]

{ #category : #contexts }
Interpreter >> isBlockContext: contextPointer [
	"Note that the receiver and method are fetched from the homeContext and the instructionPointer and 
stackPointer are fetched from the activeContext. The interpreter tells the difference between MethodContexts
and BlockContexts based on the fact that MethodContexts store the method pointer (an object pointer) and
BlockContexts store the number of block arguments (an integer pointer) in the same field. If this location
contains an integer pointer, the context is a BlockContext; otherwise, it is a MethodContext. The distinction
could be made on the basis of the class of the context, but special provision would have to be made for 
subclasses of MethodContext and BlockContext. (BB 584)"

	| methodOrArguments |
	methodOrArguments := memory	fetchPointer: MethodIndex ofObject: contextPointer.
	^ memory isIntegerObject: methodOrArguments
]

{ #category : #instances }
Interpreter >> isIndexable: classPointer [
   "(BB 591)"
   | indexableFlag |
   indexableFlag := self extractBits: 2 to: 2
                         of: (self instanceSpecificationOf: classPointer).
   ^ indexableFlag = 1
]

{ #category : #instances }
Interpreter >> isPointers: classPointer [
   "(BB 591)"
	| pointersFlag |
	pointersFlag := self extractBits: 0 to: 0 of: (self instanceSpecificationOf: classPointer).
	^ pointersFlag = 1
]

{ #category : #instances }
Interpreter >> isWords: classPointer [
   "(BB 591)"
	| wordsFlag |
	wordsFlag := self	extractBits: 1	to: 1
		               of: (self instanceSpecificationOf: classPointer).
	^ wordsFlag = 1
]

{ #category : #'compiled method header access' }
Interpreter >> largeContextFlagOf: methodPointer [
	"The large context flag indicates which of two sizes of MethodContext are needed. The flag 
	indicates whether the sum of the maximum stack depth and the number of temporary variables 
	needed is greater than twelve. The smaller MethodContexts have room for 12 and the larger 
	have room for 32. (BB 578)"

	^ self extractBits: 8 to: 8 of: (self headerOf: methodPointer)
]

{ #category : #contexts }
Interpreter >> literal: offset [
	"This routine fetch the literals base field  from contexts needed by the interpreter. Access is infrequent
enough that it is not cached in registersThis routine provides convenient access to the literals of the
 currently executing CompiledMethod. (BB 586)"

	^ self literal: offset ofMethod: method
]

{ #category : #'compiled method access' }
Interpreter >> literal: offset ofMethod: methodPointer [
	"The literal frame contains pointers to objects referred to by the bytecodes. These 
	include the selectors of messages that the method sends, and shared variables and 
	constants to which the method refers. (BB 577)"

	^ memory fetchPointer: offset + LiteralStart ofObject: methodPointer
]

{ #category : #'compiled method header access' }
Interpreter >> literalCountOf: methodPointer [
	"The literal count indicates the size of the CompiledMethod's literal frame. This, in turn, 
	indicates where the CompiledMethod's bytecodes start. (BB 578)"

	^ self literalCountOfHeader: (self headerOf: methodPointer)
]

{ #category : #'compiled method header access' }
Interpreter >> literalCountOfHeader: headerPointer [
	"Extract the literal count header from the Header field (bits 9 to 14). (BB 578)"

	^ self extractBits: 9 to: 14 of: headerPointer
]

{ #category : #classes }
Interpreter >> lookupMethodInClass: class [
	"find the method a class associates with a selector. If the selector is not found in the
initial class's dictionary, it is looked up in the next class on the superclass chain. 
The search continues up the superclass chain until a method is found or the superclass 
chain is exhausted. (BB 589)"

	| currentClass dictionary |
	currentClass := class.
	[ currentClass ~= NilPointer ]	whileTrue: 
	   [ dictionary := memory fetchPointer: MessageDictionaryIndex ofObject: currentClass.
			(self lookupMethodInDictionary: dictionary)
				ifTrue: [ ^ true ].
			currentClass := self superclassOf: currentClass ].
	messageSelector = DoesNotUnderstandSelector
		ifTrue: [ self error: 'Recursive not understood error encountered' ].
	self createActualMessage.
	messageSelector := DoesNotUnderstandSelector.
	^ self lookupMethodInClass: class
]

{ #category : #classes }
Interpreter >> lookupMethodInDictionary: dictionary [
	"The interpreter uses several registers to cache the state of the message lookup process.

- messageSelector   This is the selector of the message being sent. It is always a Symbol. 
- argumentCount     This is the number of arguments in the message currently being sent. 
                    It indicates where the message receiver can be found on the stack since
                    it is below the arguments. 
- newMethod	        This is the method associated with the messageSelector. 
- primitiveIndex    This is the index of a primitive routine associated with newMethod if one exists.
(BB 588)"

	| length index mask wrapAround nextSelector methodArray |
	length := memory fetchWordLengthOf: dictionary.
	mask := length - SelectorStart - 1.
	index := (mask bitAnd: (self hash: messageSelector)) + SelectorStart.
	wrapAround := false.
	[ true ]	whileTrue: 
	   [ nextSelector := memory fetchPointer: index ofObject: dictionary.
			nextSelector = NilPointer ifTrue: [ ^ false ].
			nextSelector = messageSelector
				ifTrue: [ methodArray := memory fetchPointer: MethodArrayIndex ofObject: dictionary.
					       newMethod := memory fetchPointer: index - SelectorStart ofObject: methodArray.
					       primitiveIndex := self primitiveIndexOf: newMethod.
					       ^ true ].
			   index := index + 1.
			   index = length
				   ifTrue: [ wrapAround ifTrue: [ ^ false ].
					          wrapAround := true.
					          index := SelectorStart ] ]
]

{ #category : #'field access' }
Interpreter >> lowByteOf: anInteger [
	"Extract high byte value from integer. (Note: the high-order bit with index 0 
	 and the low-order bit with index 15) (BB 575)"

	^ self extractBits: 8 to: 15 of: anInteger
]

{ #category : #'compiled method header access' }
Interpreter >> methodClassOf: methodPointer [
   "Any CompiledMethod that sends a superclass message (i.e., a message to super) or 
    contains a header extension, will have as its last literal an Association whose 
    value is the class in whose message dictionary the CompiledMethod is found.
    This is called the method class and is accessed by the following routine. (BB 580)"
| literalCount association |
literalCount := self literalCountOf: methodPointer.
association := self literal: literalCount - 1
        ofMethod: methodPointer.
^memory fetchPointer: ValueIndex
    ofObject: association
]

{ #category : #contexts }
Interpreter >> newActiveContext: aContext [
	"The active context register must count as a reference to the part of the object memory that 
deallocates unreferenced objects. If the object memory maintains dynamic reference counts, 
the routine to change active contexts must perform the appropriate reference counting. (BB 585)"

	self storeContextRegisters.
	memory decreaseReferencesTo: activeContext.
	activeContext := aContext.
	memory increaseReferencesTo: activeContext.
	self fetchContextRegisters
]

{ #category : #'compiled method header access' }
Interpreter >> objectPointerCountOf: methodPointer [
	"The object pointer count indicates the total number of object pointers in a 
CompiledMethod, including the header and literal frame. (BB 578)"

	^ (self literalCountOf: methodPointer) + LiteralStart
]

{ #category : #contexts }
Interpreter >> pop: number [
	"Decrease stack pointer by number (BB 585)"

	stackPointer := stackPointer - number
]

{ #category : #contexts }
Interpreter >> popStack [
	"pop the first object from the stack of the active context (BB 585)"

	| stackTop |
	stackTop := memory fetchPointer: stackPointer ofObject: activeContext.
	stackPointer := stackPointer - 1.
	^ stackTop
]

{ #category : #'compiled method header access' }
Interpreter >> primitiveIndexOf: methodPointer [
	"If the method header flag value is 7, the next to last literal is a header extension, 
	which is another SmallInteger. The header extension includes two bit fields that encode 
	the argument count and primitive index of the CompiledMethod. This routine returns the 
	primitive index. (BB 580)"

	| flagValue |
	flagValue := self flagValueOf: methodPointer.
	flagValue = 7
		ifTrue: [ ^ self extractBits: 7 to: 14
				           of: (self headerExtensionOf: methodPointer) ]
		ifFalse: [ ^ 0 ]
]

{ #category : #contexts }
Interpreter >> push: object [
	"push an object on the stack of the active context (BB 585)"

	stackPointer := stackPointer + 1.
	memory
		storePointer: stackPointer
		ofObject: activeContext
		withValue: object
]

{ #category : #contexts }
Interpreter >> sender [
	"This routine fetch the sender field from contexts needed by the interpreter. Access is infrequent
enough that it is not cached in registers. The sender is the context to be returned to when 
a CompiledMethod returns a value (either because of a ""^"" or at the end of the method). Since an
 explicit return from within a block should return from the CompiledMethod enclosing the block,
 the sender is fetched from the home context. (BB 585)"

	^ memory fetchPointer: SenderIndex ofObject: homeContext
]

{ #category : #contexts }
Interpreter >> stackPointerOfContext: contextPointer [
	"Access the stack pointer field of the home of a Block Context (see Fig.27.6 p 582 of the Blue Book)
	(BB 582)"

	^ self fetchInteger: StackPointerIndex ofObject: contextPointer
]

{ #category : #contexts }
Interpreter >> stackTop [
	"Returns the value of the pointer at the top of the stack of the active context (BB 585)"

	^ memory fetchPointer: stackPointer ofObject: activeContext
]

{ #category : #contexts }
Interpreter >> stackValue: offset [
	"Returns the value of the pointer at the top of the stack minus the offset of the active context (BB 585)"

	^ memory fetchPointer: stackPointer - offset ofObject: activeContext
]

{ #category : #contexts }
Interpreter >> storeContextRegisters [
	"Before a new context becomes the active context, the values of the instruction pointer and 
	stack pointer must be stored into the active context with the following routine. (BB 584)"

	self
		storeInstructionPointerValue: instructionPointer + 1
		inContext: activeContext.
	self
		storeStackPointerValue: stackPointer - TempFrameStart + 1
		inContext: activeContext
]

{ #category : #contexts }
Interpreter >> storeInstructionPointerValue: value inContext: contextPointer [
   "Set the instruction pointer field of the home of a Block Context (see Fig.27.6 p 582 of the Blue Book)
    (BB 582)"
	self
		storeInteger: InstructionPointerIndex
		ofObject: contextPointer
		withValue: value
]

{ #category : #'field access' }
Interpreter >> storeInteger: fieldIndex ofObject: objectPointer withValue: integerValue [
	"stores the pointer of the SmallInteger with specified value in the specified field (BB 574)"

	| integerPointer |
	(memory isIntegerValue: integerValue)
		ifTrue: [ integerPointer := memory integerObjectOf: integerValue.
			memory
				storePointer: fieldIndex
				ofObject: objectPointer
				withValue: integerPointer ]
		ifFalse: [ ^ self primitiveFail ]
]

{ #category : #contexts }
Interpreter >> storeStackPointerValue: value inContext: contextPointer [
	"Set the stack pointer field of the home of a Block Context (see Fig.27.6 p 582 of the Blue Book)
	(BB 583)"

	self
		storeInteger: StackPointerIndex
		ofObject: contextPointer
		withValue: value
]

{ #category : #classes }
Interpreter >> superclassOf: classPointer [
	"get the value of the super class given a class pointer (BB 589)"

	^ memory fetchPointer: SuperclassIndex ofObject: classPointer
]

{ #category : #contexts }
Interpreter >> temporary: offset [
	"This routine fetch the temporaries base field  from contexts needed by the interpreter. Access is infrequent
enough that it is not cached in registers. Since temporaries referenced in a block are the 
same as those referenced in the CompiledMethod enclosing the block, the temporaries are fetched 
from the home context. (BB 586)"

	^ memory fetchPointer: offset + TempFrameStart ofObject: homeContext
]

{ #category : #'compiled method header access' }
Interpreter >> temporaryCountof: methodPointer [
   "Temporary count field is encoded in bit 3 to 7 of the Header field. The temporary 
    count indicates the number of temporary variables used by the CompiledMethod. 
    This includes the number of arguments. (BB 577)"
	^ self extractBits: 3 to: 7 of: (self headerOf: methodPointer)
]

{ #category : #'field access' }
Interpreter >> transfer: count fromIndex: firstFrom ofObject: fromOop toIndex: firstTo ofObject: toOop [
	"Transfers several pointers from one object to another. It takes the number of pointers
	to transfer, and the initial field index and object pointer of the source and destination
	 objects as arguments. (BB 574)"

	| fromIndex toIndex lastFrom oop |
	fromIndex := firstFrom.
	lastFrom := firstFrom + count.
	toIndex := firstTo.
	[ fromIndex < lastFrom ] whileTrue: 
      [ oop := memory fetchPointer: fromIndex ofObject: fromOop.
		  memory storePointer: toIndex ofObject: toOop withValue: oop.
		  memory storePointer: fromIndex ofObject: fromOop withValue: NilPointer.
		  fromIndex := fromIndex + 1.
		  toIndex := toIndex + 1 ]
]

{ #category : #contexts }
Interpreter >> unPop: number [
	"Increase stack pointer by number (BB 585)"

	stackPointer := stackPointer + number
]
