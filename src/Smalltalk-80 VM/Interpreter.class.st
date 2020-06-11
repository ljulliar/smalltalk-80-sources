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
		'argumentCount',
		'currentBytecode',
		'methodCache',
		'methodCacheSize'
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
	#classInstVars : [
		'memory'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #'send bytecodes' }
Interpreter >> activateNewMethod [
   "The routine that activates a method creates a MethodContext and transfers the 
    receiver and arguments from the currently active context's stack to the new 
    context's stack, It then makes this new context be the interpreter's active 
    context. (BB 606)"

   | contextSize newContext |
   (self largeContextFlagOf: newMethod) = 1
      ifTrue: [contextSize := 32 + TempFrameStart]
      ifFalse: [contextSize := 12 + TempFrameStart].
   newContext := memory instantiateClass: ClassMethodContextPointer
                        withPointers: contextSize.
   memory storePointer: SenderIndex
          ofObject: newContext
          withValue: activeContext.
   self storeInstructionPointerValue: (self initialInstructionPointerOfMethod: newMethod)
        inContext: newContext.
   self storeStackPointerValue: (self temporaryCountof: newMethod)
        inContext: newContext.
   memory storePointer: MethodIndex
          ofObject: newContext
          withValue: newMethod.
   self transfer: argumentCount + 1
        fromIndex: stackPointer - argumentCount
        ofObject: activeContext
        toIndex: ReceiverIndex
        ofObject: newContext.
   self pop: argumentCount + 1.
   self newActiveContext: newContext

]

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

