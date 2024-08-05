"
This class serves as a proxy to create an object representation of the
Bitblt instances coming from the ST80 Virtual Machine
"
Class {
	#name : #ST80BitBlt,
	#superclass : #Object,
	#instVars : [
		'memory',
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
		'h'
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

{ #category : #initialization }
ST80BitBlt >> initializeWithBitBltPointer: bbp memory: m [

	"Make sure class variables ar initialized"
	self class initialize.

	memory := m.
   destForm := ST80Form fromObject: (memory fetchPointer: DestFormIndex ofObject: bbp) memory: memory.
   sourceForm := ST80Form fromObject: (memory fetchPointer: SourceFormIndex ofObject: bbp) memory: memory.
   destX := memory fetchPointer: DestXIndex ofObject: bbp.
   destY := memory fetchPointer: DestYIndex ofObject: bbp.
   clipX := memory fetchPointer: ClipXIndex ofObject: bbp.
   clipY := memory fetchPointer: ClipYIndex ofObject: bbp.
   clipWidth := memory fetchPointer: ClipWidthIndex ofObject: bbp.
   clipHeight := memory fetchPointer: ClipHeightIndex ofObject: bbp.
   sourceX := memory fetchPointer: SourceXIndex ofObject: bbp.
   sourceY := memory fetchPointer: SourceYIndex ofObject: bbp.
   width := memory fetchPointer: WidthIndex ofObject: bbp.
   height := memory fetchPointer: HeightIndex ofObject: bbp.
   combinationRule := memory fetchPointer: CombinationRuleIndex ofObject: bbp.

]

{ #category : #accessing }
ST80BitBlt >> memory [

	^ memory
]
