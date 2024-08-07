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
		'methodCacheSize',
		'success',
		'semaphoreIndex',
		'semaphoreList',
		'newProcessWaiting',
		'newProcess',
		'debug',
		'cycleCounter',
		'classOops',
		'methodOops',
		'currentDisplay',
		'currentDisplayWidth',
		'currentDisplayHeight',
		'hal',
		'fileSystem'
	],
	#classVars : [
		'ActiveProcessIndex',
		'BitsInForm',
		'BlockArgumentCountIndex',
		'CallerIndex',
		'CannotReturnSelector',
		'CharacterTablePointer',
		'CharacterValueIndex',
		'ClassArrayPointer',
		'ClassBlockContextPointer',
		'ClassCharacterPointer',
		'ClassCompiledMethod',
		'ClassDisplayScreenPointer',
		'ClassFloatPointer',
		'ClassLargePositiveIntegerPointer',
		'ClassMessagePointer',
		'ClassMethodContextPointer',
		'ClassPointPointer',
		'ClassPointSize',
		'ClassSemaphorePointer',
		'ClassSmallInteger',
		'ClassStringPointer',
		'ClassSymbolPointer',
		'ClassUndefinedObject',
		'DoesNotUnderstandSelector',
		'ExcessSignalsIndex',
		'ExtendedPushVariableTypes',
		'ExtendedStoreVariableTypes',
		'FalsePointer',
		'FirstLinkIndex',
		'HeaderIndex',
		'HeightInForm',
		'HomeIndex',
		'InitialIPIndex',
		'InstanceSpecificationIndex',
		'InstructionPointerIndex',
		'LastLinkIndex',
		'LiteralStart',
		'MessageArgumentsIndex',
		'MessageDictionaryIndex',
		'MessageSelectorIndex',
		'MessageSize',
		'MethodArrayIndex',
		'MethodIndex',
		'MinusOnePointer',
		'MustBeBooleanSelector',
		'MyListIndex',
		'NextLinkIndex',
		'NilPointer',
		'OnePointer',
		'PriorityIndex',
		'ProcessListsIndex',
		'PushBytecodeReceivers',
		'ReceiverIndex',
		'ReturnBytecodeTypes',
		'ReturnTopStackTypes',
		'SchedulerAssociationPointer',
		'SelectorStart',
		'SenderIndex',
		'SpecialSelectorsPointer',
		'StackPointerIndex',
		'StreamArrayIndex',
		'StreamIndexIndex',
		'StreamReadLimitIndex',
		'StreamWriteLimitIndex',
		'SuperclassIndex',
		'SuspendedContextIndex',
		'TempFrameStart',
		'TruePointer',
		'TwoPointer',
		'ValueIndex',
		'WidthInForm',
		'XIndex',
		'YIndex',
		'ZeroPointer'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #'class initialization' }
Interpreter class >> initialize [
	"Not BB code"

	"Helpers to display deubg information in clear"
	PushBytecodeReceivers := #( 'true' 'false' 'nil' '-1' '0' '1' '2' ).
	ExtendedPushVariableTypes := #( 'Receiver Variable'
	                                'Temporary Location'
	                                'Literal Constant' 'Literal Variable' ).
	ExtendedStoreVariableTypes := ExtendedPushVariableTypes.
	ReturnBytecodeTypes := #( 'true' 'false' 'nil' ).
	ReturnTopStackTypes := #( 'Message' 'Block' )

	
]

