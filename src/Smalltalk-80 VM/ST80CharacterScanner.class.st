"
Native implementation of the ST80 primitive 103 (CharacterScanner scanCharactersFrom:to:in:rightX:stopConditions:displaying:).

A proxy for the ST80 CharacterScanner object (a BitBlt subclass in the guest image). It is built once for a whole scan, not once per character, which is where the speed comes from: the guest loop is replaced by a native one and the host display is refreshed once at the end.

The scan mirrors the Smalltalk fallback method of the same name: stop at the first character that has a stop condition, stop when the next glyph would cross rightX, otherwise draw it and go on. After the scan, storeResultsIn: writes back the fields that the fallback would have changed (destX, width, sourceX and lastIndex).

Instance Variables
	lastIndex:	index (1-based, as in the guest) of the last character scanned
	xTable:	oop of the Array of glyph left x coordinates
	stopConditions:	oop of the Array of stop conditions, indexed by character code
	displaying:	true when the glyphs must be drawn
	scannedRect:	union of the rectangles drawn during the scan, or nil
"
Class {
	#name : 'ST80CharacterScanner',
	#superclass : 'ST80BitBlt',
	#instVars : [
		'lastIndex',
		'xTable',
		'stopConditions',
		'displaying',
		'scannedRect'
	],
	#classVars : [
		'CrossedX',
		'EndOfRun',
		'LastIndexIndex',
		'StopConditionsIndex',
		'UseNativeScan',
		'XTableIndexIndex'
	],
	#category : 'Smalltalk-80 VM',
	#package : 'Smalltalk-80 VM'
}