{ #category : #'main loop' }
Interpreter >> cycle [
	"Since process switches are only allowed between bytecodes, the first action in
   the interpreter's main loop is to call a routine that switches processes if necessary. 
   The checkProcessSwitch routine will be described with the process scheduling primitive
   routines in the next chapter. After checking for a process switch, a bytecode is fetched
   (perhaps from a new process), and a dispatch is made to the appropriate routine. (BB 594)"

	self checkProcessSwitch.
	currentBytecode := self fetchByte.
	self dispatchOnThisBytecode
]

{ #category : #dispatch }
Interpreter >> dispatchOnThisBytecode [
   "Not all of the bytecodes of one type are contiguous, so the main dispatch has
    seven branches each of which calls one of four routines (stackBytecode, jumpBytecode,
    sendBytecode, or returnBytecode) (BB 595)"
   (currentBytecode between: 0 and: 119)   ifTrue: [^self stackBytecode].
   (currentBytecode between: 120 and: 127) ifTrue: [^self returnBytecode].
   (currentBytecode between: 128 and: 130) ifTrue: [^self stackBytecode].
   (currentBytecode between: 131 and: 134) ifTrue: [^self sendBytecode].
   (currentBytecode between: 135 and: 137) ifTrue: [^self stackBytecode].
   (currentBytecode between: 144 and: 175) ifTrue: [^self jumpBytecode].
   (currentBytecode between: 176 and: 255) ifTrue: [^self sendBytecode]
]

{ #category : #'send bytecodes' }
Interpreter >> doubleExtendedSendBytecode [
   "The second form of extended send bytecode is followed by two bytes; the 
    first is the number of arguments and the second is the index of the selector 
    in the literal frame. (BB 607)"

   | count selector |
   count := self fetchByte.
   selector := self literal: self fetchByte.
   self sendSelector: selector
        argumentCount: count
]

{ #category : #'send bytecodes' }
Interpreter >> doubleExtendedSuperBytecode [
	"When the compiler encounters a message to super in a symbolic method, 
    it uses the bytecode that pushes self for the receiver, but it uses an 
    extended-super bytecode to indicate the selector instead of a regular 
    send bytecode. The two extended-super bytecodes are similar to the two 
    extended-send bytecodes. The first is followed by a single byte and the 
    second by two bytes that are interpreted exactly as for the extended-send 
    bytecodes. The only difference in what these bytecodes do is that they 
    start the message lookup in the superclass of the class in which the 
    current CompiledMethod was found. (BB 607)"

	| methodClass |
	argumentCount := self fetchByte.
	messageSelector := self literal: self fetchByte.
	methodClass := self methodClassOf: method.
	self sendSelectorToClass: (self superclassOf: methodClass)
]

{ #category : #'stack bytecodes' }
Interpreter >> duplicateTopBytecode [
	"The duplicateTopBytecode routine pushes another copy of the object pointer
    on the top of the stack. (BB 599)"

	^ self push: self stackTop
]

{ #category : #'send bytecodes' }
Interpreter >> executeNewMethod [
   "The executeNewMethod routine calls a primitive routine if one is associated
   with the CompiledMethod. The primitiveResponse routine returns false if no 
   primitive is indicated or the primitive routine is unable to produce a 
   result. In that case, the CompiledMethod is activated. (BB 605)"

   self primitiveResponse
      ifFalse: [self activateNewMethod]
]

{ #category : #'stack bytecodes' }
Interpreter >> extendedPushBytecode [
   "The extended push bytecode can perform any of the four operations on receiver variable,
   temporary frame location, literal constant, or literal variable). However, instead of a 
   limit of 16 or 32 variables accessible, it can access up to 64 instance variables, temporary
   locations, literal constants, or literal variables. The extended push bytecode is followed
   by a byte whose high order two bits determine which type of push is being done and whose
   low order six bits determine the offset to use. (BB 599)"
	| descriptor variableType variableIndex |
	descriptor := self fetchByte.
	variableType := self extractBits: 8 to: 9 of: descriptor.
	variableIndex := self extractBits: 10 to: 15 of: descriptor.
	variableType = 0 ifTrue: [ ^ self pushReceiverVariable: variableIndex ].
	variableType = 1 ifTrue: [ ^ self pushTemporaryVariable: variableIndex ].
	variableType = 2 ifTrue: [ ^ self pushLiteralConstant: variableIndex ].
	variableType = 3 ifTrue: [ ^ self pushLiteralVariable: variableIndex ]
]

{ #category : #dispatch }
Interpreter >> extendedSendBytecode [
   "There are four extended-send bytecodes. The first two have the same effect
   as the literal-selector bytecodes except that the selector index and argument
   count are found in one or two following bytes instead of in the bytecode 
   itself. The other two extended-send bytecodes are used for superclass messages.
   (BB 606)"

   currentBytecode = 131 ifTrue: [^self singleExtendedSendBytecode].
   currentBytecode = 132 ifTrue: [^self doubleExtendedSendBytecode].
   currentBytecode = 133 ifTrue: [^self singleExtendedSuperBytecode].
   currentBytecode = 134 ifTrue: [^self doubleExtendedSuperBytecode]
]

{ #category : #'stack bytecodes' }
Interpreter >> extendedStoreAndPopBytecode [
	"Stores into variables other than those accessible by the single byte versions 
   are accomplished by two extended store bytecodes. Also pop the stack (BB 600)"

	self extendedStoreBytecode.
	self popStackBytecode
]

{ #category : #'stack bytecodes' }
Interpreter >> extendedStoreBytecode [
	"Stores into variables other than those accessible by the single byte versions 
   are accomplished by two extended store bytecodes. (BB 600)"

	| descriptor variableType variableIndex association |
	descriptor := self fetchByte.
	variableType := self extractBits: 8 to: 9 of: descriptor.
	variableIndex := self extractBits: 10 to: 15 of: descriptor.
	variableType = 0 ifTrue: 
	   [ ^ memory storePointer: variableIndex
			        ofObject: receiver
				     withValue: self stackTop ].
	variableType = 1 ifTrue: 
	   [ ^ memory storePointer: variableIndex + TempFrameStart
				     ofObject: homeContext
				     withValue: self stackTop ].
	variableType = 2 ifTrue: 
	   [ ^ self error: 'illegal store' ].
	variableType = 3 ifTrue: 
	   [ association := self literal: variableIndex.
			^ memory storePointer: ValueIndex
			         ofObject: association
				      withValue: self stackTop ]

]

{ #category : #'field access' }
Interpreter >> extractBits: firstBitIndex to: lastBitIndex of: anInteger [
	"Generic routine that extract a bit field from a integer value (BB 575)"

	^ (anInteger bitShift: lastBitIndex - 15)
		bitAnd: (2 raisedTo: lastBitIndex - firstBitIndex + 1) - 1
]

{ #category : #'main loop' }
Interpreter >> fetchByte [
	"Fetches the byte indicated by the active context's instruction pointer and 
    increments the instruction pointer. (BB 594)"

	| byte |
	byte := memory fetchByte: instructionPointer ofObject: method.
	instructionPointer := instructionPointer + 1.
	^ byte
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

{ #category : #'send bytecodes' }
Interpreter >> findNewMethodInClass: class [
	"The interpreter uses a method cache to reduce the number of dictionary
   lookups necessary to find CompiledMethods associated with selectors. The 
   method cache may be omitted by substituting a call on lookupMethodInClass: 
   for the call on findNewMethodInClass: in sendSelectorToClass:. 
   The cache may be implemented in various ways. The following routine uses 
   four sequential locations in an Array for each entry. The four locations 
   store the selector, class, CompiledMethod, and primitive index for the entry. 
   This routine does not allow for reprobes. (BB 605)"

	| hash |
	hash := (((messageSelector bitAnd: class) bitAnd: 16rFF) bitShift: 2) + 1.
	((methodCache at: hash) = messageSelector
		   and: [ (methodCache at: hash + 1) = class ])
		ifTrue: [ newMethod := methodCache at: hash + 2.
			primitiveIndex := methodCache at: hash + 3 ]
		ifFalse: [ self lookupMethodInClass: class.
			methodCache at: hash put: messageSelector.
			methodCache at: hash + 1 put: class.
			methodCache at: hash + 2 put: newMethod.
			methodCache at: hash + 3 put: primitiveIndex ]

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
		initializeAssociationIndex;
		initializeMethodCache 
]

{ #category : #initialization }
Interpreter >> initializeAssociationIndex [
	"Associations are objects with two fields, one for a name and one for a value. 
 They are used to implement shared variables (global variables, class variables, 
 and pool variables). This routine initializes the index used to fetch 
 the value field of Associations. (BB 599)"

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
Interpreter >> initializeMethodCache [
   "Initialize the method cache (BB 605)"

   methodCacheSize := 1024.
   methodCache := Array new: methodCacheSize
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

{ #category : #'main loop' }
Interpreter >> interpret [
	"Never ending interpreter loop (BB 594)"

	[ true ] whileTrue: [ self cycle ]
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

{ #category : #'stack bytecodes' }
Interpreter >> jump: offset [
   "The jump bytecodes use the jump: routine to actually change the bytecode index. (BB 602)"

   instructionPointer := instructionPointer + offset
]

{ #category : #'stack bytecodes' }
Interpreter >> jumpBytecode [
   "The jump bytecodes change the active context's instruction pointer by a specified
   amount. Unconditional jumps change the instruction pointer whenever they are encountered. 
   Conditional jumps only change the instruction pointer if the object pointer on the top 
   of the stack is a specified Boolean object (either true or false). Both unconditional
   and conditional jumps have a short (single-byte) and a long (two-byte) form. (BB 601)"

(currentBytecode between: 144 and: 151)
   ifTrue: [^self shortUnconditionalJump].
(currentBytecode between: 152 and: 159)
   ifTrue: [^self shortConditionalJump].
(currentBytecode between: 160 and: 167)
   ifTrue: [^self longUnconditionalJump].
(currentBytecode between: 168 and: 175)
   ifTrue: [^self longConditionalJump]
]

{ #category : #'stack bytecodes' }
Interpreter >> jumpIf: condition by: offset [
   "The conditional jumps use this routine to test the top of the stack and
   decide whether to perform the jump. The top of stack is discarded after it is 
   tested. (BB 602)"

   | boolean |
   boolean := self popStack.
   boolean = condition
     ifTrue: [self jump: offset]
     ifFalse: [(boolean = TruePointer) | (boolean = FalsePointer)
                ifFalse: [self unPop: 1.
                          self sendMustBeBoolean]]
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

{ #category : #'stack bytecodes' }
Interpreter >> longConditionalJump [
	"Half of the long conditional jumps perform the jump if the top of the stack is false while the other half perform the jump if it is true. The low order two bits of the bytecode become the high order two bits of a 10-bit unsigned displacement. The byte following the jump provides the low order eight bits of the displacement. So long conditional jumps can jump up to 1023 forward. (BB 603)"

	| offset |
	offset := self extractBits: 14 to: 15 
	               of: currentBytecode.
	offset := offset * 256 + self fetchByte.
	(currentBytecode between: 168 and: 171)
		ifTrue: [ ^ self jumpIf: TruePointer 
			              by: offset ].
	(currentBytecode between: 172 and: 176)
		ifTrue: [ ^ self jumpIf: FalsePointer 
			              by: offset ]
]

{ #category : #'stack bytecodes' }
Interpreter >> longUnconditionalJump [
   "The eight long unconditional jumps are followed by another byte. The low order three 
   bits of the jump bytecode provide the high order three bits of an 11-bit twos complement
   displacement to be added to the instruction pointer. The byte following the jump
   provides the low order eight bits of the displacement. So long unconditional jumps 
   can jump up to 1023 forward and 1024 back. (BB 602)"

| offset |
offset := self extractBits: 13 to: 15
of: currentBytecode.
self jump: offset - 4 * 256 + self fetchByte
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

{ #category : #'return bytecodes' }
Interpreter >> nilContextFields [
   "Nilify context fields"

   memory storePointer: SenderIndex
          ofObject: activeContext
          withValue: NilPointer.
   memory storePointer: InstructionPointerIndex
          ofObject: activeContext
          withValue: NilPointer
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

{ #category : #'stack bytecodes' }
Interpreter >> popStackBytecode [
   "Removes the top object pointer from the stack without doing anything else with it (BB 601)"
   self popStack
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

{ #category : #'stack bytecodes' }
Interpreter >> pushActiveContextBytecode [
	"Push a pointer to the active context itself. This corresponds to the use 
   of thisContext in a Smalltalk method. (BB 600)"

	^ self push: activeContext
]

{ #category : #'stack bytecodes' }
Interpreter >> pushConstantBytecode [
   "The pushConstantBytecode routine pushes one of seven constant object 
   pointers (true, false, nil, -1, 0, 1, or 2). (BB 600)"

   currentBytecode = 113 ifTrue: [^self push: TruePointer].
   currentBytecode = 114 ifTrue: [^self push: FalsePointer].
   currentBytecode = 115 ifTrue: [^self push: NilPointer].
   currentBytecode = 116 ifTrue: [^self push: MinusOnePointer].
   currentBytecode = 117 ifTrue: [^self push: ZeroPointer].
   currentBytecode = 118 ifTrue: [^self push: OnePointer].
   currentBytecode = 119 ifTrue: [^self push: TwoPointer]
]

{ #category : #'stack bytecodes' }
Interpreter >> pushLiteralConstant: literalIndex [
	"Push temporary variable at temporary index on stack (BB 598)"

	self push: (self literal: literalIndex)
]

{ #category : #'stack bytecodes' }
Interpreter >> pushLiteralConstantBytecode [
	"Push Litteral constant from bytecode on stack (BB 598)"

	| fieldIndex |
	fieldIndex := self extractBits: 11 to: 15 of: currentBytecode.
	self pushLiteralConstant: fieldIndex
]

{ #category : #'stack bytecodes' }
Interpreter >> pushLiteralVariable: literalIndex [
	"Push literal variable at literal index on stack (BB 599)"

	| association |
	association := self literal: literalIndex.
	self push: (memory fetchPointer: ValueIndex ofObject: association)
]

{ #category : #'stack bytecodes' }
Interpreter >> pushLiteralVariableBytecode [
	"Push Litteral variable from bytecode on stack (BB 598)"

	| fieldIndex |
	fieldIndex := self extractBits: 11 to: 15 of: currentBytecode.
	self pushLiteralVariable: fieldIndex
]

{ #category : #'stack bytecodes' }
Interpreter >> pushReceiverBytecode [
	"This routine pushes a pointer to the active context's receiver. 
   This corresponds to the use of self or super in a Smalltalk method. (BB 599)"

	^ self push: receiver
]

{ #category : #'stack bytecodes' }
Interpreter >> pushReceiverVariable: fieldIndex [
   "Push receiver variable at field index on stack (BB 598)"

  self push: (memory fetchPointer: fieldIndex
                     ofObject: receiver)
]

{ #category : #'stack bytecodes' }
Interpreter >> pushReceiverVariableBytecode [
   "Push receiver variable from bytecode on stack (BB 598)"

   | fieldIndex |
   fieldIndex := self extractBits: 12 to: 15
                      of: currentBytecode.
   self pushReceiverVariable: fieldIndex
]

{ #category : #'stack bytecodes' }
Interpreter >> pushTemporaryVariable: temporaryIndex [
   "Push temporary variable at temporary index on stack (BB 598)"

   self push: (self temporary: temporaryIndex)
]

{ #category : #'stack bytecodes' }
Interpreter >> pushTemporaryVariableBytecode [
	"Push temporary variable from bytecode on stack (BB 598)"

	| fieldIndex |
	fieldIndex := self extractBits: 12 to: 15 of: currentBytecode.
	self pushTemporaryVariable: fieldIndex
]

{ #category : #'return bytecodes' }
Interpreter >> returnBytecode [
	"There are six bytecodes that return control and a value from a context; 
   five return the value of a message (invoked explicitly by ""^"" or implicitly 
   at the end of a method) and the other one returns the value of a block 
   (invoked implicitly at the end of a block). The distinction between the 
   two types of return is that the former returns to the sender of the home 
   context while the latter returns to the caller of the active context. The
   values returned from the five return bytecodes are: the receiver (self), 
   true, false, nil, or the top of the stack. The last return bytecode returns
   the top of the stack as the value of a block. (BB 608)"

	currentBytecode = 120
		ifTrue: [ ^ self returnValue: receiver to: self sender ].
	currentBytecode = 121
		ifTrue: [ ^ self returnValue: TruePointer to: self sender ].
	currentBytecode = 122
		ifTrue: [ ^ self returnValue: FalsePointer to: self sender ].
	currentBytecode = 123
		ifTrue: [ ^ self returnValue: NilPointer to: self sender ].
	currentBytecode = 124
		ifTrue: [ ^ self returnValue: self popStack to: self sender ].
	currentBytecode = 125
		ifTrue: [ ^ self returnValue: self popStack to: self caller ]
]

{ #category : #'return bytecodes' }
Interpreter >> returnToActiveContext: aContext [
   "This routine prevents the deallocation of the result being returned by 
   raising the reference count until it is pushed on the new stack. It could 
   also have pushed the result before switching active contexts. The 
   returnToActiveContext: routine is basically the same as the newActiveContext: 
   routine except that instead of restoring any cached fields of the context 
   being returned from, it stores nil into the sender and instruction 
   pointer fields. (BB 610)"

   memory increaseReferencesTo: aContext.
   self nilContextFields.
   memory decreaseReferencesTo: activeContext.
   activeContext := aContext.
   self fetchContextRegisters
]

{ #category : #'return bytecodes' }
Interpreter >> returnValue: resultPointer to: contextPointer [
	"There are three situations in which the simple return routine is too 
   simple to work correctly:
   1. If the sender of the active context were nil; this routine would store 
      a nil in the interpreter's active context pointer, bringing the system 
      to an unpleasant halt. In order to prevent this, the actual returnValue:to: 
      routine first checks to see if the sender is nil. 
   2. The interpreter also prevents returns to a context that has already been 
      returned from. It does this by storing nil in the instruction pointer of the
      active context on return and checking for a nil instruction pointer of the 
      context being returned to. Both of these situations can arise since contexts
      are objects and can be manipulated by user programs as well as by the 
      interpreter. If either situation arises, the interpreter sends a message 
      to the active context informing it of the problem.
   3. The third situation will arise in systems that automatically deallocate 
      objects based on their reference counts. The active context may be deallocated 
      as it is returning. It, in turn, may contain the only reference to the 
      result being returned. In this case, the result will be deallocated before 
      it can be pushed on the new context's stack. Because of these considerations, 
      the returnValue: routine must be somewhat more complicated.
   (BB 609)"

	| sendersIP |
	contextPointer = NilPointer
		ifTrue: [ self push: activeContext.
			self push: resultPointer.
			^ self sendSelector: CannotReturnSelector argumentCount: 1 ].
	sendersIP := memory fetchPointer: InstructionPointerIndex
	                    ofObject: contextPointer.
	sendersIP = NilPointer
		ifTrue: [ self push: activeContext.
			self push: resultPointer.
			^ self sendSelector: CannotReturnSelector argumentCount: 1 ].
	memory increaseReferencesTo: resultPointer.
	self returnToActiveContext: contextPointer.
	self push: resultPointer.
	memory decreaseReferencesTo: resultPointer
]

{ #category : #'send bytecodes' }
Interpreter >> sendBytecode [
   "The send bytecodes cause a message to be sent. The object pointers for 
   the receiver and the arguments of the message are found on the active 
   context's evaluation stack. The send bytecode determines the selector 
   of the message and how many arguments to take from the stack. The number 
   of arguments is also indicated in the CompiledMethod invoked by the message. (BB 604)"

(currentBytecode between: 131 and: 134)
   ifTrue: [^self extendedSendBytecode].
(currentBytecode between: 176 and: 207)
   ifTrue: [^self sendSpecialSelectorBytecode].
(currentBytecode between: 208 and: 255)
   ifTrue: [^self sendLiteralSelectorBytecode]
]

{ #category : #'send bytecodes' }
Interpreter >> sendLiteralSelectorBytecode [
	"The literal-selector bytecodes are single bytes that can specify 0, 1, 
    or 2 arguments and a selector in any one of the first 16 locations of 
    the literal frame. Both the selector index and the argument count are 
    encoded in the bits of the bytecode. (BB 604)"

	| selector |
	selector := self literal: (self extractBits: 12 to: 15 
	                                of: currentBytecode).
	self sendSelector: selector
		  argumentCount: (self extractBits: 10 to: 11 
		                       of: currentBytecode) - 1
]

{ #category : #'stack bytecodes' }
Interpreter >> sendMustBeBoolean [
   "The conditional jumps are used in the compiled form of messages to booleans (e.g., ifTrue: 
   and whileFalse:). If the top of the stack at the time of a conditional jump is not true or
   false it is an error since an object other than a boolean has been sent a message that
   only booleans understand. Instead of sending doesNotUnderstand:, the interpreter sends
   mustBeBoolean to it. (BB 603)"

   self sendSelector: MustBeBooleanSelector
        argumentCount: 0
]

{ #category : #'send bytecodes' }
Interpreter >> sendSelector: selector argumentCount: count [
   "Most of the send bytecodes call the sendSelector:argumentCount: routine
    after determining the appropriate selector and argument count. This 
    routine sets up the variables messageSelector and argumentCount, which 
    are available to the other routines in the interpreter that will lookup 
    the message and perhaps activate a method. (BB 604)"

   | newReceiver |
   messageSelector := selector.
   argumentCount := count.
   newReceiver := self stackValue: argumentCount.
   self sendSelectorToClass: (memory fetchClassOf: newReceiver)

]

{ #category : #'send bytecodes' }
Interpreter >> sendSelectorToClass: classPointer [
   "Find and execute a method in the class pointed to by ClassPointer (BB 604)"
   self findNewMethodInClass: classPointer.
   self executeNewMethod
]

{ #category : #'send bytecodes' }
Interpreter >> sendSpecialSelectorBytecode [
	"The set of special selectors can be used in a message without being 
   included in the literal frame. An Array in the object memory contains 
   the object pointers of the selectors in alternating locations. The 
   argument count for each selector is stored in the location following 
   the selector's object pointer. The specialSelectorPrimitiveResponse 
   routine will be described in the next chapter. (BB 608)"

	| selectorIndex selector count |
	self specialSelectorPrimitiveResponse
		ifFalse: [ selectorIndex := (currentBytecode - 176) * 2.
			selector := memory
				fetchPointer: selectorIndex
				ofObject: SpecialSelectorsPointer.
			count := self
				fetchInteger: selectorIndex + 1
				ofObject: SpecialSelectorsPointer.
			self sendSelector: selector argumentCount: count ]
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

{ #category : #'stack bytecodes' }
Interpreter >> shortConditionalJump [
	"The eight short conditional jumps advance the instruction pointer by 1 
   through 8 if the top of the stack is false. 
   So, there are three possible outcomes to a short conditional jump:
      1. If the top of the stack is false, the jump is taken.
      2. If the top of the stack is true, the jump is not taken.
      3. If the top of the stack is neither, mustBeBoolean is sent to it.
   (BB 603)"

	| offset |
	offset := self extractBits: 13 to: 15 of: currentBytecode.
	self jumpIf: FalsePointer by: offset + 1
]

{ #category : #'stack bytecodes' }
Interpreter >> shortUnconditionalJump [
	"The eight short unconditional jumps advance the instruction pointer by 1 through 8. (BB 602)"

	| offset |
	offset := self extractBits: 13 to: 15 of: currentBytecode.
	self jump: offset + 1
]

{ #category : #'return bytecodes' }
Interpreter >> simpleReturnValue: resultPointer to: contextPointer [
   "The simple way to return a value to a context would be to simply make it 
   the active context and push the value on its stack. (BB 609)"

   self newActiveContext: contextPointer.
   self push: resultPointer
]

{ #category : #'send bytecodes' }
Interpreter >> singleExtendedSendBytecode [
  "The first form of extended send is followed by a single byte specifying 
  the number of arguments in its high order three bits and selector index 
  in the low order five bits. (BB 606)"

   | descriptor selectorIndex |
   descriptor := self fetchByte.
   selectorIndex := self extractBits: 11 to: 15
                         of: descriptor.
  self sendSelector: (self literal: selectorIndex)
       argumentCount: (self extractBits: 8 to: 10
                            of: descriptor)
]

{ #category : #'send bytecodes' }
Interpreter >> singleExtendedSuperBytecode [
	"When the compiler encounters a message to super in a symbolic method, 
    it uses the bytecode that pushes self for the receiver, but it uses an 
    extended-super bytecode to indicate the selector instead of a regular 
    send bytecode. The two extended-super bytecodes are similar to the two 
    extended-send bytecodes. The first is followed by a single byte and the 
    second by two bytes that are interpreted exactly as for the extended-send 
    bytecodes. The only difference in what these bytecodes do is that they 
    start the message lookup in the superclass of the class in which the 
    current CompiledMethod was found. (BB 607)"

	| descriptor selectorIndex methodClass |
	descriptor := self fetchByte.
	argumentCount := self extractBits: 8 to: 10 
	                      of: descriptor.
	selectorIndex := self extractBits: 11 to: 15 
	                      of: descriptor.
	messageSelector := self literal: selectorIndex.
	methodClass := self methodClassOf: method.
	self sendSelectorToClass: (self superclassOf: methodClass)
]

{ #category : #dispatch }
Interpreter >> stackBytecode [
	"This routine dispatches to the appropriate stack management routine
    for the current bytecode (BB 597)"

	(currentBytecode between: 0 and: 15)
		ifTrue: [ ^ self pushReceiverVariableBytecode ].
	(currentBytecode between: 16 and: 31)
		ifTrue: [ ^ self pushTemporaryVariableBytecode ].
	(currentBytecode between: 32 and: 63)
		ifTrue: [ ^ self pushLiteralConstantBytecode ].
	(currentBytecode between: 64 and: 95)
		ifTrue: [ ^ self pushLiteralVariableBytecode ].
	(currentBytecode between: 96 and: 103)
		ifTrue: [ ^ self storeAndPopReceiverVariableBytecode ].
	(currentBytecode between: 104 and: 111)
		ifTrue: [ ^ self storeAndPopTemporaryVariableBytecode ].
	currentBytecode = 112
		ifTrue: [ ^ self pushReceiverBytecode ].
	(currentBytecode between: 113 and: 119)
		ifTrue: [ ^ self pushConstantBytecode ].
	currentBytecode = 128
		ifTrue: [ ^ self extendedPushBytecode ].
	currentBytecode = 129
		ifTrue: [ ^ self extendedStoreBytecode ].
	currentBytecode = 130
		ifTrue: [ ^ self extendedStoreAndPopBytecode ].
	currentBytecode = 135
		ifTrue: [ ^ self popStackBytecode ].
	currentBytecode = 136
		ifTrue: [ ^ self duplicateTopBytecode ].
	currentBytecode = 137
		ifTrue: [ ^ self pushActiveContextBytecode ]
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

{ #category : #'stack bytecodes' }
Interpreter >> storeAndPopReceiverVariableBytecode [
   "The store bytecodes transfer references in the opposite direction from the push 
   bytecodes; from the top of the stack to the receiver's instance variables, the temporary 
   frame, or the literal frame. There are single byte versions for storing into the first
   eight variables of the receiver or the temporary frame and then popping the stack. (BB 600)"

   | variableIndex |
   variableIndex := self extractBits: 13 to: 15
                         of: currentBytecode.
   memory storePointer: variableIndex
          ofObject: receiver
          withValue: self popStack
]

{ #category : #'stack bytecodes' }
Interpreter >> storeAndPopTemporaryVariableBytecode [
	"The store bytecodes transfer references in the opposite direction from the push 
   bytecodes; from the top of the stack to the receiver's instance variables, the temporary 
   frame, or the literal frame. There are single byte versions for storing into the first
   eight variables of the receiver or the temporary frame and then popping the stack. (BB 600)"

	| variableIndex |
	variableIndex := self extractBits: 13 to: 15 
	                      of: currentBytecode.
	memory storePointer: variableIndex + TempFrameStart
		    ofObject: homeContext
          withValue: self popStack
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
