"
Please describe the package using the class comment of the included manifest class. The manifest class also includes other additional metadata for the package. These meta data are used by other tools such as the SmalllintManifestChecker and the critics Browser
"
Class {
	#name : #ManifestSmalltalk80VM,
	#superclass : #PackageManifest,
	#category : #'Smalltalk-80 VM-Manifest'
}

{ #category : #'code-critics' }
ManifestSmalltalk80VM class >> ruleReGlobalVariablesUsageRuleV1FalsePositive [

	<ignoreForCoverage>
	^ #(#(#(#RGPackageDefinition #(#'Smalltalk-80 VM')) #'2024-08-28T10:40:01.054247+02:00') )
]
