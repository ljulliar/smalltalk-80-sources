Class {
	#name : #ST80CharacterScanner,
	#superclass : #ST80BitBlt,
	#instVars : [
		'lastIndex',
		'text',
		'textPos',
		'xTable',
		'stopX',
		'exceptions',
		'printing',
		'stopConditions'
	],
	#classVars : [
		'CrossedX',
		'EndOfRun',
		'FontIndex',
		'LastIndexIndex',
		'LeftMarginIndex',
		'LineIndex',
		'OutputMediumIndex',
		'RightMarginIndex',
		'RunStopIndexIndex',
		'SpaceCountIndex',
		'SpaceWidthIndex',
		'StopConditionsIndex',
		'TextIndex',
		'TextStyleIndex',
		'XTableIndexIndex'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #'class initialization' }
ST80CharacterScanner class >> initialize [
	"Initialize constants needed by Character Scanner"
	LastIndexIndex := 14.
	XTableIndexIndex := 15.
	StopConditionsIndex := 16.
	TextIndex := 17.
	TextStyleIndex := 18.
	LeftMarginIndex := 19.
	RightMarginIndex := 20.
	FontIndex := 21.
	LineIndex := 22.
	RunStopIndexIndex := 23.
	SpaceCountIndex := 24.
	SpaceWidthIndex := 25.
	OutputMediumIndex := 26.
	
	"TextConstants from ST80 source code"
	"TextConstants at: #EndOfRun put: 257."
	"TextConstants at: #CrossedX put: 258." 
	EndOfRun := 257.
   CrossedX := 258.
]

{ #category : #'as yet unclassified' }
ST80CharacterScanner class >> scannerPointer: scannerPointer memory: memory [
  	^ self basicNew
		  initializeWithBitBltPointer: scannerPointer memory: memory;
		  yourself
]

{ #category : #initialization }
ST80CharacterScanner >> initializeWithScannerPointer: sp memory: m [

	"Make sure class variables ar initialized"
	self class initialize.

	"Initialize parent BitBlt object"
	self initializeWithBitBltPointer: sp memory: m.
   xTable := self memory fetchPointer: XTableIndexIndex ofObject: sp.
	lastIndex := self memory fetchPointer: XTableIndexIndex ofObject: sp.
	stopConditions := self memory fetchPointer: StopConditionsIndex ofObject: sp
]

{ #category : #'as yet unclassified' }
ST80CharacterScanner >> scanCharactersFrom: startIndex to: stopIndex in: sourceString rightX: rightX stopConditions: stops displaying: display [
	"This code from dbanay implementation. I wasn't able to find it in
	the 1983 bluebook Edition"

    | ascii nextDestX |
     lastIndex := startIndex.
     [lastIndex <= stopIndex]
         whileTrue:
             [ascii := (sourceString at: lastIndex) asciiValue.
             (stopConditions at: ascii + 1) ~~ nil ifTrue: [^stops at: ascii + 1].
             sourceX := xTable at: ascii + 1.
             nextDestX := destX + (width := (xTable at: ascii + 2) - sourceX).
             nextDestX > rightX ifTrue: [^stops at: CrossedX].
             display ifTrue: [self copyBits].
             destX := nextDestX.
             lastIndex := lastIndex + 1].
     lastIndex := stopIndex.
     ^stops at: EndOfRun
]
