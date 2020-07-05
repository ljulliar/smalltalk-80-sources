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
	"initialize a table of bit masks"	
			
	RightMasks := #(0 16r1 16r3 16r7 16rF
	                16r1F 16r3F 16r7F 16rFF
	                16r1FF 16r3FF 16r7FF 16rFFF
	                16r1FFF 16r3FFF 16r7FFF 16rFFFF).
	AllOnes := 16rFFFF
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
	sourceForm notNil
	   ifTrue: [ sourceBits := sourceForm bits.
		          sourceRaster := sourceForm width - 1 // 16 + 1 ].
	halftoneForm notNil 
	   ifTrue: [ halftoneBits := halftoneForm bits ].
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
	"sets w and h"	
			
	self clipRange.
	(w <= 0 or: [h <= 0]) ifTrue: [ ^ self ]. "null range"
	self computeMasks.
	self checkOverlap.
	self calculateOffsets.
	self copyLoop
	
]
