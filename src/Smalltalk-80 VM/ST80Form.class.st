"
This a proxy class to build an object representation of the Form
instances that the BitBlt operations receive as arguments
"
Class {
	#name : #ST80Form,
	#superclass : #Object,
	#instVars : [
		'bits',
		'width',
		'height',
		'oop',
		'memory',
		'offset'
	],
	#classVars : [
		'BitsInForm',
		'HeightInForm',
		'WidthInForm'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #'instance creation' }
ST80Form class >> fromObject: objectPointer memory: memory [
   "the code below follows the Seaside Object initialization conventions"
	^ self basicNew
		initializeFromObject: objectPointer memory: memory;
		yourself
]

{ #category : #'class initialization' }
ST80Form class >> initialize [
	BitsInForm   := 0.
	WidthInForm  := 1.
	HeightInForm := 2.
]

{ #category : #initialization }
ST80Form >> asNativeFormCropped: rectangle [
	"Create a host native form from an area of the ST80 Form (self)
	 limited to the cropping rectangle"
	
	| startIndex nWords nWordsInRectangle nativeForm i j iSaved word16 nativeBits st80Bits |
	nativeForm := Form extent: rectangle extent depth: 1.
	startIndex := (width + 15) // 16 * rectangle origin y + ((rectangle origin x + 15) // 16).
	nWordsInRectangle := (rectangle width + 15) // 16.
	nWords := (self width + 15) // 16.
	nativeBits := nativeForm bits.
	st80Bits := self bits.
	
	i := startIndex.
	j := 0.
	1 to: rectangle height do: [:y |
		iSaved := i.
		1 to: nWordsInRectangle do: [:x16 |
			word16 := st80Bits at: (i := i + 1).
			x16 odd ifTrue: [nativeBits at: (j := j+1) put: (word16 bitShift: 16)]
					  ifFalse: [nativeBits at: j put: ((nativeBits at: j) bitOr: word16)]].
			"Point to beginning of next row of the cropped rectangle"
			i := iSaved + nWords.
				].
	^ nativeForm 
]

{ #category : #accessing }
ST80Form >> bits [

	^ bits
]

{ #category : #accessing }
ST80Form >> bitsArray [
   "TODO: Quick and Dirty to test Display update"
	| wm bitsStartIndex |
	wm := memory wordMemory.
	bitsStartIndex := ((memory segmentBitsOf: bits) * 65536) + (memory locationBitsOf: bits) + 1.
	^ wm copyFrom: bitsStartIndex to: (bitsStartIndex + self bitsSize - 1).
]

{ #category : #accessing }
ST80Form >> bitsSize [

	^ width + 15 // 16 * height
]

{ #category : #accessing }
ST80Form >> height [

	^ height
]

{ #category : #initialization }
ST80Form >> initializeFromObject: objectPointer memory: objectMemory [ 
	"initialize a proxy Form object based on the
	attributes of the Form coming from the ST80 VM"

	"make sure the class variables are declared"
	self class initialize.
	
	oop := objectPointer.
	memory := objectMemory.
	width := memory integerValueOf: (memory fetchWord: WidthInForm ofObject: oop).
	height := memory integerValueOf: (memory fetchWord: HeightInForm ofObject: oop).
	bits := ST80Bitmap fromObject: (memory fetchWord: BitsInForm ofObject: oop) memory: memory.

]

{ #category : #accessing }
ST80Form >> memory [

	^ memory
]

{ #category : #accessing }
ST80Form >> oop [

	^ oop
]

{ #category : #accessing }
ST80Form >> width [

	^ width
]

{ #category : #accessing }
ST80Form >> wordCount [
	"Not BB code"
	^ (width + 15) // 16 * height.
]
