"
This class serves as a proxy to create an object representation of the
Bitblt instances coming from the ST80 Virtual Machine
"
Class {
	#name : #ST80BitBlt,
	#superclass : #ST80Object,
	#instVars : [
		'destForm',
		'sourceForm',
		'halftoneForm',
		'combinationRule',
		'destX',
		'destY',
		'width',
		'height',
		'sourceX',
		'sourceY',
		'clipX',
		'clipY',
		'clipWidth',
		'clipHeight',
		'sourceBits',
		'sourceRaster',
		'destBits',
		'destRaster',
		'halftoneBits',
		'skew',
		'skewMask',
		'mask1',
		'mask2',
		'preload',
		'nWords',
		'hDir',
		'vDir',
		'sourceIndex',
		'sourceDelta',
		'destIndex',
		'destDelta',
		'sx',
		'sy',
		'dx',
		'dy',
		'w',
		'h',
		'updatedRect'
	],
	#classVars : [
		'AllOnes',
		'ClipHeightIndex',
		'ClipWidthIndex',
		'ClipXIndex',
		'ClipYIndex',
		'CombinationRuleIndex',
		'DestFormIndex',
		'DestXIndex',
		'DestYIndex',
		'HalftoneFormIndex',
		'HeightIndex',
		'RightMasks',
		'SourceFormIndex',
		'SourceXIndex',
		'SourceYIndex',
		'WidthIndex'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #'as yet unclassified' }
ST80BitBlt class >> bitBltPointer: bitBltPointer memory: memory [
  	^ self basicNew
		  initializeWithBitBltPointer: bitBltPointer memory: memory;
		  yourself
]

{ #category : #'class initialization' }
ST80BitBlt class >> initialize [

	"BitBltSimulation: initialize a table of bit masks BB 356"	
	RightMasks := #(0 16r1 16r3 16r7 16rF
	                16r1F 16r3F 16r7F 16rFF
	                16r1FF 16r3FF 16r7FF 16rFFF
	                16r1FFF 16r3FFF 16r7FFF 16rFFFF).
	AllOnes := 16rFFFF.
	
	"Not BB code"
   "ST80 Object indices to access ST80 Bitblt attributes"
	DestFormIndex := 0.
	SourceFormIndex := 1.
	HalftoneFormIndex := 2.
	CombinationRuleIndex := 3.
	DestXIndex := 4.
	DestYIndex := 5.
	WidthIndex := 6.
	HeightIndex := 7.
	SourceXIndex := 8.
	SourceYIndex := 9.
	ClipXIndex := 10.
	ClipYIndex := 11.
	ClipWidthIndex := 12.
	ClipHeightIndex := 13.
]

