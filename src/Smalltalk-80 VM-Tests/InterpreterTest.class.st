"
Tests for the Interpreter (Blue Book ch. 27 to 30) on the hand built memory of ObjectMemoryTestCase. The interpreter is built through the seam Interpreter class >> withMemory:hal:fileSystem:debug:, with no HAL and no file system, and runs on a minimal MethodContext with an empty stack (see setUpContext). Primitives are tested by pushing their operands and checking the stack and the success flag.
"
Class {
	#name : 'InterpreterTest',
	#superclass : 'ObjectMemoryTestCase',
	#instVars : [
		'context',
		'receiverClass',
		'scheduler',
		'activeProcess',
		'processLists'
	],
	#category : 'Smalltalk-80 VM-Tests',
	#package : 'Smalltalk-80 VM-Tests'
}

{ #category : 'private' }
InterpreterTest >> activate: aContext [
	"Make aContext the active context and load the interpreter registers from it. newActiveContext: cannot be used: it stores the registers of the previous context, and there is none yet."

	interpreter instVarNamed: 'activeContext' put: aContext.
	memory countUp: aContext.
	interpreter fetchContextRegisters
]

{ #category : 'private - classes' }
InterpreterTest >> arrayClassForTest [
	"The guaranteed Array class, given the shape of an Array: pointers, words, indexable, no fixed field"

	self
		class: (Interpreter classVarNamed: 'ClassArrayPointer')
		hasSpecification: (self
				 instanceSpecificationPointers: 1
				 words: 1
				 indexable: 1
				 fixed: 0).
	^ Interpreter classVarNamed: 'ClassArrayPointer'
]

{ #category : 'private' }
InterpreterTest >> assertBoolean: expected of: aPrimitive with: receiver with: argument [
	"The primitive succeeds and leaves true or false alone on the stack"

	self run: aPrimitive with: receiver with: argument.
	self
		assert: interpreter success
		description:
			aPrimitive , ' failed on ' , receiver printString , ' '
			, argument printString.
	self assert: self stackDepth equals: 1.
	self assert: interpreter stackTop equals: (expected
			 ifTrue: [ self truePointer ]
			 ifFalse: [ self falsePointer ])
]

{ #category : 'private' }
InterpreterTest >> assertFailureOf: aPrimitive with: receiver with: argument [
	"The primitive fails and leaves its two operands on the stack, as the Blue Book requires so that the fallback code can run"

	self run: aPrimitive with: receiver with: argument.
	self
		deny: interpreter success
		description: aPrimitive , ' should fail'.
	self assert: self stackDepth equals: 2.
	self assert: (self stackIntegerAt: 1) equals: receiver.
	self assert: (self stackIntegerAt: 0) equals: argument
]

{ #category : 'private' }
InterpreterTest >> assertFailureOf: aPrimitive withObjects: receiver and: argument [
	"The primitive fails on operands that are not both SmallIntegers, and leaves them on the stack in their place"

	self emptyStack.
	self push: receiver.
	self push: argument.
	interpreter initPrimitive.
	interpreter perform: aPrimitive.
	self
		deny: interpreter success
		description: aPrimitive , ' should fail'.
	self assert: self stackDepth equals: 2.
	self assert: (interpreter stackValue: 1) equals: receiver.
	self assert: (interpreter stackValue: 0) equals: argument
]

{ #category : 'private - floats' }
InterpreterTest >> assertFloatPrimitive: aPrimitive with: operands answers: expected [
	"Run a Float primitive on operands, each a host number made into a Float object. It succeeds, leaves one Float alone on the stack, and that Float holds expected."

	self
		runPrimitive: aPrimitive
		with: (operands collect: [ :each | self newFloat: each ]).
	self assert: interpreter success description: aPrimitive , ' failed'.
	self assert: self stackDepth equals: 1.
	self
		assert: (memory fetchClassOf: interpreter stackTop)
		equals: (Interpreter classVarNamed: 'ClassFloatPointer').
	self
		assert: (self floatValueOf: interpreter stackTop)
		equals: expected
]

{ #category : 'private - floats' }
InterpreterTest >> assertFloatPrimitive: aPrimitive with: operands answersBoolean: expected [
	"Run a Float comparison on operands, each a host number made into a Float object. It succeeds and leaves true or false alone on the stack."

	self
		runPrimitive: aPrimitive
		with: (operands collect: [ :each | self newFloat: each ]).
	self assert: interpreter success description: aPrimitive , ' failed'.
	self assert: self stackDepth equals: 1.
	self assert: interpreter stackTop equals: (expected
			 ifTrue: [ self truePointer ]
			 ifFalse: [ self falsePointer ])
]

{ #category : 'private - floats' }
InterpreterTest >> assertFractionalPartOf: aNumber is: expected [
	"Run fractionalPart on a Float made from aNumber: it succeeds and leaves a Float equal to expected alone on the stack"

	self
		runPrimitive: #primitiveFractionalPart
		with: { (self newFloat: aNumber) }.

	self
		assert: interpreter success
		description: 'fractionalPart failed on ' , aNumber printString.
	self assert: self stackDepth equals: 1.
	self
		assert: (self floatValueOf: interpreter stackTop)
		equals: expected
]

{ #category : 'private - primitives' }
InterpreterTest >> assertPrimitive: aPrimitive with: objects answers: expected [
	"The primitive succeeds and leaves expected alone on the stack"

	self runPrimitive: aPrimitive with: objects.
	self assert: interpreter success description: aPrimitive , ' failed'.
	self assert: self stackDepth equals: 1.
	self assert: interpreter stackTop equals: expected
]

{ #category : 'private - primitives' }
InterpreterTest >> assertPrimitiveFails: aPrimitive with: objects [
	"The primitive fails and leaves its receiver and arguments on the stack, so that the Smalltalk code of the method can run"

	self runPrimitive: aPrimitive with: objects.
	self
		deny: interpreter success
		description: aPrimitive , ' should fail'.
	self assert: self stackDepth equals: objects size.
	objects withIndexDo: [ :each :index |
			self
				assert: (interpreter stackValue: objects size - index)
				equals: each ]
]

{ #category : 'private' }
InterpreterTest >> assertResult: expected of: aPrimitive with: receiver with: argument [
	"The primitive succeeds and leaves expected, a SmallInteger value, alone on the stack"

	self run: aPrimitive with: receiver with: argument.
	self
		assert: interpreter success
		description:
			aPrimitive , ' failed on ' , receiver printString , ' '
			, argument printString.
	self assert: self stackDepth equals: 1.
	self assert: (self stackIntegerAt: 0) equals: expected
]

{ #category : 'private - floats' }
InterpreterTest >> assertTruncated: aNumber gives: expected [
	"Run truncated on a Float made from aNumber: it succeeds and leaves the SmallInteger expected alone on the stack"

	self
		runPrimitive: #primitiveTruncated
		with: { (self newFloat: aNumber) }.

	self
		assert: interpreter success
		description: 'truncated failed on ' , aNumber printString.
	self assert: self stackDepth equals: 1.
	self assert: (self stackIntegerAt: 0) equals: expected
]

{ #category : 'private - io' }
InterpreterTest >> bitsOfForm: aForm [
	"The bitmap object of a Form"

	^ memory fetchPointer: 0 ofObject: aForm
]

{ #category : 'private - methods' }
InterpreterTest >> blockContextClass [

	^ Interpreter classVarNamed: 'ClassBlockContextPointer'
]

{ #category : 'private - methods' }
InterpreterTest >> blockContextReturningTo: caller bytecodes: bytecodes [
	"A BlockContext (its method field holds its argument count) whose home is a MethodContext with the same bytecodes, and which returns to caller. It becomes the active context."

	| home block |
	home := self
		        contextOf:
		        (self methodWithLiterals: #(  ) bytecodes: bytecodes)
		        receiver: nilPointer
		        sender: nilPointer.
	block := memory
		         instantiateClass: self blockContextClass
		         withPointers: self tempFrameStart + 12.
	memory countUp: block.
	memory
		storePointer: (Interpreter classVarNamed: 'CallerIndex')
		ofObject: block
		withValue: caller.
	memory
		storePointer: (Interpreter classVarNamed: 'InstructionPointerIndex')
		ofObject: block
		withValue: (memory integerObjectOf:
				 (interpreter initialInstructionPointerOfMethod: (memory
						   fetchPointer: (Interpreter classVarNamed: 'MethodIndex')
						   ofObject: home))).
	memory
		storePointer: (Interpreter classVarNamed: 'StackPointerIndex')
		ofObject: block
		withValue: (memory integerObjectOf: 0).
	memory
		storePointer: (Interpreter classVarNamed: 'BlockArgumentCountIndex')
		ofObject: block
		withValue: (memory integerObjectOf: 0).
	memory
		storePointer: (Interpreter classVarNamed: 'HomeIndex')
		ofObject: block
		withValue: home.
	context := block.
	self activate: block.
	^ home
]

{ #category : 'private - files' }
InterpreterTest >> bufferBytesOf: aPage count: count [
	"The first count bytes of the buffer of a page, as a host ByteArray"

	^ (1 to: count)
		  collect: [ :index |
			  memory fetchByte: index - 1 ofObject: (self pageBufferOf: aPage) ]
		  as: ByteArray
]

{ #category : 'private - io' }
InterpreterTest >> bytesOf: aByteObject count: count [
	"The first count bytes of a byte object of the memory, as a host ByteArray"

	^ (0 to: count - 1)
		  collect: [ :index | memory fetchByte: index ofObject: aByteObject ]
		  as: ByteArray
]

{ #category : 'private - methods' }
InterpreterTest >> callerContext [
	"A MethodContext with an empty stack and no sender, that a callee can return to"

	^ self
		  contextOf:
		  (self methodWithLiterals: #(  ) bytecodes: #( 118 118 ))
		  receiver: nilPointer
		  sender: nilPointer
]

{ #category : 'private - primitives' }
InterpreterTest >> characterFor: code [
	"The Character of the table of the memory for an ASCII code"

	^ memory fetchPointer: code ofObject: self characterTablePointer
]

{ #category : 'private - methods' }
InterpreterTest >> characterTablePointer [

	^ Interpreter classVarNamed: 'CharacterTablePointer'
]

{ #category : 'private - classes' }
InterpreterTest >> class: aClass hasSpecification: specification [
	"Store the instance specification: a SmallInteger, whose object pointer is written as a word so that no count is touched"

	memory
		storeWord: (Interpreter classVarNamed: 'InstanceSpecificationIndex')
		ofObject: aClass
		withValue: specification
]

{ #category : 'private - methods' }
InterpreterTest >> class: aClass understands: selector as: method [
	"Add a method to the dictionary of aClass, which gets a new dictionary (the lookup does not care)"

	memory
		storePointer: (Interpreter classVarNamed: 'MessageDictionaryIndex')
		ofObject: aClass
		withValue: (self dictionaryWith: { (selector -> method) })
]

{ #category : 'running' }
InterpreterTest >> classPointerSize [
	"The test class is a real class for the interpreter: a superclass, a message dictionary and an instance specification (see setUpClasses)"

	^ 3
]

{ #category : 'private - methods' }
InterpreterTest >> contextOf: method receiver: receiver sender: sender [
	"A MethodContext about to run the first bytecode of method, with an empty stack"

	| new |
	new := memory
		       instantiateClass: self methodContextClass
		       withPointers: self tempFrameStart + 12.
	memory countUp: new.
	memory
		storePointer: (Interpreter classVarNamed: 'SenderIndex')
		ofObject: new
		withValue: sender.
	memory
		storePointer: (Interpreter classVarNamed: 'InstructionPointerIndex')
		ofObject: new
		withValue: (memory integerObjectOf:
				 (interpreter initialInstructionPointerOfMethod: method)).
	memory
		storePointer: (Interpreter classVarNamed: 'StackPointerIndex')
		ofObject: new
		withValue: (memory integerObjectOf: 0).
	memory
		storePointer: (Interpreter classVarNamed: 'MethodIndex')
		ofObject: new
		withValue: method.
	memory
		storePointer: (Interpreter classVarNamed: 'ReceiverIndex')
		ofObject: new
		withValue: receiver.
	^ new
]

{ #category : 'private - classes' }
InterpreterTest >> dictionaryWith: pairs [
	"A message dictionary (BB p. 587): a method array and the selectors, in an open addressing table that is probed the way lookupMethodInDictionary: does. pairs are selector -> method associations."

	| slots dictionary methods mask index |
	slots := 4.
	[ slots < (pairs size * 2) ] whileTrue: [ slots := slots * 2 ].
	dictionary := memory
		              instantiateClass: classPointer
		              withPointers: 2 + slots.
	methods := memory instantiateClass: classPointer withPointers: slots.
	memory
		storePointer: (Interpreter classVarNamed: 'MethodArrayIndex')
		ofObject: dictionary
		withValue: methods.
	mask := slots - 1.
	pairs do: [ :pair |
			index := mask bitAnd: (interpreter hash: pair key).
			[
			(memory fetchPointer: index + 2 ofObject: dictionary) = nilPointer ]
				whileFalse: [ index := index + 1 bitAnd: mask ].
			memory
				storePointer: index + 2
				ofObject: dictionary
				withValue: pair key.
			memory storePointer: index ofObject: methods withValue: pair value ].
	^ dictionary
]

{ #category : 'private - files' }
InterpreterTest >> directoryOperation: code with: argument1 and: argument2 [
	"Run the directory primitive (131): the receiver, the operation code and two arguments are on the stack, the second argument on top"

	self runPrimitive: #primitivePosixDirectoryOperation with: {
			nilPointer.
			(self integer: code).
			argument1.
			argument2 }
]

{ #category : 'private' }
InterpreterTest >> emptyStack [
	"Drop everything pushed so far, so that one test can run several primitives"

	interpreter instVarNamed: 'stackPointer' put: self tempFrameStart - 1
]

{ #category : 'private - scheduling' }
InterpreterTest >> excessSignalsOf: aSemaphore [

	^ memory integerValueOf:
		  (memory fetchPointer: 2 ofObject: aSemaphore)
]

{ #category : 'private' }
InterpreterTest >> falsePointer [

	^ Interpreter classVarNamed: 'FalsePointer'
]

{ #category : 'private - files' }
InterpreterTest >> fileOperation: code on: file name: name page: page [
	"Run the file primitive (130) as the guest does: the receiver, the operation code, the name and the page are on the stack, the page on top"

	self runPrimitive: #primitivePosixFileOperation with: {
			file.
			(self integer: code).
			name.
			page }
]

{ #category : 'private - files' }
InterpreterTest >> fillBufferOf: aPage with: aByteArray [
	"Put the bytes in the buffer of the page, from the first one"

	aByteArray withIndexDo: [ :byte :index |
			memory
				storeByte: index - 1
				ofObject: (self pageBufferOf: aPage)
				withValue: byte ]
]

{ #category : 'private - scheduling' }
InterpreterTest >> firstProcessOf: aList [
	"The first Link of a LinkedList, nil if it is empty"

	^ memory fetchPointer: 0 ofObject: aList
]

{ #category : 'private - floats' }
InterpreterTest >> floatClassForTest [
	"The guaranteed Float class, given the shape of a Float: indexable 16 bit words, no fixed field"

	self
		class: (Interpreter classVarNamed: 'ClassFloatPointer')
		hasSpecification: (self
				 instanceSpecificationPointers: 0
				 words: 1
				 indexable: 1
				 fixed: 0).
	^ Interpreter classVarNamed: 'ClassFloatPointer'
]

{ #category : 'private - floats' }
InterpreterTest >> floatValueOf: aFloatObject [
	"The host Float a Float object of the memory holds: the two words put back together, high word first"

	^ Float fromIEEE32Bit:
		  ((memory fetchWord: 1 ofObject: aFloatObject) bitShift: 16)
		  + (memory fetchWord: 0 ofObject: aFloatObject)
]

{ #category : 'private - classes' }
InterpreterTest >> guaranteedClassOops [
	"The classes of the guaranteed pointers (BB p. 576) the interpreter instantiates or tests the class of. The class of a CompiledMethod is the method class of ObjectMemoryTestCase."

	^ #( ClassSmallInteger ClassStringPointer ClassArrayPointer
	     ClassFloatPointer ClassMethodContextPointer
	     ClassBlockContextPointer ClassPointPointer ClassLargePositiveIntegerPointer
	     ClassMessagePointer ClassSemaphorePointer ClassCharacterPointer
	     ClassSymbolPointer ) collect: [ :name |
		  Interpreter classVarNamed: name ]
]

{ #category : 'private - classes' }
InterpreterTest >> guaranteedSelectorOops [
	"The selectors the interpreter sends by itself, and the table of special selectors"

	^ #( DoesNotUnderstandSelector CannotReturnSelector
	     MustBeBooleanSelector SpecialSelectorsPointer ) collect: [ :name |
		  Interpreter classVarNamed: name ]
]

{ #category : 'private - methods' }
InterpreterTest >> headerExtensionArguments: arguments primitive: primitive [
	"A header extension (BB p. 580) as a SmallInteger object pointer: argument count in bits 2 to 6, primitive index in bits 7 to 14"

	^ (arguments bitShift: 9) + (primitive bitShift: 1) + 1
]

{ #category : 'private - methods' }
InterpreterTest >> headerFlag: flag temporaries: temporaries large: large literals: literals [
	"A CompiledMethod header as the SmallInteger object pointer the VM reads (BB p. 577): flag in bits 0 to 2, temporary count in 3 to 7, large context flag in 8, literal count in 9 to 14, counting the bits from the most significant one"

	^ (flag bitShift: 13) + (temporaries bitShift: 8)
	  + (large bitShift: 7) + (literals bitShift: 1) + 1
]

{ #category : 'private - classes' }
InterpreterTest >> instanceSpecificationPointers: pointers words: words indexable: indexable fixed: fixed [
	"The instance specification of a class (BB p. 590), as the SmallInteger object pointer the interpreter reads: counting from the high bit, pointers flag, words flag, indexable flag, then the number of fixed fields"

	^ (pointers bitShift: 15) + (words bitShift: 14)
	  + (indexable bitShift: 13) + (fixed bitShift: 1) + 1
]

{ #category : 'private - primitives' }
InterpreterTest >> integer: anInteger [

	^ memory integerObjectOf: anInteger
]

{ #category : 'private - scheduling' }
InterpreterTest >> lastProcessOf: aList [

	^ memory fetchPointer: 1 ofObject: aList
]

{ #category : 'private - scheduling' }
InterpreterTest >> listOf: aProcess [
	"The LinkedList a Process is in"

	^ memory fetchPointer: 3 ofObject: aProcess
]

{ #category : 'private - scheduling' }
InterpreterTest >> listSize: aList [
	"The number of Links of a LinkedList, counted from its first one"

	| count link |
	count := 0.
	link := self firstProcessOf: aList.
	[ link = nilPointer ] whileFalse: [
			count := count + 1.
			link := memory fetchPointer: 0 ofObject: link ].
	^ count
]

{ #category : 'private - methods' }
InterpreterTest >> methodContextClass [

	^ Interpreter classVarNamed: 'ClassMethodContextPointer'
]

{ #category : 'private - methods' }
InterpreterTest >> methodWithArguments: arguments bytecodes: bytecodes [
	"A method taking this number of arguments, which are its first temporaries, with no literal"

	^ self
		  methodWithHeader: (self
				   headerFlag: arguments
				   temporaries: arguments
				   large: 0
				   literals: 0)
		  literals: #(  )
		  bytecodes: bytecodes
]

{ #category : 'private - methods' }
InterpreterTest >> methodWithHeader: header literals: literals bytecodes: bytecodes [
	"A CompiledMethod: the header word, the literal frame, then the bytecodes. It is a byte object of the method class, so the literals are stored as words and counted by hand (storePointer: would count down the zero it overwrites)."

	| method literalBytes |
	literalBytes := 2 * (1 + literals size).
	method := memory
		          instantiateClass: methodClassPointer
		          withBytes: literalBytes + bytecodes size.
	memory countUp: method.
	memory storeWord: 0 ofObject: method withValue: header.
	literals withIndexDo: [ :literal :index |
			memory
				storeWord: index
				ofObject: method
				withValue: (memory countUp: literal) ].
	bytecodes withIndexDo: [ :byte :index |
			memory
				storeByte: literalBytes + index - 1
				ofObject: method
				withValue: byte ].
	^ method
]

{ #category : 'private - methods' }
InterpreterTest >> methodWithLiterals: literals bytecodes: bytecodes [
	"A method with no primitive, no argument and no temporary"

	^ self
		  methodWithHeader: (self
				   headerFlag: 0
				   temporaries: 0
				   large: 0
				   literals: literals size)
		  literals: literals
		  bytecodes: bytecodes
]

{ #category : 'private - methods' }
InterpreterTest >> methodWithPrimitive: primitive arguments: arguments fallback: bytecodes [
	"A method with a header extension (BB p. 580): its primitive runs first and when it fails the bytecodes are executed. The literal frame holds the extension and the association of the method class."

	| association |
	association := self objectWithFields: {
			               nilPointer.
			               classPointer }.
	^ self
		  methodWithHeader: (self
				   headerFlag: 7
				   temporaries: arguments
				   large: 0
				   literals: 2)
		  literals: {
				  (self headerExtensionArguments: arguments primitive: primitive).
				  association }
		  bytecodes: bytecodes
]

{ #category : 'private - classes' }
InterpreterTest >> newArrayOf: size [
	"An indexable pointer object (like an Array) of size nil fields, referenced once by us"

	| array |
	array := memory
		         instantiateClass: self arrayClassForTest
		         withPointers: size.
	memory countUp: array.
	^ array
]

{ #category : 'private - io' }
InterpreterTest >> newBitBltOn: destForm source: sourceForm rule: rule [
	"A BitBlt of the guest (BB p. 356): the destination Form (field 0), the source Form (1), the halftone Form (2, nil), the combination rule (3), then destX, destY, width, height, sourceX, sourceY and the four clipping fields (4 to 13). The clip is the whole destination."

	| fields |
	fields := Array new: 14 withAll: (self integer: 0).
	fields at: 1 put: destForm.
	fields at: 2 put: (sourceForm ifNil: [ nilPointer ]).
	fields at: 3 put: nilPointer.
	fields at: 4 put: (self integer: rule).
	^ self objectWithFields: fields
]

{ #category : 'private - primitives' }
InterpreterTest >> newBytesOf: size [
	"A byte object of a class whose instances are indexable bytes, referenced once by us"

	| object |
	object := memory
		          instantiateClass: (self
				           newClassPointers: 0
				           words: 0
				           indexable: 1
				           fixed: 0)
		          withBytes: size.
	memory countUp: object.
	^ object
]

{ #category : 'private - classes' }
InterpreterTest >> newClassInheritingFrom: superclass methods: pairs [
	"A class with its own message dictionary (see dictionaryWith:), referenced once by us"

	| class |
	class := memory instantiateClass: classPointer withPointers: 3.
	memory countUp: class.
	memory
		storePointer: (Interpreter classVarNamed: 'SuperclassIndex')
		ofObject: class
		withValue: superclass.
	memory
		storePointer: (Interpreter classVarNamed: 'MessageDictionaryIndex')
		ofObject: class
		withValue: (self dictionaryWith: pairs).
	memory
		storePointer:
		(Interpreter classVarNamed: 'InstanceSpecificationIndex')
		ofObject: class
		withValue: (memory integerObjectOf: 0).
	^ class
]

{ #category : 'private - classes' }
InterpreterTest >> newClassPointers: pointers words: words indexable: indexable fixed: fixed [
	"A class whose instances have that shape, with an empty message dictionary and no superclass"

	| class |
	class := self newClassInheritingFrom: nilPointer methods: #(  ).
	self class: class hasSpecification: (self
			 instanceSpecificationPointers: pointers
			 words: words
			 indexable: indexable
			 fixed: fixed).
	^ class
]

{ #category : 'private - floats' }
InterpreterTest >> newFloat: aNumber [
	"A Float object holding aNumber as an IEEE 754 single precision value. It is two 16 bit words, the low one first, as the VM stores it. It is referenced once by us."

	| object bits |
	bits := aNumber asFloat asIEEE32BitWord.
	object := memory
		          instantiateClass: self floatClassForTest
		          withWords: 2.
	memory countUp: object.
	memory
		storeWord: 0
		ofObject: object
		withValue: (bits bitAnd: 16rFFFF).
	memory storeWord: 1 ofObject: object withValue: (bits bitShift: -16).
	^ object
]

{ #category : 'private - io' }
InterpreterTest >> newFormWidth: width height: height words: words [
	"A Form of the guest: its bits (a word object of the given words, 0 filled), its width and its height, and a 0 @ 0 offset. Field 0 is the bitmap, 1 the width, 2 the height, 3 the offset."

	^ self objectWithFields: {
			  (self newWordsOf: words).
			  (self integer: width).
			  (self integer: height).
			  (self newPoint: 0 at: 0) }
]

{ #category : 'running' }
InterpreterTest >> newInterpreter [
	"The real interpreter, through the seam that leaves the active context to us (see setUpContext)"

	^ Interpreter
		  withMemory: memory
		  hal: nil
		  fileSystem: nil
		  debug: false
]

{ #category : 'private - io' }
InterpreterTest >> newKeyboardEventOf: aKeyValue scanCode: aScanCode buttons: buttons [
	"A key down event of the host, as the display morph receives it: aKeyValue is the ASCII code of the key, buttons the modifiers held (see UserInputEvent class variables CTRL_KEY_MASK, CMD_KEY_MASK, SHIFT_KEY_MASK and ALT_KEY_MASK)"

	| event |
	event := KeyboardEvent new.
	event
		instVarNamed: 'keyValue' put: aKeyValue;
		instVarNamed: 'scanCode' put: aScanCode;
		instVarNamed: 'buttons' put: buttons;
		instVarNamed: 'type' put: #keyDown.
	^ event
]

{ #category : 'private - scheduling' }
InterpreterTest >> newLinkedList [
	"A LinkedList of the guest (BB p. 641): field 0 is its first Link, field 1 its last one, both nil when it is empty"

	^ self objectWithFields: {
			  nilPointer.
			  nilPointer }
]

{ #category : 'private - methods' }
InterpreterTest >> newMethodReturning: anInteger [
	"A method that answers a SmallInteger literal: push literal 0, return the top of the stack"

	^ self
		  methodWithHeader: (self
				   headerFlag: 0
				   temporaries: 0
				   large: 0
				   literals: 1)
		  literals: { (memory integerObjectOf: anInteger) }
		  bytecodes: #( 32 124 )
]

{ #category : 'private - io' }
InterpreterTest >> newPoint: x at: y [
	"A Point of the guest"

	| point |
	point := memory
		         instantiateClass:
		         (Interpreter classVarNamed: 'ClassPointPointer')
		         withPointers: 2.
	memory countUp: point.
	memory storePointer: 0 ofObject: point withValue: (self integer: x).
	memory storePointer: 1 ofObject: point withValue: (self integer: y).
	^ point
]

{ #category : 'private - files' }
InterpreterTest >> newPosixFile [
	"A PosixFile of the guest (BB does not have one, see dbanay): an object of 9 pointer fields, whose field 1 is the file name and field 8 the file descriptor. Both are nil until the file is opened or created."

	^ self objectWithFields: (Array new: 9 withAll: nilPointer)
]

{ #category : 'private - files' }
InterpreterTest >> newPosixFilePage: pageNumber bytes: byteCount [
	"A PosixFilePage of the guest: field 1 is a 512 byte ByteArray (the buffer of the page), field 3 the number of the page in the file, one based, and field 4 the number of bytes of the buffer that are in use"

	| page buffer |
	buffer := self newBytesOf: 512.
	page := self objectWithFields: (Array new: 5 withAll: nilPointer).
	memory storePointer: 1 ofObject: page withValue: buffer.
	memory
		storePointer: 3
		ofObject: page
		withValue: (self integer: pageNumber).
	memory
		storePointer: 4
		ofObject: page
		withValue: (self integer: byteCount).
	^ page
]

{ #category : 'private - scheduling' }
InterpreterTest >> newProcessAt: priority [
	"A Process of the guest: field 0 is the next Link of the list it is in, 1 the context it was suspended in, 2 its priority, 3 the list it is in. A new Process is in no list."

	^ self objectWithFields: {
			  nilPointer.
			  nilPointer.
			  (self integer: priority).
			  nilPointer }
]

{ #category : 'private - methods' }
InterpreterTest >> newReceiverOf: aClass [
	"An instance of aClass with no field, referenced once by us"

	| object |
	object := memory instantiateClass: aClass withPointers: 0.
	memory countUp: object.
	^ object
]

{ #category : 'private - methods' }
InterpreterTest >> newSelector [
	"Selectors are Symbols, compared by object pointer: any object will do"

	^ self objectWithFields: #(  )
]

{ #category : 'private - scheduling' }
InterpreterTest >> newSemaphore [
	"A Semaphore of the guest: a LinkedList of the Processes that wait for it, with a third field, the number of excess signals, 0"

	| semaphore |
	semaphore := memory
		             instantiateClass:
		             (Interpreter classVarNamed: 'ClassSemaphorePointer')
		             withPointers: 3.
	memory countUp: semaphore.
	memory
		storePointer: 2
		ofObject: semaphore
		withValue: (self integer: 0).
	^ semaphore
]

{ #category : 'private - primitives' }
InterpreterTest >> newStreamOn: array index: index readLimit: readLimit writeLimit: writeLimit [
	"A stream: the collection, then the position and the read and write limits (BB p. 631)"

	^ self objectWithFields: {
			  array.
			  (self integer: index).
			  (self integer: readLimit).
			  (self integer: writeLimit) }
]

{ #category : 'private - primitives' }
InterpreterTest >> newStringWith: codes [
	"A String of the given ASCII codes, referenced once by us"

	| string |
	string := memory
		          instantiateClass: self stringClass
		          withBytes: codes size.
	memory countUp: string.
	codes withIndexDo: [ :code :index |
		memory storeByte: index - 1 ofObject: string withValue: code ].
	^ string
]

{ #category : 'private - files' }
InterpreterTest >> newTemporaryDirectory [
	"A new empty directory on the host, deleted at the end of the test. The file primitives work on real files: ST80FileSystem opens them with File, which has no in-memory equivalent."

	| directory |
	directory := FileLocator temp
	             / ('st80-interpreter-test-' , UUID new asString).
	directory ensureCreateDirectory.
	self onTearDown: [ directory exists ifTrue: [ directory deleteAll ] ].
	^ directory
]

{ #category : 'private - primitives' }
InterpreterTest >> newWordsOf: size [
	"A word object of a class whose instances are indexable 16 bit words, referenced once by us"

	| object |
	object := memory
		          instantiateClass: (self
				           newClassPointers: 0
				           words: 1
				           indexable: 1
				           fixed: 0)
		          withWords: size.
	memory countUp: object.
	^ object
]

{ #category : 'private - methods' }
InterpreterTest >> objectWithFields: fields [
	"A pointer object of the test class holding these field values, referenced once by us"

	| object |
	object := memory
		          instantiateClass: classPointer
		          withPointers: fields size.
	memory countUp: object.
	fields withIndexDo: [ :field :index |
		memory storePointer: index - 1 ofObject: object withValue: field ].
	^ object
]

{ #category : 'private - files' }
InterpreterTest >> pageBufferOf: aPage [
	"The ByteArray that holds the data of a PosixFilePage"

	^ memory fetchPointer: 1 ofObject: aPage
]

{ #category : 'private' }
InterpreterTest >> push: anObject [

	interpreter push: anObject
]

{ #category : 'private' }
InterpreterTest >> pushInteger: anInteger [

	interpreter pushInteger: anInteger
]

{ #category : 'private - scheduling' }
InterpreterTest >> readyListAt: priority [
	"The LinkedList of the ready Processes of a priority"

	^ memory fetchPointer: priority - 1 ofObject: processLists
]

{ #category : 'running' }
InterpreterTest >> reservedOops [
	"nil and the method class (see ObjectMemoryTestCase), the booleans, the scheduler association, the classes the interpreter instantiates or finds the class of, the selectors it sends by itself and the table of Characters. They are the guaranteed objects of the Blue Book (p. 576)."

	^ super reservedOops , {
		  self falsePointer.
		  self truePointer.
		  self schedulerAssociationPointer } , self guaranteedClassOops
	  , self guaranteedSelectorOops , { self characterTablePointer }
]

{ #category : 'private - methods' }
InterpreterTest >> run: bytecodes literals: literals receiver: receiver [
	"Make the active context run a new method made of these bytecodes (see methodWithLiterals:bytecodes:)"

	context := self
		           contextOf:
		           (self methodWithLiterals: literals bytecodes: bytecodes)
		           receiver: receiver
		           sender: nilPointer.
	self activate: context
]

{ #category : 'private' }
InterpreterTest >> run: aPrimitive with: receiver with: argument [
	"Push two SmallIntegers and run a primitive on them, as the interpreter does after a send of a special selector"

	self emptyStack.
	self pushInteger: receiver.
	self pushInteger: argument.
	interpreter initPrimitive.
	interpreter perform: aPrimitive
]

{ #category : 'private' }
InterpreterTest >> run: aPrimitive withObject: receiver with: argument [
	"Same, with any object as the receiver"

	self push: receiver.
	self pushInteger: argument.
	interpreter initPrimitive.
	interpreter perform: aPrimitive
]

{ #category : 'private - methods' }
InterpreterTest >> runBytecodes: bytecodes [
	"Run the bytecodes as a method with no literal, on nil"

	self runBytecodes: bytecodes literals: #(  ) receiver: nilPointer
]

{ #category : 'private - methods' }
InterpreterTest >> runBytecodes: bytecodes literals: literals receiver: receiver [
	"Run the bytecodes as a method with these literals, until the instruction pointer is past the last one. A cap on the cycles keeps a wrong jump from looping forever."

	| end cycles |
	self run: bytecodes literals: literals receiver: receiver.
	end := (interpreter instVarNamed: 'instructionPointer')
	       + bytecodes size.
	cycles := 0.
	[
		(interpreter instVarNamed: 'instructionPointer') < end and: [
			(cycles := cycles + 1) <= 50 ] ] whileTrue: [ interpreter cycle ]
]

{ #category : 'private - methods' }
InterpreterTest >> runCalleeOf: caller bytecodes: bytecodes receiver: receiver [
	"Make a context that returns to caller the active one, and execute all its bytecodes"

	context := self
		           contextOf:
		           (self methodWithLiterals: #(  ) bytecodes: bytecodes)
		           receiver: receiver
		           sender: caller.
	self activate: context.
	bytecodes size timesRepeat: [ interpreter cycle ]
]

{ #category : 'private - methods' }
InterpreterTest >> runMethod: method receiver: receiver [
	"Make the active context a new context about to run method, on receiver"

	context := self
		           contextOf: method
		           receiver: receiver
		           sender: nilPointer.
	self activate: context
]

{ #category : 'private - primitives' }
InterpreterTest >> runPrimitive: aPrimitive with: objects [
	"Empty the stack, push the receiver and the arguments (object pointers), then run the primitive as the interpreter does"

	self emptyStack.
	objects do: [ :each | self push: each ].
	interpreter initPrimitive.
	interpreter perform: aPrimitive
]

{ #category : 'private - scheduling' }
InterpreterTest >> schedulerActiveProcess [
	"The Process the scheduler holds as active: this is not the active Process of the interpreter while a switch is waiting"

	^ memory fetchPointer: 1 ofObject: scheduler
]

{ #category : 'private - methods' }
InterpreterTest >> schedulerAssociationPointer [

	^ Interpreter classVarNamed: 'SchedulerAssociationPointer'
]

{ #category : 'private - methods' }
InterpreterTest >> sendSpecialSelector: bytecode to: receiver with: arguments [
	"Push the receiver and the arguments (object pointers) on the active context, then run the special selector bytecode (176 to 207) that the active context is about to execute"

	self run: { bytecode } literals: #(  ) receiver: nilPointer.
	self push: receiver.
	arguments do: [ :argument | self push: argument ].
	interpreter cycle
]

{ #category : 'private - methods' }
InterpreterTest >> sendTo: receiver selector: selector [
	"The active context pushes receiver and sends selector to it (no argument): the first cycle is the push, the second the send"

	self run: #( 112 208 ) literals: { selector } receiver: receiver.
	2 timesRepeat: [ interpreter cycle ]
]

{ #category : 'private - io' }
InterpreterTest >> setBitBlt: aBitBlt field: index to: aValue [
	"Set one field of a BitBlt, by its index: 4 destX, 5 destY, 6 width, 7 height, 8 sourceX, 9 sourceY, 10 clipX, 11 clipY, 12 clipWidth, 13 clipHeight"

	memory
		storePointer: index
		ofObject: aBitBlt
		withValue: (self integer: aValue)
]

{ #category : 'running' }
InterpreterTest >> setUp [

	super setUp.
	self setUpClasses.
	self setUpContext
]

{ #category : 'running' }
InterpreterTest >> setUpCharacters [
	"The table of Characters (BB p. 630): one Character for each ASCII code, with the code as its only field. The String primitives answer these same objects."

	0 to: 255 do: [ :code |
			| character |
			character := memory
				             instantiateClass:
				             (Interpreter classVarNamed: 'ClassCharacterPointer')
				             withPointers: 1.
			memory
				storePointer: (Interpreter classVarNamed: 'CharacterValueIndex')
				ofObject: character
				withValue: (memory integerObjectOf: code).
			memory
				storePointer: code
				ofObject: self characterTablePointer
				withValue: character ]
]

{ #category : 'running' }
InterpreterTest >> setUpClasses [
	"Every guaranteed class, and the class of the test objects, shares one empty message dictionary and has no superclass, so that a lookup that fails ends cleanly. The receiver class of the send tests has its own dictionaries (see newClassInheritingFrom:methods:)."

	| empty |
	empty := self dictionaryWith: #(  ).
	(self guaranteedClassOops copyWith: classPointer) do: [ :class |
			memory
				storePointer:
				(Interpreter classVarNamed: 'MessageDictionaryIndex')
				ofObject: class
				withValue: empty ].
	receiverClass := self
		                 newClassInheritingFrom: nilPointer
		                 methods: #(  ).
	self setUpSpecialSelectors.
	self setUpCharacters
]

{ #category : 'running' }
InterpreterTest >> setUpContext [
	"A MethodContext with an empty stack becomes the active context. Its sender and receiver are nil. Its method is a CompiledMethod with a header and no bytecodes: enough for the registers, not to run bytecodes."

	| method |
	method := memory instantiateClass: methodClassPointer withWords: 2.
	context := memory
		           instantiateClass: self methodContextClass
		           withPointers: self tempFrameStart + 12.
	memory
		storePointer: (Interpreter classVarNamed: 'InstructionPointerIndex')
		ofObject: context
		withValue: (memory integerObjectOf: 1).
	memory
		storePointer: (Interpreter classVarNamed: 'StackPointerIndex')
		ofObject: context
		withValue: (memory integerObjectOf: 0).
	memory
		storePointer: (Interpreter classVarNamed: 'MethodIndex')
		ofObject: context
		withValue: method.
	self activate: context
]

{ #category : 'private - scheduling' }
InterpreterTest >> setUpSchedulerWithPriorities: count activeAt: priority [
	"The ProcessorScheduler of the guest, as the association Processor reaches it: field 0 is an Array with one LinkedList of ready Processes for each priority, field 1 the active Process, here at the given priority and running the active context of the test. An idle Process at priority 1 is always ready, as in the image: waking the highest priority runs off the lists when none is ready."

	processLists := self newArrayOf: count.
	0 to: count - 1 do: [ :index |
			memory
				storePointer: index
				ofObject: processLists
				withValue: self newLinkedList ].
	activeProcess := self newProcessAt: priority.
	memory storePointer: 1 ofObject: activeProcess withValue: context.
	scheduler := self objectWithFields: {
			             processLists.
			             activeProcess }.
	memory
		storePointer: 1
		ofObject: self schedulerAssociationPointer
		withValue: scheduler
]

{ #category : 'running' }
InterpreterTest >> setUpSpecialSelectors [
	"Fill the table of special selectors (BB p. 618): + - < > <= >= = ~= * / \\ @ bitShift: // bitAnd: bitOr: take one argument, then at: at:put: size next nextPut: atEnd == class blockCopy: value value: do: new new: x y"

	| table counts |
	table := Interpreter classVarNamed: 'SpecialSelectorsPointer'.
	counts := (Array new: 16 withAll: 1)
	          , #( 1 2 0 0 1 0 1 0 1 0 1 1 0 1 0 0 ).
	counts withIndexDo: [ :count :index |
			memory
				storePointer: 2 * (index - 1)
				ofObject: table
				withValue: self newSelector.
			memory
				storePointer: 2 * (index - 1) + 1
				ofObject: table
				withValue: (memory integerObjectOf: count) ]
]

{ #category : 'running' }
InterpreterTest >> sizeOfReservedOop: oop [
	"A class has a superclass, a message dictionary and an instance specification: 3 fields. An association has a key and a value. The table of special selectors holds a selector and an argument count for each of the 32 special selectors. The table of Characters holds one for each of the 256 ASCII codes."

	oop = (Interpreter classVarNamed: 'SpecialSelectorsPointer') ifTrue: [
		^ 2 + 64 ].
	oop = self characterTablePointer ifTrue: [ ^ 2 + 256 ].
	oop = self schedulerAssociationPointer ifTrue: [ ^ 4 ].
	^ (self guaranteedClassOops includes: oop)
		  ifTrue: [ 5 ]
		  ifFalse: [ super sizeOfReservedOop: oop ]
]

{ #category : 'private - methods' }
InterpreterTest >> specialSelector: index [
	"The selector of the special selector bytecode 176 + index"

	^ memory
		  fetchPointer: index * 2
		  ofObject: (Interpreter classVarNamed: 'SpecialSelectorsPointer')
]

{ #category : 'private' }
InterpreterTest >> stackDepth [
	"Number of objects on the stack of the active context"

	^ (interpreter instVarNamed: 'stackPointer') - self tempFrameStart
	  + 1
]

{ #category : 'private' }
InterpreterTest >> stackIntegerAt: offset [
	"The SmallInteger value at offset from the top of the stack"

	^ memory integerValueOf: (interpreter stackValue: offset)
]

{ #category : 'private - primitives' }
InterpreterTest >> stringClass [
	"The guaranteed String class, with the shape of a String: indexable bytes"

	self
		class: (Interpreter classVarNamed: 'ClassStringPointer')
		hasSpecification: (self
				 instanceSpecificationPointers: 0
				 words: 0
				 indexable: 1
				 fixed: 0).
	^ Interpreter classVarNamed: 'ClassStringPointer'
]

{ #category : 'private - methods' }
InterpreterTest >> superSenderWith: literals bytecodes: bytecodes methodClass: aClass [
	"A method that sends to super: its header has a header extension, and its last literal is the association whose value is the class the method belongs to (BB p. 580)"

	| association |
	association := self objectWithFields: {
			               nilPointer.
			               aClass }.
	^ self
		  methodWithHeader: (self
				   headerFlag: 7
				   temporaries: 0
				   large: 0
				   literals: literals size + 2)
		  literals: literals , {
				  (self headerExtensionArguments: 0 primitive: 0).
				  association }
		  bytecodes: bytecodes
]

{ #category : 'private' }
InterpreterTest >> tempFrameStart [
	"Index of the first temporary in a context, which is also the number of fields that precede the stack"

	^ Interpreter classVarNamed: 'TempFrameStart'
]

{ #category : 'tests - paste' }
InterpreterTest >> testANewPasteReplacesTheOneThatIsStillRunning [
	"A paste in progress is stopped by the next one: its remaining characters are forgotten"

	| hal first |
	hal := self useClockHALListening.
	first := [ (Delay forSeconds: 30) wait ] forkAt:
		         Processor userSchedulingPriority.
	hal instVarNamed: 'pasteProcess' put: first.
	self assert: hal isPasting.

	hal cancelPaste.

	self deny: hal isPasting.
	self assert: first isTerminated
]

{ #category : 'tests - special selectors' }
InterpreterTest >> testActivateInitialContext [
	"The initial context is the suspended context of the active process, found through the scheduler association (BB p. 644): it becomes the active context and its registers are loaded"

	| process schedulerObject first |
	first := self callerContext.
	process := self objectWithFields: {
			           nilPointer.
			           first.
			           (memory integerObjectOf: 4).
			           nilPointer }.
	schedulerObject := self objectWithFields: {
			                   nilPointer.
			                   process }.
	memory
		storePointer: (Interpreter classVarNamed: 'ValueIndex')
		ofObject: self schedulerAssociationPointer
		withValue: schedulerObject.

	interpreter activateInitialContext.

	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: first.
	self assert: (interpreter instVarNamed: 'homeContext') equals: first.
	self deny: (interpreter instVarNamed: 'newProcessWaiting').
	self
		assert: (interpreter instVarNamed: 'newProcess')
		equals: nilPointer
]

{ #category : 'tests - scheduling' }
InterpreterTest >> testActiveProcessIsTheNewProcessWhileASwitchIsWaiting [
	"Once a switch has been asked for, the new Process is the one that counts as active, although the scheduler still holds the old one until checkProcessSwitch runs: the routines that look for the active Process must see the new one."

	| other |
	self setUpSchedulerWithPriorities: 4 activeAt: 2.
	other := self newProcessAt: 4.

	interpreter transferTo: other.

	self assert: interpreter activeProcess equals: other.
	self assert: self schedulerActiveProcess equals: activeProcess
]

{ #category : 'tests - scheduling' }
InterpreterTest >> testActiveProcessIsTheOneOfTheScheduler [
	"With no switch waiting, the active Process is the one the ProcessorScheduler holds in its field 1, which the interpreter finds through the association Processor."

	self setUpSchedulerWithPriorities: 4 activeAt: 2.

	self assert: interpreter activeProcess equals: activeProcess.
	self assert: interpreter schedulerPointer equals: scheduler
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testAdd [

	self
		assertResult: 7
		of: #primitiveAdd
		with: 3
		with: 4.
	self
		assertResult: -1
		of: #primitiveAdd
		with: 3
		with: -4
]

{ #category : 'tests - linked lists' }
InterpreterTest >> testAddLastLinkKeepsTheOrder [
	"Links are added at the end: the list is first in, first out. The first stays first, and each Link points to the next one."

	| list first second third |
	list := self newLinkedList.
	first := self newProcessAt: 3.
	second := self newProcessAt: 3.
	third := self newProcessAt: 3.

	interpreter addLastLink: first toList: list.
	interpreter addLastLink: second toList: list.
	interpreter addLastLink: third toList: list.

	self assert: (self firstProcessOf: list) equals: first.
	self assert: (self lastProcessOf: list) equals: third.
	self assert: (self listSize: list) equals: 3.
	self assert: (memory fetchPointer: 0 ofObject: first) equals: second.
	self assert: (memory fetchPointer: 0 ofObject: second) equals: third
]

{ #category : 'tests - linked lists' }
InterpreterTest >> testAddLastLinkToAnEmptyList [
	"The first Link added to an empty list is both its first and its last one, and it knows the list it is in."

	| list process |
	list := self newLinkedList.
	process := self newProcessAt: 3.

	interpreter addLastLink: process toList: list.

	self deny: (interpreter isEmptyList: list).
	self assert: (self firstProcessOf: list) equals: process.
	self assert: (self lastProcessOf: list) equals: process.
	self assert: (self listOf: process) equals: list
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testAddOverflowFails [
	"The result must fit in a SmallInteger (-16384 to 16383)"

	self
		assertResult: 16383
		of: #primitiveAdd
		with: 16382
		with: 1.
	self assertFailureOf: #primitiveAdd with: 16383 with: 1.
	self assertFailureOf: #primitiveAdd with: -16384 with: -1
]

{ #category : 'tests - method header' }
InterpreterTest >> testArgumentCountFromFlag [
	"Flags 0 to 4 are the number of arguments of a method with no primitive"

	0 to: 4 do: [ :arguments |
			| method |
			method := self
				          methodWithHeader: (self
						           headerFlag: arguments
						           temporaries: arguments
						           large: 0
						           literals: 0)
				          literals: #(  )
				          bytecodes: #( 120 ).
			self
				assert: (interpreter argumentCountOf: method)
				equals: arguments.
			self assert: (interpreter primitiveIndexOf: method) equals: 0 ]
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testArithmeticFailsOnNonIntegers [
	"Every SmallInteger primitive fails, leaving its operands, when the receiver or the argument is an object"

	#( primitiveAdd primitiveSubtract primitiveMultiply primitiveDiv
	   primitiveMod primitiveQuo primitiveBitAnd primitiveBitOr
	   primitiveBitShift primitiveLessThan primitiveEqual ) do: [
			:primitive |
			self
				assertFailureOf: primitive
				withObjects: classPointer
				and: (memory integerObjectOf: 1).
			self
				assertFailureOf: primitive
				withObjects: (memory integerObjectOf: 1)
				and: nilPointer ]
]

{ #category : 'tests - float conversions' }
InterpreterTest >> testAsFloat [
	"asFloat (primitive 40) turns a SmallInteger into a Float object: the host float is rounded to single precision and split in two words. The result replaces the receiver on the stack and is an instance of the Float class."

	#( 5 -3 0 16383 -16384 ) do: [ :integer |
			self
				runPrimitive: #primitiveAsFloat
				with: { (self integer: integer) }.

			self assert: interpreter success.
			self assert: self stackDepth equals: 1.
			self
				assert: (memory fetchClassOf: interpreter stackTop)
				equals: (Interpreter classVarNamed: 'ClassFloatPointer').
			self
				assert: (self floatValueOf: interpreter stackTop)
				equals: integer asFloat ]
]

{ #category : 'tests - float dispatch' }
InterpreterTest >> testAsFloatIsReachedByItsIndex [
	"Primitive 40 is asFloat, a method of SmallInteger: 7 asFloat answers a Float object holding 7.0."

	| selector |
	selector := self newSelector.
	self
		class: (Interpreter classVarNamed: 'ClassSmallInteger')
		understands: selector
		as: (self methodWithPrimitive: 40 arguments: 0 fallback: #( 120 )).

	self
		run: #( 33 208 )
		literals: {
				selector.
				(self integer: 7) }
		receiver: nilPointer.
	2 timesRepeat: [ interpreter cycle ].

	self assert: self stackDepth equals: 1.
	self assert: (self floatValueOf: interpreter stackTop) equals: 7.0
]

{ #category : 'tests - float conversions' }
InterpreterTest >> testAsFloatOfANonIntegerFails [
	"asFloat is defined on SmallIntegers only: on any other receiver, here a Float, the primitive fails and leaves the receiver on the stack so that the Smalltalk code of the method can handle it."

	| float |
	float := self newFloat: 1.5.

	self assertPrimitiveFails: #primitiveAsFloat with: { float }
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testAsObject [
	"asObject is the inverse of asOop: the SmallInteger whose value is half the object pointer"

	| object |
	object := self objectWithFields: #(  ).

	self
		assertPrimitive: #primitiveAsObject
		with: { (self integer: object // 2) }
		answers: object
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testAsObjectOfAFreeEntryFails [
	"No object has this pointer"

	self
		assertPrimitiveFails: #primitiveAsObject
		with: { (self integer: 1000) }
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testAsObjectOfANonIntegerFails [

	self
		assertPrimitiveFails: #primitiveAsObject
		with: { (self objectWithFields: #(  )) }
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testAsOop [
	"asOop is half the object pointer: object pointers are even, so setting the low bit is enough"

	| object |
	object := self objectWithFields: #(  ).

	self
		assertPrimitive: #primitiveAsOop
		with: { object }
		answers: object + 1
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testAsOopOfAnIntegerFails [

	self
		assertPrimitiveFails: #primitiveAsOop
		with: { (self integer: 5) }
]

{ #category : 'tests - process switch' }
InterpreterTest >> testAsynchronousSignalBuffersTheSemaphore [
	"asynchronousSignal: only records the Semaphore: nothing is signalled yet, which makes it safe to call from the host in the middle of anything."

	| semaphore |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	semaphore := self newSemaphore.

	interpreter asynchronousSignal: semaphore.

	self assert: (interpreter instVarNamed: 'semaphoreIndex') equals: 1.
	self assert: (self excessSignalsOf: semaphore) equals: 0
]

{ #category : 'tests - process switch' }
InterpreterTest >> testAsynchronousSignalIgnoresNil [
	"The host can ask to signal nothing: the input Semaphore is not set yet, or the guest has reset it to nil, or a timer was cancelled with nil. Such a request must not be buffered: checkProcessSwitch would send messages to it as if it was an object pointer, and the interpreter would die at the next cycle."

	self setUpSchedulerWithPriorities: 4 activeAt: 3.

	interpreter asynchronousSignal: nil.
	interpreter asynchronousSignal: nilPointer.

	self assert: (interpreter instVarNamed: 'semaphoreIndex') equals: 0.
	interpreter checkProcessSwitch.
	self assert: (interpreter instVarNamed: 'semaphoreIndex') equals: 0
]

{ #category : 'tests - process switch' }
InterpreterTest >> testAsynchronousSignalWakesAWaitingProcess [
	"A Process waiting for a Semaphore signalled by the host runs again at the next process check: here a higher priority waiter is resumed, preempts the active Process, and becomes the active one."

	| semaphore waiter waiterContext |
	self setUpSchedulerWithPriorities: 4 activeAt: 2.
	semaphore := self newSemaphore.
	waiterContext := self callerContext.
	waiter := self newProcessAt: 4.
	memory storePointer: 1 ofObject: waiter withValue: waiterContext.
	interpreter addLastLink: waiter toList: semaphore.

	interpreter asynchronousSignal: semaphore.
	interpreter checkProcessSwitch.

	self assert: self schedulerActiveProcess equals: waiter.
	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: waiterContext
]

{ #category : 'tests - array primitives' }
InterpreterTest >> testAt [
	"at: is one based and answers the field of an Array"

	| array |
	array := self newArrayOf: 3.
	memory storePointer: 1 ofObject: array withValue: (self integer: 77).

	self
		assertPrimitive: #primitiveAt
		with: {
				array.
				(self integer: 2) }
		answers: (self integer: 77)
]

{ #category : 'tests - string and stream primitives' }
InterpreterTest >> testAtEnd [
	"atEnd compares the position with the read limit"

	self
		assertPrimitive: #primitiveAtEnd
		with: { (self
				 newStreamOn: (self newArrayOf: 3)
				 index: 0
				 readLimit: 2
				 writeLimit: 3) }
		answers: self falsePointer.
	self
		assertPrimitive: #primitiveAtEnd
		with: { (self
				 newStreamOn: (self newArrayOf: 3)
				 index: 2
				 readLimit: 2
				 writeLimit: 3) }
		answers: self truePointer
]

{ #category : 'tests - VM bugs' }
InterpreterTest >> testAtOnAnIntegerFails [
	"A SmallInteger is not indexable: the primitive fails, quietly, so that the guest code reports the error. It must not signal the warning of an object table access on an integer (Errata by ljulliard, see checkIndexableBoundsOf:in:)."

	self
		shouldnt: [
				self assertPrimitiveFails: #primitiveAt with: {
						(self integer: 3).
						(self integer: 1) } ]
		raise: Warning
]

{ #category : 'tests - array primitives' }
InterpreterTest >> testAtOutOfBoundsFails [

	self assertPrimitiveFails: #primitiveAt with: {
			(self newArrayOf: 3).
			(self integer: 4) }.
	self assertPrimitiveFails: #primitiveAt with: {
			(self newArrayOf: 3).
			(self integer: 0) }.
	self assertPrimitiveFails: #primitiveAt with: {
			(self newArrayOf: 3).
			(self integer: -1) }
]

{ #category : 'tests - array primitives' }
InterpreterTest >> testAtPut [
	"at:put: stores the value and answers it"

	| array |
	array := self newArrayOf: 3.

	self
		assertPrimitive: #primitiveAtPut
		with: {
				array.
				(self integer: 3).
				(self integer: 5) }
		answers: (self integer: 5).

	self
		assert: (memory fetchPointer: 2 ofObject: array)
		equals: (self integer: 5)
]

{ #category : 'tests - VM bugs' }
InterpreterTest >> testAtPutOnAnIntegerFails [

	self
		shouldnt: [
				self assertPrimitiveFails: #primitiveAtPut with: {
						(self integer: 3).
						(self integer: 1).
						(self integer: 1) } ]
		raise: Warning
]

{ #category : 'tests - array primitives' }
InterpreterTest >> testAtPutOutOfBoundsFails [

	self assertPrimitiveFails: #primitiveAtPut with: {
			(self newArrayOf: 3).
			(self integer: 4).
			(self integer: 5) }.
	self assertPrimitiveFails: #primitiveAtPut with: {
			(self newArrayOf: 3).
			(self integer: 0).
			(self integer: 5) }
]

{ #category : 'tests - VM bugs' }
InterpreterTest >> testAtPutWithANonIntegerIndexFails [
	"A known limit of the Blue Book code, kept as it is: primitiveFail answers the interpreter, 
	which positive16BitValueOf: hands back as the index, so a non integer index ends in a host 
	MessageNotUnderstood instead of a primitive failure. The test says what the primitive should 
	do: it passes the day primitiveFail answers 0, as in dbanay's VM."

	<expectedFailure>
	self assertPrimitiveFails: #primitiveAtPut with: {
			(self newArrayOf: 3).
			nilPointer.
			(self integer: 1) }
]

{ #category : 'tests - array primitives' }
InterpreterTest >> testAtSkipsTheFixedFields [
	"The index of at: starts after the fixed fields"

	| object |
	object := memory
		          instantiateClass: (self
				           newClassPointers: 1
				           words: 1
				           indexable: 1
				           fixed: 2)
		          withPointers: 5.
	memory countUp: object.
	memory storePointer: 2 ofObject: object withValue: (self integer: 11).
	memory storePointer: 4 ofObject: object withValue: (self integer: 44).

	self
		assertPrimitive: #primitiveAt
		with: {
				object.
				(self integer: 1) }
		answers: (self integer: 11).
	self
		assertPrimitive: #primitiveAt
		with: {
				object.
				(self integer: 3) }
		answers: (self integer: 44).
	self assertPrimitiveFails: #primitiveAt with: {
			object.
			(self integer: 4) }
]

{ #category : 'tests - array primitives' }
InterpreterTest >> testAtWithANonIntegerIndexFails [

	self assertPrimitiveFails: #primitiveAt with: {
			(self newArrayOf: 3).
			nilPointer }
]

{ #category : 'tests - display primitives' }
InterpreterTest >> testBeDisplay [
	"Primitive 102 designates the Form that is the screen of the guest: the host is asked for a window of the size of the Form, and the interpreter keeps the Form and its size, to know later whether the screen changes size."

	| hal form |
	hal := self useHAL.
	form := self newFormWidth: 640 height: 480 words: 10.

	self runPrimitive: #primitiveBeDisplay with: { form }.

	self
		assert: (hal callsTo: #displayWidth:displayHeight:)
		equals: { { 640. 480 } }.
	self
		assert: (interpreter instVarNamed: 'currentDisplay')
		equals: form.
	self
		assert: (interpreter instVarNamed: 'currentDisplayWidth')
		equals: 640.
	self
		assert: (interpreter instVarNamed: 'currentDisplayHeight')
		equals: 480
]

{ #category : 'tests - display primitives' }
InterpreterTest >> testBeDisplayIgnoresAHeightOf100OrLess [
	"The Smalltalk-80 system shrinks the screen to 100 lines just before it saves a snapshot, and sets it back when it resumes. The host is not asked to follow, and the current display stays the one it was."

	| hal form |
	hal := self useHAL.
	form := self newFormWidth: 640 height: 100 words: 10.

	self runPrimitive: #primitiveBeDisplay with: { form }.

	self assert: (hal callsTo: #displayWidth:displayHeight:) isEmpty.
	self deny: (interpreter instVarNamed: 'currentDisplay') equals: form
]

{ #category : 'tests - display primitives' }
InterpreterTest >> testBeDisplayOfTheSameFormDoesNothing [
	"Designating the Form that is already the screen is not passed on to the host: it would rebuild the window."

	| hal form |
	hal := self useHAL.
	form := self newFormWidth: 640 height: 480 words: 10.
	self runPrimitive: #primitiveBeDisplay with: { form }.

	self runPrimitive: #primitiveBeDisplay with: { form }.

	self
		assert: (hal callsTo: #displayWidth:displayHeight:) size
		equals: 1
]

{ #category : 'tests - display primitives' }
InterpreterTest >> testBeDisplayRefusedByTheHostFails [
	"If the host cannot show a screen of that size the primitive fails, so that the guest code knows. As in the VM of reference, the Form is nevertheless remembered as the current display, with its size: the next change of the screen compares with it."

	| form |
	self useHAL displayAccepted: false.
	form := self newFormWidth: 640 height: 480 words: 10.

	self runPrimitive: #primitiveBeDisplay with: { form }.

	self deny: interpreter success.
	self
		assert: (interpreter instVarNamed: 'currentDisplay')
		equals: form.
	self
		assert: (interpreter instVarNamed: 'currentDisplayWidth')
		equals: 640
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testBeSnapshotFile [
	"Primitive 128 takes the PosixFile on top of the stack and sets the name of the snapshot file of the file system to the String in its field 1. The VM saves the next snapshot, the one of the Smalltalk-80 snapshot primitive, under that name. The primitive logs the name, so the global Logger is replaced for the test."

	| fileSystem file logger |
	fileSystem := self useFileSystemOn: self newTemporaryDirectory.
	file := self newPosixFile.
	memory
		storePointer: 1
		ofObject: file
		withValue: (self newStringWith: 'my.im' asByteArray).
	logger := ST80Logger withFile: FileSystem memory root / 'test.log'.
	self useLogger: logger.

	self emptyStack.
	self push: file.
	interpreter initPrimitive.
	interpreter primitiveBeSnapshotFile.

	self assert: fileSystem snapshotFileName equals: 'my.im'
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testBecome [
	"become: swaps what the two object pointers designate: the first now has the contents of the second, and the other way round. The receiver is the answer."

	| first second |
	first := self objectWithFields: { (self integer: 1) }.
	second := self objectWithFields: {
			          (self integer: 2).
			          (self integer: 3) }.

	self
		assertPrimitive: #primitiveBecome
		with: {
				first.
				second }
		answers: first.

	self assert: (memory fetchWordLengthOf: first) equals: 2.
	self assert: (memory fetchWordLengthOf: second) equals: 1.
	self
		assert:
		(memory integerValueOf: (memory fetchPointer: 1 ofObject: first))
		equals: 3
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testBecomeOfAnIntegerFails [

	self assertPrimitiveFails: #primitiveBecome with: {
			(self objectWithFields: #(  )).
			(self integer: 3) }.
	self assertPrimitiveFails: #primitiveBecome with: {
			(self integer: 3).
			(self objectWithFields: #(  )) }
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testBitAnd [

	self
		assertResult: 8
		of: #primitiveBitAnd
		with: 12
		with: 10
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testBitOr [

	self
		assertResult: 14
		of: #primitiveBitOr
		with: 12
		with: 10
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testBitShiftLeft [

	self
		assertResult: 8
		of: #primitiveBitShift
		with: 1
		with: 3.
	self
		assertResult: 8192
		of: #primitiveBitShift
		with: 1
		with: 13
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testBitShiftOverflowFails [
	"1 bitShift: 14 is 16384, one too many"

	self assertFailureOf: #primitiveBitShift with: 1 with: 14
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testBitShiftRight [
	"Right shifts extend the sign"

	self
		assertResult: 4
		of: #primitiveBitShift
		with: 16
		with: -2.
	self
		assertResult: -4
		of: #primitiveBitShift
		with: -8
		with: -1
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testBitXor [

	self
		assertResult: 6
		of: #primitiveBitXor
		with: 12
		with: 10
]

{ #category : 'tests - blocks' }
InterpreterTest >> testBlockCopy [
	"blockCopy: makes a BlockContext whose home is the method context: the compiler pushes thisContext and the argument count first"

	| block |
	self run: #( 137 117 200 ) literals: #(  ) receiver: nilPointer.
	3 timesRepeat: [ interpreter cycle ].
	block := interpreter stackTop.

	self assert: self stackDepth equals: 1.
	self
		assert: (memory fetchClassOf: block)
		equals: self blockContextClass.
	self assert: (interpreter isBlockContext: block).
	self
		assert: (memory
				 fetchPointer: (Interpreter classVarNamed: 'HomeIndex')
				 ofObject: block)
		equals: context.
	self assert: (interpreter argumentCountOfBlock: block) equals: 0
]

{ #category : 'tests - blocks' }
InterpreterTest >> testBlockCopyOfABlockUsesTheHomeContext [
	"A block created while a block runs still has the method context as its home"

	| home inner |
	home := self
		        blockContextReturningTo: self callerContext
		        bytecodes: #( 137 117 200 ).

	3 timesRepeat: [ interpreter cycle ].
	inner := interpreter stackTop.

	self
		assert: (memory fetchClassOf: inner)
		equals: self blockContextClass.
	self
		assert: (memory
				 fetchPointer: (Interpreter classVarNamed: 'HomeIndex')
				 ofObject: inner)
		equals: home
]

{ #category : 'tests - return bytecodes' }
InterpreterTest >> testBlockReturnGoesToTheCaller [
	"Bytecode 125 returns the top of the stack of a block to its caller, not to the sender of its home"

	| caller |
	caller := self callerContext.
	self blockContextReturningTo: caller bytecodes: #( 119 125 ).

	2 timesRepeat: [ interpreter cycle ].

	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: caller.
	self assert: (self stackIntegerAt: 0) equals: 2
]

{ #category : 'tests - blocks' }
InterpreterTest >> testBlockReturnsItsValueToTheCaller [
	"The block answers the top of its stack to the context that sent value"

	self
		run: #( 137 117 200 164 2 119 125 201 )
		literals: #(  )
		receiver: nilPointer.
	7 timesRepeat: [ interpreter cycle ].

	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: context.
	self assert: self stackDepth equals: 1.
	self assert: (self stackIntegerAt: 0) equals: 2
]

{ #category : 'tests - blocks' }
InterpreterTest >> testBlockValue [
	"value runs the block: it becomes the active context, with the context that sent value as its caller"

	| block caller |
	self
		run: #( 137 117 200 164 2 119 125 201 )
		literals: #(  )
		receiver: nilPointer.
	caller := context.
	5 timesRepeat: [ interpreter cycle ].
	block := interpreter instVarNamed: 'activeContext'.

	self assert: (interpreter isBlockContext: block).
	self assert: interpreter caller equals: caller
]

{ #category : 'tests - blocks' }
InterpreterTest >> testBlockValueWithArgument [
	"value: copies its argument to the first field after the registers of the block: that is where the block code finds it"

	| block |
	self
		run: #( 137 118 200 164 2 16 125 119 202 )
		literals: #(  )
		receiver: nilPointer.
	6 timesRepeat: [ interpreter cycle ].
	block := interpreter instVarNamed: 'activeContext'.

	self assert: (interpreter isBlockContext: block).
	self
		assert: (memory integerValueOf:
				 (memory fetchPointer: self tempFrameStart ofObject: block))
		equals: 2.
	self assert: self stackDepth equals: 1
]

{ #category : 'tests - blocks' }
InterpreterTest >> testBlockValueWithWrongArgumentCountFails [
	"A block that takes an argument is not run by value: the primitive fails and the message is sent as an ordinary one, looked up in the class of the block"

	| fallback |
	fallback := self newMethodReturning: 5.
	self
		class: self blockContextClass
		understands: (self specialSelector: 25)
		as: fallback.
	self
		run: #( 137 118 200 164 2 16 125 201 )
		literals: #(  )
		receiver: nilPointer.
	5 timesRepeat: [ interpreter cycle ].

	self assert: (interpreter instVarNamed: 'method') equals: fallback
]

{ #category : 'tests - special selectors' }
InterpreterTest >> testByteAccessors [
	"The bits of a word are numbered from the high one: the high byte is bits 0 to 7, the low byte bits 8 to 15"

	self assert: (interpreter highByteOf: 16r1234) equals: 16r12.
	self assert: (interpreter lowByteOf: 16r1234) equals: 16r34
]

{ #category : 'tests - array primitives' }
InterpreterTest >> testByteObjectAtAndAtPut [
	"A byte object answers and stores SmallIntegers from 0 to 255"

	| bytes |
	bytes := self newBytesOf: 5.

	self
		assertPrimitive: #primitiveAtPut
		with: {
				bytes.
				(self integer: 2).
				(self integer: 200) }
		answers: (self integer: 200).

	self assert: (memory fetchByte: 1 ofObject: bytes) equals: 200.
	self
		assertPrimitive: #primitiveAt
		with: {
				bytes.
				(self integer: 2) }
		answers: (self integer: 200)
]

{ #category : 'tests - array primitives' }
InterpreterTest >> testByteObjectAtPutKeepsTheLowByte [
	"The value is reduced to its low byte"

	| bytes |
	bytes := self newBytesOf: 2.

	self
		assertPrimitive: #primitiveAtPut
		with: {
				bytes.
				(self integer: 1).
				(self integer: 300) }
		answers: (self integer: 300).

	self assert: (memory fetchByte: 0 ofObject: bytes) equals: 44
]

{ #category : 'tests - array primitives' }
InterpreterTest >> testByteObjectAtPutOfAnObjectFails [

	self assertPrimitiveFails: #primitiveAtPut with: {
			(self newBytesOf: 2).
			(self integer: 1).
			nilPointer }
]

{ #category : 'tests - array primitives' }
InterpreterTest >> testByteObjectSizeIsInBytes [
	"Five bytes take three words: the size is 5, the padding byte is not counted"

	self
		assertPrimitive: #primitiveSize
		with: { (self newBytesOf: 5) }
		answers: (self integer: 5)
]

{ #category : 'tests - process switch' }
InterpreterTest >> testCheckProcessSwitchChangesTheActiveProcess [
	"The switch itself, between two bytecodes: the active context is saved in the old Process, the new Process becomes the one of the scheduler, and its suspended context becomes the active context. No switch is waiting afterwards and newProcess is nil again."

	| other otherContext |
	self setUpSchedulerWithPriorities: 4 activeAt: 2.
	otherContext := self callerContext.
	other := self newProcessAt: 4.
	memory storePointer: 1 ofObject: other withValue: otherContext.
	interpreter transferTo: other.

	interpreter checkProcessSwitch.

	self
		assert: (memory fetchPointer: 1 ofObject: activeProcess)
		equals: context.
	self assert: self schedulerActiveProcess equals: other.
	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: otherContext.
	self deny: (interpreter instVarNamed: 'newProcessWaiting').
	self
		assert: (interpreter instVarNamed: 'newProcess')
		equals: nilPointer
]

{ #category : 'tests - process switch' }
InterpreterTest >> testCheckProcessSwitchDoesNothingWithNoRequest [
	"With no switch asked for and no signal buffered, checkProcessSwitch leaves everything as it is: the same active context and the same active Process."

	self setUpSchedulerWithPriorities: 4 activeAt: 3.

	interpreter checkProcessSwitch.

	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: context.
	self assert: self schedulerActiveProcess equals: activeProcess
]

{ #category : 'tests - process switch' }
InterpreterTest >> testCheckProcessSwitchLoadsTheRegistersOfTheNewProcess [
	"After a switch the registers of the interpreter describe the new Process: its context is the home context and the receiver is the one of that context."

	| other otherContext receiver |
	self setUpSchedulerWithPriorities: 4 activeAt: 2.
	receiver := self objectWithFields: { nilPointer }.
	otherContext := self
		                contextOf:
		                (self methodWithLiterals: #(  ) bytecodes: #( 118 ))
		                receiver: receiver
		                sender: nilPointer.
	other := self newProcessAt: 4.
	memory storePointer: 1 ofObject: other withValue: otherContext.
	interpreter transferTo: other.

	interpreter checkProcessSwitch.

	self
		assert: (interpreter instVarNamed: 'homeContext')
		equals: otherContext.
	self assert: (interpreter instVarNamed: 'receiver') equals: receiver
]

{ #category : 'tests - process switch' }
InterpreterTest >> testCheckProcessSwitchSignalsTheBufferedSemaphores [
	"A Semaphore signalled from outside the interpreter (the host: a key, a timer) is not signalled at once, it is put in a buffer. checkProcessSwitch signals each one, in turn, before looking at the switch: here two signals for one Semaphore and one for another."

	| first second |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	first := self newSemaphore.
	second := self newSemaphore.
	interpreter asynchronousSignal: first.
	interpreter asynchronousSignal: second.
	interpreter asynchronousSignal: first.

	interpreter checkProcessSwitch.

	self assert: (self excessSignalsOf: first) equals: 2.
	self assert: (self excessSignalsOf: second) equals: 1.
	self assert: (interpreter instVarNamed: 'semaphoreIndex') equals: 0
]

{ #category : 'tests - main loop' }
InterpreterTest >> testCheckTimerOfTheHostOnlyEvery256Cycles [
	"The host is not asked at each cycle, which would cost too much."

	| hal |
	hal := self useHAL.

	interpreter instVarNamed: 'cycleCounter' put: 255.
	interpreter checkTimerOfTheHost.
	self assert: (hal callsTo: #checkScheduledSemaphore) isEmpty.

	interpreter instVarNamed: 'cycleCounter' put: 256.
	interpreter checkTimerOfTheHost.
	self assert: (hal callsTo: #checkScheduledSemaphore) size equals: 1
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testComparisons [

	self
		assertBoolean: true
		of: #primitiveLessThan
		with: 3
		with: 4.
	self
		assertBoolean: false
		of: #primitiveLessThan
		with: 4
		with: 3.
	self
		assertBoolean: false
		of: #primitiveLessThan
		with: 3
		with: 3
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testComparisonsOrEqual [

	self
		assertBoolean: true
		of: #primitiveLessOrEqual
		with: 3
		with: 3.
	self
		assertBoolean: false
		of: #primitiveLessOrEqual
		with: 4
		with: 3.
	self
		assertBoolean: true
		of: #primitiveGreaterOrEqual
		with: 3
		with: 3.
	self
		assertBoolean: false
		of: #primitiveGreaterOrEqual
		with: 3
		with: 4
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testComparisonsWithNegativeNumbers [

	self
		assertBoolean: true
		of: #primitiveLessThan
		with: -4
		with: -3.
	self
		assertBoolean: true
		of: #primitiveLessThan
		with: -1
		with: 0
]

{ #category : 'tests - sends' }
InterpreterTest >> testConditionalJumpOnANonBooleanSendsMustBeBoolean [
	"A conditional jump on an object that is neither true nor false leaves it on the stack and sends mustBeBoolean to it"

	| handler receiver |
	handler := self newMethodReturning: 7.
	receiver := self newReceiverOf: (self
			             newClassInheritingFrom: nilPointer
			             methods:
			             { ((Interpreter classVarNamed: 'MustBeBooleanSelector')
			              -> handler) }).
	self run: #( 112 152 118 ) literals: #(  ) receiver: receiver.
	2 timesRepeat: [ interpreter cycle ].

	self
		assert: (interpreter instVarNamed: 'messageSelector')
		equals: (Interpreter classVarNamed: 'MustBeBooleanSelector').
	self assert: (interpreter instVarNamed: 'method') equals: handler
]

{ #category : 'tests - paste' }
InterpreterTest >> testControlIsNotPassedToTheGuestWhileAPasteRuns [
	"While the characters of a paste are being typed, a Control key down (the shortcut, or its repeat) is not passed on. Outside a paste it is, as before."

	| hal control |
	hal := self useClockHALListening.
	control := self
		           newKeyboardEventOf: 0
		           scanCode: 224
		           buttons: (UserInputEvent classVarNamed: 'CTRL_KEY_MASK').

	hal handleKeyboardEvent: control way: #down.
	self assert: (hal wordsOfType: 3) asArray equals: #( 138 ).

	hal instVarNamed: 'pasteProcess' put: Processor activeProcess.
	hal handleKeyboardEvent: control way: #down.
	self assert: (hal wordsOfType: 3) asArray equals: #( 138 )
]

{ #category : 'tests - copy bits primitive' }
InterpreterTest >> testCopyBitsAtAnUnalignedDestination [
	"A destination x that is not a multiple of 16 shifts the copied bits: 8 bits of ones copied at x = 4 fill bits 4 to 11 of the word, 16r0FF0 counting the bit 0 as the high one."

	| destination source blt |
	destination := self newFormWidth: 16 height: 1 words: 1.
	source := self newFormWidth: 16 height: 1 words: 1.
	memory
		storeWord: 0
		ofObject: (self bitsOfForm: source)
		withValue: 16rFFFF.
	blt := self newBitBltOn: destination source: source rule: 3.
	self setBitBlt: blt field: 4 to: 4.
	self setBitBlt: blt field: 6 to: 8.
	self setBitBlt: blt field: 7 to: 1.
	self setBitBlt: blt field: 12 to: 16.
	self setBitBlt: blt field: 13 to: 1.

	self useHAL.
	self runPrimitive: #primitiveCopyBits with: { blt }.

	self
		assert:
		(memory fetchWord: 0 ofObject: (self bitsOfForm: destination))
		equals: 16r0FF0
]

{ #category : 'tests - copy bits primitive' }
InterpreterTest >> testCopyBitsCombinationRules [
	"The 16 combination rules (BB p. 356) combine a source of 16r00FF with a destination of 16r0F0F: 0 clears, 1 is source AND destination, 3 is the source, 6 is source XOR destination, 7 is source OR destination, 10 is the complement of the destination, 15 sets every bit."

	#( #( 0 16r0 ) #( 1 16rF ) #( 2 16rF0 ) #( 3 16rFF ) #( 4 16rF00 )
	   #( 5 16rF0F ) #( 6 16rFF0 ) #( 7 16rFFF ) #( 8 16rF000 )
	   #( 9 16rF00F ) #( 10 16rF0F0 ) #( 11 16rF0FF ) #( 12 16rFF00 )
	   #( 13 16rFF0F ) #( 14 16rFFF0 ) #( 15 16rFFFF ) ) do: [ :pair |
			| destination source blt result |
			destination := self newFormWidth: 16 height: 1 words: 1.
			source := self newFormWidth: 16 height: 1 words: 1.
			memory
				storeWord: 0
				ofObject: (self bitsOfForm: destination)
				withValue: 16r0F0F.
			memory
				storeWord: 0
				ofObject: (self bitsOfForm: source)
				withValue: 16r00FF.
			blt := self
				       newBitBltOn: destination
				       source: source
				       rule: pair first.
			self setBitBlt: blt field: 6 to: 16.
			self setBitBlt: blt field: 7 to: 1.
			self setBitBlt: blt field: 12 to: 16.
			self setBitBlt: blt field: 13 to: 1.

			self useHAL.
			self runPrimitive: #primitiveCopyBits with: { blt }.
			result := memory
				          fetchWord: 0
				          ofObject: (self bitsOfForm: destination).

			self assert: result equals: pair last ]
]

{ #category : 'tests - copy bits primitive' }
InterpreterTest >> testCopyBitsCopiesTheSource [
	"Primitive 96 is BitBlt copyBits: it combines a rectangle of the source Form with the destination Form. With rule 3 (the source replaces the destination) a 16 x 2 source is copied word for word."

	| destination source blt |
	destination := self newFormWidth: 16 height: 2 words: 2.
	source := self newFormWidth: 16 height: 2 words: 2.
	memory
		storeWord: 0
		ofObject: (self bitsOfForm: source)
		withValue: 16rFFFF.
	memory
		storeWord: 1
		ofObject: (self bitsOfForm: source)
		withValue: 16rF0F0.
	blt := self newBitBltOn: destination source: source rule: 3.
	self setBitBlt: blt field: 6 to: 16.
	self setBitBlt: blt field: 7 to: 2.
	self setBitBlt: blt field: 12 to: 16.
	self setBitBlt: blt field: 13 to: 2.

	self useHAL.
	self runPrimitive: #primitiveCopyBits with: { blt }.

	self assert: interpreter success.
	self
		assert:
		(memory fetchWord: 0 ofObject: (self bitsOfForm: destination))
		equals: 16rFFFF.
	self
		assert:
		(memory fetchWord: 1 ofObject: (self bitsOfForm: destination))
		equals: 16rF0F0
]

{ #category : 'tests - copy bits primitive' }
InterpreterTest >> testCopyBitsFromAnOffsetInTheSource [
	"The source rectangle starts at (sourceX, sourceY): taking 8 bits from x = 8 of a source whose low byte is set copies those 8 bits to the high end of the destination."

	| destination source blt |
	destination := self newFormWidth: 16 height: 1 words: 1.
	source := self newFormWidth: 16 height: 1 words: 1.
	memory
		storeWord: 0
		ofObject: (self bitsOfForm: source)
		withValue: 16r00FF.
	blt := self newBitBltOn: destination source: source rule: 3.
	self setBitBlt: blt field: 6 to: 8.
	self setBitBlt: blt field: 7 to: 1.
	self setBitBlt: blt field: 8 to: 8.
	self setBitBlt: blt field: 12 to: 16.
	self setBitBlt: blt field: 13 to: 1.

	self useHAL.
	self runPrimitive: #primitiveCopyBits with: { blt }.

	self
		assert:
		(memory fetchWord: 0 ofObject: (self bitsOfForm: destination))
		equals: 16rFF00
]

{ #category : 'tests - copy bits primitive' }
InterpreterTest >> testCopyBitsIsClippedToTheClipRectangle [
	"Nothing is drawn outside the clipping rectangle of the BitBlt: a width of 16 clipped to 4 changes only the first 4 bits, the high ones."

	| destination source blt |
	destination := self newFormWidth: 16 height: 1 words: 1.
	source := self newFormWidth: 16 height: 1 words: 1.
	memory
		storeWord: 0
		ofObject: (self bitsOfForm: source)
		withValue: 16rFFFF.
	blt := self newBitBltOn: destination source: source rule: 3.
	self setBitBlt: blt field: 6 to: 16.
	self setBitBlt: blt field: 7 to: 1.
	self setBitBlt: blt field: 12 to: 4.
	self setBitBlt: blt field: 13 to: 1.

	self useHAL.
	self runPrimitive: #primitiveCopyBits with: { blt }.

	self
		assert:
		(memory fetchWord: 0 ofObject: (self bitsOfForm: destination))
		equals: 16rF000
]

{ #category : 'tests - copy bits primitive' }
InterpreterTest >> testCopyBitsOnAnotherFormDoesNotRefreshTheHost [
	"Drawing in a Form that is not the screen, an off-screen bitmap, is not shown: it changes the memory only."

	| hal destination blt |
	hal := self useHAL.
	destination := self newFormWidth: 16 height: 1 words: 1.
	blt := self newBitBltOn: destination source: nil rule: 15.
	self setBitBlt: blt field: 6 to: 16.
	self setBitBlt: blt field: 7 to: 1.
	self setBitBlt: blt field: 12 to: 16.
	self setBitBlt: blt field: 13 to: 1.

	self runPrimitive: #primitiveCopyBits with: { blt }.

	self assert: (hal callsTo: #updateDisplayRect:fromForm:) isEmpty.
	self
		assert:
		(memory fetchWord: 0 ofObject: (self bitsOfForm: destination))
		equals: 16rFFFF
]

{ #category : 'tests - copy bits primitive' }
InterpreterTest >> testCopyBitsOnTheDisplayRefreshesTheHost [
	"When the destination is the Form that is the screen, the rectangle that changed is shown on the host: filling 10 x 7 bits at (3, 5) updates exactly that rectangle."

	| hal destination blt |
	hal := self useHAL.
	destination := self newFormWidth: 32 height: 120 words: 240.
	self runPrimitive: #primitiveBeDisplay with: { destination }.
	blt := self newBitBltOn: destination source: nil rule: 15.
	self setBitBlt: blt field: 4 to: 3.
	self setBitBlt: blt field: 5 to: 5.
	self setBitBlt: blt field: 6 to: 10.
	self setBitBlt: blt field: 7 to: 7.
	self setBitBlt: blt field: 12 to: 32.
	self setBitBlt: blt field: 13 to: 120.

	self runPrimitive: #primitiveCopyBits with: { blt }.

	self
		assert: (hal callsTo: #updateDisplayRect:fromForm:)
		equals: { { (3 @ 5 corner: 13 @ 12) } }
]

{ #category : 'tests - copy bits primitive' }
InterpreterTest >> testCopyBitsWithARuleOutOfRangeFails [
	"A combination rule that is not 0 to 15 fails the primitive, so that the Smalltalk code of BitBlt >> copyBits takes over, and the BitBlt stays on the stack."

	| destination source |
	destination := self newFormWidth: 16 height: 1 words: 1.
	source := self newFormWidth: 16 height: 1 words: 1.
	self useHAL.

	#( 16 -1 ) do: [ :rule |
			| blt |
			blt := self newBitBltOn: destination source: source rule: rule.
			self runPrimitive: #primitiveCopyBits with: { blt }.
			self
				deny: interpreter success
				description: ('rule {1}' format: { rule }).
			self assert: self stackDepth equals: 1 ]
]

{ #category : 'tests - system primitives' }
InterpreterTest >> testCoreLeft [
	"Primitive 112 answers the number of free words of the object memory, as the guest sees it. The receiver is replaced by the answer, a LargePositiveInteger when it does not fit a SmallInteger."

	| free |
	free := memory freeWordsLeft.

	self runPrimitive: #primitiveCoreLeft with: { nilPointer }.

	self assert: interpreter success.
	self assert: self stackDepth equals: 1.
	self
		assert: (interpreter positive32BitValueOf: interpreter stackTop)
		equals: free
]

{ #category : 'tests - input and cursor primitives' }
InterpreterTest >> testCursorLinkFalse [
	"The argument false decouples the cursor: the host is told false, and the argument is popped."

	| hal |
	hal := self useHAL.

	self runPrimitive: #primitiveCursorLink with: { self falsePointer }.

	self assert: self stackDepth equals: 0.
	self assert: (hal callsTo: #cursorLink:) equals: { { false } }
]

{ #category : 'tests - input and cursor primitives' }
InterpreterTest >> testCursorLinkTrue [
	"Primitive 92 makes the cursor follow the pointing device when its argument is true and decouples it when false. The argument is popped and the host is told true."

	| hal |
	hal := self useHAL.

	self runPrimitive: #primitiveCursorLink with: { self truePointer }.

	self assert: self stackDepth equals: 0.
	self assert: (hal callsTo: #cursorLink:) equals: { { true } }
]

{ #category : 'tests - input and cursor primitives' }
InterpreterTest >> testCursorLocationPut [
	"Primitive 91 moves the cursor to a screen position given as a Point: the host is asked to put the cursor at that position, and the Point is popped."

	| hal |
	hal := self useHAL.

	self
		runPrimitive: #primitiveCursorLocPut
		with: { (self newPoint: 12 at: 34) }.

	self assert: interpreter success.
	self assert: self stackDepth equals: 0.
	self
		assert: (hal callsTo: #cursorLocation:)
		equals: { { (12 @ 34) } }
]

{ #category : 'tests - input and cursor primitives' }
InterpreterTest >> testCursorLocationPutOfANonPointFails [
	"The argument must be a Point: anything else fails the primitive, and the argument stays on the stack. The host is not asked to move the cursor."

	| hal |
	hal := self useHAL.

	self
		assertPrimitiveFails: #primitiveCursorLocPut
		with: { (self integer: 3) }.

	self assert: (hal callsTo: #cursorLocation:) isEmpty
]

{ #category : 'tests - main loop' }
InterpreterTest >> testCyclePollsTheTimerOfTheHost [
	"A cycle asks the host, every 256 cycles, if the time of the outstanding timer request has passed."

	| hal |
	hal := self useHAL.
	interpreter instVarNamed: 'cycleCounter' put: 255.
	self setUpSchedulerWithPriorities: 4 activeAt: 3.

	[ interpreter cycle ]
		on: Error
		do: [ :error | "the bytecode of the test context is of no interest" ].

	self assert: (hal callsTo: #checkScheduledSemaphore) size equals: 1
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testDirectoryCreate [
	"Primitive 131, operation 0 creates a file and answers its host file handle as a SmallInteger, or nil on failure. The file exists on the host afterwards."

	| directory |
	directory := self newTemporaryDirectory.
	self useFileSystemOn: directory.

	self
		directoryOperation: 0
		with: (self newStringWith: 'new.bin' asByteArray)
		and: nilPointer.

	self assert: interpreter success.
	self assert: (memory isIntegerObject: interpreter stackTop).
	self assert: (directory / 'new.bin') exists
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testDirectoryCreateTruncatesAnExistingFile [
	"The Smalltalk-80 guest creates a file with this operation even when it exists, and expects an empty file, as the creat call of Posix does: an existing file of 5 bytes is empty after the create, and the file handle that is answered writes from its start."

	| directory fileSystem |
	directory := self newTemporaryDirectory.
	fileSystem := self useFileSystemOn: directory.
	directory / 'old.bin' binaryWriteStreamDo: [ :stream |
		stream nextPutAll: #( 1 2 3 4 5 ) asByteArray ].

	self
		directoryOperation: 0
		with: (self newStringWith: 'old.bin' asByteArray)
		and: nilPointer.

	self assert: (directory / 'old.bin') size equals: 0.
	self
		assert: (fileSystem fileSize:
				 (interpreter positive32BitValueOf: interpreter stackTop))
		equals: 0.
	self
		assert: (fileSystem tell:
				 (interpreter positive32BitValueOf: interpreter stackTop))
		equals: 0
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testDirectoryDelete [
	"Operation 1 deletes a file by name and answers true."

	| directory |
	directory := self newTemporaryDirectory.
	self useFileSystemOn: directory.
	(directory / 'gone.bin') ensureCreateFile.

	self
		directoryOperation: 1
		with: (self newStringWith: 'gone.bin' asByteArray)
		and: nilPointer.

	self assert: interpreter stackTop equals: self truePointer.
	self deny: (directory / 'gone.bin') exists
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testDirectoryDeleteOfAMissingFileAnswersFalse [
	"A file that does not exist is not an error for the VM: the answer is false and the guest code decides."

	self useFileSystemOn: self newTemporaryDirectory.

	self
		directoryOperation: 1
		with: (self newStringWith: 'nothing.bin' asByteArray)
		and: nilPointer.

	self assert: interpreter success.
	self assert: interpreter stackTop equals: self falsePointer
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testDirectoryEnumerate [
	"Operation 3 answers an Array holding the name of each file of the directory, as a String. A subdirectory is not a file and is left out."

	| directory names array |
	directory := self newTemporaryDirectory.
	self useFileSystemOn: directory.
	(directory / 'a.txt') ensureCreateFile.
	(directory / 'b.txt') ensureCreateFile.
	(directory / 'subdirectory') ensureCreateDirectory.

	self directoryOperation: 3 with: nilPointer and: nilPointer.
	array := interpreter stackTop.
	names := (0 to: (memory fetchWordLengthOf: array) - 1) collect: [
			         :index |
			         interpreter stringFromST80Object:
				         (memory fetchPointer: index ofObject: array) ].

	self assert: interpreter success.
	self
		assert: (memory fetchClassOf: array)
		equals: (Interpreter classVarNamed: 'ClassArrayPointer').
	self assert: names sorted asArray equals: #( 'a.txt' 'b.txt' )
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testDirectoryEnumerateOfAnEmptyDirectory [

	self useFileSystemOn: self newTemporaryDirectory.

	self directoryOperation: 3 with: nilPointer and: nilPointer.

	self
		assert: (memory fetchWordLengthOf: interpreter stackTop)
		equals: 0
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testDirectoryOperationWithANameThatIsNotAStringFails [
	"The name must be a String or nil."

	self useFileSystemOn: self newTemporaryDirectory.

	self directoryOperation: 0 with: (self integer: 3) and: nilPointer.

	self deny: interpreter success.
	self assert: self stackDepth equals: 4
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testDirectoryOperationWithAnUnknownCodeFails [
	"Only the operation codes 0 to 3 exist: anything else fails the primitive and leaves the four operands on the stack."

	self useFileSystemOn: self newTemporaryDirectory.

	self directoryOperation: 9 with: nilPointer and: nilPointer.

	self deny: interpreter success.
	self assert: self stackDepth equals: 4
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testDirectoryPrimitiveIsReachedByItsIndex [
	"Primitive 131 with a header extension of 3 arguments: the receiver and the three arguments of a send (operation code, name, second argument) are the four operands the primitive pops, and enumerating answers an Array. A literal selector send takes at most 2 arguments, so the extended send (bytecode 131) is used: its descriptor byte holds the argument count in the three high bits."

	| selector directory |
	directory := self newTemporaryDirectory.
	self useFileSystemOn: directory.
	(directory / 'only.txt') ensureCreateFile.
	selector := self newSelector.
	self
		class: classPointer
		understands: selector
		as: (self methodWithPrimitive: 131 arguments: 3 fallback: #( 120 )).

	"push the receiver, the operation 3 (literal 1), nil and nil, then send literal 0 with 3 arguments"
	self
		run: {
				112.
				33.
				115.
				115.
				131.
				(3 * 32) }
		literals: {
				selector.
				(self integer: 3) }
		receiver: (self newReceiverOf: classPointer).
	5 timesRepeat: [ interpreter cycle ].

	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: context.
	self assert: self stackDepth equals: 1.
	self
		assert: (memory fetchWordLengthOf: interpreter stackTop)
		equals: 1
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testDirectoryRenameOfAClosedFile [
	"Operation 2 renames the file named in field 1 of the PosixFile (argument 2) to the name in argument 1, and stores the new name in the PosixFile. The file keeps its contents."

	| directory file |
	directory := self newTemporaryDirectory.
	self useFileSystemOn: directory.
	(directory / 'old.txt') ensureCreateFile.
	file := self newPosixFile.
	memory
		storePointer: 1
		ofObject: file
		withValue: (self newStringWith: 'old.txt' asByteArray).

	self
		directoryOperation: 2
		with: (self newStringWith: 'new.txt' asByteArray)
		and: file.

	self assert: interpreter stackTop equals: self truePointer.
	self deny: (directory / 'old.txt') exists.
	self assert: (directory / 'new.txt') exists.
	self
		assert: (interpreter stringFromST80Object:
				 (memory fetchPointer: 1 ofObject: file))
		equals: 'new.txt'
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testDirectoryRenameOfAnOpenFileKeepsItOpenAtTheSamePosition [
	"An open file is closed, renamed and opened again by the VM, so that the guest does not see the difference: the descriptor field still holds a handle, and the position in the file is where it was (4 here)."

	| directory fileSystem file handle |
	directory := self newTemporaryDirectory.
	fileSystem := self useFileSystemOn: directory.
	directory / 'old.bin' binaryWriteStreamDo: [ :stream |
		stream nextPutAll: #( 1 2 3 4 5 6 ) asByteArray ].
	file := self newPosixFile.
	memory
		storePointer: 1
		ofObject: file
		withValue: (self newStringWith: 'old.bin' asByteArray).
	self
		fileOperation: 4
		on: file
		name: (self newStringWith: 'old.bin' asByteArray)
		page: nilPointer.
	fileSystem
		seekTo: (interpreter positive32BitValueOf:
				 (memory fetchPointer: 8 ofObject: file))
		position: 4.

	self
		directoryOperation: 2
		with: (self newStringWith: 'new.bin' asByteArray)
		and: file.

	self assert: interpreter stackTop equals: self truePointer.
	self assert: (directory / 'new.bin') exists.
	handle := memory fetchPointer: 8 ofObject: file.
	self deny: handle equals: nilPointer.
	self
		assert:
		(fileSystem tell: (interpreter positive32BitValueOf: handle))
		equals: 4
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testDirectoryRenameToAnUnusableNameFails [
	"If the host refuses the new name the answer is false, the file keeps its old name and the PosixFile still holds the old name."

	| directory file |
	directory := self newTemporaryDirectory.
	self useFileSystemOn: directory.
	(directory / 'old.txt') ensureCreateFile.
	file := self newPosixFile.
	memory
		storePointer: 1
		ofObject: file
		withValue: (self newStringWith: 'old.txt' asByteArray).

	self
		directoryOperation: 2
		with: (self newStringWith: 'no/such/dir/x.txt' asByteArray)
		and: file.

	self assert: interpreter stackTop equals: self falsePointer.
	self assert: (directory / 'old.txt') exists.
	self
		assert: (interpreter stringFromST80Object:
				 (memory fetchPointer: 1 ofObject: file))
		equals: 'old.txt'
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testDiv [
	"// rounds toward negative infinity"

	self
		assertResult: 3
		of: #primitiveDiv
		with: 7
		with: 2.
	self
		assertResult: -4
		of: #primitiveDiv
		with: -7
		with: 2.
	self
		assertResult: -4
		of: #primitiveDiv
		with: 7
		with: -2
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testDivByZeroFails [

	self assertFailureOf: #primitiveDiv with: 7 with: 0
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testDivOverflowFails [
	"-16384 // -1 is 16384, one too many"

	self assertFailureOf: #primitiveDiv with: -16384 with: -1
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testDivide [
	"Exact division only: / fails when there is a remainder, so that the guest falls back on its own code (fractions)"

	self
		assertResult: 3
		of: #primitiveDivide
		with: 12
		with: 4.
	self
		assertResult: -3
		of: #primitiveDivide
		with: 12
		with: -4.
	self assertFailureOf: #primitiveDivide with: 13 with: 4
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testDivideByZeroFails [
	"A guest division by zero must fail the primitive, like // and \\, and not raise a host ZeroDivide"

	self assertFailureOf: #primitiveDivide with: 12 with: 0
]

{ #category : 'tests - extended sends' }
InterpreterTest >> testDoubleExtendedSend [
	"Bytecode 132 is followed by the argument count, then the literal index: both a whole byte"

	| selector receiver |
	selector := self newSelector.
	receiver := self newReceiverOf: (self
			             newClassInheritingFrom: nilPointer
			             methods:
			             { (selector
			              ->
			              (self methodWithArguments: 1 bytecodes: #( 16 124 ))) }).

	self
		run: #( 112 119 132 1 0 )
		literals: { selector }
		receiver: receiver.
	3 timesRepeat: [ interpreter cycle ].

	self assert: (interpreter instVarNamed: 'argumentCount') equals: 1.
	self
		assert: (memory integerValueOf: (interpreter temporary: 0))
		equals: 2
]

{ #category : 'tests - extended sends' }
InterpreterTest >> testDoubleExtendedSuperSend [
	"Bytecode 134 does the same, with the argument count and the literal index in two bytes"

	| selector classes sender |
	selector := self newSelector.
	classes := self twoClassesUnderstanding: selector.
	sender := self
		          superSenderWith: { selector }
		          bytecodes: #( 112 134 0 0 )
		          methodClass: classes value.

	self runMethod: sender receiver: (self newReceiverOf: classes value).
	2 timesRepeat: [ interpreter cycle ].

	self
		assert: (memory integerValueOf:
				 (interpreter
					  literal: 0
					  ofMethod: (interpreter instVarNamed: 'method')))
		equals: 1
]

{ #category : 'tests - stack bytecodes' }
InterpreterTest >> testDuplicateTop [
	"Bytecode 136 pushes a second copy of the top of the stack"

	self runBytecodes: #( 119 136 ).

	self assert: self stackDepth equals: 2.
	self assert: (self stackIntegerAt: 0) equals: 2.
	self assert: (self stackIntegerAt: 1) equals: 2
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testEqualAndNotEqual [

	self
		assertBoolean: true
		of: #primitiveEqual
		with: 3
		with: 3.
	self
		assertBoolean: false
		of: #primitiveEqual
		with: 3
		with: 4.
	self
		assertBoolean: false
		of: #primitiveNotEqual
		with: 3
		with: 3.
	self
		assertBoolean: true
		of: #primitiveNotEqual
		with: 3
		with: 4
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testErrorString [
	"Primitive 133 answers a new String that describes an error code, to show to the user of the guest system. The text is the one of ST80FileSystem >> errorText:."

	| string |
	self useFileSystemOn: self newTemporaryDirectory.

	self runPrimitive: #primitivePosixErrorString with: {
			nilPointer.
			(self integer: -1) }.
	string := interpreter stackTop.

	self assert: interpreter success.
	self assert: self stackDepth equals: 1.
	self
		assert: (memory fetchClassOf: string)
		equals: (Interpreter classVarNamed: 'ClassStringPointer').
	self
		assert: (interpreter stringFromST80Object: string)
		equals: 'File system error: -1'
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testErrorStringWithACodeThatIsNotAnIntegerFails [
	"The code must be a SmallInteger: the primitive fails and leaves its two operands on the stack."

	self useFileSystemOn: self newTemporaryDirectory.

	self assertPrimitiveFails: #primitivePosixErrorString with: {
			nilPointer.
			nilPointer }
]

{ #category : 'tests - float conversions' }
InterpreterTest >> testExponentAndTimesTwoPowerAreNotImplemented [
	"exponent (primitive 53) and timesTwoPower: (primitive 54) are optional in the Blue Book. This VM does not implement them: they always fail, so that the guest Smalltalk code of Float runs instead. The receiver and the argument stay on the stack."

	self
		assertPrimitiveFails: #primitiveExponent
		with: { (self newFloat: 8) }.
	self assertPrimitiveFails: #primitiveTimesTwoPower with: {
			(self newFloat: 8).
			(self integer: 2) }
]

{ #category : 'tests - extended bytecodes' }
InterpreterTest >> testExtendedPushLiteralConstant [
	"Kind 2 is a literal of the method"

	self
		runBytecodes: #( 128 129 )
		literals: {
				(memory integerObjectOf: 5).
				(memory integerObjectOf: 6) }
		receiver: nilPointer.

	self assert: (self stackIntegerAt: 0) equals: 6
]

{ #category : 'tests - extended bytecodes' }
InterpreterTest >> testExtendedPushLiteralVariable [
	"Kind 3 is the value of an association of the literal frame"

	| association |
	association := self objectWithFields: {
			               nilPointer.
			               (memory integerObjectOf: 9) }.

	self
		runBytecodes: #( 128 192 )
		literals: { association }
		receiver: nilPointer.

	self assert: (self stackIntegerAt: 0) equals: 9
]

{ #category : 'tests - extended bytecodes' }
InterpreterTest >> testExtendedPushReachesFurtherThanTheShortForms [
	"The short push bytecodes reach 16 receiver variables, the extended one 64"

	| receiver |
	receiver := memory instantiateClass: classPointer withPointers: 40.
	memory countUp: receiver.
	memory
		storePointer: 33
		ofObject: receiver
		withValue: (memory integerObjectOf: 7).

	self runBytecodes: #( 128 33 ) literals: #(  ) receiver: receiver.

	self assert: (self stackIntegerAt: 0) equals: 7
]

{ #category : 'tests - extended bytecodes' }
InterpreterTest >> testExtendedPushReceiverVariable [
	"Bytecode 128 is followed by a byte: its two high bits give the kind of variable (0 is a receiver variable) and its six low bits the index"

	| receiver |
	receiver := self objectWithFields: {
			            (memory integerObjectOf: 5).
			            (memory integerObjectOf: 6).
			            (memory integerObjectOf: 77) }.

	self runBytecodes: #( 128 2 ) literals: #(  ) receiver: receiver.

	self assert: (self stackIntegerAt: 0) equals: 77
]

{ #category : 'tests - extended bytecodes' }
InterpreterTest >> testExtendedPushTemporaryVariable [
	"Kind 1 is a temporary of the home context"

	self run: #( 128 65 ) literals: #(  ) receiver: nilPointer.
	memory
		storePointer: self tempFrameStart + 1
		ofObject: context
		withValue: (memory integerObjectOf: 33).

	interpreter cycle.

	self assert: (self stackIntegerAt: 0) equals: 33
]

{ #category : 'tests - extended bytecodes' }
InterpreterTest >> testExtendedStoreAndPopLiteralVariable [
	"Kind 3 stores in the value of an association"

	| association |
	association := self objectWithFields: {
			               nilPointer.
			               (memory integerObjectOf: 9) }.

	self
		runBytecodes: #( 119 130 192 )
		literals: { association }
		receiver: nilPointer.

	self assert: self stackDepth equals: 0.
	self
		assert:
		(memory integerValueOf:
			 (memory fetchPointer: 1 ofObject: association))
		equals: 2
]

{ #category : 'tests - extended bytecodes' }
InterpreterTest >> testExtendedStoreAndPopReceiverVariable [
	"Bytecode 130 does the same, then pops"

	| receiver |
	receiver := self objectWithFields: {
			            (memory integerObjectOf: 5).
			            (memory integerObjectOf: 6) }.

	self runBytecodes: #( 119 130 1 ) literals: #(  ) receiver: receiver.

	self assert: self stackDepth equals: 0.
	self
		assert:
		(memory integerValueOf: (memory fetchPointer: 1 ofObject: receiver))
		equals: 2
]

{ #category : 'tests - extended bytecodes' }
InterpreterTest >> testExtendedStoreAndPopTemporaryVariable [

	self runBytecodes: #( 119 130 66 ).

	self assert: self stackDepth equals: 0.
	self
		assert: (memory integerValueOf: (interpreter temporary: 2))
		equals: 2
]

{ #category : 'tests - extended bytecodes' }
InterpreterTest >> testExtendedStoreIntoALiteralConstantIsIllegal [
	"Kind 2 (literal constant) cannot be stored into"

	self run: #( 119 129 130 ) literals: #(  ) receiver: nilPointer.
	interpreter cycle.

	self should: [ interpreter cycle ] raise: Error
]

{ #category : 'tests - extended bytecodes' }
InterpreterTest >> testExtendedStoreKeepsTheValueOnTheStack [
	"Bytecode 129 stores the top of the stack in a receiver variable, a temporary or a literal variable, and leaves it there"

	| receiver |
	receiver := self objectWithFields: {
			            (memory integerObjectOf: 5).
			            (memory integerObjectOf: 6) }.

	self runBytecodes: #( 118 129 1 ) literals: #(  ) receiver: receiver.

	self assert: self stackDepth equals: 1.
	self
		assert:
		(memory integerValueOf: (memory fetchPointer: 1 ofObject: receiver))
		equals: 1
]

{ #category : 'tests - float dispatch' }
InterpreterTest >> testFailedFloatPrimitiveRunsTheMethodBody [
	"When a float primitive fails, here 1.5 + 3 whose argument is not a Float, the bytecodes of the method run as a fallback: a new context becomes active. That is how the guest code coerces the argument and retries."

	| selector method |
	selector := self newSelector.
	method := self
		          methodWithPrimitive: 41
		          arguments: 1
		          fallback: #( 120 ).
	self
		class: (Interpreter classVarNamed: 'ClassFloatPointer')
		understands: selector
		as: method.

	self
		run: #( 112 33 224 )
		literals: {
				selector.
				(self integer: 3) }
		receiver: (self newFloat: 1.5).
	3 timesRepeat: [ interpreter cycle ].

	self assert: (interpreter instVarNamed: 'method') equals: method.
	self
		deny: (interpreter instVarNamed: 'activeContext')
		equals: context
]

{ #category : 'tests - special selectors' }
InterpreterTest >> testFailedPrimitiveRunsTheMethodBody [
	"When the primitive fails the bytecodes of the method are the fallback: a context is created"

	| selector method |
	selector := self newSelector.
	method := self
		          methodWithPrimitive: 1
		          arguments: 1
		          fallback: #( 32 124 ).
	self
		class: (Interpreter classVarNamed: 'ClassSmallInteger')
		understands: selector
		as: method.

	"1 + true: the argument is not an integer"
	self
		run: #( 118 113 224 )
		literals: { selector }
		receiver: nilPointer.
	3 timesRepeat: [ interpreter cycle ].

	self assert: (interpreter instVarNamed: 'method') equals: method.
	self
		deny: (interpreter instVarNamed: 'activeContext')
		equals: context
]

{ #category : 'tests - stack' }
InterpreterTest >> testFetchContextRegisters [
	"The registers are read back from the context: fetching after storing restores them"

	self pushInteger: 1.
	interpreter instVarNamed: 'instructionPointer' put: 9.
	interpreter storeContextRegisters.
	interpreter instVarNamed: 'instructionPointer' put: 0.
	interpreter instVarNamed: 'stackPointer' put: 0.

	interpreter fetchContextRegisters.

	self
		assert: (interpreter instVarNamed: 'instructionPointer')
		equals: 9.
	self assert: self stackDepth equals: 1.
	self
		assert: (interpreter instVarNamed: 'homeContext')
		equals: context
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testFileClose [
	"Operation 5 closes the host file, answers true and puts nil back in the descriptor field: the PosixFile is closed for the guest."

	| directory file |
	directory := self newTemporaryDirectory.
	self useFileSystemOn: directory.
	(directory / 'c.bin') ensureCreateFile.
	file := self newPosixFile.
	self
		fileOperation: 4
		on: file
		name: (self newStringWith: 'c.bin' asByteArray)
		page: nilPointer.

	self
		fileOperation: 5
		on: file
		name: nilPointer
		page: nilPointer.

	self assert: interpreter stackTop equals: self truePointer.
	self
		assert: (memory fetchPointer: 8 ofObject: file)
		equals: nilPointer
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testFileOpenOfAMissingFileFails [
	"Primitive 130, operation 4 opens an existing file by name. A file that does not exist is not an error for the VM: the primitive answers false and the PosixFile keeps a nil descriptor, so that the guest code can report it."

	| file |
	self useFileSystemOn: self newTemporaryDirectory.
	file := self newPosixFile.

	self
		fileOperation: 4
		on: file
		name: (self newStringWith: 'missing.bin' asByteArray)
		page: nilPointer.

	self assert: interpreter success.
	self assert: interpreter stackTop equals: self falsePointer.
	self
		assert: (memory fetchPointer: 8 ofObject: file)
		equals: nilPointer
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testFileOpenOfAnExistingFile [
	"Opening an existing file answers true and stores the host file handle, as a SmallInteger, in field 8 of the PosixFile: every later operation finds the file through it."

	| directory file |
	directory := self newTemporaryDirectory.
	self useFileSystemOn: directory.
	(directory / 'a.bin') ensureCreateFile.
	file := self newPosixFile.

	self
		fileOperation: 4
		on: file
		name: (self newStringWith: 'a.bin' asByteArray)
		page: nilPointer.

	self assert: interpreter success.
	self assert: interpreter stackTop equals: self truePointer.
	self deny: (memory fetchPointer: 8 ofObject: file) equals: nilPointer
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testFileOpenWithANameThatIsNotAStringFails [
	"The name must be a String: anything else fails the primitive and leaves the four operands (receiver, code, name, page) on the stack for the Smalltalk fallback code."

	self useFileSystemOn: self newTemporaryDirectory.

	self
		fileOperation: 4
		on: self newPosixFile
		name: (self integer: 3)
		page: nilPointer.

	self deny: interpreter success.
	self assert: self stackDepth equals: 4
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testFileOperationOnANilFileFails [
	"The receiver must be a PosixFile, not nil."

	self useFileSystemOn: self newTemporaryDirectory.

	self
		fileOperation: 3
		on: nilPointer
		name: nilPointer
		page: nilPointer.

	self deny: interpreter success.
	self assert: self stackDepth equals: 4
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testFileOperationWithAnUnknownCodeFails [
	"Only the operation codes 0 to 5 exist."

	self useFileSystemOn: self newTemporaryDirectory.

	self
		fileOperation: 6
		on: self newPosixFile
		name: nilPointer
		page: nilPointer.

	self deny: interpreter success.
	self assert: self stackDepth equals: 4
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testFileOperationsOnAFileAbove8MB [
	"A page number above 16383 is a LargePositiveInteger: a file above 8 MB. Page 20000 is at byte 10239488. Writing it makes a sparse file of that size plus the bytes of the page, the size is answered as a LargePositiveInteger, and the page reads back."

	| directory file page read |
	directory := self newTemporaryDirectory.
	self useFileSystemOn: directory.
	(directory / 'big.bin') ensureCreateFile.
	file := self newPosixFile.
	self
		fileOperation: 4
		on: file
		name: (self newStringWith: 'big.bin' asByteArray)
		page: nilPointer.
	page := self newPosixFilePage: 1 bytes: 3.
	memory
		storePointer: 3
		ofObject: page
		withValue: (interpreter positive32BitIntegerFor: 20000).
	self fillBufferOf: page with: #( 1 2 3 ) asByteArray.

	self
		fileOperation: 1
		on: file
		name: nilPointer
		page: page.
	self assert: interpreter stackTop equals: self truePointer.
	self
		fileOperation: 3
		on: file
		name: nilPointer
		page: nilPointer.

	self
		assert: (memory fetchClassOf: interpreter stackTop)
		equals:
		(Interpreter classVarNamed: 'ClassLargePositiveIntegerPointer').
	self
		assert: (interpreter positive32BitValueOf: interpreter stackTop)
		equals: 10239491.

	read := self newPosixFilePage: 1 bytes: 0.
	memory
		storePointer: 3
		ofObject: read
		withValue: (interpreter positive32BitIntegerFor: 20000).
	self
		fileOperation: 0
		on: file
		name: nilPointer
		page: read.

	self
		assert: (self bufferBytesOf: read count: 3)
		equals: #( 1 2 3 ) asByteArray
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testFileOperationsOnAnUnopenedFileFail [
	"Read, write, truncate and size need an open file: with a nil descriptor the primitive fails and leaves its four operands on the stack."

	self useFileSystemOn: self newTemporaryDirectory.

	#( 0 1 2 ) do: [ :code |
			self
				fileOperation: code
				on: self newPosixFile
				name: nilPointer
				page: (self newPosixFilePage: 1 bytes: 1).
			self deny: interpreter success.
			self assert: self stackDepth equals: 4 ].
	self
		fileOperation: 3
		on: self newPosixFile
		name: nilPointer
		page: nilPointer.
	self deny: interpreter success.
	self assert: self stackDepth equals: 4
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testFilePrimitivesAreReachedByTheirIndex [
	"The private primitives 128 and 130 to 133 are dispatched by dispatchPrivatePrimitives, like the others by their index. Here a method of the test class with primitive 132 (last error) is sent a message: the answer, 0 as nothing failed, replaces the receiver on the stack of the sender and no context is created."

	| selector |
	self useFileSystemOn: self newTemporaryDirectory.
	selector := self newSelector.
	self
		class: classPointer
		understands: selector
		as: (self methodWithPrimitive: 132 arguments: 0 fallback: #( 120 )).

	self
		run: #( 112 208 )
		literals: { selector }
		receiver: (self newReceiverOf: classPointer).
	2 timesRepeat: [ interpreter cycle ].

	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: context.
	self assert: self stackDepth equals: 1.
	self assert: (self stackIntegerAt: 0) equals: 0
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testFileReadOfPageZeroFails [
	"Pages are numbered from 1: page 0 fails the primitive (see fetchPageNumberOf:)."

	| directory file page |
	directory := self newTemporaryDirectory.
	self useFileSystemOn: directory.
	(directory / 'z.bin') ensureCreateFile.
	file := self newPosixFile.
	self
		fileOperation: 4
		on: file
		name: (self newStringWith: 'z.bin' asByteArray)
		page: nilPointer.
	page := self newPosixFilePage: 1 bytes: 0.
	memory storePointer: 3 ofObject: page withValue: (self integer: 0).

	self
		fileOperation: 0
		on: file
		name: nilPointer
		page: page.

	self deny: interpreter success.
	self assert: self stackDepth equals: 4
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testFileReadPastTheEndAnswersZeroBytes [
	"Reading a page beyond the end of the file is not an error: the primitive answers true and the number of bytes read is 0, which is how the guest code detects the end of the file."

	| directory file page |
	directory := self newTemporaryDirectory.
	self useFileSystemOn: directory.
	directory / 'e.bin' binaryWriteStreamDo: [ :stream |
		stream nextPutAll: #( 1 2 3 ) asByteArray ].
	file := self newPosixFile.
	self
		fileOperation: 4
		on: file
		name: (self newStringWith: 'e.bin' asByteArray)
		page: nilPointer.
	page := self newPosixFilePage: 3 bytes: 99.

	self
		fileOperation: 0
		on: file
		name: nilPointer
		page: page.

	self assert: interpreter stackTop equals: self truePointer.
	self
		assert:
		(memory integerValueOf: (memory fetchPointer: 4 ofObject: page))
		equals: 0
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testFileSize [
	"Operation 3 answers the size of the open file in bytes, as a SmallInteger."

	| directory file |
	directory := self newTemporaryDirectory.
	self useFileSystemOn: directory.
	directory / 's.bin' binaryWriteStreamDo: [ :stream |
		stream nextPutAll: #( 1 2 3 4 5 ) asByteArray ].
	file := self newPosixFile.
	self
		fileOperation: 4
		on: file
		name: (self newStringWith: 's.bin' asByteArray)
		page: nilPointer.

	self
		fileOperation: 3
		on: file
		name: nilPointer
		page: nilPointer.

	self assert: interpreter success.
	self assert: (self stackIntegerAt: 0) equals: 5
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testFileTruncate [
	"Operation 2 cuts the file after the bytes in use of the given page: page 2 with 4 bytes is a file of 512 + 4 bytes."

	| directory file |
	directory := self newTemporaryDirectory.
	self useFileSystemOn: directory.
	directory / 't.bin' binaryWriteStreamDo: [ :stream |
		stream nextPutAll: (ByteArray new: 522) ].
	file := self newPosixFile.
	self
		fileOperation: 4
		on: file
		name: (self newStringWith: 't.bin' asByteArray)
		page: nilPointer.

	self
		fileOperation: 2
		on: file
		name: nilPointer
		page: (self newPosixFilePage: 2 bytes: 4).
	self assert: interpreter stackTop equals: self truePointer.
	self
		fileOperation: 5
		on: file
		name: nilPointer
		page: nilPointer.

	self assert: (directory / 't.bin') size equals: 516
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testFileWriteAndReadAPage [
	"The guest reads and writes a file by pages of 512 bytes. Write (operation 1) copies the bytes in use of the page buffer to the file at (page number - 1) * 512, and read (operation 0) fills the buffer from the same place and sets the number of bytes read. Here 5 bytes are written to page 1 and read back into another page."

	| directory file written read |
	directory := self newTemporaryDirectory.
	self useFileSystemOn: directory.
	(directory / 'p.bin') ensureCreateFile.
	file := self newPosixFile.
	self
		fileOperation: 4
		on: file
		name: (self newStringWith: 'p.bin' asByteArray)
		page: nilPointer.
	written := self newPosixFilePage: 1 bytes: 5.
	self fillBufferOf: written with: #( 1 2 3 4 5 ) asByteArray.

	self
		fileOperation: 1
		on: file
		name: nilPointer
		page: written.
	self assert: interpreter stackTop equals: self truePointer.

	read := self newPosixFilePage: 1 bytes: 0.
	self
		fileOperation: 0
		on: file
		name: nilPointer
		page: read.

	self assert: interpreter stackTop equals: self truePointer.
	self
		assert:
		(memory integerValueOf: (memory fetchPointer: 4 ofObject: read))
		equals: 5.
	self
		assert: (self bufferBytesOf: read count: 5)
		equals: #( 1 2 3 4 5 ) asByteArray
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testFileWriteGoesToThePositionOfThePageNumber [
	"Page n starts at byte (n - 1) * 512 of the file: writing page 2 after page 1 makes a file of 512 + the bytes of page 2, and writing page 1 does not change the size of a longer file."

	| directory file |
	directory := self newTemporaryDirectory.
	self useFileSystemOn: directory.
	(directory / 'q.bin') ensureCreateFile.
	file := self newPosixFile.
	self
		fileOperation: 4
		on: file
		name: (self newStringWith: 'q.bin' asByteArray)
		page: nilPointer.

	self
		fileOperation: 1
		on: file
		name: nilPointer
		page: (self newPosixFilePage: 1 bytes: 512).
	self
		fileOperation: 1
		on: file
		name: nilPointer
		page: (self newPosixFilePage: 2 bytes: 10).
	self
		fileOperation: 5
		on: file
		name: nilPointer
		page: nilPointer.

	self assert: (directory / 'q.bin') size equals: 522
]

{ #category : 'tests - float arithmetic' }
InterpreterTest >> testFloatAdd [
	"Float add (primitive 41) pops two Float objects, adds the host floats and pushes a new Float object holding the sum. 1.5 + 2.25 is 3.75, exact in single precision. A negative operand is a subtraction."

	self
		assertFloatPrimitive: #primitiveFloatAdd
		with: #( 1.5 2.25 )
		answers: 3.75.
	self
		assertFloatPrimitive: #primitiveFloatAdd
		with: #( 1.5 -4.0 )
		answers: -2.5
]

{ #category : 'tests - float arithmetic' }
InterpreterTest >> testFloatArithmeticOnAnIntegerFails [
	"The Float primitives need two Float objects: a SmallInteger, as receiver or as argument, fails the primitive and both operands stay on the stack, so that the guest code can convert and retry."

	#( primitiveFloatAdd primitiveFloatSubstract primitiveFloatMultiply
	   primitiveFloatDivide ) do: [ :primitive |
			self assertPrimitiveFails: primitive with: {
					(self newFloat: 1.5).
					(self integer: 3) }.
			self assertPrimitiveFails: primitive with: {
					(self integer: 3).
					(self newFloat: 1.5) } ]
]

{ #category : 'tests - float arithmetic' }
InterpreterTest >> testFloatArithmeticOnAnotherObjectFails [
	"Any object that is not a Float fails the primitive, not only a SmallInteger: here nil."

	self assertPrimitiveFails: #primitiveFloatAdd with: {
			(self newFloat: 1.5).
			nilPointer }.
	self assertPrimitiveFails: #primitiveFloatAdd with: {
			nilPointer.
			(self newFloat: 1.5) }
]

{ #category : 'tests - float arithmetic' }
InterpreterTest >> testFloatArithmeticOverflowsToInfinity [
	"A result too large for single precision becomes an infinity when it is stored, it does not fail: 1e30 * 1e30 is far above the largest single, about 3.4e38."

	self
		assertFloatPrimitive: #primitiveFloatMultiply
		with: #( 1.0e30 1.0e30 )
		answers: Float infinity
]

{ #category : 'tests - float arithmetic' }
InterpreterTest >> testFloatArithmeticRoundsToSinglePrecision [
	"The result is stored on 32 bits: a Float of the guest has the precision of an IEEE single (about 7 decimal digits), not of the 64 bit float of the host. 0.1 + 0.2 comes back as the single precision nearest to the sum of the two single precision operands, which is not the host 0.1 + 0.2."

	| single |
	single := Float fromIEEE32Bit:
		          ((Float fromIEEE32Bit: 0.1 asIEEE32BitWord)
		           + (Float fromIEEE32Bit: 0.2 asIEEE32BitWord))
			          asIEEE32BitWord.

	self runPrimitive: #primitiveFloatAdd with: {
			(self newFloat: 0.1).
			(self newFloat: 0.2) }.

	self assert: (self floatValueOf: interpreter stackTop) equals: single.
	self
		deny: (self floatValueOf: interpreter stackTop)
		equals: 0.1 + 0.2
]

{ #category : 'tests - float arithmetic' }
InterpreterTest >> testFloatArithmeticUnderflowsToZero [
	"A result too small for single precision becomes zero when it is stored: 1e-30 * 1e-30 is far below the smallest single, about 1.4e-45."

	self
		assertFloatPrimitive: #primitiveFloatMultiply
		with: #( 1.0e-30 1.0e-30 )
		answers: 0.0
]

{ #category : 'tests - float comparisons' }
InterpreterTest >> testFloatComparisonsOnNonFloatsFail [
	"Every Float comparison fails, leaving both operands on the stack, if one of them is not a Float: here a SmallInteger as argument and as receiver."

	#( primitiveFloatLessThan primitiveFloatGreaterThan
	   primitiveFloatLessOrEqual primitiveFloatGreaterOrEqual
	   primitiveFloatEqual primitiveFloatNotEqual ) do: [ :primitive |
			self assertPrimitiveFails: primitive with: {
					(self newFloat: 1.5).
					(self integer: 3) }.
			self assertPrimitiveFails: primitive with: {
					(self integer: 3).
					(self newFloat: 1.5) } ]
]

{ #category : 'tests - float comparisons' }
InterpreterTest >> testFloatComparisonsWithNaN [
	"NaN is neither less, greater nor equal to anything, itself included, and is different from everything: that is the IEEE rule, and what the guest code expects."

	self
		assertFloatPrimitive: #primitiveFloatEqual
		with: {
				Float nan.
				Float nan }
		answersBoolean: false.
	self
		assertFloatPrimitive: #primitiveFloatLessThan
		with: {
				Float nan.
				1.0 }
		answersBoolean: false.
	self
		assertFloatPrimitive: #primitiveFloatGreaterThan
		with: {
				Float nan.
				1.0 }
		answersBoolean: false.
	self
		assertFloatPrimitive: #primitiveFloatNotEqual
		with: {
				Float nan.
				1.0 }
		answersBoolean: true
]

{ #category : 'tests - float comparisons' }
InterpreterTest >> testFloatComparisonsWithNegativeNumbers [
	"The comparison is on the signed value, not on the bits: -4.0 < -1.5 and -1.5 < 0.0, although the sign bit makes the IEEE words of the negative numbers larger."

	self
		assertFloatPrimitive: #primitiveFloatLessThan
		with: #( -4.0 -1.5 )
		answersBoolean: true.
	self
		assertFloatPrimitive: #primitiveFloatLessThan
		with: #( -1.5 0.0 )
		answersBoolean: true.
	self
		assertFloatPrimitive: #primitiveFloatGreaterThan
		with: #( -1.5 -4.0 )
		answersBoolean: true
]

{ #category : 'tests - float arithmetic' }
InterpreterTest >> testFloatDivide [
	"Float divide (primitive 50) answers receiver divided by argument: 10 / 4 is 2.5, and 1 / 4 is 0.25. Both are exact in single precision."

	self
		assertFloatPrimitive: #primitiveFloatDivide
		with: #( 10.0 4.0 )
		answers: 2.5.
	self
		assertFloatPrimitive: #primitiveFloatDivide
		with: #( 1.0 4.0 )
		answers: 0.25
]

{ #category : 'tests - float arithmetic' }
InterpreterTest >> testFloatDivideByZeroFails [
	"A division by zero fails the primitive: the guest code decides what to do (it raises a ZeroDivide). The VM must not produce an infinity or raise a host ZeroDivide. Both operands stay on the stack."

	self assertPrimitiveFails: #primitiveFloatDivide with: {
			(self newFloat: 1).
			(self newFloat: 0) }
]

{ #category : 'tests - float comparisons' }
InterpreterTest >> testFloatEqual [
	"Float equal (primitive 47) compares the values, not the object pointers: two different Float objects holding 1.5 are equal."

	self
		assertFloatPrimitive: #primitiveFloatEqual
		with: #( 1.5 1.5 )
		answersBoolean: true.
	self
		assertFloatPrimitive: #primitiveFloatEqual
		with: #( 1.5 2.25 )
		answersBoolean: false
]

{ #category : 'tests - float comparisons' }
InterpreterTest >> testFloatGreaterOrEqual [
	"Float greater or equal (primitive 46): true for a larger number and for the same number, false for a smaller one."

	self
		assertFloatPrimitive: #primitiveFloatGreaterOrEqual
		with: #( 2.25 1.5 )
		answersBoolean: true.
	self
		assertFloatPrimitive: #primitiveFloatGreaterOrEqual
		with: #( 1.5 1.5 )
		answersBoolean: true.
	self
		assertFloatPrimitive: #primitiveFloatGreaterOrEqual
		with: #( 1.5 2.25 )
		answersBoolean: false
]

{ #category : 'tests - float comparisons' }
InterpreterTest >> testFloatGreaterThan [
	"Float greater than (primitive 44): 2.25 > 1.5 is true, 1.5 > 2.25 is false, and a number is not greater than itself."

	self
		assertFloatPrimitive: #primitiveFloatGreaterThan
		with: #( 2.25 1.5 )
		answersBoolean: true.
	self
		assertFloatPrimitive: #primitiveFloatGreaterThan
		with: #( 1.5 2.25 )
		answersBoolean: false.
	self
		assertFloatPrimitive: #primitiveFloatGreaterThan
		with: #( 1.5 1.5 )
		answersBoolean: false
]

{ #category : 'tests - float arithmetic' }
InterpreterTest >> testFloatInfinityAndNaN [
	"IEEE special values go through the primitives unchanged: infinity plus one is infinity, and NaN plus one is NaN."

	self
		assertFloatPrimitive: #primitiveFloatAdd
		with: {
				Float infinity.
				1.0 }
		answers: Float infinity.
	self
		assertFloatPrimitive: #primitiveFloatAdd
		with: {
				Float negativeInfinity.
				1.0 }
		answers: Float negativeInfinity.

	self runPrimitive: #primitiveFloatAdd with: {
			(self newFloat: Float nan).
			(self newFloat: 1.0) }.
	self assert: (self floatValueOf: interpreter stackTop) isNaN
]

{ #category : 'tests - float comparisons' }
InterpreterTest >> testFloatLessOrEqual [
	"Float less or equal (primitive 45): true for a smaller number and for the same number, false for a larger one."

	self
		assertFloatPrimitive: #primitiveFloatLessOrEqual
		with: #( 1.5 2.25 )
		answersBoolean: true.
	self
		assertFloatPrimitive: #primitiveFloatLessOrEqual
		with: #( 1.5 1.5 )
		answersBoolean: true.
	self
		assertFloatPrimitive: #primitiveFloatLessOrEqual
		with: #( 2.25 1.5 )
		answersBoolean: false
]

{ #category : 'tests - float comparisons' }
InterpreterTest >> testFloatLessThan [
	"Float less than (primitive 43) answers true or false, the guaranteed objects of the VM, and not a Float: 1.5 < 2.25 is true, 2.25 < 1.5 is false, and a number is not less than itself."

	self
		assertFloatPrimitive: #primitiveFloatLessThan
		with: #( 1.5 2.25 )
		answersBoolean: true.
	self
		assertFloatPrimitive: #primitiveFloatLessThan
		with: #( 2.25 1.5 )
		answersBoolean: false.
	self
		assertFloatPrimitive: #primitiveFloatLessThan
		with: #( 1.5 1.5 )
		answersBoolean: false
]

{ #category : 'tests - float arithmetic' }
InterpreterTest >> testFloatMultiply [
	"Float multiply (primitive 49): 1.5 * 4 is 6.0, and a negative factor changes the sign."

	self
		assertFloatPrimitive: #primitiveFloatMultiply
		with: #( 1.5 4.0 )
		answers: 6.0.
	self
		assertFloatPrimitive: #primitiveFloatMultiply
		with: #( -1.5 4.0 )
		answers: -6.0.
	self
		assertFloatPrimitive: #primitiveFloatMultiply
		with: #( 1.5 0.0 )
		answers: 0.0
]

{ #category : 'tests - float comparisons' }
InterpreterTest >> testFloatNotEqual [
	"Float not equal (primitive 48) is the opposite of equal: false for the same value, true for different values."

	self
		assertFloatPrimitive: #primitiveFloatNotEqual
		with: #( 1.5 1.5 )
		answersBoolean: false.
	self
		assertFloatPrimitive: #primitiveFloatNotEqual
		with: #( 1.5 2.25 )
		answersBoolean: true
]

{ #category : 'tests - float conversions' }
InterpreterTest >> testFloatObjectLayout [
	"A Float object of the guest is two 16 bit words holding an IEEE 754 single precision number: sign, 8 bit exponent, 23 bit mantissa. The low word comes first in memory (the VM runs on the LSB image format). 1.5 is 16r3FC00000: high word 16r3FC0, low word 0. This test checks the helper the other float tests rely on, and the layout the VM must read."

	| float |
	float := self newFloat: 1.5.

	self
		assert: (memory fetchClassOf: float)
		equals: (Interpreter classVarNamed: 'ClassFloatPointer').
	self assert: (memory fetchWordLengthOf: float) equals: 2.
	self assert: (memory fetchWord: 0 ofObject: float) equals: 0.
	self assert: (memory fetchWord: 1 ofObject: float) equals: 16r3FC0.
	self assert: (self floatValueOf: float) equals: 1.5
]

{ #category : 'tests - float dispatch' }
InterpreterTest >> testFloatPlusThroughTheSpecialSelector [
	"The + bytecode (176) first tries the SmallInteger primitive. With a Float receiver that fails, so + is sent to the Float class, whose method has primitive 41: 1.5 + 2.25 is 3.75 and no context is created. This is the path of every float addition of the guest."

	self
		class: (Interpreter classVarNamed: 'ClassFloatPointer')
		understands: (self specialSelector: 0)
		as: (self methodWithPrimitive: 41 arguments: 1 fallback: #( 120 )).

	self
		run: #( 112 33 176 )
		literals: {
				self newSelector.
				(self newFloat: 2.25) }
		receiver: (self newFloat: 1.5).
	3 timesRepeat: [ interpreter cycle ].

	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: context.
	self assert: self stackDepth equals: 1.
	self assert: (self floatValueOf: interpreter stackTop) equals: 3.75
]

{ #category : 'tests - float dispatch' }
InterpreterTest >> testFloatPrimitivesAreReachedByTheirIndex [
	"The guest does not call the primitive routines by name: a CompiledMethod carries a primitive index, and dispatchFloatPrimitives maps 40 to 54 to a routine. Here a method of the Float class with primitive 50 (divide) is sent a message: no context is created, 10 / 4 = 2.5 replaces the receiver and the argument on the stack of the sender."

	| selector |
	selector := self newSelector.
	self
		class: (Interpreter classVarNamed: 'ClassFloatPointer')
		understands: selector
		as: (self methodWithPrimitive: 50 arguments: 1 fallback: #( 120 )).

	"push self (a Float 10.0), push literal 1 (a Float 4.0), send literal 0 with one argument"
	self
		run: #( 112 33 224 )
		literals: {
				selector.
				(self newFloat: 4) }
		receiver: (self newFloat: 10).
	3 timesRepeat: [ interpreter cycle ].

	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: context.
	self assert: self stackDepth equals: 1.
	self assert: (self floatValueOf: interpreter stackTop) equals: 2.5
]

{ #category : 'tests - float arithmetic' }
InterpreterTest >> testFloatSubtract [
	"Float subtract (primitive 42) answers receiver minus argument: the order of the two operands on the stack matters. 10 - 2.5 is 7.5 and 2.5 - 10 is -7.5."

	self
		assertFloatPrimitive: #primitiveFloatSubstract
		with: #( 10.0 2.5 )
		answers: 7.5.
	self
		assertFloatPrimitive: #primitiveFloatSubstract
		with: #( 2.5 10.0 )
		answers: -7.5.
	self
		assertFloatPrimitive: #primitiveFloatSubstract
		with: #( 1.5 1.5 )
		answers: 0.0
]

{ #category : 'tests - perform and value primitives' }
InterpreterTest >> testFlushCacheEmptiesTheMethodCache [
	"Primitive 89 forgets what the method cache holds: it is used when a method dictionary changes. The cache is as large as before and has no entry."

	| selector |
	selector := self newSelector.
	self
		sendTo: (self newReceiverOf: (self
					  newClassInheritingFrom: nilPointer
					  methods: { (selector -> (self newMethodReturning: 42)) }))
		selector: selector.
	self assert:
		((interpreter instVarNamed: 'methodCache') includes: selector).

	self runPrimitive: #primitiveFlushCache with: { nilPointer }.

	self deny:
		((interpreter instVarNamed: 'methodCache') includes: selector).
	self
		assert: (interpreter instVarNamed: 'methodCache') size
		equals: 1024
]

{ #category : 'tests - float conversions' }
InterpreterTest >> testFractionalPart [
	"fractionalPart (primitive 52) is the receiver minus its truncation: 3.75 gives 0.75, and -3.75 gives -0.75 (same sign as the receiver). A whole number gives 0.0. The answer is a Float object."

	self assertFractionalPartOf: 3.75 is: 0.75.
	self assertFractionalPartOf: -3.75 is: -0.75.
	self assertFractionalPartOf: 0.25 is: 0.25.
	self assertFractionalPartOf: 5.0 is: 0.0
]

{ #category : 'tests - float conversions' }
InterpreterTest >> testFractionalPartOfANonFloatFails [
	"fractionalPart is defined on Floats: a SmallInteger receiver fails the primitive before anything is computed, and stays on the stack."

	self
		assertPrimitiveFails: #primitiveFractionalPart
		with: { (self integer: 3) }
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testGreaterThan [

	self
		assertBoolean: true
		of: #primitiveGreaterThan
		with: 4
		with: 3.
	self
		assertBoolean: false
		of: #primitiveGreaterThan
		with: 3
		with: 3
]

{ #category : 'tests - method header' }
InterpreterTest >> testHeaderExtension [
	"Flag 7: the next to last literal holds the argument count and the primitive index, the last one is the association of the method class (BB p. 580)"

	| method association |
	association := memory instantiateClass: classPointer withPointers: 2.
	memory storePointer: 1 ofObject: association withValue: classPointer.
	method := self
		          methodWithHeader: (self
				           headerFlag: 7
				           temporaries: 2
				           large: 0
				           literals: 3)
		          literals: {
				          (memory integerObjectOf: 5).
				          (self headerExtensionArguments: 2 primitive: 60).
				          association }
		          bytecodes: #( 120 ).

	self assert: (interpreter flagValueOf: method) equals: 7.
	self assert: (interpreter argumentCountOf: method) equals: 2.
	self assert: (interpreter primitiveIndexOf: method) equals: 60.
	self assert: (interpreter methodClassOf: method) equals: classPointer
]

{ #category : 'tests - method header' }
InterpreterTest >> testHeaderFields [
	"Flag, temporary count, large context flag and literal count are packed in the header SmallInteger (BB p. 577)"

	| method |
	method := self
		          methodWithHeader: (self
				           headerFlag: 3
				           temporaries: 5
				           large: 1
				           literals: 2)
		          literals: {
				          (memory integerObjectOf: 11).
				          (memory integerObjectOf: 22) }
		          bytecodes: #( 120 ).

	self assert: (interpreter flagValueOf: method) equals: 3.
	self assert: (interpreter temporaryCountof: method) equals: 5.
	self assert: (interpreter largeContextFlagOf: method) equals: 1.
	self assert: (interpreter literalCountOf: method) equals: 2
]

{ #category : 'tests - input and cursor primitives' }
InterpreterTest >> testInputSemaphore [
	"Primitive 93 tells the host which Semaphore to signal for each input event. Its argument is popped and handed to the host."

	| hal semaphore |
	hal := self useHAL.
	semaphore := self newReceiverOf:
		             (Interpreter classVarNamed: 'ClassSemaphorePointer').

	self runPrimitive: #primitiveInputSemaphore with: { semaphore }.

	self assert: interpreter success.
	self assert: self stackDepth equals: 0.
	self
		assert: (hal callsTo: #inputSemaphore:)
		equals: { { semaphore } }
]

{ #category : 'tests - input and cursor primitives' }
InterpreterTest >> testInputSemaphoreAcceptsNil [
	"nil is accepted, to stop the signalling."

	self useHAL.

	self runPrimitive: #primitiveInputSemaphore with: { nilPointer }.

	self assert: interpreter success
]

{ #category : 'tests - input and cursor primitives' }
InterpreterTest >> testInputSemaphoreNilIsGivenToTheHostAsNil [
	"The guest nil means that nobody listens to the input events: the host is told with its own nil, not with the object pointer of the guest nil, which it would take for a Semaphore."

	| hal |
	hal := self useHAL.

	self runPrimitive: #primitiveInputSemaphore with: { nilPointer }.

	self assert: (hal callsTo: #inputSemaphore:) equals: { { nil } }
]

{ #category : 'tests - input and cursor primitives' }
InterpreterTest >> testInputSemaphoreOfAnotherObjectFails [
	"Anything that is neither a Semaphore nor nil fails the primitive."

	self useHAL.

	self
		assertPrimitiveFails: #primitiveInputSemaphore
		with: { (self integer: 3) }
]

{ #category : 'tests - input and cursor primitives' }
InterpreterTest >> testInputWord [
	"Primitive 95 takes the next word of the input queue of the host: the receiver is replaced by the word, in order, as a SmallInteger."

	| hal |
	hal := self useHAL.
	hal queueInputWord: 16r1234.
	hal queueInputWord: 7.

	self runPrimitive: #primitiveInputWord with: { nilPointer }.
	self assert: (self stackIntegerAt: 0) equals: 16r1234.
	self assert: self stackDepth equals: 1.

	self runPrimitive: #primitiveInputWord with: { nilPointer }.
	self assert: (self stackIntegerAt: 0) equals: 7
]

{ #category : 'tests - input and cursor primitives' }
InterpreterTest >> testInputWordAboveSmallIntegerAnswersALargePositiveInteger [
	"An input word is 16 bits: above 16383 it does not fit in a SmallInteger and is answered as a LargePositiveInteger of two bytes."

	self useHAL queueInputWord: 40000.

	self runPrimitive: #primitiveInputWord with: { nilPointer }.

	self
		assert: (memory fetchClassOf: interpreter stackTop)
		equals:
		(Interpreter classVarNamed: 'ClassLargePositiveIntegerPointer').
	self
		assert: (interpreter positive16BitValueOf: interpreter stackTop)
		equals: 40000
]

{ #category : 'tests - input and cursor primitives' }
InterpreterTest >> testInputWordOfAnEmptyQueueFails [
	"No event waiting is a failure: the Smalltalk code of the method runs, and the receiver stays on the stack."

	self useHAL.

	self runPrimitive: #primitiveInputWord with: { nilPointer }.

	self deny: interpreter success
]

{ #category : 'tests - input and cursor primitives' }
InterpreterTest >> testInputWordsAreDroppedWithoutAnInputSemaphore [
	"With no input Semaphore nobody listens: the words are dropped, and nothing is buffered for the interpreter. Once a Semaphore is set each word signals it."

	| hal semaphore |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	hal := self useClockHAL.
	semaphore := self newSemaphore.

	hal inputWord: 16r1234.
	self assert: (interpreter instVarNamed: 'semaphoreIndex') equals: 0.
	self assert: hal nextInputWord isNil.

	hal inputSemaphore: semaphore.
	hal inputWord: 16r1234.
	self assert: (interpreter instVarNamed: 'semaphoreIndex') equals: 1.
	self assert: hal nextInputWord equals: 16r1234.

	hal inputSemaphore: nil.
	hal inputWord: 16r4321.
	self assert: (interpreter instVarNamed: 'semaphoreIndex') equals: 1.
	self assert: hal nextInputWord isNil
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testInstVarAt [
	"instVarAt: numbers the fixed fields first, from 1, then the indexed ones"

	| object |
	object := memory
		          instantiateClass: (self
				           newClassPointers: 1
				           words: 1
				           indexable: 1
				           fixed: 2)
		          withPointers: 4.
	memory countUp: object.
	memory storePointer: 3 ofObject: object withValue: (self integer: 33).

	self
		assertPrimitive: #primitiveInstVarAt
		with: {
				object.
				(self integer: 4) }
		answers: (self integer: 33)
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testInstVarAtOutOfBoundsFails [

	| object |
	object := memory
		          instantiateClass: (self
				           newClassPointers: 1
				           words: 1
				           indexable: 1
				           fixed: 2)
		          withPointers: 4.
	memory countUp: object.

	self assertPrimitiveFails: #primitiveInstVarAt with: {
			object.
			(self integer: 5) }.
	self assertPrimitiveFails: #primitiveInstVarAt with: {
			object.
			(self integer: 0) }
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testInstVarAtPut [

	| object |
	object := memory
		          instantiateClass: (self
				           newClassPointers: 1
				           words: 1
				           indexable: 1
				           fixed: 2)
		          withPointers: 4.
	memory countUp: object.

	self
		assertPrimitive: #primitiveInstVarAtPut
		with: {
				object.
				(self integer: 1).
				(self integer: 9) }
		answers: (self integer: 9).

	self
		assert: (memory fetchPointer: 0 ofObject: object)
		equals: (self integer: 9)
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testInstVarAtPutOutOfBoundsFails [

	| object |
	object := memory
		          instantiateClass: (self
				           newClassPointers: 1
				           words: 1
				           indexable: 1
				           fixed: 2)
		          withPointers: 4.
	memory countUp: object.

	self assertPrimitiveFails: #primitiveInstVarAtPut with: {
			object.
			(self integer: 5).
			(self integer: 9) }
]

{ #category : 'tests - special selectors' }
InterpreterTest >> testLargeIntegerPrimitivesAlwaysFail [
	"Primitives 21 to 37 are optional: this VM does not implement them, so they fail and the Smalltalk code of the method runs"

	| selector method |
	selector := self newSelector.
	method := self
		          methodWithPrimitive: 21
		          arguments: 1
		          fallback: #( 32 124 ).
	self
		class: (Interpreter classVarNamed: 'ClassSmallInteger')
		understands: selector
		as: method.

	self
		run: #( 118 119 224 )
		literals: { selector }
		receiver: nilPointer.
	3 timesRepeat: [ interpreter cycle ].

	self assert: (interpreter instVarNamed: 'method') equals: method
]

{ #category : 'tests - array primitives' }
InterpreterTest >> testLargePositiveIntegerIndex [
	"An index above 16383 is a LargePositiveInteger of two bytes, low byte first"

	| big |
	big := interpreter positive16BitIntegerFor: 16384.

	self assert: (memory fetchByteLengthOf: big) equals: 2.
	self assert: (interpreter positive16BitValueOf: big) equals: 16384.
	self
		assert: (interpreter positive16BitValueOf: (self integer: 7))
		equals: 7
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testLastErrorAfterAFailedOperation [
	"A failed file operation, here opening a file that does not exist, sets the error code to -1 (the VM does not keep the host error numbers), and primitive 132 answers it."

	| fileSystem |
	fileSystem := self useFileSystemOn: self newTemporaryDirectory.
	fileSystem openFile: 'missing.bin'.

	self
		assertPrimitive: #primitivePosixLastError
		with: { nilPointer }
		answers: (self integer: -1)
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testLastErrorIsZeroWhenNothingFailed [
	"Primitive 132 answers the last host error code of the file system as a SmallInteger: 0 when no file operation has failed."

	self useFileSystemOn: self newTemporaryDirectory.

	self
		assertPrimitive: #primitivePosixLastError
		with: { nilPointer }
		answers: (self integer: 0)
]

{ #category : 'tests - method header' }
InterpreterTest >> testLiteralOfMethod [
	"Literals are numbered from 0, after the header"

	| method |
	method := self
		          methodWithLiterals: {
				          (memory integerObjectOf: 11).
				          (memory integerObjectOf: 22) }
		          bytecodes: #( 120 ).

	self
		assert:
		(memory integerValueOf: (interpreter literal: 0 ofMethod: method))
		equals: 11.
	self
		assert:
		(memory integerValueOf: (interpreter literal: 1 ofMethod: method))
		equals: 22
]

{ #category : 'tests - jump bytecodes' }
InterpreterTest >> testLongConditionalJumpDoesNotJumpOnTheOtherValue [
	"168 jumps on true only, 172 on false only"

	| start |
	self
		run: #( 114 168 2 118 118 118 )
		literals: #(  )
		receiver: nilPointer.
	interpreter cycle.
	start := interpreter instVarNamed: 'instructionPointer'.

	interpreter cycle.

	self
		assert: (interpreter instVarNamed: 'instructionPointer')
		equals: start + 2.
	self assert: self stackDepth equals: 0
]

{ #category : 'tests - jump bytecodes' }
InterpreterTest >> testLongConditionalJumpOnFalse [
	"Bytecodes 172 to 175 jump when the top of the stack is false"

	| start |
	self
		run: #( 114 172 2 118 118 118 )
		literals: #(  )
		receiver: nilPointer.
	interpreter cycle.
	start := interpreter instVarNamed: 'instructionPointer'.

	interpreter cycle.

	self
		assert: (interpreter instVarNamed: 'instructionPointer')
		equals: start + 4.
	self assert: self stackDepth equals: 0
]

{ #category : 'tests - jump bytecodes' }
InterpreterTest >> testLongConditionalJumpOnTrue [
	"Bytecodes 168 to 171 jump forward by a 10 bit displacement when the top of the stack is true"

	| start |
	self
		run: #( 113 168 2 118 118 118 )
		literals: #(  )
		receiver: nilPointer.
	interpreter cycle.
	start := interpreter instVarNamed: 'instructionPointer'.

	interpreter cycle.

	self
		assert: (interpreter instVarNamed: 'instructionPointer')
		equals: start + 4.
	self assert: self stackDepth equals: 0
]

{ #category : 'tests - jump bytecodes' }
InterpreterTest >> testLongUnconditionalJumpBackward [
	"The displacement is two's complement: 163 and 253 is -3"

	| start |
	self run: #( 163 253 118 ) literals: #(  ) receiver: nilPointer.
	start := interpreter instVarNamed: 'instructionPointer'.

	interpreter cycle.

	self
		assert: (interpreter instVarNamed: 'instructionPointer')
		equals: start - 1
]

{ #category : 'tests - jump bytecodes' }
InterpreterTest >> testLongUnconditionalJumpForward [
	"Bytecodes 160 to 167 are followed by the low byte of an 11 bit displacement, whose high bits are in the bytecode: 164 is a displacement of 0 to 255 forward"

	| start |
	self
		run: #( 164 3 118 118 118 118 )
		literals: #(  )
		receiver: nilPointer.
	start := interpreter instVarNamed: 'instructionPointer'.

	interpreter cycle.

	"2 bytes fetched, then 3 skipped"
	self
		assert: (interpreter instVarNamed: 'instructionPointer')
		equals: start + 5
]

{ #category : 'tests - stack' }
InterpreterTest >> testMethodContextIsNotABlockContext [
	"The field a MethodContext holds its method in is a SmallInteger (the argument count) in a BlockContext"

	self deny: (interpreter isBlockContext: context)
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testMod [
	"\\ takes the sign of the divisor"

	self
		assertResult: 1
		of: #primitiveMod
		with: 7
		with: 2.
	self
		assertResult: 1
		of: #primitiveMod
		with: -7
		with: 2.
	self
		assertResult: -1
		of: #primitiveMod
		with: 7
		with: -2
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testModByZeroFails [

	self assertFailureOf: #primitiveMod with: 7 with: 0
]

{ #category : 'tests - input and cursor primitives' }
InterpreterTest >> testMousePoint [
	"Primitive 90 polls the pointing device: it drops the receiver and pushes a new Point of the guest holding the host mouse position. Only a host that does not send events is polled."

	| point |
	self useHAL mousePosition: 30 @ 40.

	self runPrimitive: #primitiveMousePoint with: { nilPointer }.
	point := interpreter stackTop.

	self assert: interpreter success.
	self assert: self stackDepth equals: 1.
	self
		assert: (memory fetchClassOf: point)
		equals: (Interpreter classVarNamed: 'ClassPointPointer').
	self
		assert:
		(memory integerValueOf: (memory fetchPointer: 0 ofObject: point))
		equals: 30.
	self
		assert:
		(memory integerValueOf: (memory fetchPointer: 1 ofObject: point))
		equals: 40
]

{ #category : 'tests - input and cursor primitives' }
InterpreterTest >> testMousePointFailsWhenTheHostSendsEvents [
	"When the host sends mouse events (the case of the real HAL) the guest does not need to poll: the primitive fails and the receiver stays on the stack."

	self useHAL eventDriven: true.

	self assertPrimitiveFails: #primitiveMousePoint with: { nilPointer }
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testMultiply [

	self
		assertResult: 10000
		of: #primitiveMultiply
		with: 100
		with: 100.
	self
		assertResult: -16384
		of: #primitiveMultiply
		with: -128
		with: 128
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testMultiplyOverflowFails [

	self assertFailureOf: #primitiveMultiply with: 128 with: 128.
	self assertFailureOf: #primitiveMultiply with: 16383 with: 2
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testNew [
	"new makes an instance with the fixed fields of the class, all nil"

	| class instance |
	class := self
		         newClassPointers: 1
		         words: 1
		         indexable: 0
		         fixed: 2.

	self runPrimitive: #primitiveNew with: { class }.
	instance := interpreter stackTop.

	self assert: interpreter success.
	self assert: self stackDepth equals: 1.
	self assert: (memory fetchClassOf: instance) equals: class.
	self assert: (memory fetchWordLengthOf: instance) equals: 2.
	self
		assert: (memory fetchPointer: 0 ofObject: instance)
		equals: nilPointer
]

{ #category : 'tests - stack' }
InterpreterTest >> testNewContextHasAnEmptyStack [

	self assert: self stackDepth equals: 0
]

{ #category : 'tests - linked lists' }
InterpreterTest >> testNewLinkedListIsEmpty [
	"A LinkedList is empty when its first Link is nil. The scheduler keeps one for each priority, and every Semaphore is one."

	self assert: (interpreter isEmptyList: self newLinkedList)
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testNewOfANonPointerClass [
	"A class of words makes an instance of words, zero filled"

	| instance |
	self runPrimitive: #primitiveNew with: { (self
			 newClassPointers: 0
			 words: 1
			 indexable: 0
			 fixed: 2) }.
	instance := interpreter stackTop.

	self assert: (memory pointerBitOf: instance) equals: 0.
	self assert: (memory fetchWord: 1 ofObject: instance) equals: 0
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testNewOfAnIndexableClassFails [
	"new is for classes without indexable fields: new: is for the others"

	self assertPrimitiveFails: #primitiveNew with: { (self
			 newClassPointers: 1
			 words: 1
			 indexable: 1
			 fixed: 0) }
]

{ #category : 'tests - VM bugs' }
InterpreterTest >> testNewWithANonIntegerArgumentFails [
	"Same limit as testAtPutWithANonIntegerIndexFails: the size is the interpreter"

	<expectedFailure>
	self assertPrimitiveFails: #primitiveNewWithArg with: {
			(self
				 newClassPointers: 1
				 words: 1
				 indexable: 1
				 fixed: 0).
			nilPointer }
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testNewWithArgument [
	"new: makes an instance with that many indexable fields, plus the fixed ones"

	| instance |
	self runPrimitive: #primitiveNewWithArg with: {
			(self
				 newClassPointers: 1
				 words: 1
				 indexable: 1
				 fixed: 2).
			(self integer: 3) }.
	instance := interpreter stackTop.

	self assert: interpreter success.
	self assert: (memory fetchWordLengthOf: instance) equals: 5.
	self assert: (memory pointerBitOf: instance) equals: 1
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testNewWithArgumentOfAClassWithoutIndexableFieldsFails [

	self assertPrimitiveFails: #primitiveNewWithArg with: {
			(self
				 newClassPointers: 1
				 words: 1
				 indexable: 0
				 fixed: 2).
			(self integer: 3) }
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testNewWithArgumentOfBytes [
	"A class of bytes makes an instance of that many bytes"

	| instance |
	self runPrimitive: #primitiveNewWithArg with: {
			(self
				 newClassPointers: 0
				 words: 0
				 indexable: 1
				 fixed: 0).
			(self integer: 5) }.
	instance := interpreter stackTop.

	self assert: (memory fetchByteLengthOf: instance) equals: 5.
	self assert: (memory pointerBitOf: instance) equals: 0
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testNewWithArgumentOfWords [

	| instance |
	self runPrimitive: #primitiveNewWithArg with: {
			(self
				 newClassPointers: 0
				 words: 1
				 indexable: 1
				 fixed: 0).
			(self integer: 3) }.
	instance := interpreter stackTop.

	self assert: (memory fetchWordLengthOf: instance) equals: 3.
	self assert: (memory fetchByteLengthOf: instance) equals: 6
]

{ #category : 'tests - storage primitives' }
InterpreterTest >> testNewWithArgumentTooLargeFails [
	"No object can have more than 65533 indexable fields"

	self assertPrimitiveFails: #primitiveNewWithArg with: {
			(self
				 newClassPointers: 1
				 words: 1
				 indexable: 1
				 fixed: 0).
			(interpreter positive16BitIntegerFor: 65534) }
]

{ #category : 'tests - string and stream primitives' }
InterpreterTest >> testNextAtTheEndFails [
	"Past the read limit the primitive fails, and the position does not move"

	| stream |
	stream := self
		          newStreamOn: (self newArrayOf: 3)
		          index: 2
		          readLimit: 2
		          writeLimit: 3.

	self assertPrimitiveFails: #primitiveNext with: { stream }.

	self
		assert:
		(memory integerValueOf: (memory fetchPointer: 1 ofObject: stream))
		equals: 2
]

{ #category : 'tests - string and stream primitives' }
InterpreterTest >> testNextOnAByteObjectFails [
	"Like nextPut: and atEnd, next only works on an Array or a String"

	self assertPrimitiveFails: #primitiveNext with: { (self
			 newStreamOn: (self newBytesOf: 2)
			 index: 0
			 readLimit: 2
			 writeLimit: 2) }
]

{ #category : 'tests - string and stream primitives' }
InterpreterTest >> testNextOnAString [
	"On a String next answers a Character"

	| stream |
	stream := self
		          newStreamOn: (self newStringWith: #( 72 105 ))
		          index: 0
		          readLimit: 2
		          writeLimit: 2.

	self
		assertPrimitive: #primitiveNext
		with: { stream }
		answers: (self characterFor: 72)
]

{ #category : 'tests - string and stream primitives' }
InterpreterTest >> testNextOnAnArray [
	"next answers the element after the position and moves the position"

	| array stream |
	array := self newArrayOf: 3.
	memory storePointer: 0 ofObject: array withValue: (self integer: 10).
	memory storePointer: 1 ofObject: array withValue: (self integer: 20).
	stream := self
		          newStreamOn: array
		          index: 0
		          readLimit: 2
		          writeLimit: 3.

	self
		assertPrimitive: #primitiveNext
		with: { stream }
		answers: (self integer: 10).
	self
		assertPrimitive: #primitiveNext
		with: { stream }
		answers: (self integer: 20).

	self
		assert:
		(memory integerValueOf: (memory fetchPointer: 1 ofObject: stream))
		equals: 2
]

{ #category : 'tests - string and stream primitives' }
InterpreterTest >> testNextPut [
	"nextPut: stores after the position, moves it, and answers the value"

	| array stream |
	array := self newArrayOf: 3.
	stream := self
		          newStreamOn: array
		          index: 1
		          readLimit: 1
		          writeLimit: 3.

	self
		assertPrimitive: #primitiveNextPut
		with: {
				stream.
				(self integer: 99) }
		answers: (self integer: 99).

	self
		assert: (memory fetchPointer: 1 ofObject: array)
		equals: (self integer: 99).
	self
		assert:
		(memory integerValueOf: (memory fetchPointer: 1 ofObject: stream))
		equals: 2
]

{ #category : 'tests - string and stream primitives' }
InterpreterTest >> testNextPutOnAString [
	"On a String nextPut: takes a Character and stores its code"

	| string stream |
	string := self newStringWith: #( 0 0 0 ).
	stream := self
		          newStreamOn: string
		          index: 0
		          readLimit: 0
		          writeLimit: 3.

	self
		assertPrimitive: #primitiveNextPut
		with: {
				stream.
				(self characterFor: 88) }
		answers: (self characterFor: 88).

	self assert: (memory fetchByte: 0 ofObject: string) equals: 88
]

{ #category : 'tests - string and stream primitives' }
InterpreterTest >> testNextPutPastTheWriteLimitFails [

	self assertPrimitiveFails: #primitiveNextPut with: {
			(self
				 newStreamOn: (self newArrayOf: 3)
				 index: 3
				 readLimit: 3
				 writeLimit: 3).
			(self integer: 1) }
]

{ #category : 'tests - method header' }
InterpreterTest >> testObjectPointerCountAndFirstBytecode [
	"The header and the literals come first: the bytecodes start after them, at a one based byte index"

	| method |
	method := self
		          methodWithLiterals: {
				          (memory integerObjectOf: 11).
				          (memory integerObjectOf: 22) }
		          bytecodes: #( 120 ).

	self assert: (interpreter objectPointerCountOf: method) equals: 3.
	self
		assert: (interpreter initialInstructionPointerOfMethod: method)
		equals: 7
]

{ #category : 'tests - system primitives' }
InterpreterTest >> testOopsLeft [
	"Primitive 115 answers the number of free object table entries: how many more objects can be created."

	| free |
	free := memory freeOopsLeft.

	self runPrimitive: #primitiveOopsLeft with: { nilPointer }.

	self assert: interpreter success.
	self assert: self stackDepth equals: 1.
	self
		assert: (interpreter positive16BitValueOf: interpreter stackTop)
		equals: free
]

{ #category : 'tests - extended sends' }
InterpreterTest >> testOrdinarySendDoesNotSkipTheClass [
	"The same send without super finds the method of the class of the receiver: the control of the two tests above"

	| selector classes |
	selector := self newSelector.
	classes := self twoClassesUnderstanding: selector.

	self sendTo: (self newReceiverOf: classes value) selector: selector.

	self
		assert: (memory integerValueOf:
				 (interpreter
					  literal: 0
					  ofMethod: (interpreter instVarNamed: 'method')))
		equals: 2
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testPageNumberOfAPage [
	"The page number of a PosixFilePage is a SmallInteger up to 16383 and a LargePositiveInteger beyond (the pages are 512 bytes: a file above 8 MB). fetchPageNumberOf: answers the host integer in both cases."

	| page |
	page := self newPosixFilePage: 7 bytes: 0.
	interpreter initPrimitive.

	self assert: (interpreter fetchPageNumberOf: page) equals: 7.

	memory
		storePointer: 3
		ofObject: page
		withValue: (interpreter positive32BitIntegerFor: 20000).

	self assert: (interpreter fetchPageNumberOf: page) equals: 20000.
	self assert: interpreter success
]

{ #category : 'tests - paste' }
InterpreterTest >> testPasteConvertsLineEndingsToReturn [
	"CR, LF and CRLF are all one Return (13) for the guest"

	| hal |
	hal := self useClockHAL.

	self
		assert: (hal asST80Characters:
				 'a' , (String with: Character cr) , 'b'
				 , (String with: Character lf) , 'c'
				 , (String with: Character cr with: Character lf) , 'd')
		equals: #( 97 13 98 13 99 13 100 )
]

{ #category : 'tests - paste' }
InterpreterTest >> testPasteConvertsTheAssignmentOfPharoToTheOneOfSmalltalk80 [
	"x := 1 is typed x _ 1, the assignment of the guest. The conversion can be switched off."

	| hal saved |
	hal := self useClockHAL.
	saved := ST80HardwareAbstractionLayer convertAssignmentOnPaste.
	self onTearDown: [
		ST80HardwareAbstractionLayer convertAssignmentOnPaste: saved ].

	ST80HardwareAbstractionLayer convertAssignmentOnPaste: true.
	self
		assert: (hal asST80Characters: 'x := 1')
		equals: #( 120 32 95 32 49 ).

	ST80HardwareAbstractionLayer convertAssignmentOnPaste: false.
	self
		assert: (hal asST80Characters: 'x := 1')
		equals: #( 120 32 58 61 32 49 )
]

{ #category : 'tests - paste' }
InterpreterTest >> testPasteDoesNothingWhenTheGuestDoesNotListen [
	"With no input semaphore the guest has not asked for input events: nothing is queued"

	| hal |
	hal := self useClockHAL.

	hal pasteText: 'abc'.

	self deny: hal isPasting.
	self assert: (hal wordsOfType: 3) isEmpty
]

{ #category : 'tests - paste' }
InterpreterTest >> testPasteDropsWhatTheGuestCanNotType [
	"The guest only knows 7 bit ASCII: accents, symbols and control characters are dropped, not replaced by a question mark"

	| hal |
	hal := self useClockHAL.

	self
		assert:
			(hal asST80Characters:
				 'caf' , (String with: (Character value: 233))
				 , (String with: (Character value: 16r20AC))
				 , (String with: (Character value: 7))
				 , (String with: (Character value: 127)) , 'e')
		equals: #( 99 97 102 101 )
]

{ #category : 'tests - paste' }
InterpreterTest >> testPasteIsFedByBatchesSoThatTheSemaphoreBufferDoesNotOverflow [
	"The interpreter buffers 4096 signals and a character costs 3: a long text is fed in batches, and the guest reads the input between two batches (here the test drains the queue at each wait)."

	| hal text |
	hal := self useClockHALListening.
	text := String new: 1000 withAll: $a.

	hal pasteCodes: (hal asST80Characters: text).

	self assert: hal keysTyped size equals: 1000.
	self
		assert: hal drainCount
		equals: (1000 / hal pasteBatchSize) ceiling.
	self assert: hal pasteBatchSize * 3 < 4096
]

{ #category : 'tests - paste' }
InterpreterTest >> testPasteKeepsTabsAndPrintableCharacters [
	"Tab (9) and the characters from space to tilde are typed as they are"

	| hal |
	hal := self useClockHAL.

	self
		assert:
		(hal asST80Characters: (String with: Character tab) , ' ~Az09')
		equals: #( 9 32 126 65 122 48 57 )
]

{ #category : 'tests - paste' }
InterpreterTest >> testPasteOfNilOrAnEmptyTextIsEmpty [

	| hal |
	hal := self useClockHAL.

	self assert: (hal asST80Characters: nil) equals: #(  ).
	self assert: (hal asST80Characters: '') equals: #(  )
]

{ #category : 'tests - paste' }
InterpreterTest >> testPasteReplacesTypographicCharactersByTheirAsciiLookAlike [
	"What word processors and web pages put in the text: curly quotes, dashes, non breaking space"

	| hal |
	hal := self useClockHAL.

	self
		assert:
			(hal asST80Characters: (String with: (Character value: 16r2019))
				 , (String with: (Character value: 16r201C))
				 , (String with: (Character value: 16r201D))
				 , (String with: (Character value: 16r2013))
				 , (String with: (Character value: 16r2014))
				 , (String with: (Character value: 16rA0)))
		equals: #( 39 34 34 45 45 32 )
]

{ #category : 'tests - paste' }
InterpreterTest >> testPasteShortcutIsControlVOrCommandV [
	"Ctrl-V (Linux, Windows) and Cmd-V (macOS) paste. Plain v, other letters and the combinations with Shift or Alt do not."

	| morph ctrl cmd shift alt v |
	morph := ST80DisplayMorph basicNew.
	ctrl := UserInputEvent classVarNamed: 'CTRL_KEY_MASK'.
	cmd := UserInputEvent classVarNamed: 'CMD_KEY_MASK'.
	shift := UserInputEvent classVarNamed: 'SHIFT_KEY_MASK'.
	alt := UserInputEvent classVarNamed: 'ALT_KEY_MASK'.
	v := [ :buttons :keyName |
		     | event |
		     event := self
			              newKeyboardEventOf: keyName first asInteger
			              scanCode: 25
			              buttons: buttons.
		     event instVarNamed: 'key' put: (KeyboardKey named: keyName).
		     morph isPasteShortcut: event ].

	self assert: (v value: ctrl value: #V).
	self assert: (v value: cmd value: #V).
	self deny: (v value: 0 value: #V).
	self deny: (v value: ctrl value: #C).
	self deny: (v value: ctrl + shift value: #V).
	self deny: (v value: ctrl + alt value: #V)
]

{ #category : 'tests - paste' }
InterpreterTest >> testPasteTellsTheGuestThatControlIsReleased [
	"The user holds Control for the shortcut, and the guest was told: pasted characters would arrive as control characters (ctrl-c is the user interrupt). The guest is told that Control is up before the first character."

	| hal controlUp |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	hal := self useClockHALListening.

	hal pasteText: 'c'.
	(Delay forMilliseconds: 200) wait.

	controlUp := hal wordsOfType: 4.
	self assert: controlUp first equals: 138.
	self assert: hal keysTyped equals: #( 99 )
]

{ #category : 'tests - paste' }
InterpreterTest >> testPasteTypesTheCharactersInTheGuest [
	"Each character is typed as a time word followed by the immediate down and up of its key (BB p. 649): the guest reads the same input as if the text had been typed. Each input word signals the input semaphore once."

	| hal |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	hal := self useClockHALListening.

	hal pasteCodes: (hal asST80Characters: 'Ab 1').

	self assert: hal keysTyped equals: #( 65 98 32 49 ).
	self assert: (hal wordsOfType: 4) asArray equals: #( 65 98 32 49 ).
	self
		assert: (interpreter instVarNamed: 'semaphoreIndex')
		equals: hal wordsRead.
	self assert: hal wordsRead >= 12
]

{ #category : 'tests - perform and value primitives' }
InterpreterTest >> testPerform [
	"Primitive 83 (perform:) sends the message whose selector is its argument: the method found for that selector is the one that runs, on the same receiver, with the selector taken off the stack. Here perform: is sent with the selector of a method that takes no argument."

	| performSelector target method receiver |
	performSelector := self newSelector.
	target := self newSelector.
	method := self newMethodReturning: 42.
	receiver := self newReceiverOf:
		            (self newClassInheritingFrom: nilPointer methods: {
				             (target -> method).
				             (performSelector
				              ->
				              (self
					               methodWithPrimitive: 83
					               arguments: 1
					               fallback: #( 120 ))) }).

	self
		run: #( 112 33 224 )
		literals: {
				performSelector.
				target }
		receiver: receiver.
	3 timesRepeat: [ interpreter cycle ].

	self assert: (interpreter instVarNamed: 'method') equals: method.
	self assert: (interpreter instVarNamed: 'receiver') equals: receiver.
	self
		assert: (interpreter instVarNamed: 'messageSelector')
		equals: target.
	self assert: (interpreter instVarNamed: 'argumentCount') equals: 0
]

{ #category : 'tests - perform and value primitives' }
InterpreterTest >> testPerformWithAnArgument [
	"perform:with: passes the argument on: the method that is found takes one argument less than perform:with: did, and finds it as its first temporary. The receiver is the one of the send."

	| performSelector target method receiver |
	performSelector := self newSelector.
	target := self newSelector.
	method := self methodWithArguments: 1 bytecodes: #( 16 124 ).
	receiver := self newReceiverOf:
		            (self newClassInheritingFrom: nilPointer methods: {
				             (target -> method).
				             (performSelector
				              ->
				              (self
					               methodWithPrimitive: 83
					               arguments: 2
					               fallback: #( 120 ))) }).

	"push self, the selector to perform (literal 1), the argument 2, and send perform:with: (2 arguments)"
	self
		run: #( 112 33 119 240 )
		literals: {
				performSelector.
				target }
		receiver: receiver.
	4 timesRepeat: [ interpreter cycle ].

	self assert: (interpreter instVarNamed: 'method') equals: method.
	self assert: (interpreter instVarNamed: 'argumentCount') equals: 1.
	self
		assert: (memory integerValueOf: (interpreter temporary: 0))
		equals: 2
]

{ #category : 'tests - perform and value primitives' }
InterpreterTest >> testPerformWithArguments [
	"Primitive 84 (perform:withArguments:) takes the arguments from an Array: its elements are pushed in order, and the method found finds them as its first temporaries."

	| performSelector target method receiver array |
	performSelector := self newSelector.
	target := self newSelector.
	method := self methodWithArguments: 2 bytecodes: #( 17 124 ).
	receiver := self newReceiverOf:
		            (self newClassInheritingFrom: nilPointer methods: {
				             (target -> method).
				             (performSelector
				              ->
				              (self
					               methodWithPrimitive: 84
					               arguments: 2
					               fallback: #( 120 ))) }).
	array := self newArrayOf: 2.
	memory storePointer: 0 ofObject: array withValue: (self integer: 5).
	memory storePointer: 1 ofObject: array withValue: (self integer: 6).

	self
		run: #( 112 33 34 240 )
		literals: {
				performSelector.
				target.
				array }
		receiver: receiver.
	4 timesRepeat: [ interpreter cycle ].

	self assert: (interpreter instVarNamed: 'method') equals: method.
	self assert: (interpreter instVarNamed: 'argumentCount') equals: 2.
	self
		assert: (memory integerValueOf: (interpreter temporary: 0))
		equals: 5.
	self
		assert: (memory integerValueOf: (interpreter temporary: 1))
		equals: 6
]

{ #category : 'tests - perform and value primitives' }
InterpreterTest >> testPerformWithArgumentsAndTheWrongNumberFails [
	"An Array of two elements for a method that takes one: the primitive fails and the Smalltalk code of the method with the primitive runs, to report the error. The method that was found is not run, and the arguments of perform:withArguments:, the selector and the Array, are put back on the stack."

	| performSelector target receiver fallback array |
	performSelector := self newSelector.
	target := self newSelector.
	fallback := self
		            methodWithPrimitive: 84
		            arguments: 2
		            fallback: #( 120 ).
	receiver := self newReceiverOf:
		            (self newClassInheritingFrom: nilPointer methods: {
				             (target
				              ->
				              (self methodWithArguments: 1 bytecodes: #( 16 124 ))).
				             (performSelector -> fallback) }).
	array := self newArrayOf: 2.

	self
		run: #( 112 33 34 240 )
		literals: {
				performSelector.
				target.
				array }
		receiver: receiver.
	4 timesRepeat: [ interpreter cycle ].

	self assert: (interpreter instVarNamed: 'method') equals: fallback.
	self assert: (interpreter instVarNamed: 'argumentCount') equals: 2.
	self assert: (interpreter temporary: 0) equals: target.
	self assert: (interpreter temporary: 1) equals: array
]

{ #category : 'tests - perform and value primitives' }
InterpreterTest >> testPerformWithTheWrongNumberOfArgumentsFails [
	"If the method found does not take as many arguments as perform: passes, the primitive fails and the Smalltalk code of the perform: method runs, to report the error: here perform:with: finds a method that takes none. The method that was found is not run, and the perform: method gets its own arguments, the selector and the value, as its first temporaries."

	| performSelector target method receiver fallback |
	performSelector := self newSelector.
	target := self newSelector.
	method := self newMethodReturning: 42.
	fallback := self
		            methodWithPrimitive: 83
		            arguments: 2
		            fallback: #( 120 ).
	receiver := self newReceiverOf:
		            (self newClassInheritingFrom: nilPointer methods: {
				             (target -> method).
				             (performSelector -> fallback) }).

	self
		run: #( 112 33 119 240 )
		literals: {
				performSelector.
				target }
		receiver: receiver.
	4 timesRepeat: [ interpreter cycle ].

	self
		assert: (interpreter instVarNamed: 'messageSelector')
		equals: performSelector.
	self assert: (interpreter instVarNamed: 'method') equals: fallback.
	self assert: (interpreter instVarNamed: 'argumentCount') equals: 2.
	self assert: (interpreter temporary: 0) equals: target.
	self
		assert: (memory integerValueOf: (interpreter temporary: 1))
		equals: 2
]

{ #category : 'tests - stack' }
InterpreterTest >> testPopDoesNotReleaseTheObject [
	"popStack only moves the stack pointer: the slot still holds the object, which is released when it is overwritten or the context dies"

	| before |
	self push: classPointer.
	before := memory countBitsOf: classPointer.

	interpreter popStack.

	self assert: (memory countBitsOf: classPointer) equals: before
]

{ #category : 'tests - stack' }
InterpreterTest >> testPopNumberAndUnPop [
	"pop: and unPop: only move the stack pointer, and unPop: gets back what pop: dropped"

	self pushInteger: 1.
	self pushInteger: 2.

	interpreter pop: 2.
	self assert: self stackDepth equals: 0.
	interpreter unPop: 2.
	self assert: self stackDepth equals: 2.
	self assert: (self stackIntegerAt: 0) equals: 2
]

{ #category : 'tests - stack bytecodes' }
InterpreterTest >> testPopStack [
	"Bytecode 135 drops the top of the stack"

	self runBytecodes: #( 118 119 135 ).

	self assert: self stackDepth equals: 1.
	self assert: (self stackIntegerAt: 0) equals: 1
]

{ #category : 'tests - array primitives' }
InterpreterTest >> testPositive16BitIntegerForNegativeFails [

	interpreter initPrimitive.

	interpreter positive16BitIntegerFor: -1.

	self deny: interpreter success
]

{ #category : 'tests - method header' }
InterpreterTest >> testPrimitiveReturnFlags [
	"Flags 5 and 6 are primitive returns of self and of an instance variable: no argument, and the field index is in the temporary count bits"

	| returnSelf returnField |
	returnSelf := self
		              methodWithHeader: (self
				               headerFlag: 5
				               temporaries: 0
				               large: 0
				               literals: 0)
		              literals: #(  )
		              bytecodes: #( 120 ).
	returnField := self
		               methodWithHeader: (self
				                headerFlag: 6
				                temporaries: 3
				                large: 0
				                literals: 0)
		               literals: #(  )
		               bytecodes: #( 120 ).

	self assert: (interpreter argumentCountOf: returnSelf) equals: 0.
	self assert: (interpreter argumentCountOf: returnField) equals: 0.
	self assert: (interpreter fieldIndexOf: returnField) equals: 3
]

{ #category : 'tests - special selectors' }
InterpreterTest >> testPrimitiveRunFromASend [
	"A method with a primitive index runs the primitive when it is sent: no context is created, and the answer replaces the receiver and the argument"

	| selector |
	selector := self newSelector.
	self
		class: (Interpreter classVarNamed: 'ClassSmallInteger')
		understands: selector
		as: (self methodWithPrimitive: 1 arguments: 1 fallback: #( 32 124 )).

	self
		run: #( 118 119 224 )
		literals: { selector }
		receiver: nilPointer.
	3 timesRepeat: [ interpreter cycle ].

	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: context.
	self assert: self stackDepth equals: 1.
	self assert: (self stackIntegerAt: 0) equals: 3
]

{ #category : 'tests - stack bytecodes' }
InterpreterTest >> testPushActiveContext [
	"Bytecode 137 pushes thisContext"

	self runBytecodes: #( 137 ).

	self assert: interpreter stackTop equals: context
]

{ #category : 'tests - stack' }
InterpreterTest >> testPushAndPop [
	"The stack grows in the active context itself, and popStack answers the last object pushed"

	self push: classPointer.
	self pushInteger: 5.
	self assert: self stackDepth equals: 2.

	self assert: (memory integerValueOf: interpreter popStack) equals: 5.
	self assert: interpreter popStack equals: classPointer.
	self assert: self stackDepth equals: 0
]

{ #category : 'tests - stack bytecodes' }
InterpreterTest >> testPushConstants [
	"Bytecodes 113 to 119 push true, false, nil, -1, 0, 1 and 2"

	self runBytecodes: #( 113 114 115 116 117 118 119 ).

	self assert: self stackDepth equals: 7.
	self assert: (interpreter stackValue: 6) equals: self truePointer.
	self assert: (interpreter stackValue: 5) equals: self falsePointer.
	self assert: (interpreter stackValue: 4) equals: nilPointer.
	self assert: (self stackIntegerAt: 3) equals: -1.
	self assert: (self stackIntegerAt: 2) equals: 0.
	self assert: (self stackIntegerAt: 1) equals: 1.
	self assert: (self stackIntegerAt: 0) equals: 2
]

{ #category : 'tests - stack' }
InterpreterTest >> testPushCountsTheObject [
	"The stack is a field of the context: pushing an object is a reference to it"

	| before |
	before := memory countBitsOf: classPointer.
	self push: classPointer.
	self assert: (memory countBitsOf: classPointer) equals: before + 1
]

{ #category : 'tests - stack bytecodes' }
InterpreterTest >> testPushLiteralConstant [
	"Bytecodes 32 to 63 push a literal of the method"

	self
		runBytecodes: #( 33 )
		literals: {
				(memory integerObjectOf: 5).
				(memory integerObjectOf: 6) }
		receiver: nilPointer.

	self assert: (self stackIntegerAt: 0) equals: 6
]

{ #category : 'tests - stack bytecodes' }
InterpreterTest >> testPushLiteralVariable [
	"Bytecodes 64 to 95 push the value of an association of the literal frame"

	| association |
	association := self objectWithFields: {
			               nilPointer.
			               (memory integerObjectOf: 9) }.

	self
		runBytecodes: #( 64 )
		literals: { association }
		receiver: nilPointer.

	self assert: (self stackIntegerAt: 0) equals: 9
]

{ #category : 'tests - stack bytecodes' }
InterpreterTest >> testPushReceiver [
	"Bytecode 112 pushes self"

	| receiver |
	receiver := self objectWithFields: { nilPointer }.

	self runBytecodes: #( 112 ) literals: #(  ) receiver: receiver.

	self assert: interpreter stackTop equals: receiver
]

{ #category : 'tests - stack bytecodes' }
InterpreterTest >> testPushReceiverVariable [
	"Bytecodes 0 to 15 push an instance variable of the receiver"

	| receiver |
	receiver := self objectWithFields: {
			            (memory integerObjectOf: 5).
			            (memory integerObjectOf: 6).
			            (memory integerObjectOf: 77) }.

	self runBytecodes: #( 2 ) literals: #(  ) receiver: receiver.

	self assert: self stackDepth equals: 1.
	self assert: (self stackIntegerAt: 0) equals: 77
]

{ #category : 'tests - stack bytecodes' }
InterpreterTest >> testPushTemporaryVariable [
	"Bytecodes 16 to 31 push a temporary of the home context"

	self run: #( 17 ) literals: #(  ) receiver: nilPointer.
	memory
		storePointer: self tempFrameStart + 1
		ofObject: context
		withValue: (memory integerObjectOf: 33).

	interpreter cycle.

	self assert: (self stackIntegerAt: 0) equals: 33
]

{ #category : 'tests - sends' }
InterpreterTest >> testQuickReturnOfAnInstanceVariable [
	"A method whose flag is 6 returns the instance variable numbered by its temporary count bits"

	| selector receiver |
	selector := self newSelector.
	receiver := memory
		            instantiateClass: (self
				             newClassInheritingFrom: nilPointer
				             methods: { (selector -> (self
						               methodWithHeader: (self
								                headerFlag: 6
								                temporaries: 1
								                large: 0
								                literals: 0)
						               literals: #(  )
						               bytecodes: #( 120 ))) })
		            withPointers: 2.
	memory countUp: receiver.
	memory
		storePointer: 1
		ofObject: receiver
		withValue: (memory integerObjectOf: 55).

	self sendTo: receiver selector: selector.

	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: context.
	self assert: self stackDepth equals: 1.
	self assert: (self stackIntegerAt: 0) equals: 55
]

{ #category : 'tests - sends' }
InterpreterTest >> testQuickReturnSelf [
	"A method whose flag is 5 returns self without a context: the receiver stays on the stack and the sender stays active"

	| selector receiver |
	selector := self newSelector.
	receiver := self newReceiverOf: (self
			             newClassInheritingFrom: nilPointer
			             methods: { (selector -> (self
					               methodWithHeader: (self
							                headerFlag: 5
							                temporaries: 0
							                large: 0
							                literals: 0)
					               literals: #(  )
					               bytecodes: #( 120 ))) }).

	self sendTo: receiver selector: selector.

	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: context.
	self assert: self stackDepth equals: 1.
	self assert: interpreter stackTop equals: receiver
]

{ #category : 'tests - system primitives' }
InterpreterTest >> testQuit [
	"Primitive 113 leaves the system: the VM asks the host to stop. The stand-in host only records it, so the test goes on."

	| hal |
	hal := self useHAL.

	self runPrimitive: #primitiveQuit with: { nilPointer }.

	self assert: (hal callsTo: #quit) equals: { #(  ) }
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testQuo [
	"quo: truncates toward zero"

	self
		assertResult: 3
		of: #primitiveQuo
		with: 7
		with: 2.
	self
		assertResult: -3
		of: #primitiveQuo
		with: -7
		with: 2
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testQuoByZeroFails [

	self assertFailureOf: #primitiveQuo with: 7 with: 0
]

{ #category : 'tests - sends' }
InterpreterTest >> testRecursiveDoesNotUnderstandIsAnError [
	"If even doesNotUnderstand: is not understood there is nothing left to do: the VM stops"

	| receiver |
	receiver := self newReceiverOf:
		            (self newClassInheritingFrom: nilPointer methods: #(  )).

	self
		run: #( 112 208 )
		literals: { self newSelector }
		receiver: receiver.
	interpreter cycle.

	self should: [ interpreter cycle ] raise: Error
]

{ #category : 'tests - display primitives' }
InterpreterTest >> testRefreshDisplayRectDoesNotFollowAShrinkTo100 [
	"The shrink to 100 lines before a snapshot is not passed on to the host: the window keeps its size."

	| hal form |
	hal := self useHAL.
	form := self newFormWidth: 640 height: 480 words: 10.
	self runPrimitive: #primitiveBeDisplay with: { form }.
	memory storePointer: 2 ofObject: form withValue: (self integer: 100).

	interpreter
		refreshDisplayRect: (0 @ 0 corner: 5 @ 5)
		ofForm: (ST80Form fromObject: form memory: memory).

	self
		assert: (hal callsTo: #displayWidth:displayHeight:) size
		equals: 1.
	self
		assert: (interpreter instVarNamed: 'currentDisplayHeight')
		equals: 480
]

{ #category : 'tests - display primitives' }
InterpreterTest >> testRefreshDisplayRectFollowsAResize [
	"If the guest changed the size of the screen, the host is told before the rectangle: the window is resized and the new size is remembered."

	| hal form |
	hal := self useHAL.
	form := self newFormWidth: 640 height: 480 words: 10.
	self runPrimitive: #primitiveBeDisplay with: { form }.
	memory storePointer: 2 ofObject: form withValue: (self integer: 500).

	interpreter
		refreshDisplayRect: (0 @ 0 corner: 5 @ 5)
		ofForm: (ST80Form fromObject: form memory: memory).

	self
		assert: (hal callsTo: #displayWidth:displayHeight:) last
		equals: { 640. 500 }.
	self
		assert: (interpreter instVarNamed: 'currentDisplayHeight')
		equals: 500
]

{ #category : 'tests - display primitives' }
InterpreterTest >> testRefreshDisplayRectIgnoresAnEmptyRectangle [
	"A rectangle without area, or no rectangle, is not worth a host redraw."

	| hal form |
	hal := self useHAL.
	form := self newFormWidth: 640 height: 480 words: 10.
	self runPrimitive: #primitiveBeDisplay with: { form }.

	interpreter
		refreshDisplayRect: (10 @ 20 corner: 10 @ 60)
		ofForm: (ST80Form fromObject: form memory: memory).
	interpreter
		refreshDisplayRect: nil
		ofForm: (ST80Form fromObject: form memory: memory).

	self assert: (hal callsTo: #updateDisplayRect:fromForm:) isEmpty
]

{ #category : 'tests - display primitives' }
InterpreterTest >> testRefreshDisplayRectOfAnotherFormDoesNothing [
	"Only the Form that is the screen is shown: a change to any other Form is not the host's business."

	| hal form |
	hal := self useHAL.
	form := self newFormWidth: 640 height: 480 words: 10.
	self runPrimitive: #primitiveBeDisplay with: { form }.

	interpreter
		refreshDisplayRect: (0 @ 0 corner: 5 @ 5)
		ofForm: (ST80Form
				 fromObject: (self newFormWidth: 16 height: 1 words: 1)
				 memory: memory).

	self assert: (hal callsTo: #updateDisplayRect:fromForm:) isEmpty
]

{ #category : 'tests - display primitives' }
InterpreterTest >> testRefreshDisplayRectOfTheCurrentDisplay [
	"A rectangle changed on the Form that is the screen is shown on the host: it is passed to it as it is."

	| hal form |
	hal := self useHAL.
	form := self newFormWidth: 640 height: 480 words: 10.
	self runPrimitive: #primitiveBeDisplay with: { form }.

	interpreter
		refreshDisplayRect: (10 @ 20 corner: 50 @ 60)
		ofForm: (ST80Form fromObject: form memory: memory).

	self
		assert: (hal callsTo: #updateDisplayRect:fromForm:)
		equals: { { (10 @ 20 corner: 50 @ 60) } }
]

{ #category : 'tests - linked lists' }
InterpreterTest >> testRemoveFirstLinkOfAList [
	"The first Link is removed and answered, the second becomes the first, and the removed Link points to nothing. The answer is counted once more than the list held it: the caller owns that reference and must release it."

	| list first second removed countBefore |
	list := self newLinkedList.
	first := self newProcessAt: 3.
	second := self newProcessAt: 3.
	interpreter addLastLink: first toList: list.
	interpreter addLastLink: second toList: list.
	countBefore := memory countBitsOf: first.

	removed := interpreter removeFirstLinkOfList: list.

	self assert: removed equals: first.
	self assert: (self firstProcessOf: list) equals: second.
	self assert: (self listSize: list) equals: 1.
	self
		assert: (memory fetchPointer: 0 ofObject: first)
		equals: nilPointer.
	self assert: (memory countBitsOf: first) equals: countBefore
]

{ #category : 'tests - linked lists' }
InterpreterTest >> testRemoveTheOnlyLinkEmptiesTheList [
	"Removing the only Link leaves the list empty, with no first and no last Link."

	| list process |
	list := self newLinkedList.
	process := self newProcessAt: 3.
	interpreter addLastLink: process toList: list.

	interpreter removeFirstLinkOfList: list.

	self assert: (interpreter isEmptyList: list).
	self assert: (self lastProcessOf: list) equals: nilPointer
]

{ #category : 'tests - scheduling' }
InterpreterTest >> testResumeOfAHigherPriorityProcessSwitchesToIt [
	"resume: of a Process whose priority is above the active one's preempts it: the active Process goes to sleep (it stays ready), and the resumed one is the new Process, waiting for the switch."

	| high |
	self setUpSchedulerWithPriorities: 4 activeAt: 2.
	high := self newProcessAt: 4.

	interpreter resume: high.

	self assert: (interpreter instVarNamed: 'newProcessWaiting').
	self assert: (interpreter instVarNamed: 'newProcess') equals: high.
	self
		assert: (self listOf: activeProcess)
		equals: (self readyListAt: 2)
]

{ #category : 'tests - scheduling' }
InterpreterTest >> testResumeOfALowerPriorityProcessOnlyMakesItReady [
	"A Process with a lower priority does not preempt: it only joins the ready list of its priority, and no switch is asked for."

	| low |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	low := self newProcessAt: 1.

	interpreter resume: low.

	self deny: (interpreter instVarNamed: 'newProcessWaiting').
	self assert: (self listOf: low) equals: (self readyListAt: 1)
]

{ #category : 'tests - scheduling' }
InterpreterTest >> testResumeOfAProcessOfTheSamePriorityDoesNotPreempt [
	"At the same priority the active Process keeps the processor: the resumed one waits in the ready list. Processes of equal priority do not preempt each other."

	| same |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	same := self newProcessAt: 3.

	interpreter resume: same.

	self deny: (interpreter instVarNamed: 'newProcessWaiting').
	self assert: (self listOf: same) equals: (self readyListAt: 3)
]

{ #category : 'tests - semaphores and processes' }
InterpreterTest >> testResumePrimitive [
	"Primitive 87, resume, calls resume: with its receiver: here a higher priority Process, which preempts the active one. The receiver stays on the stack as the answer."

	| process |
	self setUpSchedulerWithPriorities: 4 activeAt: 2.
	process := self newProcessAt: 4.

	self runPrimitive: #primitiveResume with: { process }.

	self assert: (interpreter instVarNamed: 'newProcess') equals: process.
	self assert: interpreter stackTop equals: process
]

{ #category : 'tests - return bytecodes' }
InterpreterTest >> testReturnNilsTheFieldsOfTheReturningContext [
	"A returned context cannot be returned from again: its sender and instruction pointer are set to nil (BB p. 610)"

	| caller callee |
	caller := self callerContext.
	self runCalleeOf: caller bytecodes: #( 119 124 ) receiver: nilPointer.
	callee := context.

	self
		assert: (memory
				 fetchPointer: (Interpreter classVarNamed: 'SenderIndex')
				 ofObject: callee)
		equals: nilPointer.
	self
		assert: (memory
				 fetchPointer:
				 (Interpreter classVarNamed: 'InstructionPointerIndex')
				 ofObject: callee)
		equals: nilPointer
]

{ #category : 'tests - return bytecodes' }
InterpreterTest >> testReturnReceiver [
	"Bytecode 120 returns self to the sender: the sender becomes active and gets the value on its stack"

	| caller receiver |
	caller := self callerContext.
	receiver := self objectWithFields: { nilPointer }.

	self runCalleeOf: caller bytecodes: #( 119 120 ) receiver: receiver.

	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: caller.
	self assert: self stackDepth equals: 1.
	self assert: interpreter stackTop equals: receiver
]

{ #category : 'tests - return bytecodes' }
InterpreterTest >> testReturnRegistersAreRestoredFromTheSender [
	"After a return the registers describe the sender: its receiver, its method and where it stopped"

	| caller receiver |
	receiver := self objectWithFields: { nilPointer }.
	caller := self
		          contextOf:
		          (self methodWithLiterals: #(  ) bytecodes: #( 118 118 ))
		          receiver: receiver
		          sender: nilPointer.

	self runCalleeOf: caller bytecodes: #( 119 124 ) receiver: nilPointer.

	self assert: (interpreter instVarNamed: 'receiver') equals: receiver.
	self assert: (interpreter instVarNamed: 'homeContext') equals: caller
]

{ #category : 'tests - return bytecodes' }
InterpreterTest >> testReturnStackTop [
	"Bytecode 124 returns the top of the stack of the callee"

	| caller |
	caller := self callerContext.

	self runCalleeOf: caller bytecodes: #( 119 124 ) receiver: nilPointer.

	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: caller.
	self assert: self stackDepth equals: 1.
	self assert: (self stackIntegerAt: 0) equals: 2
]

{ #category : 'tests - return bytecodes' }
InterpreterTest >> testReturnTrueFalseAndNil [
	"Bytecodes 121 to 123 return true, false and nil"

	#( 121 122 123 )
		with: {
				self truePointer.
				self falsePointer.
				nilPointer }
		do: [ :bytecode :expected |
				| caller |
				caller := self callerContext.
				self
					runCalleeOf: caller
					bytecodes: {
							119.
							bytecode }
					receiver: nilPointer.
				self
					assert: (interpreter instVarNamed: 'activeContext')
					equals: caller.
				self assert: interpreter stackTop equals: expected ]
]

{ #category : 'tests - sends' }
InterpreterTest >> testReturnWithNoSenderSendsCannotReturn [
	"A return from a context whose sender is nil pushes the context and the value, and sends cannotReturn: to the context (BB p. 609)"

	| handler |
	handler := self methodWithArguments: 1 bytecodes: #( 16 124 ).
	self
		class: self methodContextClass
		understands: (Interpreter classVarNamed: 'CannotReturnSelector')
		as: handler.
	self run: #( 119 124 ) literals: #(  ) receiver: nilPointer.

	2 timesRepeat: [ interpreter cycle ].

	self
		assert: (interpreter instVarNamed: 'messageSelector')
		equals: (Interpreter classVarNamed: 'CannotReturnSelector').
	self assert: (interpreter instVarNamed: 'method') equals: handler
]

{ #category : 'tests - input and cursor primitives' }
InterpreterTest >> testSampleInterval [
	"Primitive 94 sets the minimum time between two events of the pointing device, in milliseconds: the SmallInteger argument is passed to the host as a number and popped, leaving the receiver."

	| hal |
	hal := self useHAL.

	self runPrimitive: #primitiveSampleInterval with: {
			nilPointer.
			(self integer: 20) }.

	self assert: interpreter success.
	self assert: self stackDepth equals: 1.
	self assert: (hal callsTo: #sampleInterval:) equals: { { 20 } }
]

{ #category : 'tests - input and cursor primitives' }
InterpreterTest >> testSampleIntervalOfANonIntegerFails [

	self useHAL.

	self assertPrimitiveFails: #primitiveSampleInterval with: {
			nilPointer.
			nilPointer }
]

{ #category : 'tests - sends' }
InterpreterTest >> testSendActivatesTheMethod [
	"A send looks the selector up in the class of the receiver and makes a new context active: its sender is the context that sent, its receiver and method are those of the lookup"

	| selector method receiver sender |
	selector := self newSelector.
	method := self newMethodReturning: 42.
	receiver := self newReceiverOf: (self
			             newClassInheritingFrom: nilPointer
			             methods: { (selector -> method) }).

	self sendTo: receiver selector: selector.
	sender := context.

	self assert: (interpreter instVarNamed: 'method') equals: method.
	self assert: (interpreter instVarNamed: 'receiver') equals: receiver.
	self deny: (interpreter instVarNamed: 'activeContext') equals: sender.
	self assert: interpreter sender equals: sender
]

{ #category : 'tests - sends' }
InterpreterTest >> testSendDistinguishesSelectors [
	"Several selectors in one dictionary, including some that probe the same slot"

	| selectors methods receiver |
	selectors := (1 to: 6) collect: [ :k | self newSelector ].
	methods := (1 to: 6) collect: [ :k | self newMethodReturning: k ].
	receiver := self newReceiverOf: (self
			             newClassInheritingFrom: nilPointer
			             methods:
			             (selectors with: methods collect: [ :s :m | s -> m ])).

	selectors with: methods do: [ :selector :method |
			self sendTo: receiver selector: selector.
			self assert: (interpreter instVarNamed: 'method') equals: method ]
]

{ #category : 'tests - sends' }
InterpreterTest >> testSendFillsTheMethodCache [
	"The selector, the class, the method and the primitive index are kept in the method cache"

	| selector method cache |
	selector := self newSelector.
	method := self newMethodReturning: 42.
	self
		sendTo: (self newReceiverOf: (self
					  newClassInheritingFrom: nilPointer
					  methods: { (selector -> method) }))
		selector: selector.

	cache := interpreter instVarNamed: 'methodCache'.
	self assert: (cache includes: selector).
	self assert: (cache includes: method)
]

{ #category : 'tests - sends' }
InterpreterTest >> testSendFindsAMethodInASuperclass [
	"The lookup goes up the superclass chain"

	| selector method receiver base |
	selector := self newSelector.
	method := self newMethodReturning: 42.
	base := self
		        newClassInheritingFrom: nilPointer
		        methods: { (selector -> method) }.
	receiver := self newReceiverOf:
		            (self newClassInheritingFrom: base methods: #(  )).

	self sendTo: receiver selector: selector.

	self assert: (interpreter instVarNamed: 'method') equals: method
]

{ #category : 'tests - sends' }
InterpreterTest >> testSendFindsTheMethodOfTheSubclassFirst [
	"A method of the class overrides the one of its superclass"

	| selector own inherited receiver base |
	selector := self newSelector.
	own := self newMethodReturning: 1.
	inherited := self newMethodReturning: 2.
	base := self
		        newClassInheritingFrom: nilPointer
		        methods: { (selector -> inherited) }.
	receiver := self newReceiverOf:
		            (self
			             newClassInheritingFrom: base
			             methods: { (selector -> own) }).

	self sendTo: receiver selector: selector.

	self assert: (interpreter instVarNamed: 'method') equals: own
]

{ #category : 'tests - sends' }
InterpreterTest >> testSendOfAnUnknownSelectorSendsDoesNotUnderstand [
	"When the lookup fails the arguments are packed in a Message, which is the only argument of a doesNotUnderstand: send"

	| selector understanding receiver message arguments |
	selector := self newSelector.
	understanding := self methodWithArguments: 1 bytecodes: #( 16 124 ).
	receiver := self newReceiverOf: (self
			             newClassInheritingFrom: nilPointer
			             methods:
				             { ((Interpreter classVarNamed:
					               'DoesNotUnderstandSelector') -> understanding) }).

	self
		run: #( 112 118 119 240 )
		literals: { selector }
		receiver: receiver.
	4 timesRepeat: [ interpreter cycle ].
	message := interpreter temporary: 0.
	arguments := memory
		             fetchPointer:
		             (Interpreter classVarNamed: 'MessageArgumentsIndex')
		             ofObject: message.

	self
		assert: (interpreter instVarNamed: 'method')
		equals: understanding.
	self
		assert: (memory fetchClassOf: message)
		equals: (Interpreter classVarNamed: 'ClassMessagePointer').
	self
		assert: (memory
				 fetchPointer: (Interpreter classVarNamed: 'MessageSelectorIndex')
				 ofObject: message)
		equals: selector.
	self
		assert: (memory fetchClassOf: arguments)
		equals: (Interpreter classVarNamed: 'ClassArrayPointer').
	self assert: (memory fetchWordLengthOf: arguments) equals: 2.
	self
		assert:
		(memory integerValueOf: (memory fetchPointer: 0 ofObject: arguments))
		equals: 1.
	self
		assert:
		(memory integerValueOf: (memory fetchPointer: 1 ofObject: arguments))
		equals: 2
]

{ #category : 'tests - sends' }
InterpreterTest >> testSendReturnsToTheCaller [
	"The value the method returns is pushed on the stack of the sender"

	| selector receiver caller |
	selector := self newSelector.
	receiver := self newReceiverOf: (self
			             newClassInheritingFrom: nilPointer
			             methods:
			             { (selector -> (self newMethodReturning: 42)) }).

	self sendTo: receiver selector: selector.
	caller := interpreter sender.
	2 timesRepeat: [ interpreter cycle ].

	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: caller.
	self assert: self stackDepth equals: 1.
	self assert: (self stackIntegerAt: 0) equals: 42
]

{ #category : 'tests - sends' }
InterpreterTest >> testSendTakesTheReceiverOffTheCallerStack [
	"The receiver and the arguments are moved to the new context, which starts with an empty stack"

	| selector receiver |
	selector := self newSelector.
	receiver := self newReceiverOf: (self
			             newClassInheritingFrom: nilPointer
			             methods:
			             { (selector -> (self newMethodReturning: 42)) }).

	self sendTo: receiver selector: selector.

	self assert: self stackDepth equals: 0
]

{ #category : 'tests - sends' }
InterpreterTest >> testSendUsesTheMethodCache [
	"A second send of the same selector to the same class does not look in the dictionary again: removing it from the dictionary changes nothing"

	| selector method class receiver |
	selector := self newSelector.
	method := self newMethodReturning: 42.
	class := self
		         newClassInheritingFrom: nilPointer
		         methods: { (selector -> method) }.
	receiver := self newReceiverOf: class.
	self sendTo: receiver selector: selector.
	memory
		storePointer: (Interpreter classVarNamed: 'MessageDictionaryIndex')
		ofObject: class
		withValue: (self dictionaryWith: #(  )).

	self sendTo: receiver selector: selector.

	self assert: (interpreter instVarNamed: 'method') equals: method
]

{ #category : 'tests - sends' }
InterpreterTest >> testSendWithArguments [
	"The arguments become the first temporaries of the new context, in the order they were pushed"

	| selector receiver |
	selector := self newSelector.
	receiver := self newReceiverOf: (self
			             newClassInheritingFrom: nilPointer
			             methods:
			             { (selector
			              ->
			              (self methodWithArguments: 2 bytecodes: #( 17 124 ))) }).

	"push self, 1, 2, then send literal 0 with 2 arguments"
	self
		run: #( 112 118 119 240 )
		literals: { selector }
		receiver: receiver.
	4 timesRepeat: [ interpreter cycle ].

	self
		assert: (memory integerValueOf: (interpreter temporary: 0))
		equals: 1.
	self
		assert: (memory integerValueOf: (interpreter temporary: 1))
		equals: 2.
	self assert: (interpreter instVarNamed: 'receiver') equals: receiver
]

{ #category : 'tests - sends' }
InterpreterTest >> testSendWithArgumentsReturnsTheValue [
	"The method answers its second argument: the receiver and the arguments are replaced by the answer on the stack of the sender"

	| selector receiver |
	selector := self newSelector.
	receiver := self newReceiverOf: (self
			             newClassInheritingFrom: nilPointer
			             methods:
			             { (selector
			              ->
			              (self methodWithArguments: 2 bytecodes: #( 17 124 ))) }).

	self
		run: #( 112 118 119 240 )
		literals: { selector }
		receiver: receiver.
	6 timesRepeat: [ interpreter cycle ].

	self assert: self stackDepth equals: 1.
	self assert: (self stackIntegerAt: 0) equals: 2
]

{ #category : 'tests - jump bytecodes' }
InterpreterTest >> testShortConditionalJumpOnFalse [
	"Bytecodes 152 to 159 jump by 1 to 8 when the top of the stack is false, and pop it"

	| start |
	self run: #( 114 152 118 118 ) literals: #(  ) receiver: nilPointer.
	interpreter cycle.
	start := interpreter instVarNamed: 'instructionPointer'.

	interpreter cycle.

	self
		assert: (interpreter instVarNamed: 'instructionPointer')
		equals: start + 2.
	self assert: self stackDepth equals: 0
]

{ #category : 'tests - jump bytecodes' }
InterpreterTest >> testShortConditionalJumpOnTrueDoesNotJump [
	"The same bytecode falls through when the top of the stack is true, and still pops it"

	| start |
	self run: #( 113 152 118 118 ) literals: #(  ) receiver: nilPointer.
	interpreter cycle.
	start := interpreter instVarNamed: 'instructionPointer'.

	interpreter cycle.

	self
		assert: (interpreter instVarNamed: 'instructionPointer')
		equals: start + 1.
	self assert: self stackDepth equals: 0
]

{ #category : 'tests - jump bytecodes' }
InterpreterTest >> testShortUnconditionalJump [
	"Bytecodes 144 to 151 advance the instruction pointer by 1 to 8 after the bytecode"

	| start |
	self run: #( 145 118 118 119 ) literals: #(  ) receiver: nilPointer.
	start := interpreter instVarNamed: 'instructionPointer'.

	interpreter cycle.

	"1 byte fetched, then 2 skipped"
	self
		assert: (interpreter instVarNamed: 'instructionPointer')
		equals: start + 3
]

{ #category : 'tests - system primitives' }
InterpreterTest >> testSignalAtOopsLeftWordsLeft [
	"Primitive 116 asks to signal a Semaphore when the free object table entries or the free words drop below the given numbers: the three arguments are popped and the interpreter keeps the Semaphore and the two limits."

	| semaphore |
	semaphore := self newReceiverOf:
		             (Interpreter classVarNamed: 'ClassSemaphorePointer').

	self runPrimitive: #primitiveSignalAtOopsLeftWordsLeft with: {
			semaphore.
			(self integer: 50).
			(self integer: 1000) }.

	self assert: interpreter success.
	self assert: self stackDepth equals: 0.
	self
		assert: (interpreter instVarNamed: 'lowSpaceSemaphore')
		equals: semaphore.
	self assert: (interpreter instVarNamed: 'oopsLeftLimit') equals: 50.
	self
		assert: (interpreter instVarNamed: 'wordsLeftLimit')
		equals: 1000
]

{ #category : 'tests - system primitives' }
InterpreterTest >> testSignalAtOopsLeftWordsLeftOfANonSemaphoreFails [
	"The first argument must be a Semaphore or nil: anything else fails the primitive and leaves the three arguments on the stack."

	self
		assertPrimitiveFails: #primitiveSignalAtOopsLeftWordsLeft
		with: {
				(self integer: 3).
				(self integer: 50).
				(self integer: 1000) }
]

{ #category : 'tests - time primitives' }
InterpreterTest >> testSignalAtTick [
	"Primitive 100 asks the host to signal a Semaphore when the millisecond clock reaches a time: the time is in the first four bytes of the second argument, low order byte first (the same layout primitive 99 writes). Both arguments are popped and the host gets the Semaphore and the time: the bytes 1, 2, 3, 4 are 16r04030201, which is above 65535 milliseconds, so each of the four bytes matters."

	| hal semaphore bytes |
	hal := self useHAL.
	semaphore := self newReceiverOf:
		             (Interpreter classVarNamed: 'ClassSemaphorePointer').
	bytes := self newBytesOf: 4.
	#( 1 2 3 4 ) withIndexDo: [ :byte :index |
		memory storeByte: index - 1 ofObject: bytes withValue: byte ].

	self runPrimitive: #primitiveSignalAtTick with: {
			semaphore.
			bytes }.

	self assert: interpreter success.
	self assert: self stackDepth equals: 0.
	self assert: (hal callsTo: #signal:atMilliseconds:) equals: { {
			semaphore.
			16r04030201 } }
]

{ #category : 'tests - time primitives' }
InterpreterTest >> testSignalAtTickOfANonSemaphoreFails [
	"The first argument must be a Semaphore or nil: anything else fails the primitive and leaves both arguments on the stack."

	self useHAL.

	self assertPrimitiveFails: #primitiveSignalAtTick with: {
			(self integer: 3).
			(self newBytesOf: 4) }
]

{ #category : 'tests - time primitives' }
InterpreterTest >> testSignalAtTickRoundTripsTheClock [
	"The time that primitive 99 writes is what primitive 100 reads: a clock value of 16rFFFFFFFF written to a byte object and then given to primitive 100 comes back unchanged to the host."

	| hal bytes |
	hal := self useHAL.
	hal uptime: 16rFFFFFFFF.
	bytes := self newBytesOf: 4.
	self runPrimitive: #primitiveTickWordsInto with: { bytes }.

	self runPrimitive: #primitiveSignalAtTick with: {
			(self newReceiverOf:
				 (Interpreter classVarNamed: 'ClassSemaphorePointer')).
			bytes }.

	self
		assert: (hal callsTo: #signal:atMilliseconds:) first last
		equals: 16rFFFFFFFF
]

{ #category : 'tests - time primitives' }
InterpreterTest >> testSignalAtTickWithATimeBelow256 [
	"A time that fits in the low byte is passed as it is, and the three other bytes, 0, add nothing."

	| hal bytes |
	hal := self useHAL.
	bytes := self newBytesOf: 4.
	memory storeByte: 0 ofObject: bytes withValue: 200.

	self runPrimitive: #primitiveSignalAtTick with: {
			(self newReceiverOf:
				 (Interpreter classVarNamed: 'ClassSemaphorePointer')).
			bytes }.

	self
		assert: (hal callsTo: #signal:atMilliseconds:) first last
		equals: 200
]

{ #category : 'tests - semaphores and processes' }
InterpreterTest >> testSignalResumesTheFirstWaiter [
	"With a Process waiting, signal does not count anything: the first waiter is removed from the Semaphore and resumed. Here it has a higher priority than the active one, so it preempts it: it becomes the new Process."

	| semaphore waiter |
	self setUpSchedulerWithPriorities: 4 activeAt: 2.
	semaphore := self newSemaphore.
	waiter := self newProcessAt: 4.
	interpreter addLastLink: waiter toList: semaphore.

	self runPrimitive: #primitiveSignal with: { semaphore }.

	self assert: (interpreter isEmptyList: semaphore).
	self assert: (self excessSignalsOf: semaphore) equals: 0.
	self assert: (interpreter instVarNamed: 'newProcess') equals: waiter
]

{ #category : 'tests - semaphores and processes' }
InterpreterTest >> testSignalResumesWaitersInOrder [
	"Waiters are served first in, first out: with two waiting, the first one is resumed and the second one is still in the Semaphore."

	| semaphore first second |
	self setUpSchedulerWithPriorities: 4 activeAt: 2.
	semaphore := self newSemaphore.
	first := self newProcessAt: 4.
	second := self newProcessAt: 4.
	interpreter addLastLink: first toList: semaphore.
	interpreter addLastLink: second toList: semaphore.

	self runPrimitive: #primitiveSignal with: { semaphore }.

	self assert: (interpreter instVarNamed: 'newProcess') equals: first.
	self assert: (self firstProcessOf: semaphore) equals: second
]

{ #category : 'tests - semaphores and processes' }
InterpreterTest >> testSignalThenWaitDoNotBlock [
	"A signal before a wait is not lost: the wait that follows finds it and the Process does not stop. This is the semaphore as a counter."

	| semaphore |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	semaphore := self newSemaphore.

	self runPrimitive: #primitiveSignal with: { semaphore }.
	self runPrimitive: #primitiveWait with: { semaphore }.

	self deny: (interpreter instVarNamed: 'newProcessWaiting').
	self assert: (self excessSignalsOf: semaphore) equals: 0
]

{ #category : 'tests - semaphores and processes' }
InterpreterTest >> testSignalWithNoWaiterCountsAnExcessSignal [
	"Primitive 85, signal, on a Semaphore nobody waits for remembers the signal: its excess signals count goes up by one, so that a later wait does not block. The receiver stays on the stack as the answer."

	| semaphore |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	semaphore := self newSemaphore.

	self runPrimitive: #primitiveSignal with: { semaphore }.

	self assert: (self excessSignalsOf: semaphore) equals: 1.
	self assert: self stackDepth equals: 1.
	self assert: interpreter stackTop equals: semaphore
]

{ #category : 'tests - semaphores and processes' }
InterpreterTest >> testSignalsAccumulate [
	"Each signal with no waiter adds one to the count."

	| semaphore |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	semaphore := self newSemaphore.

	3 timesRepeat: [
		self runPrimitive: #primitiveSignal with: { semaphore } ].

	self assert: (self excessSignalsOf: semaphore) equals: 3
]

{ #category : 'tests - special selectors' }
InterpreterTest >> testSimpleReturnValueTo [
	"The simple return makes the context active and pushes the value, with none of the checks of returnValue:to:"

	| caller |
	caller := self callerContext.

	interpreter simpleReturnValue: (memory integerObjectOf: 9) to: caller.

	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: caller.
	self assert: (self stackIntegerAt: 0) equals: 9
]

{ #category : 'tests - extended sends' }
InterpreterTest >> testSingleExtendedSend [
	"Bytecode 131 is followed by a byte: the argument count in its three high bits, the literal index of the selector in the five low bits"

	| selector method receiver |
	selector := self newSelector.
	method := self newMethodReturning: 42.
	receiver := self newReceiverOf: (self
			             newClassInheritingFrom: nilPointer
			             methods: { (selector -> method) }).

	self run: #( 112 131 0 ) literals: { selector } receiver: receiver.
	2 timesRepeat: [ interpreter cycle ].

	self assert: (interpreter instVarNamed: 'method') equals: method.
	self assert: (interpreter instVarNamed: 'argumentCount') equals: 0
]

{ #category : 'tests - extended sends' }
InterpreterTest >> testSingleExtendedSendReachesFurtherLiterals [
	"The short send bytecodes reach 16 literals, the extended one 32"

	| selector method receiver literals |
	selector := self newSelector.
	method := self newMethodReturning: 42.
	receiver := self newReceiverOf: (self
			             newClassInheritingFrom: nilPointer
			             methods: { (selector -> method) }).
	literals := ((1 to: 20) collect: [ :k | memory integerObjectOf: k ])
		            copyWith: selector.

	self run: #( 112 131 20 ) literals: literals receiver: receiver.
	2 timesRepeat: [ interpreter cycle ].

	self assert: (interpreter instVarNamed: 'method') equals: method
]

{ #category : 'tests - extended sends' }
InterpreterTest >> testSingleExtendedSendWithArgument [
	"The argument count of the descriptor byte: 32 is one argument, literal 0"

	| selector receiver |
	selector := self newSelector.
	receiver := self newReceiverOf: (self
			             newClassInheritingFrom: nilPointer
			             methods:
			             { (selector
			              ->
			              (self methodWithArguments: 1 bytecodes: #( 16 124 ))) }).

	self
		run: #( 112 119 131 32 )
		literals: { selector }
		receiver: receiver.
	3 timesRepeat: [ interpreter cycle ].

	self assert: (interpreter instVarNamed: 'argumentCount') equals: 1.
	self
		assert: (memory integerValueOf: (interpreter temporary: 0))
		equals: 2
]

{ #category : 'tests - extended sends' }
InterpreterTest >> testSingleExtendedSuperSend [
	"Bytecode 133 looks the selector up from the superclass of the class the sending method belongs to, whatever the class of the receiver"

	| selector classes sender |
	selector := self newSelector.
	classes := self twoClassesUnderstanding: selector.
	sender := self
		          superSenderWith: { selector }
		          bytecodes: #( 112 133 0 )
		          methodClass: classes value.

	self runMethod: sender receiver: (self newReceiverOf: classes value).
	2 timesRepeat: [ interpreter cycle ].

	self
		assert: (memory integerValueOf:
				 (interpreter
					  literal: 0
					  ofMethod: (interpreter instVarNamed: 'method')))
		equals: 1
]

{ #category : 'tests - array primitives' }
InterpreterTest >> testSize [
	"size answers the number of indexable fields"

	self
		assertPrimitive: #primitiveSize
		with: { (self newArrayOf: 3) }
		answers: (self integer: 3).
	self
		assertPrimitive: #primitiveSize
		with: { (self newArrayOf: 0) }
		answers: (self integer: 0)
]

{ #category : 'tests - array primitives' }
InterpreterTest >> testSizeIgnoresTheFixedFields [
	"The fixed fields of the class are not counted"

	self
		assertPrimitive: #primitiveSize
		with: { (memory
				 instantiateClass: (self
						  newClassPointers: 1
						  words: 1
						  indexable: 1
						  fixed: 2)
				 withPointers: 5) }
		answers: (self integer: 3)
]

{ #category : 'tests - VM bugs' }
InterpreterTest >> testSizeOfAnIntegerFails [

	self
		shouldnt: [
			self
				assertPrimitiveFails: #primitiveSize
				with: { (self integer: 3) } ]
		raise: Warning
]

{ #category : 'tests - scheduling' }
InterpreterTest >> testSleepPutsTheProcessInTheListOfItsPriority [
	"sleep: makes a Process ready: it joins, at the end, the list of the scheduler for its priority, and the other lists are untouched."

	| process |
	self setUpSchedulerWithPriorities: 4 activeAt: 2.
	process := self newProcessAt: 3.

	interpreter sleep: process.

	self assert: (self listOf: process) equals: (self readyListAt: 3).
	self assert: (self listSize: (self readyListAt: 3)) equals: 1.
	self assert: (self listSize: (self readyListAt: 2)) equals: 0
]

{ #category : 'tests - snapshot primitive' }
InterpreterTest >> testSnapshot [
	"Primitive 97 saves the object memory: it stores the active context in the active process (so that the snapshot resumes where the guest was), collects the garbage, asks the host to write the file, then replaces the receiver with nil, which tells the guest that it has just saved."

	| hal process schedulerObject |
	hal := self useHAL.
	process := self objectWithFields: {
			           nilPointer.
			           nilPointer.
			           (self integer: 4).
			           nilPointer }.
	schedulerObject := self objectWithFields: {
			                   nilPointer.
			                   process }.
	memory
		storePointer: 1
		ofObject: self schedulerAssociationPointer
		withValue: schedulerObject.

	self runPrimitive: #primitiveSnapshot with: { nilPointer }.

	self assert: hal vm savedCount equals: 1.
	self assert: self stackDepth equals: 1.
	self assert: interpreter stackTop equals: nilPointer.
	self
		assert: (memory fetchPointer: 1 ofObject: process)
		equals: context
]

{ #category : 'tests - snapshot primitive' }
InterpreterTest >> testSnapshotCollectsGarbage [
	"The garbage is collected before the file is written: an object that no root reaches is gone when the primitive returns, so the snapshot does not carry it. The object is counted once, as for any object that the guest created, and then no root refers to it. A collected object keeps its entry in the object table as a free chunk, so hasObject: is the test."

	| garbage process schedulerObject |
	self useHAL.
	process := self objectWithFields: {
			           nilPointer.
			           nilPointer.
			           (self integer: 4).
			           nilPointer }.
	schedulerObject := self objectWithFields: {
			                   nilPointer.
			                   process }.
	memory
		storePointer: 1
		ofObject: self schedulerAssociationPointer
		withValue: schedulerObject.
	garbage := self objectWithFields: { (self integer: 1) }.
	self assert: (memory hasObject: garbage).

	self runPrimitive: #primitiveSnapshot with: { nilPointer }.

	self deny: (memory hasObject: garbage)
]

{ #category : 'tests - special selectors' }
InterpreterTest >> testSpecialSelectorAdd [
	"Bytecodes 176 to 191 are the arithmetic special selectors: with two SmallIntegers the primitive answers directly, no send happens"

	self
		sendSpecialSelector: 176
		to: (memory integerObjectOf: 3)
		with: { (memory integerObjectOf: 4) }.

	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: context.
	self assert: self stackDepth equals: 1.
	self assert: (self stackIntegerAt: 0) equals: 7
]

{ #category : 'tests - special selectors' }
InterpreterTest >> testSpecialSelectorClass [
	"Bytecode 199 is class: the class of an object, or SmallInteger for an integer"

	| class |
	class := self newClassInheritingFrom: nilPointer methods: #(  ).

	self
		sendSpecialSelector: 199
		to: (self newReceiverOf: class)
		with: #(  ).
	self assert: interpreter stackTop equals: class.

	self
		sendSpecialSelector: 199
		to: (memory integerObjectOf: 5)
		with: #(  ).
	self
		assert: interpreter stackTop
		equals: (Interpreter classVarNamed: 'ClassSmallInteger')
]

{ #category : 'tests - special selectors' }
InterpreterTest >> testSpecialSelectorComparison [

	self
		sendSpecialSelector: 178
		to: (memory integerObjectOf: 3)
		with: { (memory integerObjectOf: 4) }.

	self assert: interpreter stackTop equals: self truePointer
]

{ #category : 'tests - special selectors' }
InterpreterTest >> testSpecialSelectorEquivalent [
	"Bytecode 198 is ==, true for the same object pointer only"

	| object |
	object := self newReceiverOf: classPointer.

	self sendSpecialSelector: 198 to: object with: { object }.
	self assert: interpreter stackTop equals: self truePointer.

	self sendSpecialSelector: 198 to: object with: { nilPointer }.
	self assert: interpreter stackTop equals: self falsePointer.
	self assert: self stackDepth equals: 1
]

{ #category : 'tests - special selectors' }
InterpreterTest >> testSpecialSelectorFailureSendsTheMessage [
	"When the primitive fails, + is an ordinary send: here to an object, whose class answers it"

	| method receiver |
	method := self newMethodReturning: 5.
	receiver := self newReceiverOf: (self
			             newClassInheritingFrom: nilPointer
			             methods: { ((self specialSelector: 0) -> method) }).

	self
		sendSpecialSelector: 176
		to: receiver
		with: { (memory integerObjectOf: 4) }.

	self assert: (interpreter instVarNamed: 'method') equals: method
]

{ #category : 'tests - special selectors' }
InterpreterTest >> testSpecialSelectorMakePoint [
	"Bytecode 187 is @: it makes a Point from two SmallIntegers"

	| point |
	self
		sendSpecialSelector: 187
		to: (memory integerObjectOf: 3)
		with: { (memory integerObjectOf: 4) }.
	point := interpreter stackTop.

	self assert: self stackDepth equals: 1.
	self
		assert: (memory fetchClassOf: point)
		equals: (Interpreter classVarNamed: 'ClassPointPointer').
	self
		assert: (memory integerValueOf: (memory
					  fetchPointer: (Interpreter classVarNamed: 'XIndex')
					  ofObject: point))
		equals: 3.
	self
		assert: (memory integerValueOf: (memory
					  fetchPointer: (Interpreter classVarNamed: 'YIndex')
					  ofObject: point))
		equals: 4
]

{ #category : 'tests - stack' }
InterpreterTest >> testStackTopAndStackValue [
	"stackValue: counts down from the top, which is stackValue: 0"

	self pushInteger: 1.
	self pushInteger: 2.
	self pushInteger: 3.

	self assert: (memory integerValueOf: interpreter stackTop) equals: 3.
	self assert: (self stackIntegerAt: 0) equals: 3.
	self assert: (self stackIntegerAt: 1) equals: 2.
	self assert: (self stackIntegerAt: 2) equals: 1
]

{ #category : 'tests - stack bytecodes' }
InterpreterTest >> testStoreAndPopReceiverVariable [
	"Bytecodes 96 to 103 store the top of the stack in an instance variable of the receiver, and pop"

	| receiver |
	receiver := self objectWithFields: {
			            nilPointer.
			            nilPointer }.

	self runBytecodes: #( 118 97 ) literals: #(  ) receiver: receiver.

	self assert: self stackDepth equals: 0.
	self
		assert:
		(memory integerValueOf: (memory fetchPointer: 1 ofObject: receiver))
		equals: 1
]

{ #category : 'tests - stack bytecodes' }
InterpreterTest >> testStoreAndPopTemporaryVariable [
	"Bytecodes 104 to 111 store the top of the stack in a temporary of the home context, and pop"

	self runBytecodes: #( 119 106 ).

	self assert: self stackDepth equals: 0.
	self
		assert: (memory integerValueOf: (interpreter temporary: 2))
		equals: 2
]

{ #category : 'tests - stack' }
InterpreterTest >> testStoreContextRegisters [
	"The stack pointer and instruction pointer are written back to the context as SmallIntegers: the stack pointer relative to the first stack field, the instruction pointer one based"

	self pushInteger: 1.
	self pushInteger: 2.
	interpreter instVarNamed: 'instructionPointer' put: 6.

	interpreter storeContextRegisters.

	self assert: (interpreter stackPointerOfContext: context) equals: 2.
	self
		assert: (interpreter instructionPointerOfContext: context)
		equals: 7
]

{ #category : 'tests - string and stream primitives' }
InterpreterTest >> testStreamPrimitivesFailOnOtherCollections [
	"Only an Array or a String can be streamed by the primitives: a byte object that is neither makes them fail"

	| stream |
	stream := self
		          newStreamOn: (self newBytesOf: 3)
		          index: 0
		          readLimit: 3
		          writeLimit: 3.

	self assertPrimitiveFails: #primitiveAtEnd with: { stream }.
	self assertPrimitiveFails: #primitiveNextPut with: {
			stream.
			(self integer: 1) }
]

{ #category : 'tests - string and stream primitives' }
InterpreterTest >> testStringAt [
	"String at: answers the Character of the table for the byte"

	self
		assertPrimitive: #primitiveStringAt
		with: {
				(self newStringWith: #( 65 66 67 )).
				(self integer: 2) }
		answers: (self characterFor: 66)
]

{ #category : 'tests - string and stream primitives' }
InterpreterTest >> testStringAtOutOfBoundsFails [

	self assertPrimitiveFails: #primitiveStringAt with: {
			(self newStringWith: #( 65 66 )).
			(self integer: 3) }.
	self assertPrimitiveFails: #primitiveStringAt with: {
			(self newStringWith: #( 65 66 )).
			(self integer: 0) }
]

{ #category : 'tests - string and stream primitives' }
InterpreterTest >> testStringAtPut [
	"String at:put: stores the code of a Character"

	| string |
	string := self newStringWith: #( 65 66 67 ).

	self
		assertPrimitive: #primitiveStringAtPut
		with: {
				string.
				(self integer: 3).
				(self characterFor: 90) }
		answers: (self characterFor: 90).

	self assert: (memory fetchByte: 2 ofObject: string) equals: 90
]

{ #category : 'tests - string and stream primitives' }
InterpreterTest >> testStringAtPutOfANonCharacterFails [

	self assertPrimitiveFails: #primitiveStringAtPut with: {
			(self newStringWith: #( 65 )).
			(self integer: 1).
			(self integer: 66) }
]

{ #category : 'tests - string and stream primitives' }
InterpreterTest >> testStringAtPutOutOfBoundsFails [

	self assertPrimitiveFails: #primitiveStringAtPut with: {
			(self newStringWith: #( 65 )).
			(self integer: 2).
			(self characterFor: 66) }
]

{ #category : 'tests - VM bugs' }
InterpreterTest >> testStringAtPutWithANonIntegerIndexFails [
	"Same limit as testAtPutWithANonIntegerIndexFails"

	<expectedFailure>
	self assertPrimitiveFails: #primitiveStringAtPut with: {
			(self newStringWith: #( 65 )).
			nilPointer.
			(self characterFor: 66) }
]

{ #category : 'tests - VM bugs' }
InterpreterTest >> testStringAtWithANonIntegerIndexFails [
	"Same limit as testAtPutWithANonIntegerIndexFails"

	<expectedFailure>
	self assertPrimitiveFails: #primitiveStringAt with: {
			(self newStringWith: #( 65 )).
			nilPointer }
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testStringConversionRoundTrip [
	"stringFromST80Object: and st80StringObjectFor: convert between a host String and a String object of the memory, byte by byte: the object is an instance of the String class, as long as the text, and the host String comes back unchanged. An empty String is a String object of length 0."

	| object |
	object := interpreter st80StringObjectFor: 'Hello, world'.

	self
		assert: (memory fetchClassOf: object)
		equals: (Interpreter classVarNamed: 'ClassStringPointer').
	self assert: (memory fetchByteLengthOf: object) equals: 12.
	self
		assert: (interpreter stringFromST80Object: object)
		equals: 'Hello, world'.
	self
		assert: (interpreter stringFromST80Object:
				 (interpreter st80StringObjectFor: ''))
		equals: ''
]

{ #category : 'tests - file primitives' }
InterpreterTest >> testStringObjectForNilIsNil [
	"There is no String object for nil: it answers the nil object, which is how a missing name is passed to the guest."

	self
		assert: (interpreter st80StringObjectFor: nil)
		equals: nilPointer
]

{ #category : 'tests - system primitives' }
InterpreterTest >> testStringReplaceAndDrawLoopAreNotImplemented [
	"The optional primitives 105 (string replace) and 104 (draw loop, for faster lines) are not implemented: they always fail, so that the Smalltalk code of the guest, slower but complete, runs instead."

	self
		assertPrimitiveFails: #primitiveStringReplace
		with: { nilPointer }.
	self assertPrimitiveFails: #primitiveDrawLoop with: { nilPointer }
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testSubtract [

	self
		assertResult: -1
		of: #primitiveSubtract
		with: 3
		with: 4.
	self
		assertResult: 7
		of: #primitiveSubtract
		with: 3
		with: -4
]

{ #category : 'tests - arithmetic primitives' }
InterpreterTest >> testSubtractOverflowFails [

	self assertFailureOf: #primitiveSubtract with: -16384 with: 1.
	self assertFailureOf: #primitiveSubtract with: 16383 with: -1
]

{ #category : 'tests - semaphores and processes' }
InterpreterTest >> testSuspendOfAnotherProcessFails [
	"Only the active Process can be suspended by this primitive: for any other Process it fails, and the receiver stays on the stack."

	self setUpSchedulerWithPriorities: 4 activeAt: 3.

	self
		assertPrimitiveFails: #primitiveSuspend
		with: { (self newProcessAt: 2) }
]

{ #category : 'tests - semaphores and processes' }
InterpreterTest >> testSuspendOfTheActiveProcess [
	"Primitive 88, suspend, of the active Process answers nil and switches to the highest priority ready Process: the active one is in no list afterwards, so nothing runs it again until it is resumed."

	| idle |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	idle := self newProcessAt: 1.
	interpreter sleep: idle.

	self runPrimitive: #primitiveSuspend with: { activeProcess }.

	self assert: interpreter success.
	self assert: interpreter stackTop equals: nilPointer.
	self assert: (interpreter instVarNamed: 'newProcess') equals: idle.
	self assert: (self listOf: activeProcess) equals: nilPointer
]

{ #category : 'tests - special selectors' }
InterpreterTest >> testSystemPrimitiveClassFromASend [
	"Primitive 111 is class"

	| selector object |
	selector := self newSelector.
	object := self newReceiverOf: classPointer.
	self
		class: classPointer
		understands: selector
		as: (self methodWithPrimitive: 111 arguments: 0 fallback: #( 120 )).

	self run: #( 112 208 ) literals: { selector } receiver: object.
	2 timesRepeat: [ interpreter cycle ].

	self assert: self stackDepth equals: 1.
	self assert: interpreter stackTop equals: classPointer
]

{ #category : 'tests - special selectors' }
InterpreterTest >> testSystemPrimitiveEquivalentFromASend [
	"Primitive 110 is ==, reached through the system primitives dispatch"

	| selector object |
	selector := self newSelector.
	object := self newReceiverOf: classPointer.
	self
		class: classPointer
		understands: selector
		as: (self methodWithPrimitive: 110 arguments: 1 fallback: #( 120 )).

	self run: #( 112 112 224 ) literals: { selector } receiver: object.
	3 timesRepeat: [ interpreter cycle ].

	self assert: self stackDepth equals: 1.
	self assert: interpreter stackTop equals: self truePointer
]

{ #category : 'tests - time primitives' }
InterpreterTest >> testTickWordsInto [
	"Primitive 99 stores the host millisecond clock as an unsigned 32 bit number in the first four bytes of its argument, the low order byte first: 16r04030201 gives the bytes 1, 2, 3, 4. The argument is popped."

	| bytes |
	self useHAL uptime: 16r04030201.
	bytes := self newBytesOf: 4.

	self runPrimitive: #primitiveTickWordsInto with: { bytes }.

	self assert: self stackDepth equals: 0.
	self
		assert: (self bytesOf: bytes count: 4)
		equals: #( 1 2 3 4 ) asByteArray
]

{ #category : 'tests - time primitives' }
InterpreterTest >> testTickWordsIntoKeepsTheHighBytes [
	"The clock is 32 bits and rolls over: the largest value fills the four bytes."

	| bytes |
	self useHAL uptime: 16rFFFFFFFF.
	bytes := self newBytesOf: 4.

	self runPrimitive: #primitiveTickWordsInto with: { bytes }.

	self
		assert: (self bytesOf: bytes count: 4)
		equals: #( 255 255 255 255 ) asByteArray
]

{ #category : 'tests - time primitives' }
InterpreterTest >> testTimeWordsInto [
	"Primitive 98 stores the number of seconds since the midnight before January 1, 1901 (the Smalltalk-80 epoch) as an unsigned 32 bit number, low order byte first, in its argument: 16r0A0B0C0D gives 13, 12, 11, 10."

	| bytes |
	self useHAL seconds: 16r0A0B0C0D.
	bytes := self newBytesOf: 4.

	self runPrimitive: #primitiveTimeWordsInto with: { bytes }.

	self assert: self stackDepth equals: 0.
	self
		assert: (self bytesOf: bytes count: 4)
		equals: #( 13 12 11 10 ) asByteArray
]

{ #category : 'tests - time primitives' }
InterpreterTest >> testTimerAcrossTheRollOverOfTheClock [
	"The millisecond clock is a 32 bit number that rolls over: a time just after the roll over is in the future for a clock just before it, and in the past for a clock just after it."

	| hal timer |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	hal := self useClockHAL.
	timer := self newSemaphore.
	hal uptime: 16rFFFFFFF0.

	hal signal: timer atMilliseconds: 16r10.
	self assert: (interpreter instVarNamed: 'semaphoreIndex') equals: 0.

	hal uptime: 16rF.
	hal checkScheduledSemaphore.
	self assert: (interpreter instVarNamed: 'semaphoreIndex') equals: 0.

	hal uptime: 16r10.
	hal checkScheduledSemaphore.
	self assert: (interpreter instVarNamed: 'semaphoreIndex') equals: 1
]

{ #category : 'tests - time primitives' }
InterpreterTest >> testTimerCancelledWithNilSignalsNothing [
	"A nil Semaphore cancels the outstanding request (BB p 652): nothing reaches the interpreter, even when the time of the cancelled request is reached."

	| hal timer |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	hal := self useClockHAL.
	timer := self newSemaphore.
	hal signal: timer atMilliseconds: 1500.

	hal signal: nil atMilliseconds: 1500.
	hal uptime: 2000.
	hal checkScheduledSemaphore.

	self assert: hal scheduledSemaphore isNil.
	self assert: (interpreter instVarNamed: 'semaphoreIndex') equals: 0
]

{ #category : 'tests - time primitives' }
InterpreterTest >> testTimerInThePastSignalsAtOnce [
	"If the time has already passed when the request is made, the Semaphore is signaled immediately (BB p 652)."

	| hal timer |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	hal := self useClockHAL.
	timer := self newSemaphore.

	hal signal: timer atMilliseconds: 900.

	self assert: (interpreter instVarNamed: 'semaphoreIndex') equals: 1.
	self assert: hal scheduledSemaphore isNil
]

{ #category : 'tests - time primitives' }
InterpreterTest >> testTimerRequestReplacesThePreviousOne [
	"Only one request is outstanding: a new one replaces the previous one, whose Semaphore is not signaled (BB p 652)."

	| hal first second |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	hal := self useClockHAL.
	first := self newSemaphore.
	second := self newSemaphore.

	hal signal: first atMilliseconds: 1500.
	hal signal: second atMilliseconds: 1600.
	hal uptime: 2000.
	hal checkScheduledSemaphore.
	interpreter checkProcessSwitch.

	self assert: (self excessSignalsOf: first) equals: 0.
	self assert: (self excessSignalsOf: second) equals: 1
]

{ #category : 'tests - time primitives' }
InterpreterTest >> testTimerSignalsOnceWhenItsTimeHasPassed [
	"The outstanding request is polled: nothing is buffered before its time, the Semaphore is buffered once when the time is reached, and the request is then forgotten."

	| hal timer |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	hal := self useClockHAL.
	timer := self newSemaphore.

	hal signal: timer atMilliseconds: 1500.
	hal checkScheduledSemaphore.
	self assert: (interpreter instVarNamed: 'semaphoreIndex') equals: 0.

	hal uptime: 1500.
	hal checkScheduledSemaphore.
	hal checkScheduledSemaphore.

	self assert: (interpreter instVarNamed: 'semaphoreIndex') equals: 1.
	self assert: hal scheduledSemaphore isNil.
	interpreter checkProcessSwitch.
	self assert: (self excessSignalsOf: timer) equals: 1
]

{ #category : 'tests - scheduling' }
InterpreterTest >> testTransferToAsksForASwitch [
	"transferTo: only records the request: the new Process is held in newProcess, and the switch happens between two bytecodes, in checkProcessSwitch. The new Process is counted, so that it cannot be freed while it waits."

	| other count |
	self setUpSchedulerWithPriorities: 4 activeAt: 2.
	other := self newProcessAt: 4.
	count := memory countBitsOf: other.

	interpreter transferTo: other.

	self assert: (interpreter instVarNamed: 'newProcessWaiting').
	self assert: (interpreter instVarNamed: 'newProcess') equals: other.
	self assert: (memory countBitsOf: other) equals: count + 1
]

{ #category : 'tests - scheduling' }
InterpreterTest >> testTransferToReleasesThePreviousNewProcess [
	"If a switch was already waiting, the Process that was to be switched to is released: its count goes back down, so that nothing is leaked when the request is replaced."

	| first second count |
	self setUpSchedulerWithPriorities: 4 activeAt: 2.
	first := self newProcessAt: 3.
	second := self newProcessAt: 4.
	count := memory countBitsOf: first.
	interpreter transferTo: first.

	interpreter transferTo: second.

	self assert: (memory countBitsOf: first) equals: count.
	self assert: (interpreter instVarNamed: 'newProcess') equals: second
]

{ #category : 'tests - float conversions' }
InterpreterTest >> testTruncated [
	"truncated (primitive 51) drops the fractional part, rounding toward zero: 3.7 gives 3 and -3.7 gives -3 (not -4, that would be floor). The answer is a SmallInteger."

	self assertTruncated: 3.7 gives: 3.
	self assertTruncated: -3.7 gives: -3.
	self assertTruncated: 0.5 gives: 0.
	self assertTruncated: 5.0 gives: 5
]

{ #category : 'tests - float conversions' }
InterpreterTest >> testTruncatedAtTheEdgesOfSmallInteger [
	"A SmallInteger holds -16384 to 16383. The largest and smallest floats that still truncate into that range work: 16383.9 gives 16383 and -16384.5 gives -16384."

	self assertTruncated: 16383.9 gives: 16383.
	self assertTruncated: -16384.5 gives: -16384
]

{ #category : 'tests - float conversions' }
InterpreterTest >> testTruncatedOfANonFloatFails [
	"truncated is defined on Floats: a SmallInteger receiver fails the primitive and stays on the stack."

	self
		assertPrimitiveFails: #primitiveTruncated
		with: { (self integer: 3) }
]

{ #category : 'tests - float conversions' }
InterpreterTest >> testTruncatedOutOfSmallIntegerRangeFails [
	"A result that does not fit in a SmallInteger fails the primitive, here 16384.0 and -16385.0 which are just out of range, and 1e10 which is far out: the guest Smalltalk code then builds a LargeInteger. The receiver stays on the stack."

	#( 16384.0 -16385.0 1.0e10 ) do: [ :value |
			| float |
			float := self newFloat: value.
			self assertPrimitiveFails: #primitiveTruncated with: { float } ]
]

{ #category : 'tests - perform and value primitives' }
InterpreterTest >> testValueWithArguments [
	"Primitive 82 (valueWithArguments:) runs a block with its arguments taken from an Array: the Array elements are the first fields after the registers of the block, and the block becomes the active context."

	| block array |
	self
		run: #( 137 119 200 164 2 16 125 )
		literals: #(  )
		receiver: nilPointer.
	3 timesRepeat: [ interpreter cycle ].
	block := interpreter stackTop.
	array := self newArrayOf: 2.
	memory storePointer: 0 ofObject: array withValue: (self integer: 5).
	memory storePointer: 1 ofObject: array withValue: (self integer: 6).

	self runPrimitive: #primitiveValueWithArgs with: {
			block.
			array }.

	self assert: interpreter success.
	self
		assert: (interpreter instVarNamed: 'activeContext')
		equals: block.
	self
		assert: (memory integerValueOf:
				 (memory fetchPointer: self tempFrameStart ofObject: block))
		equals: 5.
	self
		assert: (memory integerValueOf:
				 (memory fetchPointer: self tempFrameStart + 1 ofObject: block))
		equals: 6
]

{ #category : 'tests - perform and value primitives' }
InterpreterTest >> testValueWithArgumentsWithTheWrongNumberFails [
	"A block of two arguments given an Array of three: the primitive fails and the block and the Array stay on the stack."

	| block |
	self
		run: #( 137 119 200 164 2 16 125 )
		literals: #(  )
		receiver: nilPointer.
	3 timesRepeat: [ interpreter cycle ].
	block := interpreter stackTop.

	self assertPrimitiveFails: #primitiveValueWithArgs with: {
			block.
			(self newArrayOf: 3) }
]

{ #category : 'tests - semaphores and processes' }
InterpreterTest >> testWaitWithAnExcessSignalDoesNotBlock [
	"Primitive 86, wait, on a Semaphore that has been signalled uses up one signal and goes on: the count goes down and the active Process keeps running."

	| semaphore |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	semaphore := self newSemaphore.
	memory
		storePointer: 2
		ofObject: semaphore
		withValue: (self integer: 2).

	self runPrimitive: #primitiveWait with: { semaphore }.

	self assert: (self excessSignalsOf: semaphore) equals: 1.
	self deny: (interpreter instVarNamed: 'newProcessWaiting').
	self assert: (interpreter isEmptyList: semaphore)
]

{ #category : 'tests - semaphores and processes' }
InterpreterTest >> testWaitWithNoSignalBlocksTheActiveProcess [
	"With no excess signal, wait puts the active Process in the Semaphore and switches to the highest priority ready Process, here an idle one at priority 1."

	| semaphore idle |
	self setUpSchedulerWithPriorities: 4 activeAt: 3.
	semaphore := self newSemaphore.
	idle := self newProcessAt: 1.
	interpreter sleep: idle.

	self runPrimitive: #primitiveWait with: { semaphore }.

	self assert: (self firstProcessOf: semaphore) equals: activeProcess.
	self assert: (interpreter instVarNamed: 'newProcessWaiting').
	self assert: (interpreter instVarNamed: 'newProcess') equals: idle.
	self assert: (interpreter isEmptyList: (self readyListAt: 1))
]

{ #category : 'tests - scheduling' }
InterpreterTest >> testWakeHighestPriorityTakesTheHighestReadyProcess [
	"wakeHighestPriority looks from the highest priority down for a list that is not empty and removes its first Process: of two ready Processes the one of the higher priority is chosen, and the other stays ready."

	| low high |
	self setUpSchedulerWithPriorities: 4 activeAt: 2.
	low := self newProcessAt: 1.
	high := self newProcessAt: 3.
	interpreter sleep: low.
	interpreter sleep: high.

	self assert: interpreter wakeHighestPriority equals: high.

	self assert: (interpreter isEmptyList: (self readyListAt: 3)).
	self assert: (self listSize: (self readyListAt: 1)) equals: 1
]

{ #category : 'tests - array primitives' }
InterpreterTest >> testWordObjectAtAndAtPut [
	"A word object stores 16 bit values: values above 16383 are LargePositiveIntegers"

	| words |
	words := self newWordsOf: 3.

	self
		assertPrimitive: #primitiveAtPut
		with: {
				words.
				(self integer: 2).
				(self integer: 5) }
		answers: (self integer: 5).

	self assert: (memory fetchWord: 1 ofObject: words) equals: 5.
	self
		assertPrimitive: #primitiveAt
		with: {
				words.
				(self integer: 2) }
		answers: (self integer: 5)
]

{ #category : 'tests - array primitives' }
InterpreterTest >> testWordObjectAtAnswersALargePositiveInteger [
	"A word above 16383 does not fit in a SmallInteger"

	| words answer |
	words := self newWordsOf: 2.
	memory storeWord: 0 ofObject: words withValue: 40000.

	self runPrimitive: #primitiveAt with: {
			words.
			(self integer: 1) }.
	answer := interpreter stackTop.

	self assert: interpreter success.
	self
		assert: (memory fetchClassOf: answer)
		equals:
		(Interpreter classVarNamed: 'ClassLargePositiveIntegerPointer').
	self assert: (interpreter positive16BitValueOf: answer) equals: 40000
]

{ #category : 'tests - array primitives' }
InterpreterTest >> testWordObjectAtPutOfAnObjectFails [

	self assertPrimitiveFails: #primitiveAtPut with: {
			(self newWordsOf: 2).
			(self integer: 1).
			nilPointer }
]

{ #category : 'private' }
InterpreterTest >> truePointer [

	^ Interpreter classVarNamed: 'TruePointer'
]

{ #category : 'private - methods' }
InterpreterTest >> twoClassesUnderstanding: selector [
	"A class and its subclass that both understand selector: answers an association from the method of the superclass to the subclass. The subclass answers 2, the superclass 1."

	| base |
	base := self
		        newClassInheritingFrom: nilPointer
		        methods: { (selector -> (self newMethodReturning: 1)) }.
	^ base -> (self
		   newClassInheritingFrom: base
		   methods: { (selector -> (self newMethodReturning: 2)) })
]

{ #category : 'private - io' }
InterpreterTest >> useClockHAL [
	"The real hardware abstraction layer, hooked to a VM that answers the interpreter of the test, with a millisecond clock that the test sets (at 1000 to start with)"

	| vm hal |
	vm := InterpreterTestVM new.
	vm interpreter: interpreter.
	hal := InterpreterTestClockHAL withVM: vm.
	hal uptime: 1000.
	interpreter instVarNamed: 'hal' put: hal.
	^ hal
]

{ #category : 'private - io' }
InterpreterTest >> useClockHALListening [
	"The real hardware layer with a clock that the test sets (see #useClockHAL), and an input semaphore of the guest to signal: the guest listens to the input events."

	| hal |
	hal := self useClockHAL.
	hal inputSemaphore: self newSemaphore.
	^ hal
]

{ #category : 'private - files' }
InterpreterTest >> useFileSystemOn: aDirectory [
	"Give the interpreter a file system rooted at aDirectory, as the VM does for the images directory. The files opened through it are closed at the end of the test, before the directory is deleted."

	| fileSystem |
	fileSystem := ST80FileSystem withRoot: aDirectory.
	interpreter instVarNamed: 'fileSystem' put: fileSystem.
	self onTearDown: [
			(fileSystem instVarNamed: 'fileHandles') keys copy do: [ :handle |
				fileSystem closeFile: handle ] ].
	^ fileSystem
]

{ #category : 'private - io' }
InterpreterTest >> useHAL [
	"Give the interpreter a stand-in for the host: no window, canned answers, and a log of what the primitives ask for"

	| hal |
	hal := InterpreterTestHAL new.
	interpreter instVarNamed: 'hal' put: hal.
	^ hal
]

{ #category : 'private - files' }
InterpreterTest >> useLogger: aLogger [
	"Replace the global Logger for the length of the test: the VM writes to it, and the tests must not touch the log of a running VM. The previous one is put back at the end."

	| previous |
	previous := Smalltalk globals at: #Logger ifAbsent: [ nil ].
	Smalltalk globals at: #Logger put: aLogger.
	self onTearDown: [
			previous
				ifNil: [ Smalltalk globals removeKey: #Logger ifAbsent: [ nil ] ]
				ifNotNil: [ Smalltalk globals at: #Logger put: previous ] ]
]