{ #category : #'instance creation' }
Interpreter class >> withSnapshot: stream hal: hwAbstractionLayer fileSystem: hostFS debug: debug [
   "the code below follows the Seaside Object initialization conventions"
	^ self basicNew
		initializeWithSnapshot: stream hal: hwAbstractionLayer fileSystem: hostFS debug: debug;
		yourself
]

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

{ #category : #'control primitives' }
Interpreter >> activeProcess [
   "Any routines desiring to know what the active process will be must take
   into account the newProcessWaiting and newProcess registers. Therefore,
   they use the following routine. (BB 644)"

   newProcessWaiting
      ifTrue: [^newProcess]
      ifFalse: [^memory fetchPointer: ActiveProcessIndex
                        ofObject: self schedulerPointer]
]

{ #category : #'control primitives' }
Interpreter >> addLastLink: aLink toList: aLinkedList [
   "Routines removeFirstLinkOfList:, addLastLink:toList: and isEmptyList: 
    are used to manipulate LinkedLists. (BB 645)"

   | lastLink |
   (self isEmptyList: aLinkedList)
      ifTrue: [memory storePointer: FirstLinkIndex
                      ofObject: aLinkedList
                      withValue: aLink]
      ifFalse: [lastLink := memory fetchPointer: LastLinkIndex
                                   ofObject: aLinkedList.
                memory storePointer: NextLinkIndex
                       ofObject: lastLink
                       withValue: aLink].
   memory storePointer: LastLinkIndex
          ofObject: aLinkedList
          withValue: aLink.
   memory storePointer: MyListIndex
          ofObject: aLink
          withValue: aLinkedList
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

{ #category : #'primitive methods' }
Interpreter >> arithmeticSelectorPrimitive [
   "A primitive routine will be accessed by a special arithmetic selector 
   only if the receiver is a SmallInteger. The actual primitive routines 
   will be described in the section on arithmetic primitives. (BB 619)"

   "self success: (memory isIntegerObject: (self stackValue: 1))."
   self success
   ifTrue: [currentBytecode = 176 ifTrue: [^self primitiveAdd].
            currentBytecode = 177 ifTrue: [^self primitiveSubtract].
            currentBytecode = 178 ifTrue: [^self primitiveLessThan].
            currentBytecode = 179 ifTrue: [^self primitiveGreaterThan].
            currentBytecode = 180 ifTrue: [^self primitiveLessOrEqual].
            currentBytecode = 181 ifTrue: [^self primitiveGreaterOrEqual].
            currentBytecode = 182 ifTrue: [^self primitiveEqual].
            currentBytecode = 183 ifTrue: [^self primitiveNotEqual].
            currentBytecode = 184 ifTrue: [^self primitiveMultiply].
            currentBytecode = 185 ifTrue: [^self primitiveDivide].
            currentBytecode = 186 ifTrue: [^self primitiveMod].
            currentBytecode = 187 ifTrue: [^self primitiveMakePoint].
            currentBytecode = 188 ifTrue: [^self primitiveBitShift].
            currentBytecode = 189 ifTrue: [^self primitiveDiv].
            currentBytecode = 190 ifTrue: [^self primitiveBitAnd].
            currentBytecode = 191 ifTrue: [^self primitiveBitOr]]

]

{ #category : #contexts }
Interpreter >> caller [
	"This routine fetch the caller field from contexts needed by the interpreter. Access is infrequent
enough that it is not cached in registers. The caller is the context to be returned to when a 
BlockContext returns a value (at the end of the block) (BB 586)."

	^ memory fetchPointer: SenderIndex ofObject: activeContext
]

{ #category : #'array stream primitives' }
Interpreter >> checkIndexableBoundsOf: index in: array [
	"Check the bounds on subscripting operations and to perform the subscripting
   accesses. This routine takes a one-relative index and determines whether it is a legal 
   subscript of an object. It must take into account any fixed fields. (BB 627)"

	| class |
	class := memory fetchClassOf: array.
	self success: index >= 1.
	self success: index + (self fixedFieldsOf: class) <= (self lengthOf: array)
]

{ #category : #'storage management primitives' }
Interpreter >> checkInstanceVariableBoundsOf: index in: object [
	"check that index is within the object size range. (BB 635)"

	| class |
	class := memory fetchClassOf: object. "TODO: this line seems to be useless"
	self success: index >= 1.
	self success: index <= (self lengthOf: object)
]

{ #category : #'control primitives' }
Interpreter >> checkProcessSwitch [
   "The checkProcessSwitch routine is called before each bytecode fetch (in 
   the interpret routine) and performs the actual process switch if one has 
   been called for. It stores the active context pointer in the old Process, 
   stores the new Process in the ProcessorScheduler's active process field, 
   and loads the new active context out of that Process. (BB 643)"

   | activeProcess |
   [semaphoreIndex > 0]
      whileTrue: [self synchronousSignal: (semaphoreList at: semaphoreIndex).
                  semaphoreIndex := semaphoreIndex - 1].
   newProcessWaiting
      ifTrue: [newProcessWaiting := false.
               activeProcess := self activeProcess.
               memory storePointer: SuspendedContextIndex
                      ofObject: activeProcess
                      withValue: activeContext.
               memory storePointer: ActiveProcessIndex
                      ofObject: self schedulerPointer
                      withValue: newProcess.
               self newActiveContext: (memory fetchPointer: SuspendedContextIndex
                                              ofObject: newProcess).
               "From dbanay: Need to remove reference"
               memory decreaseReferencesTo: newProcess.
               newProcess := nil]

]

{ #category : #'primitive methods' }
Interpreter >> commonSelectorPrimitive [
   "If the receiver is not a SmallInteger then this routine is used to process
   the call (BB 619)"

   | receiverClass |
   argumentCount := self fetchInteger: (currentBytecode - 176) * 2 + 1
                         ofObject: SpecialSelectorsPointer.
   receiverClass := memory fetchClassOf: (self stackValue: argumentCount).
   currentBytecode = 198 ifTrue: [^self primitiveEquivalent].
   currentBytecode = 199 ifTrue: [^self primitiveClass].
   currentBytecode = 200
   ifTrue: [self success: (receiverClass = ClassMethodContextPointer)
                          | (receiverClass = ClassBlockContextPointer).
   ^ self success ifTrue: [self primitiveBlockCopy]].
   (currentBytecode = 201) | (currentBytecode = 202)
      ifTrue: [self success: receiverClass = ClassBlockContextPointer.
               ^ self success ifTrue: [self primitiveValue]].
   self primitiveFail
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

   cycleCounter := cycleCounter + 1.
	self checkProcessSwitch.
	currentBytecode := self fetchByte.
	debug ifTrue: [
		Transcript show: 'cycle '; nextPutAll: cycleCounter printString;
	   		nextPutAll: ' - Bytecode: '; nextPutAll: currentBytecode printString; cr.
		].
	self dispatchOnThisBytecode.


]

{ #category : #accessing }
Interpreter >> debug: onOff [
  debug := onOff.
]

{ #category : #'bytecode dispatch' }
Interpreter >> dispatchArithmeticPrimitives [
  "There are three sets of arithmetic primitive routines, one for SmallIntegers,
  one for large integers (LargePositiveIntegers and LargeNegativeIntegers), and
  one for Floats. The primitives for SmallIntegers and Floats must be implemented,
  the primitives for large integers are optional. (BB 621)"

   primitiveIndex < 20 ifTrue: [^self dispatchIntegerPrimitives].
   primitiveIndex < 40 ifTrue: [^self dispatchLargeIntegerPrimitives].
   primitiveIndex < 60 ifTrue: [^self dispatchFloatPrimitives]


]

{ #category : #'bytecode dispatch' }
Interpreter >> dispatchControlPrimitives [
   "The control primitives provide the control structures not provided by the
   bytecodes. They include support for the behavior of BlockContexts, Processes,
   and Semaphores. They also provide for messages with parameterized selectors. 
  (BB 637)"

   primitiveIndex = 80 ifTrue: [^self primitiveBlockCopy].
   primitiveIndex = 81 ifTrue: [^self primitiveValue].
   primitiveIndex = 82 ifTrue: [^self primitiveValueWithArgs].
   primitiveIndex = 83 ifTrue: [^self primitivePerform].
   primitiveIndex = 84 ifTrue: [^self primitivePerformWithArgs].
   primitiveIndex = 85 ifTrue: [^self primitiveSignal].
   primitiveIndex = 86 ifTrue: [^self primitiveWait].
   primitiveIndex = 87 ifTrue: [^self primitiveResume].
   primitiveIndex = 88 ifTrue: [^self primitiveSuspend].
   primitiveIndex = 89 ifTrue: [^self primitiveFlushCache]
]

{ #category : #'bytecode dispatch' }
Interpreter >> dispatchFloatPrimitives [
   "Instances of Float are represented in IEEE single-precision (32-bit) format.
   This format represents a floating point quantity as a number between one and two, 
   a power of two, and a sign. A Float is a word-size, nonpointer object. (BB 626)"
   primitiveIndex = 40 ifTrue: [^self primitiveAsFloat].
   primitiveIndex = 41 ifTrue: [^self primitiveFloatAdd].
   primitiveIndex = 42 ifTrue: [^self primitiveFloatSubstract].
   primitiveIndex = 43 ifTrue: [^self primitiveFloatLessThan].
   primitiveIndex = 44 ifTrue: [^self primitiveFloatGreaterThan].
   primitiveIndex = 45 ifTrue: [^self primitiveFloatLessOrEqual].
   primitiveIndex = 46 ifTrue: [^self primitiveFloatGreaterOrEqual].
   primitiveIndex = 47 ifTrue: [^self primitiveFloatEqual].
   primitiveIndex = 48 ifTrue: [^self primitiveFloatNotEqual].
   primitiveIndex = 49 ifTrue: [^self primitiveFloatMultiply].
   primitiveIndex = 50 ifTrue: [^self primitiveFloatDivide].
   primitiveIndex = 51 ifTrue: [^self primitiveTruncated].
   primitiveIndex = 52 ifTrue: [^self primitiveFractionalPart].
   primitiveIndex = 53 ifTrue: [^self primitiveExponent].
   primitiveIndex = 54 ifTrue: [^self primitiveTimesTwoPower]
]

{ #category : #'bytecode dispatch' }
Interpreter >> dispatchInputOutputPrimitives [
   "The input/output primitive routines provide Smalltalk with access to the
   state of the hardware devices. Since the implementation of these routines 
   will be dependent on the structure of the implementing machine, no routines 
   will be given, just a specification of the behavior of the primitives. 
   (BB 647)"

   primitiveIndex = 90 ifTrue: [^self primitiveMousePoint].
   primitiveIndex = 91 ifTrue: [^self primitiveCursorLocPut].
   primitiveIndex = 92 ifTrue: [^self primitiveCursorLink].
   primitiveIndex = 93 ifTrue: [^self primitiveInputSemaphore].
   primitiveIndex = 94 ifTrue: [^self primitiveSampleInterval].
   primitiveIndex = 95 ifTrue: [^self primitiveInputWord].
   primitiveIndex = 96 ifTrue: [^self primitiveCopyBits].
   primitiveIndex = 97 ifTrue: [^self primitiveSnapshot].
   primitiveIndex = 98 ifTrue: [^self primitiveTimeWordsInto].
   primitiveIndex = 99 ifTrue: [^self primitiveTickWordsInto].
   primitiveIndex = 100 ifTrue: [^self primitiveSignalAtTick].
   primitiveIndex = 101 ifTrue: [^self primitiveBeCursor].
   primitiveIndex = 102 ifTrue: [^self primitiveBeDisplay].
   primitiveIndex = 103 ifTrue: [^self primitiveScanCharacters].
   primitiveIndex = 104 ifTrue: [^self primitiveDrawLoop].
   primitiveIndex = 105 ifTrue: [^self primitiveStringReplace]
]

{ #category : #'bytecode dispatch' }
Interpreter >> dispatchIntegerPrimitives [
   "The first set of arithmetic primitive routines all pop a receiver and 
   argument off the stack and fail if they are not both SmallIntegers. The
   routines then push on the stack either the integral result of a computation
   or the Boolean result of a comparison. The routines that produce an integral
   result fail if the value cannot be represented as a SmallInteger. (BB 621)"

   primitiveIndex = 1 ifTrue: [^self primitiveAdd].
   primitiveIndex = 2 ifTrue: [^self primitiveSubtract].
   primitiveIndex = 3 ifTrue: [^self primitiveLessThan].
   primitiveIndex = 4 ifTrue: [^self primitiveGreaterThan].
   primitiveIndex = 5 ifTrue: [^self primitiveLessOrEqual].
   primitiveIndex = 6 ifTrue: [^self primitiveGreaterOrEqual].
   primitiveIndex = 7 ifTrue: [^self primitiveEqual].
   primitiveIndex = 8 ifTrue: [^self primitiveNotEqual].
   primitiveIndex = 9 ifTrue: [^self primitiveMultiply].
   primitiveIndex = 10 ifTrue: [^self primitiveDivide].
   primitiveIndex = 11 ifTrue: [^self primitiveMod].
   primitiveIndex = 12 ifTrue: [^self primitiveDiv].
   primitiveIndex = 13 ifTrue: [^self primitiveQuo].
   primitiveIndex = 14 ifTrue: [^self primitiveBitAnd].
   primitiveIndex = 15 ifTrue: [^self primitiveBitOr].
   primitiveIndex = 16 ifTrue: [^self primitiveBitXor].
   primitiveIndex = 17 ifTrue: [^self primitiveBitShift].
   primitiveIndex = 18 ifTrue: [^self primitiveMakePoint]
]

{ #category : #'bytecode dispatch' }
Interpreter >> dispatchLargeIntegerPrimitives [
	"The primitive indices 21 to 37 are the same as primitives 1 to 17 except
	that they perform their operations on large integers (instances of 
	LargePositiveInteger and LargeNegativeInteger). There are adequate Smalltalk 
	implementations for all of these operations so the primitive routines are 
	optional and will not be specified in this chapter. To implement them, the 
	corresponding Smalltalk methods should be translated into machine language 
	routines. (BB 625)"

	self primitiveFail
]

{ #category : #'bytecode dispatch' }
Interpreter >> dispatchOnThisBytecode [
   "Not all of the bytecodes of one type are contiguous, so the main dispatch has
    seven branches each of which calls one of four routines (stackBytecode, jumpBytecode,
    sendBytecode, or returnBytecode) (BB 595)"

	debug ifTrue: [ 
		Transcript show: 'Bytecode '; nextPutAll: '<'; 
			nextPutAll: currentBytecode printString; nextPutAll: '> '.
		].
	
   (currentBytecode between: 0 and: 119)   ifTrue: [^self stackBytecode].
   (currentBytecode between: 120 and: 127) ifTrue: [^self returnBytecode].
   (currentBytecode between: 128 and: 130) ifTrue: [^self stackBytecode].
   (currentBytecode between: 131 and: 134) ifTrue: [^self sendBytecode].
   (currentBytecode between: 135 and: 137) ifTrue: [^self stackBytecode].
   (currentBytecode between: 144 and: 175) ifTrue: [^self jumpBytecode].
   (currentBytecode between: 176 and: 255) ifTrue: [^self sendBytecode]
]

{ #category : #'bytecode dispatch' }
Interpreter >> dispatchPrimitives [
   "The six types of primitives in the formal specification deal with 
   arithmetic, subscripting and streaming, storage management, control structures, 
   input/output, and general system access. These correspond to six ranges of 
   primitive indices. A range of primitive indices has been reserved for 
   implementation-private primitive routines. They may be assigned any meaning, 
   but cannot be depended upon from interpreter to interpreter. Since these are
   not part of the specification, they cannot be described here. (BB 621)"

	debug ifTrue: [ 
		Transcript show: 'Primitive #'; nextPutAll: primitiveIndex printString;cr.
		 ].
	
   primitiveIndex < 60 ifTrue: [^self dispatchArithmeticPrimitives].
   primitiveIndex < 68 ifTrue: [^self dispatchSubscriptAndStreamPrimitives].
   primitiveIndex < 80 ifTrue: [^self dispatchStorageManagementPrimitives].
   primitiveIndex < 90 ifTrue: [^self dispatchControlPrimitives].
   primitiveIndex < 110 ifTrue: [^self dispatchInputOutputPrimitives].
   primitiveIndex < 128 ifTrue: [^self dispatchSystemPrimitives].
   primitiveIndex < 256 ifTrue: [^self dispatchPrivatePrimitives]
]

{ #category : #'bytecode dispatch' }
Interpreter >> dispatchPrivatePrimitives [
	"BB p. 621"
	"A range of primitive indices has been reserved for implementation-private primitive routines. 
	They may be Arithmetic Primitives assigned any meaning, but cannot be depended upon from
	interpreter to interpreter. Since these are not part of the specification, they cannot
	be described here."
	"NO PRIAVTE PRIMITIVE IMPLEMENTED FOR NOW"

]

{ #category : #'bytecode dispatch' }
Interpreter >> dispatchStorageManagementPrimitives [
   "The storage management primitive routines manipulate the representation
   of objects. They include primitives for manipulating object pointers, 
   accessing fields, creating new instances of a class, and enumerating 
   the instances of a class. (BB 633)"

   primitiveIndex = 68 ifTrue: [^self primitiveObjectAt].
   primitiveIndex = 69 ifTrue: [^self primitiveObjectAtPut].
   primitiveIndex = 70 ifTrue: [^self primitiveNew].
   primitiveIndex = 71 ifTrue: [^self primitiveNewWithArg].
   primitiveIndex = 72 ifTrue: [^self primitiveBecome].
   primitiveIndex = 73 ifTrue: [^self primitiveInstVarAt].
   primitiveIndex = 74 ifTrue: [^self primitiveInstVarAtPut].
   primitiveIndex = 75 ifTrue: [^self primitiveAsOop].
   primitiveIndex = 76 ifTrue: [^self primitiveAsObject].
   primitiveIndex = 77 ifTrue: [^self primitiveSomeInstance].
   primitiveIndex = 78 ifTrue: [^self primitiveNextInstance].
   primitiveIndex = 79 ifTrue: [^self primitiveNewMethod]
]

{ #category : #'bytecode dispatch' }
Interpreter >> dispatchSubscriptAndStreamPrimitives [
   "Primitive routines for manipulating the indexable fields of objects both 
   directly, by subscripting, and indirectly, by streaming. These routines 
   make use of the 16-bit positive integer routines, since the limit on 
   indexable fields is 65534. (BB 627)"

	primitiveIndex = 60 ifTrue: [^self primitiveAt].
	primitiveIndex = 61 ifTrue: [^self primitiveAtPut].
	primitiveIndex = 62 ifTrue: [^self primitiveSize].
	primitiveIndex = 63 ifTrue: [^self primitiveStringAt].
	primitiveIndex = 64 ifTrue: [^self primitiveStringAtPut].
	primitiveIndex = 65 ifTrue: [^self primitiveNext].
	primitiveIndex = 66 ifTrue: [^self primitiveNextPut].
	primitiveIndex = 67 ifTrue: [^self primitiveAtEnd]
]

{ #category : #'bytecode dispatch' }
Interpreter >> dispatchSystemPrimitives [
	"BB p. 652"
	primitiveIndex = 110 ifTrue: [^self primitiveEquivalent].
	primitiveIndex = 111 ifTrue: [^self primitiveClass].
	primitiveIndex = 112 ifTrue: [^self primitiveCoreLeft].
	primitiveIndex = 113 ifTrue: [^self primitiveQuit].
	primitiveIndex = 114 ifTrue: [^self primitiveExitToDebugger].
	primitiveIndex = 115 ifTrue: [^self primitiveOopsLeft].
	primitiveIndex = 116 ifTrue: [^self primitiveSignalAtOopsLeftWordsLeft]
]

{ #category : #'send bytecodes' }
Interpreter >> doubleExtendedSendBytecode [
   "The second form of extended send bytecode is followed by two bytes; the 
    first is the number of arguments and the second is the index of the selector 
    in the literal frame. (BB 607)"

   | count selector selBits |
   count := self fetchByte.
   selBits := self fetchByte.
   selector := self literal: selBits.
	debug ifTrue: [ 
		Transcript show: 'Send Literal Selector #'; 
			nextPutAll: selBits printString; 
			nextPutAll: ' With '; 
			nextPutAll: count printString;
			nextPutAll: ' Arguments';		 
			cr.
		].
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

	| methodClass selBits |
	argumentCount := self fetchByte.
	selBits := self fetchByte.
	messageSelector := self literal: selBits.
	debug ifTrue: [ 
		Transcript show: 'Send Literal Selector #'; 
			nextPutAll: selBits printString; 
			nextPutAll: ' To Super Class With '; 
			nextPutAll: argumentCount printString;
			nextPutAll: 'Arguments';		 
			cr.
		].

	methodClass := self methodClassOf: method.
	self sendSelectorToClass: (self superclassOf: methodClass)
]

{ #category : #'stack bytecodes' }
Interpreter >> duplicateTopBytecode [
	"The duplicateTopBytecode routine pushes another copy of the object pointer
    on the top of the stack. (BB 599)"
	debug ifTrue: [ 
		Transcript show: 'Duplicate Stack Top ' ; cr.
	   ].
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
	debug ifTrue: [ 
		Transcript show:'(Extended) Push '; 
		nextPutAll: (ExtendedPushVariableTypes at: (variableType + 1)) printString;
		nextPutAll: '#'; nextPutAll: variableIndex printString; cr.
	   ].
	
	variableType = 0 ifTrue: [ ^ self pushReceiverVariable: variableIndex ].
	variableType = 1 ifTrue: [ ^ self pushTemporaryVariable: variableIndex ].
	variableType = 2 ifTrue: [ ^ self pushLiteralConstant: variableIndex ].
	variableType = 3 ifTrue: [ ^ self pushLiteralVariable: variableIndex ]
]

{ #category : #'bytecode dispatch' }
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
	debug ifTrue: [ 
		Transcript show: ((currentBytecode = 129) ifTrue: [ '(Extended) Store ' ]);
		nextPutAll: ((currentBytecode = 130) ifTrue: [ '(Extended) Pop and Store ' ]); 
		nextPutAll: (ExtendedStoreVariableTypes at: (variableType + 1)) printString;
		nextPutAll: '#'; nextPutAll: variableIndex printString; cr.
	   ].
	
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

{ #category : #'primitive methods' }
Interpreter >> extractFloat: objectPointer [
   "This routine is not implemented in the BB. It rebuilds a 32 bit
   Float from 2 words"

   ^ (memory fetchWord: 1 ofObject: objectPointer) << 16 | 
   	  (memory fetchWord: 0 ofObject: objectPointer)
]

{ #category : #'primitive methods' }
Interpreter >> failPrimitive [
   "set the state of the success flag when a primitive routine cannot complete successfully (BB 616)"

   success := false
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
		ifTrue: [homeContext := memory fetchPointer: HomeIndex ofObject: activeContext]
		ifFalse: [homeContext := activeContext ].
		
	receiver := memory fetchPointer: ReceiverIndex ofObject: homeContext.
	method := memory fetchPointer: MethodIndex ofObject: homeContext.
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

{ #category : #'control primitives' }
Interpreter >> firstContext [
   "When Smalltalk is started up, the initial active context is found through
   the scheduler's active Process. (BB 644)"

   newProcessWaiting := false.
   "ERROR From dbanay need to initialize new Process"
	newProcess := nil.
   ^memory fetchPointer: SuspendedContextIndex
           ofObject: self activeProcess
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

{ #category : #'primitive methods' }
Interpreter >> initPrimitive [
   "initialize the state of the success flag before a primitive routine runs (BB 616)"

   success := true
]

{ #category : #'compiled method header access' }
Interpreter >> initialInstructionPointerOfMethod: methodPointer [
	"Returns the byte index of the first bytecode of a CompiledMethod. (BB 578)"

	^ ((self literalCountOf: methodPointer) + LiteralStart) * 2 + 1
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
Interpreter >> initializeCharacterIndex [
   "Index where the value of the character field in Character object is placed (BB 630)"

   CharacterValueIndex := 0
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
Interpreter >> initializeClassOopsWith: stream [
	"Not BB code"
   "Load method symbol table from stream"

	| cols oop |
	classOops := Dictionary new.
	
	"symbol table file format is one symbol per line with
	3 columns each and TAB as a separator
	oop in octal\toop in hexa\tclass name"
	[ stream atEnd ] whileFalse: [
		cols := stream nextLine splitOn: Character tab.
		"Transcript show: 'Class cols: '; nextPutAll: cols printString; cr."
		cols size = 3 ifTrue: [ 
				oop := (cols at: 2).	
				oop := Integer readFrom: (oop allButFirst: 3) base: 16.
				classOops at: oop put: (cols at: 3) 
			]
		]


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
	ClassLargePositiveIntegerPointer := 28.
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
Interpreter >> initializeMethodOopsWith: stream [
	"Not BB code"
   "Load method symbol table from stream"

	| cols oop |
	methodOops := Dictionary new.
	
	"symbol table file format is one symbol per line with
	3 columns each and TAB as a separator: 
	oop in octal\toop in hexa\tmethod name"
	[ stream atEnd ] whileFalse: [
		cols := stream nextLine splitOn: Character tab.
		"Transcript show: 'Method cols: '; nextPutAll: cols printString; cr."
		cols size = 3 ifTrue: [ 
				oop := (cols at: 2).	
				oop := Integer readFrom: (oop allButFirst: 3) base: 16.
				methodOops at: oop put: (cols at: 3) 
			]
		]



]

{ #category : #initialization }
Interpreter >> initializeOtherConstants [
	"Not BB code"
	"Constants that are needed by the implementation specific code"
	
	"Index of Form attributes in ST80 objects to access
	display size"
	WidthInForm := 1.
	HeightInForm := 2.
	

]

{ #category : #initialization }
Interpreter >> initializePointIndices [
   "initialize indices of the Point Class"
    XIndex := 0.
    YIndex := 1.
    ClassPointSize := 2
]

{ #category : #initialization }
Interpreter >> initializeSchedulerIndices [
	"The next four primitive routines (for primitive indices 85 through 88) 
   are used for communication and scheduling of independent processes. The 
   following routine initializes the indices used to access Processes, 
   ProcessorSchedulers, and Semaphores. (BB 641)"

	"Class ProcessorScheduler"

	ProcessListsIndex  := 0.
	ActiveProcessIndex := 1.
	"Class LinkedList"
	FirstLinkIndex := 0.
	LastLinkIndex  := 1.
	"Class Semaphore"
	ExcessSignalsIndex := 2.
	"Class Link"
	NextLinkIndex := 0.
	"Class Process"
	SuspendedContextIndex := 1.
	PriorityIndex := 2.
	MyListIndex   := 3

]

{ #category : #initialization }
Interpreter >> initializeSmallIntegers [
	"SmallIntegers definition (BB 575)"

	MinusOnePointer := 65535.
	ZeroPointer := 1.
	OnePointer  := 3.
	TwoPointer  := 5
]

{ #category : #initialization }
Interpreter >> initializeStreamIndices [
	"Indices to the Stream instance variables"

	StreamArrayIndex := 0.
	StreamIndexIndex := 1.
	StreamReadLimitIndex  := 2.
	StreamWriteLimitIndex := 3
]

{ #category : #initialization }
Interpreter >> initializeWithSnapshot: stream hal: hwAbstractionLayer fileSystem: hostFS debug: onOff [
   "Not BB code"
   "Initialize the Interpreter"
 
	hal := hwAbstractionLayer.
	fileSystem := hostFS.
	debug := onOff.
	
	"Make sure class variables are initialized"
	self class initialize.
	
	"Initialize all constants known to the interpreter"
	self
		initializeSmallIntegers;
		initializeGuaranteedPointers;
		initializeMethodIndices;
		initializeContextIndices;
		initializeMessageIndices;
		initializeClassIndices;
		initializeAssociationIndex;
		initializeMethodCache;
		initializePointIndices;
		initializeCharacterIndex;
		initializeSchedulerIndices;
		initializeStreamIndices;
		initializeOtherConstants.

	"Create the object memory and load it with VM Snapshot"
	memory := ObjectMemory new.
	memory loadWithSnapshot: stream debug: onOff.
	
	"BB doesn't say how large the semaphore list must be..."
	"TODO: turn it into an #initializeSemaphore method when code is stable"
	semaphoreList := Array new: 255 withAll: 0.
	semaphoreIndex := 0.
	
	debug ifTrue: [ 
		Transcript show: '>>>>>> Initializing interpreter...'; cr
	].

	"When Smalltalk is started up, the initial active context is found
	through the scheduler's active Process (BB p. 644)"
	activeContext := self firstContext.
	memory increaseReferencesTo: activeContext.
	
	"Fetch all the registers of the context that represents the 
	CompiledMethod or block currently being executed (aka activeContext)"
	self fetchContextRegisters.
	
	"Cycle counter"
	cycleCounter := 0.
	
	
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

{ #category : #'control primitives' }
Interpreter >> isEmptyList: aLinkedList [
   "Routines removeFirstLinkOfList:, addLastLink:toList: and isEmptyList: 
    are used to manipulate LinkedLists. (BB 645)"

   ^(memory fetchPointer: FirstLinkIndex
            ofObject: aLinkedList) = NilPointer
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

{ #category : #'array stream primitives' }
Interpreter >> lengthOf: array [
	"Length of the array (number of elements). It determines whether the object 
	being indexed contains pointers, 16-bit integer values, or 8-bit integer 
	values, in its indexable fields. (BB 627)"

	(self isWords: (memory fetchClassOf: array))
		ifTrue: [ ^ memory fetchWordLengthOf: array ]
		ifFalse: [ ^ memory fetchByteLengthOf: array ]
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

	debug ifTrue: [ 
		Transcript show: 'Pop and Jump On  '; 
			nextPutAll: offset printString; 	 
			cr.
		].			
	(currentBytecode between: 168 and: 171)
		ifTrue: [ 
			debug ifTrue: [ 
				Transcript show: 'True  '; 
				nextPutAll: offset printString; 	 
				cr.
				].	
			^ self jumpIf: TruePointer 
			              by: offset ].
	(currentBytecode between: 172 and: 176)
		ifTrue: [ 
			debug ifTrue: [ 
				Transcript show: 'False  '; 
				nextPutAll: offset printString; 	 
				cr.
				].
			^ self jumpIf: FalsePointer 
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
	offset := (offset - 4) * 256 + self fetchByte.
	debug ifTrue: [ 
		Transcript show: 'Jump '; 
			nextPutAll: offset printString; 	 
			cr.
		].						
	self jump: offset
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

{ #category : #accessing }
Interpreter >> memory [
	"Not BB code"
	"Accessor used by the VM image loader"

	^ memory
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

{ #category : #'primitive methods' }
Interpreter >> popFloat [
   "This routine is not implementedin the BB. It is needed to pop a Float
   object from the stack"

   | objectPointer |
   objectPointer := self popStack.
   self success: (memory fetchClassOf: objectPointer) = ClassFloatPointer.
   self success
      ifTrue: [^ Float fromIEEE32Bit: (self extractFloat: objectPointer)]
]

{ #category : #'primitive methods' }
Interpreter >> popInteger [
   "Many of the primitives manipulate integer quantities, so the interpreter 
   includes several routines that perform common functions. The popInteger 
   routine is used when a primitive expects a SmallInteger on the top of 
   the stack. If it is a SmallInteger, its value is returned; if not, 
   a primitive failure is signaled. (BB 617)"

   | integerPointer |
   integerPointer := self popStack.
   self success: (memory isIntegerObject: integerPointer).
   self success
      ifTrue: [^ memory integerValueOf: integerPointer]
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
	debug ifTrue: [ 
		Transcript show: 'Pop Stack Top ' ; cr.
	   ].
   self popStack
]

{ #category : #'primitive methods' }
Interpreter >> positive16BitIntegerFor: integerValue [
	"Since the largest indexable collections may have 65534 indexable elements, 
   and SmallIntegers can only represent values up to 16383, primitive routines 
   that deal with indices or sizes must be able to manipulate LargePositiveIntegers. 
   This routine convert between 16-bit unsigned values and object pointers 
   to SmallIntegers or LargePositiveIntegers. (BB 617)"

	| newLargeInteger |
	(self extractBits: 0 to: 1 of: integerValue) = 0
		ifTrue: [ ^ memory integerObjectOf: integerValue ].
	newLargeInteger := memory instantiateClass: ClassLargePositiveIntegerPointer
		                       withBytes: 2.
	memory storeByte: 0
		    ofObject: newLargeInteger
		    withValue: (self lowByteOf: integerValue).
	memory storeByte: 1
          ofObject: newLargeInteger
          withValue: (self highByteOf: integerValue).
	^ newLargeInteger
]

{ #category : #'primitive methods' }
Interpreter >> positive16BitValueOf: integerPointer [
	"Since the largest indexable collections may have 65534 indexable elements, 
   and SmallIntegers can only represent values up to 16383, primitive routines 
   that deal with indices or sizes must be able to manipulate LargePositiveIntegers. 
   This routine convert between from SmallIntegers or LargePositiveIntegers
   16-bit unsigned values and object pointers. (BB 617)"

	| value |
	(memory isIntegerObject: integerPointer)
		ifTrue: [ ^ memory integerValueOf: integerPointer ].
	(memory fetchClassOf: integerPointer) = ClassLargePositiveIntegerPointer
		ifFalse: [ ^ self primitiveFail ].
	(memory fetchByteLengthOf: integerPointer) = 2
		ifFalse: [ ^ self primitiveFail ].
	value := memory fetchByte: 1 ofObject: integerPointer.
	value := value * 256 + (memory fetchByte: 0 ofObject: integerPointer).
	^ value
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveAdd [
	"Primitive add operation (BB 622)"

	| integerReceiver integerArgument integerResult |
	integerArgument := self popInteger.
	integerReceiver := self popInteger.
	self success
		ifTrue: [ integerResult := integerReceiver + integerArgument.
			       self success: (memory isIntegerValue: integerResult) ].
	self success
		ifTrue: [ self pushInteger: integerResult ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveAsFloat [
   "Converts its SmallInteger receiver into a Float (BB 626)
   This routine first convert the receiver to a Float the size of the
   native type of the VM (32 or 64 bit) and then turn it into a IEEE 32
   bit single precision float so that it is 2 word long as expected by
   the original ST-80 VM"

   	| integerReceiver |
	integerReceiver := self popInteger.
	self success
		ifTrue: [ self pushFloat: (integerReceiver asFloat asIEEE32BitWord) ]
		ifFalse: [ self unPop: 1 ]
]

{ #category : #'storage management primitives' }
Interpreter >> primitiveAsObject [
	"The primitiveAsObject routine performs the inverse operation of primitiveAsOop.
   It only works for SmallInteger receivers (it is associated with the asObject 
   message in SmallInteger). It produces the object pointer that is twice the 
   receiver's value. The primitive fails if there is no object for that pointer. (BB 635)"

	| thisReceiver newOop |
	thisReceiver := self popStack.
	newOop := thisReceiver bitAnd: 16rFFFE.
	self success: (memory isIntegerObject: thisReceiver).
	self success
		ifTrue: [ self push: newOop ]
		ifFalse: [ self unPop: 1 ]
]

{ #category : #'storage management primitives' }
Interpreter >> primitiveAsOop [
	"The primitiveAsOop routine produces a SmallInteger whose value is half 
   of the receiver's object pointer (interpreting object pointers as 16-bit 
   signed quantities). The primitive only works for non-SmallInteger receivers. 
   Since non-SmallInteger object pointers are even, no information in the 
   object pointer is lost. Because of the encoding of SmallIntegers, the 
   halving operation can be performed by setting the least significant bit
   of the receiver's object pointer. (BB 636)"

	| thisReceiver |
	thisReceiver := self popStack.
	self success: (memory isIntegerObject: thisReceiver) == false.
	self success
		ifTrue: [ self push: (thisReceiver bitOr: 1) ]
		ifFalse: [ self unPop: 1 ]
]

{ #category : #'array stream primitives' }
Interpreter >> primitiveAt [
   "The primitiveAt simply fetch one of the indexable fields of the receiver. 
   It fails if the index is not a SmallInteger or if it is out of bounds. (BB 628)"

   | index array arrayClass result |
   index := self positive16BitValueOf: self popStack.
   array := self popStack.
   arrayClass := memory fetchClassOf: array.
   self checkIndexableBoundsOf: index in: array.

   self success
      ifTrue: [index := index + (self fixedFieldsOf: arrayClass).
               result := self subscript: array with: index].

   self success
      ifTrue: [self push: result]
      ifFalse: [self unPop: 2]
]

{ #category : #'array stream primitives' }
Interpreter >> primitiveAtEnd [
	"The primitiveAtEnd routine is an optional primitive version of the Smalltalk
   code for the atEnd message to streams. This routine only works if the object 
   being streamed is an Array or a String. (BB 632)"

	| stream array arrayClass index limit |
	stream := self popStack.
	array := memory fetchPointer: StreamArrayIndex ofObject: stream.
	arrayClass := memory fetchClassOf: array.
	index := self fetchInteger: StreamIndexIndex ofObject: stream.
	limit := self fetchInteger: StreamReadLimitIndex ofObject: stream.
	
	self success: (arrayClass = ClassArrayPointer) | (arrayClass = ClassStringPointer).
	self success
		ifTrue: [index >= limit
				     ifTrue: [ self push: TruePointer]
				     ifFalse: [ self push: FalsePointer]]
		ifFalse: [self unPop: 1]
]

{ #category : #'array stream primitives' }
Interpreter >> primitiveAtPut [
   "This routine simply store one of the indexable fields of the receiver. It fails
   if the receiver is not a pointer type and the second argument is not an 8-bit 
   (for byte-indexable objects) or 16-bit (for word-indexable objects) positive integer. 
   The primitive routine returns the stored value as its value. (BB 629)"

   | array index arrayClass value |
   value := self popStack.
   index := self positive16BitValueOf: self popStack.
   array := self popStack.
   arrayClass := memory fetchClassOf: array.
   self checkIndexableBoundsOf: index in: array.

   self success
      ifTrue: [index := index + (self fixedFieldsOf: arrayClass).
               self subscript: array with: index storing: value].
   self success
      ifTrue: [self push: value]
      ifFalse: [self unPop: 3]
]

{ #category : #'primitive methods' }
Interpreter >> primitiveBeDisplay [
	"Not BB code - This primitive is implementation dependent
	From BB p. 651
	The instance of DisplayScreen that should be used to
   update the screen is designated by sending it the message beDisplay.
   This message invokes the primitiveBeDisplay primitive routine.  
	The screen will be updated from the last recipient of 
	beDisplay approximately 60 times a second."
	
	| newDisplay width height |
	
	"Fetch the dimensions of the current display"
	newDisplay := self stackTop.
	
	currentDisplay = newDisplay ifTrue: [ ^ self ].
	
	width := self fetchInteger: WidthInForm ofObject: newDisplay.
	height := self fetchInteger: HeightInForm ofObject: newDisplay.
			
   	debug ifTrue: [ 
		Transcript show: 'newDisplay: '; nextPutAll: newDisplay printString;
		   	nextPutAll: ' width: '; nextPutAll: width printString;
			nextPutAll: ' height: '; nextPutAll: height printString; cr.
		].

	"Interesting fact: In order to save space when writing the object image
    Smalltalk resizes the display to the current width x 100 just before saving.
    When the system resumes, it will be resized to the last actual size.
    Here we ignore the change to the height of 100. (From dbanay)"
	height <= 100 ifTrue: [ ^ self ]. 
	(hal displayWidth: width displayHeight: height)
		ifFalse: [ self primitiveFail ].
	currentDisplay := newDisplay.
	currentDisplayWidth := width.
	currentDisplayHeight := height.

]

{ #category : #'storage management primitives' }
Interpreter >> primitiveBecome [
	"The primitiveBecome routine swaps the instance pointers of the receiver
   and argument. This means that all objects that used to point to the receiver
   now point to the argument and vice versa. (BB 634)"

	| thisReceiver otherPointer |
	otherPointer := self popStack.
	thisReceiver := self popStack.
	self success: (memory isIntegerObject: otherPointer) not.
	self success: (memory isIntegerObject: thisReceiver) not.
	self success
		ifTrue: [memory swapPointersOf: thisReceiver and: otherPointer.
			      self push: thisReceiver]
		ifFalse: [self unPop: 2]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveBitAnd [
	"Bit and of receiver and argument (BB 624)"

	| integerReceiver integerArgument integerResult |
	integerArgument := self popInteger.
	integerReceiver := self popInteger.
	self success
		ifTrue: [ integerResult := integerReceiver bitAnd: integerArgument ].
	self success
		ifTrue: [ self pushInteger: integerResult ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveBitOr [
	"Bit or of receiver and argument (BB 624)"

	| integerReceiver integerArgument integerResult |
	integerArgument := self popInteger.
	integerReceiver := self popInteger.
	self success
		ifTrue: [ integerResult := integerReceiver bitOr: integerArgument ].
	self success
		ifTrue: [ self pushInteger: integerResult ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveBitShift [
	"The primitive routine for shifting (associated with the selector bitShift:) 
   returns a SmallInteger whose value represented in two's-complement is the 
   receiver's value represented in two's-complement shifted left by the number
   of bits indicated by the argument. Negative arguments shift right. Zeros are 
   shifted in from the right in left shifts. The sign bit is extended in right
   shifts. This primitive fails if the correct result cannot be represented 
   as a SmallInteger. (BB 624)"

	| integerReceiver integerArgument integerResult |
	integerArgument := self popInteger.
	integerReceiver := self popInteger.
	self success
		ifTrue: [ integerResult := integerReceiver bitShift: integerArgument.
		          self success: (memory isIntegerValue: integerResult) ].
	self success
		ifTrue: [ self pushInteger: integerResult ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveBitXor [
	"Bit xor of receiver and argument (BB 624)"

	| integerReceiver integerArgument integerResult |
	integerArgument := self popInteger.
	integerReceiver := self popInteger.
	self success
		ifTrue: [ integerResult := integerReceiver bitXor: integerArgument ].
	self success
		ifTrue: [ self pushInteger: integerResult ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'control primitives' }
Interpreter >> primitiveBlockCopy [
	"The primitiveBlockCopy routine is associated with the blockCopy: message in 
   both BlockContext and MethodContext. This message is only produced by the compiler. 
   The number of block arguments the new BlockContext takes is passed as the argument. 
   The primitiveBlockCopy routine creates a new instance of BlockContext. If the 
   receiver is a MethodContext, it becomes the new BlockContext's home context. 
   If the receiver is a BlockContext, its home context is used for the new BlockContext's
   home context. (BB 638)"

	| context methodContext blockArgumentCount newContext initialIP contextSize |
	blockArgumentCount := self popStack.
	context := self popStack.
	(self isBlockContext: context)
		ifTrue: [ methodContext := memory fetchPointer: HomeIndex ofObject: context ]
		ifFalse: [ methodContext := context ].
	contextSize := memory fetchWordLengthOf: methodContext.
	newContext := memory instantiateClass: ClassBlockContextPointer
		                  withPointers: contextSize.
	initialIP := memory integerObjectOf: instructionPointer + 3.
	memory storePointer: InitialIPIndex
		    ofObject: newContext
		    withValue: initialIP.
	memory storePointer: InstructionPointerIndex
		    ofObject: newContext
		    withValue: initialIP.
	self storeStackPointerValue: 0 
	     inContext: newContext.
	memory storePointer: BlockArgumentCountIndex
		    ofObject: newContext
		    withValue: blockArgumentCount.
	memory storePointer: HomeIndex
		    ofObject: newContext
		    withValue: methodContext.
	self push: newContext
]

{ #category : #'primitive methods' }
Interpreter >> primitiveClass [
	"The primitiveClass routine is associated with the class message
	in Object. It returns the object pointer of the receiver's class. (BB 653)"
	| instance |
	instance := self popStack.
	self push: (memory fetchClassOf: instance)
]

{ #category : #'primitive methods' }
Interpreter >> primitiveCopyBits [

	| bitBltPointer bitBlt |
	
	bitBltPointer := self stackTop.
	bitBlt := ST80BitBlt bitBltPointer: bitBltPointer memory: memory.
	
	self success: ((bitBlt combinationRule) between: 0 and: 15).
	success ifFalse: [ 
		self error: ('Unsupported BitBlt combination rule: ', bitBlt combinationRule printString).  
		].
	bitBlt copyBits.

	"if the copyBits operates on the Display then update the
	application window"
	(bitBlt destForm = currentDisplay) ifTrue: [ 
		hal updateDisplayRect: Rectangle origin: 0@0  corner: 640@480 bitmap: (bitBlt destForm bitsArray).
		]

]

{ #category : #'primitive methods' }
Interpreter >> primitiveCoreLeft [
	"BB p. 653"
	Exception signal: 'NOT IMPLEMENTED YET !!'
]

{ #category : #'io primitives' }
Interpreter >> primitiveCursorLink [
	"Cause the cursor to track the pointing device location if the argument is true.
   Decouple the cursor from the pointing device if the argument is false. (BB 651)"	
			
	| flag |
	flag := self popStack.
	" set cursor link to true here"
	self vm hal cursorLink: (flag class = TruePointer)
]

{ #category : #'io primitives' }
Interpreter >> primitiveCursorLocPut [
	"Move the cursor to the screen location specified by the argument. Fail if
   the argument is not a Point. (BB 651)"	
			
	| point x y |
   point := self popStack.
   self success: (memory fetchClassOf: point == ClassPointPointer).
   self success
      ifTrue: [ x := self fetchInteger: XIndex ofObject: point.
	             y := self fetchInteger: YIndex ofObject: point.
	             "TODO: adapt to set cursor location of the VM window"
	             self currentWorld activeHand position: x@y ]
      ifFalse: [ self unPop: 1 ]

]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveDiv [
	"There are two primitive routines for rounding division (associated with 
	 the selectors // and quo:). The result of // is always rounded down (toward 
	 negative infinity). (BB 622)"

	| integerReceiver integerArgument integerResult |
	integerArgument := self popInteger.
	integerReceiver := self popInteger.
	self success: integerArgument ~= 0.
	self success
		ifTrue: [ integerResult := integerReceiver // integerArgument.
		          self success: (memory isIntegerValue: integerResult) ].
	self success
		ifTrue: [ self pushInteger: integerResult ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveDivide [
	"The primitive routine for the modulo function (associated with the 
	selector \\) gives the remainder of a division where the quotient is 
	always rounded down (toward negative infinity). This primitive fails
	if its argument is 0. (BB 623)"

	| integerReceiver integerArgument integerResult |
	integerArgument := self popInteger.
	integerReceiver := self popInteger.
	self success: integerArgument ~= 0.
	self success: integerReceiver \\ integerArgument = 0.
	self success
		ifTrue: [ integerResult := integerReceiver // integerArgument.
			       self success: (memory isIntegerValue: integerResult) ].
	self success
		ifTrue: [ self push: (memory integerObjectOf: integerResult) ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'as yet unclassified' }
Interpreter >> primitiveDrawLoop [
	"BB 652 The primitiveDrawLoop routine is an optional primitive associated
   with the drawLoopX:Y: message in BitBIt. If implemented line drawing will 
	go faster."
	self primitiveFail.
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveEqual [
	"Test two objects equality (=) (BB 623)"

	| integerReceiver integerArgument |
	integerArgument := self popInteger.
	integerReceiver := self popInteger.
	self success
		ifTrue: [ integerReceiver = integerArgument
			          ifTrue: [ self push: TruePointer ]
				       ifFalse: [ self push: FalsePointer ] ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'primitive methods' }
Interpreter >> primitiveEquivalent [
	"The primitiveEquivalent routine is associated with the = message 
	in Object. It returns true if the receiver and argument are the 
	same object (have the same object pointer) and false otherwise. (BB 653)"
	| thisObject otherObject |
	otherObject := self popStack.
	thisObject := self popStack.
	thisObject = otherObject
		ifTrue: [self push: TruePointer]
		ifFalse: [self push: FalsePointer]
]

{ #category : #'primitive methods' }
Interpreter >> primitiveExitToDebugger [
	"BB p. 653"
	Exception signal: 'NOT IMPLEMENTED YET !!'
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveExponent [
   "Returns the exponent of the receiver (optional) (BB 626)"

   ^ self primitiveFail 
]

{ #category : #'primitive failure' }
Interpreter >> primitiveFail [
	"BB code p. 616"
	success := false
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveFloatAdd [
	"Primitive float add operation (BB 626)"

	| floatReceiver floatArgument floatResult |
	floatArgument := self popFloat.
	floatReceiver := self popFloat.
	self success
		ifTrue: [ floatResult := floatReceiver + floatArgument.
			       self pushFloat:  (floatResult asIEEE32BitWord) ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveFloatDivide [
	"This routine is not implemented in the BB. it divides the float
	receiver by the float argument (BB 626)"

	| floatReceiver floatArgument floatResult |
	floatArgument := self popFloat.
	floatReceiver := self popFloat.
	self success: floatArgument ~= 0.
	self success
		ifTrue: [ floatResult := floatReceiver / floatArgument.
                self pushFloat:  (floatResult asIEEE32BitWord) ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveFloatEqual [
	"Primitive float less or equal operation (BB 626)"

	| floatReceiver floatArgument |
	floatArgument := self popFloat.
	floatReceiver := self popFloat.
	self success
		ifTrue: [ floatReceiver = floatArgument
			         ifTrue: [ self push: TruePointer ]
				      ifFalse: [ self push: FalsePointer ] ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveFloatGreaterOrEqual [
	"Primitive float less or equal operation (BB 626)"

	| floatReceiver floatArgument |
	floatArgument := self popFloat.
	floatReceiver := self popFloat.
	self success
		ifTrue: [ floatReceiver >= floatArgument
			         ifTrue: [ self push: TruePointer ]
				      ifFalse: [ self push: FalsePointer ] ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveFloatGreaterThan [
	"Primitive float less than operation (BB 626)"

	| floatReceiver floatArgument |
	floatArgument := self popFloat.
	floatReceiver := self popFloat.
	self success
		ifTrue: [ floatReceiver > floatArgument
			         ifTrue: [ self push: TruePointer ]
				      ifFalse: [ self push: FalsePointer ] ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveFloatLessOrEqual [
	"Primitive float less or equal operation (BB 626)"

	| floatReceiver floatArgument |
	floatArgument := self popFloat.
	floatReceiver := self popFloat.
	self success
		ifTrue: [ floatReceiver <= floatArgument
			         ifTrue: [ self push: TruePointer ]
				      ifFalse: [ self push: FalsePointer ] ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveFloatLessThan [
	"Primitive float less than operation (BB 626)"

	| floatReceiver floatArgument |
	floatArgument := self popFloat.
	floatReceiver := self popFloat.
	self success
		ifTrue: [ floatReceiver < floatArgument
			         ifTrue: [ self push: TruePointer ]
				      ifFalse: [ self push: FalsePointer ] ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveFloatMultiply [
	"Primitive float add operation (BB 626)"

	| floatReceiver floatArgument floatResult |
	floatArgument := self popFloat.
	floatReceiver := self popFloat.
	self success
		ifTrue: [ 
			floatResult := floatReceiver * floatArgument.
			self pushFloat: (floatResult asIEEE32BitWord) ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveFloatNotEqual [
	"Primitive float less or equal operation (BB 626)"

	| floatReceiver floatArgument |
	floatArgument := self popFloat.
	floatReceiver := self popFloat.
	self success
		ifTrue: [ floatReceiver ~= floatArgument
			         ifTrue: [ self push: TruePointer ]
				      ifFalse: [ self push: FalsePointer ] ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveFloatSubstract [
	"Primitive float substract operation (BB 626)"

	| floatReceiver floatArgument floatResult |
	floatArgument := self popFloat.
	floatReceiver := self popFloat.
	self success
		ifTrue: [ floatResult := floatReceiver - floatArgument.
			       self pushFloat: (floatResult asIEEE32BitWord) ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'control primitives' }
Interpreter >> primitiveFlushCache [
   "The primitiveFlushCache routine removes the contents of the method cache.
   Implementations that do not use a method cache can treat this as a no-op.
   (BB 647)"

   self initializeMethodCache
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveFractionalPart [
	"Primitive float fractional part operation (BB 626)"

	| floatReceiver floatResult |
	floatReceiver := self popFloat.
	self success
		ifTrue: [ floatResult := floatReceiver - floatReceiver asInteger.
			       self pushFloat: floatResult ]
		ifFalse: [ self unPop: 1 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveGreaterOrEqual [
	"Test if receiver >= argument (BB 623)"

	| integerReceiver integerArgument |
	integerArgument := self popInteger.
	integerReceiver := self popInteger.
	self success
		ifTrue: [ integerReceiver >= integerArgument
			          ifTrue: [ self push: TruePointer ]
				       ifFalse: [ self push: FalsePointer ] ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveGreaterThan [
	"Test if receiver > argument (BB 623)"

	| integerReceiver integerArgument |
	integerArgument := self popInteger.
	integerReceiver := self popInteger.
	self success
		ifTrue: [ integerReceiver > integerArgument
			          ifTrue: [ self push: TruePointer ]
				       ifFalse: [ self push: FalsePointer ] ]
		ifFalse: [ self unPop: 2 ]
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

{ #category : #'io primitives' }
Interpreter >> primitiveInputSemaphore [
	"Initialize the Semaphore to be signalled whenever an input event occurs.
   The semaphore will be signaled once for every word placed in the input 
   buffer by an I/O device. Fail if the argument is neither a Semaphore 
   nor nil. (BB 648)"	
			
	| semaphore  |
	semaphore := self popStack.
	self success: (semaphore = NilPointer | memory fetchClassOf: semaphore = ClassSemaphorePointer).
	
	self success
      "TODO: adjust for Semaphore handling in the VM"	   
	   ifTrue: [ self vm hal inputSemaphore: semaphore ]
	   ifFalse: [ self unPop: 1 ]
	
]

{ #category : #'io primitives' }
Interpreter >> primitiveInputWord [
	"Get the next word from the input buffer and remove the word from the
   buffer. This message should be sent just after the input semaphore
   finished a wait (was sent a signal by an I/O device). Fail if the input
   buffer is empty. (BB 648)"	
			
	| word |
	word := self vm hal nextInputWord.
	self success: (word ~= 0). "A value of 0 should not happen so use it as an error code"
	
	self success
		ifTrue: [ self pop: 1.
			       self push: (self positive16BitIntegerFor: word) ]
		ifFalse: [ self primitiveFail ]
]

{ #category : #'storage management primitives' }
Interpreter >> primitiveInstVarAt [
   "The primitiveInstVarAt routine is associated with the instVarAt: message
   in Object. They are similar to primitiveAt except that the numbering of 
   fields starts with the fixed fields (corresponding to named instance variables)
   instead of with the indexable fields. The indexable fields are numbered
   starting with one more than the number of fixed fields. (BB 635)"

	| thisReceiver index value |
	index := self popInteger.
	thisReceiver := self popStack.
	self checkInstanceVariableBoundsOf: index in: thisReceiver.
	self success
		ifTrue: [ value := self subscript: thisReceiver with: index ].
	self success
		ifTrue: [ self push: value ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'storage management primitives' }
Interpreter >> primitiveInstVarAtPut [
	"The primitiveInstVarAtPut routine is associated with the instVarAt:put: message
   in Object. They are similar to primitiveAtPut except that the numbering of 
   fields starts with the fixed fields (corresponding to named instance variables)
   instead of with the indexable fields. The indexable fields are numbered
   starting with one more than the number of fixed fields. (BB 635)"

	| thisReceiver index newValue |
	newValue := self popStack.
	index := self popInteger.
	thisReceiver := self popStack.
	self checkInstanceVariableBoundsOf: index in: thisReceiver.
	self success
		ifTrue: [self subscript: thisReceiver 
			           with: index
			           storing: newValue].
	self success
		ifTrue: [self push: newValue]
		ifFalse: [self unPop: 3]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveLessOrEqual [
	"Test if receiver <= argument (BB 623)"

	| integerReceiver integerArgument |
	integerArgument := self popInteger.
	integerReceiver := self popInteger.
	self success
		ifTrue: [ integerReceiver <= integerArgument
			          ifTrue: [ self push: TruePointer ]
				       ifFalse: [ self push: FalsePointer ] ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveLessThan [
	"Test if receiver < argument (BB 623)"

	| integerReceiver integerArgument |
	integerArgument := self popInteger.
	integerReceiver := self popInteger.
	self success
		ifTrue: [ integerReceiver < integerArgument
			          ifTrue: [ self push: TruePointer ]
				       ifFalse: [ self push: FalsePointer ] ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveMakePoint [
	"The primitive routine associated with the selector @ returns a new Point 
	whose x value is the receiver and whose y value is the argument. (BB 625)"

	| integerReceiver integerArgument pointResult |
	"BB code ERROR modified from dbanay implementation"
	integerArgument := self popStack.
	integerReceiver := self popStack.
	"integerArgument := self popInteger.
	integerReceiver := self popInteger."
	self success: (memory isIntegerValue: integerReceiver).
	self success: (memory isIntegerValue: integerArgument).
	self success
		ifTrue: [ pointResult := memory instantiateClass: ClassPointPointer
				                          withPointers: ClassPointSize.
					"BB code ERROR modified from dbanay implementation"
					memory storePointer: XIndex
				           ofObject: pointResult
				          withValue: integerReceiver.
			      memory storePointer: YIndex
				           ofObject: pointResult
				           withValue: integerArgument.
			       "self storeInteger: XIndex
				           ofObject: pointResult
				          withValue: integerReceiver.
			       self storeInteger: YIndex
				           ofObject: pointResult
				           withValue: integerArgument.
			       self push: pointResult" ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveMod [
	"The primitive routine for the modulo function (associated with the 
   selector \\) gives the remainder of a division where the quotient is always
   rounded down (toward negative infinity). (BB 623)"

	| integerReceiver integerArgument integerResult |
	integerArgument := self popInteger.
	integerReceiver := self popInteger.
	self success: integerArgument ~= 0.
	self success
		ifTrue: [ integerResult := integerReceiver \\ integerArgument.
			self success: (memory isIntegerValue: integerResult) ].
	self success
		ifTrue: [ self pushInteger: integerResult ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'io primitives' }
Interpreter >> primitiveMousePoint [
	"The primitiveMousePoint routine allows the location of the pointing device
	 to be polled. It allocates a new Point and stores the location of the 
	 pointing device in its x and y fields. (BB 651)"
			
	| currentPoint pointResult |
	self pop: 1. "remove receiver from stack"
	"TODO: Adapt to get coordinates relative to the simulated screen"
   currentPoint := self currentWorld activeHand position.
   "Create a point object and push it to the VM stack"
   pointResult := memory instantiateClass: ClassPointPointer withPointers: ClassPointSize.
   self storeInteger: XIndex ofObject: pointResult withValue: currentPoint x.
   self storeInteger: YIndex ofObject: pointResult withValue: currentPoint y.
	self push: pointResult
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveMultiply [
	"Primitive multiply operation (BB 622)"

	| integerReceiver integerArgument integerResult |
	integerArgument := self popInteger.
	integerReceiver := self popInteger.
	self success
		ifTrue: [ integerResult := integerReceiver * integerArgument.
			       self success: (memory isIntegerValue: integerResult) ].
	self success
		ifTrue: [ self pushInteger: integerResult ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'storage management primitives' }
Interpreter >> primitiveNew [
	"The primitiveNew routine creates a new instance of the receiver (a class)
   without indexable fields. The primitive fails if the class is indexable. (BB 634)"

	| class size |
	class := self popStack.
	size := self fixedFieldsOf: class.
	self success: (self isIndexable: class) == false.
	self success
		ifTrue: [ (self isPointers: class)
				       ifTrue: [ self push: (memory instantiateClass: class withPointers: size) ]
				       ifFalse: [ self push: (memory instantiateClass: class withWords: size) ] ]
		ifFalse: [ self unPop: 1 ]
]

{ #category : #'storage management primitives' }
Interpreter >> primitiveNewMethod [
	"The primitiveNewMethod routine is associated with the newMethod:header: message
   in CompiledMethod class. Instances of CompiledMethod are created with a special 
   message. Since the part of a CompiledMethod that contains pointers instead of 
   bytes is indicated in the header, all CompiledMethods must have a valid header. 
   Therefore, CompiledMethods are created with a message (newMethod:header:) that 
   takes the number of bytes as the first argument and the header as the second 
   argument. The header, in turn, indicates the number of pointer fields. (BB 637)"

	| header bytecodeCount class size literalCount |
	header := self popStack.
	bytecodeCount := self popInteger.
	class := self popStack.
	"ERROR from dbanay : need to initialize literal frame.
	See also Part 4 Errata of Xerox VM Booklet bullet 4"
	literalCount := self literalCountOfHeader: header.
	size := (literalCount + 1) * 2 + bytecodeCount.
	newMethod := memory instantiateClass: class withBytes: size.
	0 to: literalCount - 1 do: [ :i | 
		memory storeWord: LiteralStart + i ofObject: newMethod  withValue: NilPointer.
		].
	"Note from dbanay : using storeWord vs storePointer because it
   initialized memory with zeros and this break ref counting"
   memory storeWord: HeaderIndex ofObject: newMethod  withValue: header.
	self push: newMethod 
]

{ #category : #'storage management primitives' }
Interpreter >> primitiveNewWithArg [
	"The primitiveNewWithArg routine creates a new instance of the receiver 
   (a class) with the number of indexable fields specified by the integer 
   argument. The primitive fails if the class is not indexable. (BB 634)"

	| size class |
	size := self positive16BitValueOf: self popStack.
	"ERROR from dbanay check maw size"
	self success: size <= 65533.
	
	class := self popStack.
	self success: (self isIndexable: class).
	self success
		ifTrue: [size := size + (self fixedFieldsOf: class).
			      (self isPointers: class)
				      ifTrue: [self push: (memory instantiateClass: class withPointers: size)]
				      ifFalse: [(self isWords: class)
						             ifTrue: [self push: (memory instantiateClass: class withWords: size)]
						             ifFalse: [self push: (memory instantiateClass: class withBytes: size)]]]
		ifFalse: [self unPop: 2]
]

{ #category : #'array stream primitives' }
Interpreter >> primitiveNext [
   "The primitiveNext routine is an optional primitive version of the Smalltalk
   code for the next message to streams. This routine only works if the object 
   being streamed is an Array or a String. (BB 631)"

   | stream index limit array arrayClass result ascii |
   stream := self popStack.
   array := memory fetchPointer: StreamArrayIndex
                   ofObject: stream.
   arrayClass := memory fetchClassOf: array.
   index := self fetchInteger: StreamIndexIndex
                 ofObject: stream.
   limit := self fetchInteger: StreamReadLimitIndex
                 ofObject: stream.

   self success: index < limit.
   self success: (arrayClass ~= ClassArrayPointer) | (arrayClass = ClassStringPointer).
   self checkIndexableBoundsOf: index + 1
        in: array.

   self success
      ifTrue: [index := index + 1.
               result := self subscript: array
                              with: index].
   self success
      ifTrue: [self storeInteger: StreamIndexIndex
                    ofObject: stream
                    withValue: index].
   self success
      ifTrue: [arrayClass = ClassArrayPointer
                  ifTrue: [self push: result]
                  ifFalse: [ascii := memory integerValueOf: result.
                            self push: (memory fetchPointer: ascii
                                               ofObject: CharacterTablePointer)]]
     ifFalse: [self unPop: 1]
]

{ #category : #'storage management primitives' }
Interpreter >> primitiveNextInstance [
	"The primitiveSomeInstance and primitiveNextInstance routines allow for
   the enumeration of the instances of a class. They rely on the ability 
   of the object memory to define an ordering on object pointers, to find
   the first instance of a class in that ordering, and, given an object 
   pointer, to find the next instance of the same class. (BB 637)"

	"Note: the original source code in the BB uses the ObjectMemory >> instancesOf
   routine but it is not implemented anywahere in the ObjectMemory class
   so the code is revised here (source: 
   https://github.com/dbanay/Smalltalk/blob/6a7619cba3d7a3bd3d9807e429bf00d6c6886061/src/interpreter.cpp#L5160"

	| object instance |
	object := self popStack.
	instance := memory instanceAfter: object.
	instance = NilPointer
		ifTrue: [ self primitiveFail ]
		ifFalse: [ self push: instance ]
]

{ #category : #'array stream primitives' }
Interpreter >> primitiveNextPut [
	"The primitiveNextPut routine is an optional primitive version of the Smalltalk
   code for the nextPut: message to streams. This routine only works if the object 
   being streamed is an Array or a String. (BB 631)"

	| value stream index limit array arrayClass ascii |
	value  := self popStack.
	stream := self popStack.
	array  := memory fetchPointer: StreamArrayIndex ofObject: stream.
	arrayClass := memory fetchClassOf: array.
	index := self fetchInteger: StreamIndexIndex ofObject: stream.
	limit := self fetchInteger: StreamWriteLimitIndex ofObject: stream.
	self success: index < limit.
	self success: 
	   (arrayClass = ClassArrayPointer) | (arrayClass = ClassStringPointer).
	self checkIndexableBoundsOf: index + 1 in: array.
	
	self success
		ifTrue: [index := index + 1.
			      arrayClass = ClassArrayPointer
				      ifTrue: [self subscript: array with: index storing: value]
				      ifFalse: [ascii := memory fetchPointer: CharacterValueIndex ofObject: value.
					             self subscript: array with: index storing: ascii]].
	self success
		ifTrue: [self storeInteger: StreamIndexIndex
				        ofObject: stream
				        withValue: index].
	self success
		ifTrue: [self push: value]
		ifFalse: [self unPop: 2]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveNotEqual [
	"Test two objects inequality (~=) (BB 623)"

	| integerReceiver integerArgument |
	integerArgument := self popInteger.
	integerReceiver := self popInteger.
	self success
		ifTrue: [ integerReceiver ~= integerArgument
			          ifTrue: [ self push: TruePointer ]
				       ifFalse: [ self push: FalsePointer ] ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'storage management primitives' }
Interpreter >> primitiveObjectAt [
	"The primitiveObjectAt routine is associated with the objectAt: message 
   in CompiledMethod. It provides access to the object pointer fields of the
   receiver (the method header and the literals) from Smalltalk. The header
   is accessed with an index of 1 and the literals are accessed with indices
   2 through the number of literals plus 1. This message is used primarily
   by the compiler. (BB 633)"

	| thisReceiver index |
	index := self popInteger.
	thisReceiver := self popStack.
	self success: index > 0.
	self success: index <= (self objectPointerCountOf: thisReceiver).
	self success
		ifTrue: [ self push: (memory fetchPointer: index - 1 
			                          ofObject: thisReceiver) ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'storage management primitives' }
Interpreter >> primitiveObjectAtPut [
	"The primitiveObjectAtPut routine is associated with the objectAt: message 
   in CompiledMethod. It provides access to the object pointer fields of the
   receiver (the method header and the literals) from Smalltalk. The header
   is accessed with an index of 1 and the literals are accessed with indices
   2 through the number of literals plus 1. This message is used primarily
   by the compiler. (BB 634)"

	| thisReceiver index newValue |
	newValue := self popStack.
	index := self popInteger.
	thisReceiver := self popStack.
	self success: index > 0.
	self success: index <= (self objectPointerCountOf: thisReceiver).
	self success
		ifTrue: [ memory storePointer: index - 1
				           ofObject: thisReceiver
				           withValue: newValue.
			      self push: newValue ]
		ifFalse: [ self unPop: 3 ]
]

{ #category : #'primitive methods' }
Interpreter >> primitiveOopsLeft [
	"BB p. 653"
	Exception signal: 'NOT IMPLEMENTED YET !!'
]

{ #category : #'control primitives' }
Interpreter >> primitivePerform [
	"The primitivePerform routine is associated with all 'perform' messages 
   in Object (perform:, perform:with:, perform:with:with:, and so on). It 
   is equivalent to sending a message to the receiver whose selector is the 
   first argument of and whose arguments are the remaining arguments. It is, 
   therefore, similar to the sendSelector:argumentCount: routine except that 
   it must get rid of the selector from the stack before calling executeNewMethod 
   and it must check that the CompiledMethod it finds takes one less argument 
   than the 'perform' message did. The primitive fails if the number of arguments 
   does not match. (BB 640)"

	| performSelector newReceiver selectorIndex |
	performSelector := messageSelector.
	messageSelector := self stackValue: argumentCount - 1.
	newReceiver := self stackValue: argumentCount.
	self lookupMethodInClass: (memory fetchClassOf: newReceiver).
	self success: (self argumentCountOf: newMethod) = (argumentCount - 1).
	self success
		ifTrue: [ selectorIndex := stackPointer - argumentCount + 1.
			       self transfer: argumentCount - 1
				         fromIndex: selectorIndex + 1
				         ofObject: activeContext
				         toIndex: selectorIndex
				         ofObject: activeContext.
			      self pop: 1.
			      argumentCount := argumentCount - 1.
			     self executeNewMethod ]
		ifFalse: [ messageSelector := performSelector ]
]

{ #category : #'control primitives' }
Interpreter >> primitivePerformWithArgs [
	"The primitivePerformWithArgs routine is associated with the performWithArguments:
   messages in Object. It is basically the same as the primitivePerform routine except
   that the message arguments come in a single Array argument to the performWithArguments: 
   message instead of as multiple arguments to the 'perform' message. (BB 641)"

	| thisReceiver performSelector argumentArray arrayClass arraySize index |
	argumentArray := self popStack.
	arraySize := memory fetchWordLengthOf: argumentArray.
	arrayClass := memory fetchClassOf: argumentArray.
	self
		success: stackPointer + arraySize < (memory fetchWordLengthOf: activeContext).
	self success: arrayClass = ClassArrayPointer.
	self success
		ifTrue: [ performSelector := messageSelector.
			messageSelector := self popStack.
			thisReceiver := self stackTop.
			argumentCount := arraySize.
			index := 1.
			[ index <= argumentCount ]
				whileTrue: [ self push: (memory fetchPointer: index - 1 
					                             ofObject: argumentArray).
					         index := index + 1 ].
			self lookupMethodInClass: (memory fetchClassOf: thisReceiver).
			self success: (self argumentCountOf: newMethod) = argumentCount.
			self success
				ifTrue: [ self executeNewMethod ]
				ifFalse: [ self pop: argumentCount.
					        self push: messageSelector.
					        self push: argumentArray.
					        argumentCount := 2.
					        messageSelector := performSelector ] ]
		ifFalse: [ self unPop: 1 ]
]

{ #category : #'primitive methods' }
Interpreter >> primitiveQuit [
	"BB p. 653"
	Exception signal: 'NOT IMPLEMENTED YET !!'
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveQuo [
	"The result of quo: is truncated (rounded toward zero). (BB 622)"

	| integerReceiver integerArgument integerResult |
	integerArgument := self popInteger.
	integerReceiver := self popInteger.
	self success: integerArgument ~= 0.
	self success
		ifTrue: [ integerResult := integerReceiver quo: integerArgument.
			       self success: (memory isIntegerValue: integerResult) ].
	self success
		ifTrue: [ self pushInteger: integerResult ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'primitive methods' }
Interpreter >> primitiveResponse [
   "The presence of a primitive is detected by the primitiveResponse routine
    called in executeNewMethod. The primitiveResponse routine is similar to 
    the specialSelectorPrimitiveResponse routine in that it returns true if 
    a primitive response was successfully made and false otherwise. (BB 620)"
   | flagValue |
   primitiveIndex = 0
      ifTrue: [flagValue := self flagValueOf: newMethod.
               flagValue = 5
                  ifTrue: [self quickReturnSelf. 
	                        ^ true].
               flagValue = 6
                  ifTrue: [self quickInstanceLoad.
	                        ^ true].
               ^ false]
   ifFalse: [self initPrimitive.
             self dispatchPrimitives.
             ^ self success]
]

{ #category : #'control primitives' }
Interpreter >> primitiveResume [
   "The primitiveResume routine is associated with the resume message in 
    Process. It simply calls the resume: routine with the receiver as 
    argument. (BB 647)"

   self resume: self stackTop
]

{ #category : #'io primitives' }
Interpreter >> primitiveSampleInterval [
	"Set the minimum time span between events generated by the ponting
	device. The argument is a SmallInteger representing the number 
   of milliseconds. Fail if the argument is not a SmallInteger. (BB 648)"	
			
	| interval |
	interval := self popStack.
	self success: (memory isIntegerObject: interval).
	
	self success
      "TODO: adjust for call below handling in the VM"	   
	   ifTrue: [ self vm hal sampleInterval: interval ]
	   ifFalse: [ self unPop: 1 ]
]

{ #category : #'primitive methods' }
Interpreter >> primitiveScanCharacters [
   "TODO: Do not implement native implementation for now"
	self primitiveFail.

"	| scannerPointer  characterScan |
	
	scannerPointer := self stackTop.
	characterScan  := ST80CharacterScanner scannerPointer: scannerPointer memory: memory.
	
	self success: ((scannerPointer combinationRule) between: 0 and: 15).
	success ifFalse: [ 
		self error: ('Unsupported BitBlt combination rule in Character Scanner: ', scannerPointer combinationRule printString).  
		].
	
"
]

{ #category : #'control primitives' }
Interpreter >> primitiveSignal [
   "The primitiveSignal routine is associated with the signal message in 
   Semaphore. Since it is called in the process of interpreting a bytecode, 
   it can use the synchronousSignal: routine. Any other signaling of Semaphores
   by the interpreter (for example, for timeouts and keystrokes) must use the
   asynchronousSignal: routine. (BB 646)"

   self synchronousSignal: self stackTop
]

{ #category : #'primitive methods' }
Interpreter >> primitiveSignalAtOopsLeftWordsLeft [
	"BB p. 653"
	Exception signal: 'NOT IMPLEMENTED YET !!'
]

{ #category : #'array stream primitives' }
Interpreter >> primitiveSize [
   "The primitiveSize routine returns the number of indexable fields the receiver 
   has (i.e., the largest legal subscript). (BB 629)"

   | array class length |
   array := self popStack.
	"Line below not in BB code. See dbanay implementation"
	self success: ((memory isIntegerObject: array ) not).
   class := memory fetchClassOf: array.
   length := self positive16BitIntegerFor: (self lengthOf: array) - (self fixedFieldsOf: class).

   self success
      ifTrue: [self push: length]
      ifFalse: [self unPop: 1]
]

{ #category : #'storage management primitives' }
Interpreter >> primitiveSomeInstance [
	"The primitiveSomeInstance and primitiveNextInstance routines allow for
   the enumeration of the instances of a class. They rely on the ability 
   of the object memory to define an ordering on object pointers, to find
   the first instance of a class in that ordering, and, given an object 
   pointer, to find the next instance of the same class. (BB 637)"

	"Note: the original source code in the BB uses the ObjectMemory >> instancesOf
   routine but it is not implemented anywahere in the ObjectMemory class
   so the code is revised here (source: 
   https://github.com/dbanay/Smalltalk/blob/6a7619cba3d7a3bd3d9807e429bf00d6c6886061/src/interpreter.cpp#L5099"

	| class instance |
	class := self popStack.
	instance := memory initialInstanceOf: class.
	instance = NilPointer
		ifTrue: [ self primitiveFail ]
		ifFalse: [ self push: instance ]
]

{ #category : #'array stream primitives' }
Interpreter >> primitiveStringAt [
   "The primitiveStringAt routine is a special response to the at: message 
   by instances of String. A String actually stores 8-bit numbers in byte-indexable
   fields, but it communicates through the at: message with instances of Character.

   A Character has a single instance variable that holds a SmallInteger. The
   value of the SmallInteger returned from the at: message is then stored in
   the indicated field of the String. The primitiveStringAt routine always
   returns the same instance of Character for any particular value. It gets
   the Characters from an Array in the object memory that has a guaranteed
   object pointer called CharacterTablePointer. (BB 630)"

   | index array ascii character |
   index := self positive16BitValueOf: self popStack.
   array := self popStack.
   self checkIndexableBoundsOf: index in: array.

   self success
      ifTrue: [ascii := memory integerValueOf: (self subscript: array with: index).
              character := memory fetchPointer: ascii
                                  ofObject: CharacterTablePointer].

   self success
      ifTrue:[self push: character]
      ifFalse: [self unPop: 2]
]

{ #category : #'array stream primitives' }
Interpreter >> primitiveStringAtPut [
   "The primitiveStringAtPut routine is a special response to the at:put: message 
   by instances of String. A String actually stores 8-bit numbers in byte-indexable
   fields, but it communicates through the at: message with instances of Character.

   A Character has a single instance variable that holds a SmallInteger. The
   value of the SmallInteger returned from the at: message is then stored in
   the indicated field of the String. It gets the Characters from an Array
   in the object memory that has a guaranteed object pointer called 
   CharacterTablePointer. (BB 630)"

   | index array ascii character |
   character := self popStack.
   index := self positive16BitValueOf: self popStack.
   array := self popStack.
   self checkIndexableBoundsOf: index in: array.
   self success: (memory fetchClassOf: character) = ClassCharacterPointer.

   self success
      ifTrue: [ascii := memory fetchPointer: CharacterValueIndex
                               ofObject: character.
               self subscript: array with: index storing: ascii].

   self success
      ifTrue: [self push: character]
      ifFalse: [self unPop: 3]
]

{ #category : #'as yet unclassified' }
Interpreter >> primitiveStringReplace [
	"BB 648 undocumented"
	self primitiveFail.
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveSubtract [
	"Primitive substract operation (BB 622)"

	| integerReceiver integerArgument integerResult |
	integerArgument := self popInteger.
	integerReceiver := self popInteger.
	self success
		ifTrue: [ integerResult := integerReceiver - integerArgument.
			       self success: (memory isIntegerValue: integerResult) ].
	self success
		ifTrue: [ self pushInteger: integerResult ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'control primitives' }
Interpreter >> primitiveSuspend [
   "The primitiveSuspend routine is associated with the suspend message in 
   Process. The primitiveSuspend routine suspends the receiver if it is the 
   active Process. If the receiver is not the active Process, the primitive 
   fails. (BB 647)"

   self success: self stackTop = self activeProcess.
   self success
      ifTrue: [self popStack.
               self push: NilPointer.
               self suspendActive]
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveTimesTwoPower [
   "Increases the exponent of the receiver by an amount specified by the
   argument (optional) (BB 626)"

   ^ self primitiveFail 
]

{ #category : #'arithmetic primitives' }
Interpreter >> primitiveTruncated [
	"Primitive float truncate operation (BB 626)"

	| floatReceiver integerResult |
	floatReceiver := self popFloat.
	self success
		ifTrue: [ integerResult := floatReceiver asInteger.
			       self success: (memory isIntegerValue: integerResult) ].
	self success 
	   ifTrue: [ self pushInteger: integerResult ]
		ifFalse: [ self unPop: 1 ]
]

{ #category : #'control primitives' }
Interpreter >> primitiveValue [
	"The primitiveValue routine is associated with all 'value' messages in
   BlockContext (value, value:, value:value:, and so on). It checks that 
   the receiver takes the same number of block arguments that the 'value'
   message did and then transfers them from the active context's stack to 
   the receiver's stack. The primitive fails if the number of arguments do 
   not match. The primitiveValue routine also stores the active context in
   the receiver's caller field and initializes the receiver's instruction 
   pointer and stack pointer. After the receiver has been initialized, it 
   becomes the active context. (BB 639)"

	| blockContext blockArgumentCount initialIP |
	blockContext := self stackValue: argumentCount.
	blockArgumentCount := self argumentCountOfBlock: blockContext.
	self success: argumentCount = blockArgumentCount.
	self success
		ifTrue: [ self transfer: argumentCount
				         fromIndex: stackPointer - argumentCount + 1
				         ofObject: activeContext
				         toIndex: TempFrameStart
				         ofObject: blockContext.
			      self pop: argumentCount + 1.
			      initialIP := memory fetchPointer: InitialIPIndex
				                       ofObject: blockContext.
			      memory storePointer: InstructionPointerIndex
				          ofObject: blockContext
				          withValue: initialIP.
			      self storeStackPointerValue: argumentCount inContext: blockContext.
			      memory storePointer: CallerIndex
				          ofObject: blockContext
				          withValue: activeContext.
			      self newActiveContext: blockContext ]
]

{ #category : #'control primitives' }
Interpreter >> primitiveValueWithArgs [
	"The primitiveValueWithArgs routine is associated with the valueWithArguments:
   messages in BlockContext. It is basically the same as the primitiveValue 
   routine except that the block arguments come in a single Array argument to 
   the valueWithArguments: message instead of as multiple arguments to the 
   'value' message. (BB 639)"

	| argumentArray blockContext blockArgumentCount arrayClass arrayArgumentCount initialIP |
	argumentArray := self popStack.
	blockContext := self popStack.
	blockArgumentCount := self argumentCountOfBlock: blockContext.
	arrayClass := memory fetchClassOf: argumentArray.
	self success: arrayClass = ClassArrayPointer.
	self success
		ifTrue: [ arrayArgumentCount := memory fetchWordLengthOf: argumentArray.
			       self success: arrayArgumentCount = blockArgumentCount ].
	self success
		ifTrue: [ self transfer: arrayArgumentCount
				         fromIndex: 0
				         ofObject: argumentArray
				         toIndex: TempFrameStart
				         ofObject: blockContext.
                initialIP := memory fetchPointer: InitialIPIndex
				                        ofObject: blockContext.
                memory storePointer: InstructionPointerIndex
				           ofObject: blockContext
				           withValue: initialIP.
			      self storeStackPointerValue: arrayArgumentCount
				        inContext: blockContext.
			      memory storePointer: CallerIndex
				          ofObject: blockContext
				          withValue: activeContext.
			      self newActiveContext: blockContext ]
		ifFalse: [ self unPop: 2 ]
]

{ #category : #'control primitives' }
Interpreter >> primitiveWait [
   "The primitiveWait routine is associated with the wait message in Semaphore. 
   If the receiver has an excess signal count greater than 0, primitiveWait 
   routine decrements the count. If the excess signal count is 0, the primitiveWait
   suspends the active Process and adds it to the receiver's list of Processes. 
  (BB 646)"

   | thisReceiver excessSignals |
   thisReceiver := self stackTop.
   excessSignals := self fetchInteger: ExcessSignalsIndex ofObject: thisReceiver.
   excessSignals > 0
      ifTrue: [self storeInteger: ExcessSignalsIndex
                    ofObject: thisReceiver
                    withValue: excessSignals - 1]
      ifFalse: [self addLastLink: self activeProcess
                toList: thisReceiver.
                self suspendActive]
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
	debug ifTrue: [ 
		Transcript show: 'Push Active Context' ; cr.
	   ].
	^ self push: activeContext
]

{ #category : #'stack bytecodes' }
Interpreter >> pushConstantBytecode [
   "The pushConstantBytecode routine pushes one of seven constant object 
   pointers (true, false, nil, -1, 0, 1, or 2). (BB 600)"

	debug ifTrue: [ 
		Transcript show: 'Push Receiver '; 
		nextPutAll: (PushBytecodeReceivers at: (currentBytecode - 112)) printString; cr.
	   ].
   currentBytecode = 113 ifTrue: [^self push: TruePointer].
   currentBytecode = 114 ifTrue: [^self push: FalsePointer].
   currentBytecode = 115 ifTrue: [^self push: NilPointer].
   currentBytecode = 116 ifTrue: [^self push: MinusOnePointer].
   currentBytecode = 117 ifTrue: [^self push: ZeroPointer].
   currentBytecode = 118 ifTrue: [^self push: OnePointer].
   currentBytecode = 119 ifTrue: [^self push: TwoPointer]
]

{ #category : #'primitive methods' }
Interpreter >> pushFloat: floatValue [
   "This routine is not implemented in the BB. It is needed to push a 32 bit
    Float on the stack (see primitiveAsFloat)"

   | objectPointer |
   "Create a Float object (IEEE 32 bits = 2 words long), split it in 2 words and
   store it in the class instance"
   objectPointer := memory instantiateClass: ClassFloatPointer withWords: 2.
   memory storeWord: 0 ofObject: objectPointer withValue: (floatValue bitAnd: 16rffff).
   memory storeWord: 1 ofObject: objectPointer withValue: floatValue >> 16.
	self push: objectPointer 
]

{ #category : #'primitive methods' }
Interpreter >> pushInteger: integerValue [
   "Recall that the fetchInteger:ofObject: routine signaled a primitive 
   failure if the indicated field did not contain a SmallInteger. The 
   pushInteger: routine converts a value to a SmallInteger and pushes 
   it on the stack. (BB 617)"

   self push: (memory integerObjectOf: integerValue)
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
	debug ifTrue: [ 
	Transcript show: 'Push Literal Constant #'; 
		nextPutAll: fieldIndex printString; cr.
	   ].
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
	debug ifTrue: [ 
	Transcript show: 'Push Literal Variable #'; 
		nextPutAll: fieldIndex printString; cr.
	   ].
	self pushLiteralVariable: fieldIndex
]

{ #category : #'stack bytecodes' }
Interpreter >> pushReceiverBytecode [
	"This routine pushes a pointer to the active context's receiver. 
   This corresponds to the use of self or super in a Smalltalk method. (BB 599)"
	debug ifTrue: [ 
		Transcript show: 'Push Receiver '; 
		  nextPutAll: receiver printString; cr.
	   ].
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
	debug ifTrue: [ 
		Transcript show: 'Push Receiver Variable #'; 
			nextPutAll: fieldIndex printString; cr.
		 ].
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
	debug ifTrue: [ 
	Transcript show: 'Push Temporary Variable #'; 
		nextPutAll: fieldIndex printString; cr.
	   ].
	self pushTemporaryVariable: fieldIndex
]

{ #category : #'primitive methods' }
Interpreter >> quickInstanceLoad [
	"Returns an instance variable of the receiver (BB 620)"

	| thisReceiver fieldIndex |
	thisReceiver := self popStack.
	fieldIndex := self fieldIndexOf: newMethod.
	self push: (memory fetchPointer: fieldIndex ofObject: thisReceiver)
]

{ #category : #'primitive methods' }
Interpreter >> quickReturnSelf [
   "Returning self is a no-op as far as the interpreter is concerned since 
    self's object pointer occupies the same place on the stack as the message
    receiver that it should occupy as the message response. (BB 620)"
]

{ #category : #'control primitives' }
Interpreter >> removeFirstLinkOfList: aLinkedList [
   "If the object memory automatically deallocates objects on the basis of 
   reference counting, special consideration must be given to reference counting 
   in the process scheduling routines. During the execution of some of these 
   routines, there will be times at which there are no references to some 
   object from the object memory (e.g., after a Process has been removed from
   a Semaphore but before it has been placed on one of the ProcessorScheduler's
   LinkedLists). If the object memory uses garbage collection, it simply must avoid
   doing a collection in the middle of a primitive routine. The routines listed
   here ignore the reference-counting problem in the interest of clarity. 
   Implementations using reference-counting will have to modify these routines
   in order to prevent premature deallocation of objects.

   Routines removeFirstLinkOfList:, addLastLink:toList: and isEmptyList: are used 
   to manipulate LinkedLists. (BB 644)"

	"From dbanay: The routines listed here ignore the reference-counting 
	problem in the interest of clarity. (BB pg. 644).
   Found and fixed. -dbanay"

   | firstLink lastLink nextLink |
   firstLink := memory fetchPointer: FirstLinkIndex
                       ofObject: aLinkedList.

    "Also from dbanayWhen the link list is updated the references to fistLink
    will drop to zero. So, we need to return an increased pointer that
    must be decreased by the caller.
    Calls sequence:
         suspendActive ->  wakeHighestPriority -> removeFirstLinkOfList ->
         synchronousSignal -> removeFirstLinkOfList."

	"dbanay: protect it in case lastLink = firstLink"
	memory increaseReferencesTo: firstLink.

   lastLink := memory fetchPointer: LastLinkIndex
                      ofObject: aLinkedList.
   lastLink = firstLink
      ifTrue: [memory storePointer: FirstLinkIndex
                      ofObject: aLinkedList
                      withValue: NilPointer.
              memory storePointer: LastLinkIndex
                     ofObject: aLinkedList
                     withValue: NilPointer]
      ifFalse: [nextLink := memory fetchPointer: NextLinkIndex
                                   ofObject: firstLink.
                memory storePointer: FirstLinkIndex
                       ofObject: aLinkedList
                       withValue: nextLink].
   memory storePointer: NextLinkIndex
          ofObject: firstLink
          withValue: NilPointer.
   ^firstLink
]

{ #category : #'control primitives' }
Interpreter >> resume: aProcess [
   "Resume given process (BB 646)"

   | activeProcess activePriority newPriority |
   activeProcess := self activeProcess.
   activePriority := self fetchInteger: PriorityIndex
                          ofObject: activeProcess.
   newPriority := self fetchInteger: PriorityIndex
                       ofObject: aProcess.
   newPriority > activePriority
      ifTrue: [self sleep: activeProcess.
               self transferTo: aProcess]
      ifFalse: [self sleep: aProcess]
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

	debug ifTrue: [ 
		(currentBytecode = 120) 
			ifTrue: [ 
				Transcript nextPutAll: 'Return '; 
					nextPutAll: receiver printString; cr.
		 		]
			ifFalse: [ 
				(currentBytecode between: 121 and: 123) 
					ifTrue: [ 
						Transcript nextPutAll: 'Return '; 
							nextPutAll: (ReturnBytecodeTypes at: (currentBytecode - 120)) printString; cr.
		 				]
					ifFalse: [ "Bytecode 124, 125"
						Transcript nextPutAll: 'Return Top Stack from '; 
							nextPutAll: (ReturnTopStackTypes at: (currentBytecode - 123)) printString; cr.
		 				]
					]
			].			
				 

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

{ #category : #'control primitives' }
Interpreter >> schedulerPointer [
   "The instance of ProcessorScheduler responsible for scheduling the actual
   processor needs to be known globally so that the primitives will know where
   to resume and suspend Processes. This ProcessorScheduler is bound to the 
   name Processor in the Smalltalk global dictionary. The association 
   corresponding to Processor has a guaranteed object pointer, so the 
   appropriate ProcessorScheduler can be found. (BB 644)"

   ^memory fetchPointer: ValueIndex
      ofObject: SchedulerAssociationPointer
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

	| selector literalIndex argCount|
	literalIndex := self extractBits: 12 to: 15 
	                     of: currentBytecode.
	argCount := (self extractBits: 10 to: 11 
		              of: currentBytecode) - 1.
	debug ifTrue: [ 
		Transcript show: 'Send Literal Selector #'; 
			nextPutAll: literalIndex  printString; 
			nextPutAll: ' With ';
			nextPutAll: argCount printString;
			nextPutAll: ' Arguments'; 			 
			cr.
		].
	
	selector := self literal: literalIndex.
	self sendSelector: selector
		  argumentCount: argCount
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
	debug ifTrue: [ 
		Transcript show: 'sendSelector selector: '; nextPutAll: selector printString; 
		nextPutAll: ' argumentCount: ';nextPutAll: count printString; 
		nextPutAll: ' newReceiver: '; nextPutAll: newReceiver printString; cr.
		].
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
	debug ifTrue: [ 

		(currentBytecode between: 176 and: 191 )
			ifTrue: [
				Transcript show: 'Send Arithmetic Message #'; 
					nextPutAll: (currentBytecode - 176) printString; 
					cr.
					]
			ifFalse: [ "Bytecode 192-207"
				Transcript show: 'Send Special Message #'; 
					nextPutAll: (currentBytecode - 192) printString; 
					cr.
					]
			].

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
	debug ifTrue: [ 
		Transcript show: 'Pop and Jump On False '; 
			nextPutAll: (offset+1) printString; 	 
			cr.
		].
	self jumpIf: FalsePointer by: offset + 1
]

{ #category : #'stack bytecodes' }
Interpreter >> shortUnconditionalJump [
	"The eight short unconditional jumps advance the instruction pointer by 1 through 8. (BB 602)"

	| offset |
	offset := self extractBits: 13 to: 15 of: currentBytecode.
	debug ifTrue: [ 
		Transcript show: 'Jump '; 
			nextPutAll: (offset+1) printString; 	 
			cr.
		].
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

   | descriptor selectorIndex argCount |
   descriptor := self fetchByte.
   selectorIndex := self extractBits: 11 to: 15
                         of: descriptor.
	argCount := self extractBits: 8 to: 10
                         of: descriptor.
	debug ifTrue: [ 
		Transcript show: 'Send Literal Selector #'; 
			nextPutAll: selectorIndex printString; 
			nextPutAll: ' With '; 
			nextPutAll: argCount printString;
			nextPutAll: ' Arguments'; 			 
			cr.
		].

  self sendSelector: (self literal: selectorIndex)
      argumentCount: argCount
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
	debug ifTrue: [ 
		Transcript show: 'Send Literal Selector #'; 
			nextPutAll: selectorIndex printString; 
			nextPutAll: ' To Super Class With '; 
			nextPutAll: argumentCount printString;
			nextPutAll: ' Arguments';		 
			cr.
		].

	messageSelector := self literal: selectorIndex.
	methodClass := self methodClassOf: method.
	self sendSelectorToClass: (self superclassOf: methodClass)
]

{ #category : #'control primitives' }
Interpreter >> sleep: aProcess [
   "Add links to the ProcessorScheduler's LinkedLists of quiescent Processes. (BB 646)"

   | priority processLists processList |
   priority := self fetchInteger: PriorityIndex
                    ofObject: aProcess.
   processLists := memory fetchPointer: ProcessListsIndex
                          ofObject: self schedulerPointer.
   processList := memory fetchPointer: priority - 1
                         ofObject: processLists.
   self addLastLink: aProcess
        toList: processList
]

{ #category : #'primitive methods' }
Interpreter >> specialSelectorPrimitiveResponse [
	"The first path to a primitive routine was represented by the call on 
   specialSelectorPrimitiveResponse in the sendSpecialSelectorBytecode routine.
   The specialSelectorPrimitiveResponse routine selects an appropriate primitive
   routine and returns true if a primitive response was successfully made 
   and false otherwise. Recall that the sendSpecialSelectorBytecode routine 
   looks up the special selector if specialSelectorPrimitiveResponse returns
   false. (BB 618)"

	self initPrimitive.
	(currentBytecode between: 176 and: 191)
		ifTrue: [ self arithmeticSelectorPrimitive ].
	(currentBytecode between: 192 and: 207)
		ifTrue: [ self commonSelectorPrimitive ].
	^ self success
]

{ #category : #'bytecode dispatch' }
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
	debug ifTrue: [ 
		Transcript show: 'Pop and Store Receiver Variable #'; 
			nextPutAll: variableIndex printString; cr.
	   ].
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
	debug ifTrue: [ 
		Transcript show: 'Pop and Store Temporary Variable #'; 
			nextPutAll: variableIndex printString; cr.
	   	].	
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
	debug ifTrue: [ 
		Transcript show: 'storeInstructionPointerValue value: '; nextPutAll: value printString;
		   nextPutAll: ' contextPointer: '; nextPutAll: contextPointer printString; cr.
		].
	self
		storeInteger: InstructionPointerIndex
		ofObject: contextPointer
		withValue: value
]

{ #category : #'field access' }
Interpreter >> storeInteger: fieldIndex ofObject: objectPointer withValue: integerValue [
	"stores the pointer of the SmallInteger with specified value in the specified field (BB 574)"

	| integerPointer |
	
	debug ifTrue: [ 
		Transcript show: 'storeInteger: '; nextPutAll: fieldIndex printString;
	   nextPutAll: ' ofObject: '; nextPutAll: objectPointer printString;
	   nextPutAll: ' WithValue: '; nextPutAll: integerValue printString; cr.
		].
	
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

{ #category : #'array stream primitives' }
Interpreter >> subscript: array with: index [
   "Get value at index in array. Note: this routine assume that the number
   of fixed fields has been added into the index, so they use it as a 
   one-relative index into the object as a whole. (BB 628)"

	| class value |
	class := memory fetchClassOf: array.
	(self isWords: class)
		ifTrue: [(self isPointers: class)
						ifTrue: [^memory fetchPointer: index - 1
      						 				  ofObject: array]
						ifFalse: [value := memory fetchWord: index - 1
       					                       ofObject: array.
									^self positive16BitIntegerFor: value]]
		ifFalse: [value := memory fetchByte: index - 1
       								 ofObject: array.
					^memory integerObjectOf: value]
]

{ #category : #'array stream primitives' }
Interpreter >> subscript: array with: index storing: value [
   "Set value at index in array. Note: this routine assume that the number
   of fixed fields has been added into the index, so they use it as a 
   one-relative index into the object as a whole. (BB 628)"

   | class |
   class := memory fetchClassOf: array.
   (self isWords: class)
      ifTrue: [(self isPointers: class)
                  ifTrue: [^memory storePointer: index - 1
                                    ofObject: array
                                    withValue: value]
                  ifFalse: [self success: (memory isIntegerObject: value).
                     self success ifTrue:
                     [^memory storeWord: index - 1
                                   ofObject: array
                                 withValue: (self positive16BitValueOf: value)]]]
      ifFalse: [self success: (memory isIntegerObject: value).
                self success ifTrue:
                   [^memory storeByte: index - 1
                            ofObject: array
                            withValue: (self lowByteOf: (memory integerValueOf: value))]]
]

{ #category : #'primitive methods' }
Interpreter >> success [
   "test the state of the primitive success register (BB 616)"
   ^ success
]

{ #category : #'primitive methods' }
Interpreter >> success: successValue [
   "set the state of the primitive success register (BB 616)"

   success := successValue & success
]

{ #category : #classes }
Interpreter >> superclassOf: classPointer [
	"get the value of the super class given a class pointer (BB 589)"

	^ memory fetchPointer: SuperclassIndex ofObject: classPointer
]

{ #category : #'control primitives' }
Interpreter >> suspendActive [
   "Suspend active process (BB 646)"

	| aProcess |
	"Original code :
	self transferTo: self wakeHighestPriority"
	"Modified code from dbanay"
	"Note: wakeHighestPriority returns a pointer that must be decreased by caller"	
	aProcess := self wakeHighestPriority.
	self transferTo: aProcess.
	memory decreaseReferencesTo: aProcess.
]

{ #category : #'control primitives' }
Interpreter >> synchronousSignal: aSemaphore [
   "The Semaphores will actually be signaled in the checkProcessSwitch 
   routine which calls the synchronousSignal: routine once for each Semaphore 
   in the buffer. If a Process is waiting for the Semaphore, the 
   synchronousSignal: routine resumes it. If no Process is waiting, the 
   synchronousSignal: routine increments the Semaphore's count of excess 
   signals. The isEmptyList:, resume:, and removeFirstLinkOfList: routines 
   are described later in this section. (BB 643)"

   | excessSignals aProcess |
   (self isEmptyList: aSemaphore)
      ifTrue: [
			excessSignals := self fetchInteger: ExcessSignalsIndex
                               ofObject: aSemaphore.
         self storeInteger: ExcessSignalsIndex
              ofObject: aSemaphore
              withValue: excessSignals + 1]
		" Error correction on original code from dbanay"
      "ifFalse: [self resume: (self removeFirstLinkOfList: aSemaphore)]"
      ifFalse: [
			aProcess := self removeFirstLinkOfList: aSemaphore.
			self resume: aProcess.
			memory decreaseReferencesTo: aProcess.
			]
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

{ #category : #'control primitives' }
Interpreter >> transferTo: aProcess [
   "The transferTo: routine is used whenever the need to switch processes is 
   detected. It sets the newProcessWaiting and newProcess registers. (BB 643)"

   newProcessWaiting := true.
   "dbanay needs ref count newProcess line below addedd"
   newProcess ~~ NilPointer ifTrue: [ memory decreaseReferencesTo: newProcess ].
   newProcess := aProcess.
   "dbanay needs ref count newProcess line below addedd"
	memory increaseReferencesTo: newProcess
]

{ #category : #contexts }
Interpreter >> unPop: number [
	"Increase stack pointer by number (BB 585)"

	stackPointer := stackPointer + number
]

{ #category : #'control primitives' }
Interpreter >> wakeHighestPriority [
   "Remove links from the ProcessorScheduler's LinkedLists of quiescent Processes. (BB 645)"

   | priority processLists processList |
   processLists := memory fetchPointer: ProcessListsIndex
                          ofObject: self schedulerPointer.
   priority := memory fetchWordLengthOf: processLists.
   [processList := memory fetchPointer: priority - 1
                   ofObject: processLists.
    self isEmptyList: processList] whileTrue: [priority := priority - 1].
   ^self removeFirstLinkOfList: processList
]