{ #category : 'class initialization' }
ST80CharacterScanner class >> initialize [
	"Indices of the fields that a CharacterScanner adds to the BitBlt ones, and the
	TextConstants shared with the guest image."

	LastIndexIndex := 14.
	XTableIndexIndex := 15.
	StopConditionsIndex := 16.

	"TextConstants at: #EndOfRun put: 257.
	 TextConstants at: #CrossedX put: 258."
	EndOfRun := 257.
	CrossedX := 258.

	"Not BB code. Only initialized when nil so that re-initializing the class does
	not undo a choice made by the developer (see useNativeScan:)"
	UseNativeScan ifNil: [ UseNativeScan := true ]
]

{ #category : 'instance creation' }
ST80CharacterScanner class >> isScanner: aPointer in: aMemory [
	"Answer whether aPointer is a pointer object big enough to have all the fields of a
	CharacterScanner that a scan reads."

	(aMemory isIntegerObject: aPointer) ifTrue: [ ^ false ].
	(aMemory pointerBitOf: aPointer) = 1 ifFalse: [ ^ false ].
	^ (aMemory fetchWordLengthOf: aPointer) > StopConditionsIndex
]

{ #category : 'instance creation' }
ST80CharacterScanner class >> scannerPointer: scannerPointer memory: aMemory displaying: aBoolean [
	"Answer a proxy for the guest CharacterScanner at scannerPointer, or nil when it can
	not be scanned natively (not a scanner, or a field holds something unexpected). aBoolean
	tells whether the characters are going to be drawn: the BitBlt fields of the guest
	scanner are only read in that case."

	| scanner |
	(self isScanner: scannerPointer in: aMemory) ifFalse: [ ^ nil ].
	scanner := (self fromObject: scannerPointer memory: aMemory)
		           initializeDisplaying: aBoolean;
		           yourself.
	^ scanner isReadyToScan ifTrue: [ scanner ]
]

{ #category : 'accessing' }
ST80CharacterScanner class >> useNativeScan [
	"Answer whether primitive 103 scans characters natively. When false the primitive
	always fails and the guest runs its own Smalltalk loop, which is useful to compare
	the two or to debug a text display problem."

	^ UseNativeScan
]

{ #category : 'accessing' }
ST80CharacterScanner class >> useNativeScan: aBoolean [
	"Switch the native scan of characters on or off. Takes effect immediately.
	Example: ST80CharacterScanner useNativeScan: false"

	UseNativeScan := aBoolean
]

{ #category : 'testing' }
ST80CharacterScanner >> canScanFrom: startIndex to: stopIndex in: aString stops: stops [
	"Answer whether scanning these arguments can run to its end without any failure. A scan
	draws as it goes, so every check is done before the first glyph is drawn. When this
	answers false the guest runs its own Smalltalk loop, which reports the error if there is one."

	(self isByteObject: aString holding: stopIndex) ifFalse: [ ^ false ].
	startIndex >= 1 ifFalse: [ ^ false ].
	(self isArray: stops holdingAtLeast: CrossedX) ifFalse: [ ^ false ].
	^ self hasGlyphDataFrom: startIndex to: stopIndex in: aString
]

{ #category : 'scanning' }
ST80CharacterScanner >> drawGlyph [
	"Copy the current glyph to the destination form, and add the rectangle it covers to
	the one that the whole scan has changed."

	self copyBits.
	updatedRect ifNotNil: [ self extendScannedRect ]
]

{ #category : 'scanning' }
ST80CharacterScanner >> extendScannedRect [
	"copyBits sets updatedRect to the rectangle it has changed, empty when it clipped everything"

	updatedRect hasPositiveExtent ifFalse: [ ^ self ].
	scannedRect := scannedRect
		               ifNil: [ updatedRect ]
		               ifNotNil: [ scannedRect merge: updatedRect ]
]

{ #category : 'initialization' }
ST80CharacterScanner >> formAt: fieldIndex [
	"A proxy for the Form in a field of the guest scanner, or nil when the field is nil"

	| formPointer |
	formPointer := memory fetchPointer: fieldIndex ofObject: oop.
	^ (memory isObjectNil: formPointer) ifFalse: [
		  ST80Form fromObject: formPointer memory: memory ]
]

{ #category : 'testing' }
ST80CharacterScanner >> hasBitBltFields [
	"The fields needed to draw the glyphs: both forms, a clipping rectangle, a height, a
	source y and a combination rule that the BitBlt knows."

	(destForm isNotNil and: [ sourceForm isNotNil ]) ifFalse: [ ^ false ].
	^ ({
		   destY.
		   height.
		   sourceY.
		   clipX.
		   clipY.
		   clipWidth.
		   clipHeight.
		   combinationRule } allSatisfy: [ :each | each isNotNil ]) and: [
		  combinationRule between: 0 and: 15 ]
]

{ #category : 'testing' }
ST80CharacterScanner >> hasGlyphDataFrom: startIndex to: stopIndex in: aString [
	"Answer whether the stop conditions and the glyph positions that the scan reads, those of
	the characters from startIndex to stopIndex, exist in the guest arrays and are usable:
	stopConditions is indexed by character code and xTable has one more entry than the
	glyphs, to give the right edge of the last one."

	| stopConditionCount xTableCount |
	stopConditionCount := self sizeOfArray: stopConditions.
	xTableCount := self sizeOfArray: xTable.
	^ (startIndex to: stopIndex) allSatisfy: [ :index |
			  | code |
			  code := memory fetchByte: index - 1 ofObject: aString.
			  code < stopConditionCount and: [
					  code + 1 < xTableCount and: [
							  (self isIntegerAt: code inArray: xTable) and: [
								  self isIntegerAt: code + 1 inArray: xTable ] ] ] ]
]

{ #category : 'scanning' }
ST80CharacterScanner >> hasStopConditionAt: code [
	"Answer whether the character code has a stop condition (a non nil entry in the guest
	stopConditions array, indexed from 0 here)"

	^ (memory isObjectNil:
		   (memory fetchPointer: code ofObject: stopConditions)) not
]

{ #category : 'initialization' }
ST80CharacterScanner >> initializeBitBltFields [
	"The BitBlt part of the guest scanner, as ST80BitBlt does for a plain BitBlt. sourceX
	and width are not read: they are set for each glyph while scanning."

	destForm := self formAt: DestFormIndex.
	sourceForm := self formAt: SourceFormIndex.
	halftoneForm := self formAt: HalftoneFormIndex.
	destY := self integerAt: DestYIndex.
	height := self integerAt: HeightIndex.
	sourceY := self integerAt: SourceYIndex.
	clipX := self integerAt: ClipXIndex.
	clipY := self integerAt: ClipYIndex.
	clipWidth := self integerAt: ClipWidthIndex.
	clipHeight := self integerAt: ClipHeightIndex.
	combinationRule := self integerAt: CombinationRuleIndex.

	"copyBits expects this one to be an integer"
	sourceRaster := 0
]

{ #category : 'initialization' }
ST80CharacterScanner >> initializeDisplaying: aBoolean [
	"Read from the guest scanner what a scan needs. The BitBlt fields (forms, clipping
	rectangle, rule...) are only meaningful, and only fetched, when the characters are drawn."

	displaying := aBoolean.
	scannedRect := nil.
	destX := self integerAt: DestXIndex.
	lastIndex := self integerAt: LastIndexIndex.
	xTable := memory fetchPointer: XTableIndexIndex ofObject: oop.
	stopConditions := memory
		                  fetchPointer: StopConditionsIndex
		                  ofObject: oop.
	displaying ifTrue: [ self initializeBitBltFields ]
]

{ #category : 'initialization' }
ST80CharacterScanner >> integerAt: fieldIndex [
	"The SmallInteger value of a field of the guest scanner, or nil when the field holds
	anything else (a scan must not start from a field it can not interpret)"

	| pointer |
	pointer := memory fetchPointer: fieldIndex ofObject: oop.
	^ (memory isIntegerObject: pointer) ifTrue: [
		  memory integerValueOf: pointer ]
]

{ #category : 'testing' }
ST80CharacterScanner >> isArray: aPointer holdingAtLeast: minimumSize [
	"A pointer object (an Array) with at least minimumSize elements"

	^ (self sizeOfArray: aPointer) >= minimumSize
]

{ #category : 'testing' }
ST80CharacterScanner >> isByteObject: aPointer holding: byteCount [
	"A string like object (not a pointer object) of at least byteCount bytes"

	^ (memory isIntegerObject: aPointer) not and: [
			  (memory pointerBitOf: aPointer) = 0 and: [
				  (memory fetchByteLengthOf: aPointer) >= byteCount ] ]
]

{ #category : 'testing' }
ST80CharacterScanner >> isIntegerAt: index inArray: anArrayPointer [
	"Answer whether the element at index (0-based) of a guest Array is a SmallInteger"

	^ memory isIntegerObject:
		  (memory fetchPointer: index ofObject: anArrayPointer)
]

{ #category : 'testing' }
ST80CharacterScanner >> isReadyToScan [
	"Answer whether every guest field that this scan relies on has a usable value, so that
	the scan can run to its end without failing half way."

	(destX isNotNil and: [ lastIndex isNotNil ]) ifFalse: [ ^ false ].
	^ displaying not or: [ self hasBitBltFields ]
]

{ #category : 'scanning' }
ST80CharacterScanner >> measureGlyph: code [
	"Set sourceX and width to the position and width in the font bitmap of the glyph of the
	character code: xTable holds the left x of every glyph, and the one of the next glyph
	is the right x of this one."

	sourceX := self xTableValueAt: code.
	width := (self xTableValueAt: code + 1) - sourceX
]

{ #category : 'scanning' }
ST80CharacterScanner >> scanFrom: startIndex to: stopIndex in: aString rightX: rightX stops: stops [
	"Scan the characters of the guest string aString from startIndex to stopIndex (1-based).
	Answer the pointer found in stops for the reason why the scan ended, as the guest method
	does:
	 - a character that has a stop condition: the entry of stops for this character
	 - the next glyph would end beyond rightX: the entry CrossedX of stops
	 - stopIndex reached: the entry EndOfRun of stops
	The glyphs are drawn when displaying. Call storeResultsIn: afterwards."

	startIndex to: stopIndex do: [ :index |
			| code |
			lastIndex := index.
			code := memory fetchByte: index - 1 ofObject: aString.
			(self hasStopConditionAt: code) ifTrue: [
				^ self stopEntryAt: code + 1 in: stops ].
			self measureGlyph: code.
			destX + width > rightX ifTrue: [
				^ self stopEntryAt: CrossedX in: stops ].
			displaying ifTrue: [ self drawGlyph ].
			destX := destX + width ].
	lastIndex := stopIndex.
	^ self stopEntryAt: EndOfRun in: stops
]

{ #category : 'scanning' }
ST80CharacterScanner >> scannedRect [
	"The rectangle changed in the destination form by the scan, nil if nothing was drawn"

	^ scannedRect
]

{ #category : 'testing' }
ST80CharacterScanner >> sizeOfArray: anArrayPointer [
	"The number of elements of a guest Array, 0 when it is not a pointer object"

	^ ((memory isIntegerObject: anArrayPointer) or: [
		   (memory pointerBitOf: anArrayPointer) = 0 ])
		  ifTrue: [ 0 ]
		  ifFalse: [ memory fetchWordLengthOf: anArrayPointer ]
]

{ #category : 'scanning' }
ST80CharacterScanner >> stopEntryAt: index in: stops [
	"The entry of the guest array stops at index (1-based, as in the guest)"

	^ memory fetchPointer: index - 1 ofObject: stops
]

{ #category : 'scanning' }
ST80CharacterScanner >> storeInteger: anInteger at: fieldIndex [
	"Store anInteger as a SmallInteger in a field of the guest scanner"

	memory
		storePointer: fieldIndex
		ofObject: oop
		withValue: (memory integerObjectOf: anInteger)
]

{ #category : 'scanning' }
ST80CharacterScanner >> storeResults [
	"Write back to the guest scanner the fields that the scan changed, as the Smalltalk
	method would have: destX and lastIndex always, sourceX and width only when at least
	one glyph has been measured."

	self storeInteger: destX at: DestXIndex.
	self storeInteger: lastIndex at: LastIndexIndex.
	sourceX ifNotNil: [ self storeInteger: sourceX at: SourceXIndex ].
	width ifNotNil: [ self storeInteger: width at: WidthIndex ]
]

{ #category : 'scanning' }
ST80CharacterScanner >> xTableValueAt: index [
	"The SmallInteger value of the entry of the guest xTable at index (0-based)"

	^ memory integerValueOf:
		  (memory fetchPointer: index ofObject: xTable)
]
