"
This is the Smalltalk implementation of BitBlt as documented at the end
of Chapter 18 in the Blue Book (BB 355).


"
Class {
	#name : #BitBltSimulation,
	#superclass : #BitBlt,
	#instVars : [
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
		'h'
	],
	#classVars : [
		'AllOnes',
		'RightMasks'
	],
	#category : #'Smalltalk-80 VM'
}

{ #category : #'class initialization' }
BitBltSimulation class >> initialize [
	"initialize a table of bit masks BB 356"	
			
	RightMasks := #(0 16r1 16r3 16r7 16rF
	                16r1F 16r3F 16r7F 16rFF
	                16r1FF 16r3FF 16r7FF 16rFFF
	                16r1FFF 16r3FFF 16r7FFF 16rFFFF).
	AllOnes := 16rFFFF
]

{ #category : #private }
BitBltSimulation >> calculateOffsets [
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
	destDelta := (destRaster * vDir) - (nWords * hDir)
]

{ #category : #private }
BitBltSimulation >> checkOverlap [
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
						mask2 := t]]]
]

{ #category : #private }
BitBltSimulation >> clipRange [
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
   sx < 0
      ifTrue: [ dx := dx - sx. w := w + sx. sx := 0 ].
   sx + w > sourceForm width 
      ifTrue: [ w := w - (sx + w - sourceForm width) ].
   sy < 0
      ifTrue: [ dy := dy - sy. h := h + sy. sy := 0 ].
   sy + h > sourceForm height  
      ifTrue: [ h := h - (sy + h - sourceForm height) ]

]

{ #category : #private }
BitBltSimulation >> computeMasks [
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
	mask2 := (RightMasks at: endBits + 1) bitInvert.
	skewMask := ( skew = 0
	                ifTrue: [0]
	                ifFalse: [RightMasks at: 16 - skew + 1])
	"determine number of words stored per line; merge masks if necessary"
	w < startBits
	   ifTrue: [ mask1 := mask1 bitAnd: mask2.
		          mask2 := 0.
		          nWords := 1 ]
	   ifFalse: [ nWords := (w - startBits - 1) // 16 + 2 ]
	
]

{ #category : #operations }
BitBltSimulation >> copyBits [
   "from BB 356"
	"sets w and h"	
			
	self clipRange.
	(w <= 0 or: [h <= 0]) ifTrue: [ ^ self ]. "null range"
	self computeMasks.
	self checkOverlap.
	self calculateOffsets.
	self copyLoop
	
]

{ #category : #'inner loop' }
BitBltSimulation >> copyLoop [
	| prevWord thisWord skewWord mergeMask halftoneWord mergeWord |
	1 to: h do: "here is the vertical loop"
		[ :i |
			(halftoneForm notNil)
				ifTrue: [halftoneWord := halftoneBits at: (1 + (dy bitAnd: 15)).
					dy := dy + vDir]
				ifFalse: [halftoneWord := AllOnes].
			skewWord := halftoneWord.
			preload
				ifTrue: [prevWord := sourceBits at: sourceIndex + 1.
					"load the 32-bit shifter"
					sourceIndex := sourceIndex + hDir]
				ifFalse: [prevWord := 0].
			mergeMask := mask1.
			"ERROR: extra to on next line in BB 360"
			1 to: nWords do: "here is the inner horizontal loop"
				[ :word |
					sourceForm notNil "if source used"
						ifTrue: [prevWord := prevWord bitAnd: skewMask.
							thisWord := sourceBits at: sourceIndex + 1.
							"pick up next word"
							skewWord :=
								prevWord bitOr: (thisWord bitAnd:
									skewMask bitInvert).
							prevWord := thisWord.
							skewWord := (skewWord bitShift: skew) bitOr:
									(skewWord bitShift: skew - 16)].
									"16-bit rotate"
					mergeWord := self merge: (skewWord bitAnd: halftoneWord)
							with: (destBits at: destIndex + 1).
					destBits
						at: destIndex + 1
						put: ((mergeMask bitAnd: mergeWord)
							bitOr: (mergeMask bitInvert
								bitAnd: (destBits at: destIndex + 1))).
					sourceIndex := sourceIndex + hDir.
					destIndex := destIndex + hDir.
					word = (nWords - 1)
						ifTrue: [mergeMask := mask2]
						ifFalse: [mergeMask := AllOnes]].
			sourceIndex := sourceIndex + sourceDelta.
			destIndex := destIndex + destDelta]
]

{ #category : #'inner loop' }
BitBltSimulation >> merge: sourceWord with: destinationWord [
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