{ #category : #private }
ST80BitBlt >> calculateOffsets [
	"BitBltSimulation code BB 359"
	"check if need to preload buffer
	(i.e., two words of source needed for first word of destination)"
	
	preload := (sourceForm notNil) and:
			[skew ~= 0 and: [skew <= (sx bitAnd: 15)]].
	hDir < 0 ifTrue: [preload := preload == false].
	
	"calculate starting offsets"
	sourceIndex := sy * sourceRaster + (sx // 16).
	destIndex := dy * destRaster + (dx // 16).
	
	"calculate increments from end of 1 line to start of next"
	sourceDelta :=
		(sourceRaster * vDir) -
		(nWords + (preload ifTrue: [1] ifFalse: [0]) * hDir).
	destDelta := (destRaster * vDir) - (nWords * hDir).
	memory debug ifTrue: [  
		Logger << '-- calculateOffsets'; cr.
	   Logger << ' sourceIndex: ' << sourceIndex printString
			<< ' destIndex: ' << destIndex printString; cr.
		Logger << ' sourceDelta ' << sourceDelta printString
			<< ' destDelta: ' << destDelta printString; cr.
		Logger << ' preload: ' << sourceIndex printString; cr.
		]	
]

{ #category : #private }
ST80BitBlt >> checkOverlap [
	"BitBltSimulation code BB 358"
	| t |
	"check for possible overlap of source and destination"
	hDir := vDir := 1. "defaults for no overlap"
	(sourceForm == destForm and: [dy >= sy])
		ifTrue: [dy > sy "have to start at bottom"
				ifTrue: [vDir := -1.
					sy := sy + h - 1.
					dy := dy + h - 1]
				ifFalse: [dx > sx "y's are equal, but x's are backward"
						ifTrue: [hDir := -1.
							sx := sx + w - 1.
							"start at right"
							dx := dx + w - 1.
							"and fix up masks"
							skewMask := skewMask bitInvert.
							t := mask1.
							mask1 := mask2.
						mask2 := t]]].
			
	memory debug ifTrue: [ 
		Logger << '-- checkOverlap'; cr.
	   Logger << ' hDir: ' << hDir printString
			<< ' vDir: ' << vDir printString; cr.
		Logger << ' w:  ' << w printString
			<< ' h: ' << h printString
			<< ' sx:  ' << sx printString
			<< ' dx: ' << dx printString
			<< ' sy: ' << sy printString
			<< ' dy: ' << dy printString; cr.
		Logger << ' skewMask: ' << skewMask printString
			<< ' mask1: ' << mask1 printString
			<< ' mask2: ' << mask2 printString; cr.
		]
]

{ #category : #private }
ST80BitBlt >> clipRange [
	"BitBltSimulation code BB 356"
	"clip and adjust source origin and extent appropriately"

	"first in x"	
   destX >= clipX
      ifTrue: [ sx := sourceX. dx := destX. w := width ]
      ifFalse: [ sx := sourceX + (clipX - destX).
	              w := width - (clipX - destX).
	              dx := clipX ].
   (dx + w) > (clipX + clipWidth)
      ifTrue: [ w := w -((dx +w) - (clipX + clipWidth)) ].

   "then in y"
   destY >= clipY
      ifTrue: [ sy := sourceY. dy := destY. h := height ]
      ifFalse: [ sy := sourceY + clipY - destY.
	              h := height -clipY + destY.
	              dy := clipY ].
   (dy + h) > (clipY + clipHeight)
      ifTrue: [ h := h - ((dy + h) - (clipY + clipHeight)) ].

   "ERROR skip code below if sourceForm is nil. (also in dbanay)"
	sourceForm ifNil: [ ^ false ].
   sx < 0
      ifTrue: [ dx := dx - sx. w := w + sx. sx := 0 ].
   sx + w > sourceForm width 
      ifTrue: [ w := w - (sx + w - sourceForm width) ].
   sy < 0
      ifTrue: [ dy := dy - sy. h := h + sy. sy := 0 ].
   sy + h > sourceForm height  
      ifTrue: [ h := h - (sy + h - sourceForm height) ].
	^ true "Not BB code. This is to behave like modern Pharo clipRange"

]

{ #category : #accessing }
ST80BitBlt >> combinationRule [

	^ combinationRule
]

{ #category : #private }
ST80BitBlt >> computeMasks [
	"BitBltSimulation code BB 357"
	"calculate skew and edge masks"	
			
	| startBits endBits |
	destBits := destForm bits.
	destRaster := destForm width - 1 // 16 + 1.
	sourceForm
	   ifNotNil: [ sourceBits := sourceForm bits.
		          sourceRaster := sourceForm width - 1 // 16 + 1 ].
	halftoneForm
	   ifNotNil: [ halftoneBits := halftoneForm bits ].
	skew := (sx - dx) bitAnd: 15.
	"how many bits source get skewed to right"
	startBits := 16 - (dx bitAnd: 15).
	"how many bits in first word"
	mask1 := RightMasks at: startBits + 1.
	endBits := 15 - ((dx + w - 1) bitAnd: 15).
	"how many bits in last word"
	"ljulliard: & 16rFFFF added to keep a 16 bit value"
	mask2 := (RightMasks at: endBits + 1) bitInvert bitAnd: 16rFFFF.
	skewMask := ( skew = 0
	                ifTrue: [0]
	                ifFalse: [RightMasks at: 16 - skew + 1]).
	"determine number of words stored per line; merge masks if necessary"
	w < startBits
	   ifTrue: [ mask1 := mask1 bitAnd: mask2.
		          mask2 := 0.
		          nWords := 1 ]
      "ERROR from dbanay says that the formula should use + 1
      instead of + 2 but dbanay doesn't use the formula given
      in the BB p. 358.
      For values of startBits between 0 and 16, I checked that both
      formulas give the same results. So the + 2 in the BB is correct.
       dbanay : (w - startBits + 15) // 16 + 1
	    BB: (w - startBits - 1) // 16 + 2"
	   ifFalse: [ nWords := (w - startBits - 1) // 16 + 2 ].

	memory debug ifTrue: [ 
		Logger << '-- computeMasks'; cr.
		Logger << ' skewMask: ' << skewMask printString
			<< ' mask1: ' << mask1 printString
			<< ' mask2: ' << mask2 printString	
			<< ' nWords ' << nWords printString; cr.	
		]
]

{ #category : #operations }
ST80BitBlt >> copyBits [
	"BitBltSimulation code BB 356"
	"The bits copy operation"

	memory debug ifTrue: [ 
		Logger << 'copyBits sourceForm: ' << (sourceForm ifNotNil: [ sourceForm oop ]) printString
			<< ' destForm: ' << destForm oop  printString
			<< ' halftoneForm: ' << halftoneForm oop  printString; cr.
		Logger << ' destX: ' << destX printString
			<< ' destY: ' << destY printString; cr.
		Logger << ' clipX: ' << clipX printString 			
			<< ' clipY: ' << clipY printString
			<< ' clipWidth: ' << clipWidth printString			
			<< ' clipHeight: ' << clipHeight printString; cr.
		Logger << ' sourceX: ' << sourceX printString
			<< ' sourceY: ' << sourceY printString
			<< ' width: ' << width printString
			<< ' height: ' << height printString; cr.
	   Logger << ' combinationRule: ' << combinationRule printString; cr.
	].
	"sets w and h"	
	self clipRange.
	
	"Not BB code. Keep track of the rectangle updated on the destForm
	 as we will need it in primitiveCopyBits to update the host display"
	(w <= 0 or: [h <= 0]) 
		ifTrue: [ "null range"
			updatedRect := Rectangle origin: 0@0 extent: 0@0.
		 	^ self ]
		ifFalse: [ 
			updatedRect := Rectangle origin: dx@dy extent: w@h ].
		
	Logger << 'Updated rectangle: ' << updatedRect origin printString
		<< ' ' << updatedRect corner printString; cr.
	
	
	"Not BB code
	Some sanity check before doing the actual copy. Make sure 
	source and dest	form objects do exist and have the proper number
	of bits to copy"
	(sourceForm notNil and: [ sourceForm wordCount ~= sourceForm bitsSize ]) ifTrue: [ ^ false ].
	(destForm notNil and: [ destForm wordCount ~= destForm bitsSize ]) ifTrue: [ ^ false ].
	
	self computeMasks.
	self checkOverlap.
	self calculateOffsets.
	self copyLoop
	
]

{ #category : #'inner loop' }
ST80BitBlt >> copyLoop [
	"BitBltSimulation code BB 359"
	"With some optimization from ljulliard"

	| prevWord thisWord skewWord mergeMask halftoneWord mergeWord destWord |
	1 to: h do: "here is the vertical loop"
		[ :i |
			(halftoneForm notNil)
				ifTrue: [halftoneWord := halftoneBits at: (1 + (dy bitAnd: 15)).
					"Transcript show: 'vloop '; nextPutAll: halftoneBits oop printString;
					 nextPutAll: ' htword '; nextPutAll: (dy bitAnd: 15) printString;
					 nextPutAll: ' = '; nextPutAll: halftoneWord printString; cr."
					dy := dy + vDir]
				ifFalse: [halftoneWord := AllOnes].
			skewWord := halftoneWord.
			preload
				ifTrue: [
					"load the 32-bit shifter"
					prevWord := sourceBits at: sourceIndex + 1.
					"Transcript show: 'vloop '; nextPutAll: sourceBits oop printString;
					 nextPutAll: ' preword '; nextPutAll: sourceIndex printString;
					 nextPutAll: ' = '; nextPutAll: prevWord printString; cr."
					sourceIndex := sourceIndex + hDir]
				ifFalse: [prevWord := 0].
			mergeMask := mask1.
			"ERROR: extra to on next line in BB 360"
			1 to: nWords do: "here is the inner horizontal loop"
				[ :word |
					sourceForm notNil "if source used"
						ifTrue: [
							prevWord := prevWord bitAnd: skewMask.
							"ERROR: from dbanay need to check if out of range. use 0 if that is the case"
							word <= sourceRaster & (sourceIndex >= 0) & (sourceIndex < (sourceBits size)) 
								ifTrue: [ thisWord := sourceBits at: sourceIndex + 1 ]
								ifFalse: [ thisWord := 0 ].
							"pick up next word"
							skewWord :=	prevWord bitOr: (thisWord bitAnd:	skewMask bitInvert & 16rFFFF).
							prevWord := thisWord.
							skewWord := (skewWord bitShift: skew) bitOr: (skewWord bitShift: skew - 16).
							"Transcript show: 'ihloop '; nextPutAll: sourceBits oop printString;
					 			nextPutAll: ' thisword '; nextPutAll: sourceIndex printString;
					 			nextPutAll: ' = '; nextPutAll: thisWord printString; cr."
							].
							
					"BB ERROR Added from dbanay"
					destIndex >= (destBits size) ifTrue: [ ^ self].
					
					"16-bit rotate"
					destWord := destBits at: destIndex + 1. "ljulliard optimization"
					"Transcript show: 'ihloop '; nextPutAll: destBits oop printString;
						nextPutAll: ' destword '; nextPutAll: destIndex printString;
						nextPutAll: ' = '; nextPutAll: destWord printString; cr."
					mergeWord := self merge: (skewWord bitAnd: halftoneWord)
							with: destWord. "ljulliard optimization"				
					destBits
						at: destIndex + 1
						put: ((mergeMask bitAnd: mergeWord)
							bitOr: (mergeMask bitInvert & 16rFFFF
								bitAnd: destWord)). "ljulliard optimization"
					"Transcript show: 'ihloop '; nextPutAll: destBits oop printString;
					 nextPutAll: ' destword '; nextPutAll: destIndex printString;
					 nextPutAll: ' <- '; nextPutAll: ((mergeMask bitAnd: mergeWord) bitOr: (mergeMask bitInvert & 16rFFFF	bitAnd: destWord)) printString; cr."
					sourceIndex := sourceIndex + hDir.
					destIndex := destIndex + hDir.
					word = (nWords - 1)
						ifTrue: [mergeMask := mask2]
						ifFalse: [mergeMask := AllOnes]].
			sourceIndex := sourceIndex + sourceDelta.
			destIndex := destIndex + destDelta]
]

{ #category : #accessing }
ST80BitBlt >> destForm [

	^ destForm
]

{ #category : #initialization }
ST80BitBlt >> initializeWithBitBltPointer: bbp memory: m [

	| sourceFormOop |

	"Make sure class variables ar initialized"
	self class initialize.

	memory := m.
   destForm := ST80Form fromObject: (m fetchPointer: DestFormIndex ofObject: bbp) memory: m.
	sourceFormOop := m fetchPointer: SourceFormIndex ofObject: bbp.
	(m isObjectNil: sourceFormOop) ifFalse: [ 
   		sourceForm := ST80Form fromObject: sourceFormOop memory: m ].
   halftoneForm := ST80Form fromObject: (m fetchPointer: HalftoneFormIndex ofObject: bbp) memory: m.
   destX := m integerValueOf: (m fetchWord: DestXIndex ofObject: bbp).
   destY := m integerValueOf: (m fetchWord: DestYIndex ofObject: bbp).
   clipX := m integerValueOf: (m fetchWord: ClipXIndex ofObject: bbp).
   clipY := m integerValueOf: (m fetchWord: ClipYIndex ofObject: bbp).
   clipWidth := m integerValueOf: (m fetchWord: ClipWidthIndex ofObject: bbp).
   clipHeight := m integerValueOf: (m fetchWord: ClipHeightIndex ofObject: bbp).
   sourceX := m integerValueOf: (m fetchWord: SourceXIndex ofObject: bbp).
   sourceY := m integerValueOf: (m fetchWord: SourceYIndex ofObject: bbp).
   width := m integerValueOf: (m fetchWord: WidthIndex ofObject: bbp).
   height := m integerValueOf: (m fetchWord: HeightIndex ofObject: bbp).
   combinationRule := m integerValueOf: (m fetchWord: CombinationRuleIndex ofObject: bbp).

	"copyBits and the methods it calls expect some integer instance 
	variables to be initialized to 0 or it crashes"
	sourceRaster := 0.
	

]

{ #category : #accessing }
ST80BitBlt >> memory [

	^ memory
]

{ #category : #'inner loop' }
ST80BitBlt >> merge: sourceWord with: destinationWord [
	"These are the 16 combination rules:"
	combinationRule = 0
		ifTrue: [^0].
	combinationRule = 1
		ifTrue: [^sourceWord bitAnd: destinationWord].
	combinationRule = 2
		ifTrue: [^sourceWord bitAnd: destinationWord bitInvert].
	combinationRule = 3
		ifTrue: [^sourceWord].
	combinationRule = 4
		ifTrue: [^sourceWord bitInvert bitAnd: destinationWord].
	combinationRule = 5
		ifTrue: [^destinationWord].
	combinationRule = 6
		ifTrue: [^sourceWord bitXor: destinationWord].
	combinationRule = 7
		ifTrue: [^sourceWord bitOr: destinationWord].
	combinationRule = 8
		ifTrue: [^sourceWord bitInvert bitAnd: destinationWord bitInvert].
	combinationRule = 9
		ifTrue: [^sourceWord bitInvert bitXor: destinationWord].
	combinationRule = 10
		ifTrue: [^destinationWord bitInvert].
	combinationRule = 11
		ifTrue: [^sourceWord bitOr: destinationWord bitInvert].
	combinationRule = 12
		ifTrue: [^sourceWord bitInvert].
	combinationRule = 13
		ifTrue: [^sourceWord bitInvert bitOr: destinationWord].
	combinationRule = 14
		ifTrue: [^sourceWord bitInvert bitOr: destinationWord bitInvert].
	combinationRule = 15
		ifTrue: [^AllOnes]

]

{ #category : #accessing }
ST80BitBlt >> updatedRect [

	^ updatedRect
]
