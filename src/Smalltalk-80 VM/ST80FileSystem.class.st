"
This class maps the ST80 file system calls to the native file system of the host Smalltalk
environment. It maintains a table of open file handles mapping integer descriptors to Pharo
FileStream objects. The root directory is the ST80 image assets directory.
All file names passed from the ST80 VM are resolved relative to that root directory.

This class is the Pharo equivalent of dbanay's PosixST80FileSystem / IFileSystem classes.
It is used for both VM snapshot operations and for the ST80 file primitives (128-133).
"
Class {
	#name : 'ST80FileSystem',
	#superclass : 'Object',
	#instVars : [
		'rootDirectory',
		'fileHandles',
		'nextHandle',
		'lastError',
		'snapshotFileName'
	],
	#category : 'Smalltalk-80 VM',
	#package : 'Smalltalk-80 VM'
}

{ #category : 'instance creation' }
ST80FileSystem class >> withRoot: aDirectoryPath [
	"Create a new ST80FileSystem rooted at the given directory path"
	^ self basicNew initializeWithRoot: aDirectoryPath asFileReference; yourself
]

{ #category : 'file operations' }
ST80FileSystem >> closeFile: handle [
	"Close the file with the given integer handle. Return 0 on success, -1 on error."
	| stream |
	stream := fileHandles at: handle ifAbsent: [ ^ -1 ].
	[ stream close ] on: Error do: [ :e | lastError := -1. ^ -1 ].
	fileHandles removeKey: handle.
	^ 0
]

{ #category : 'file operations' }
ST80FileSystem >> createFile: fileName [
	"Create a new file, truncating it if it already exists.
	Return an integer file handle on success, or -1 on error."

	| ref stream handle |
	ref := rootDirectory / fileName.
	[ ref binaryWriteStream close ]
		on: Error
		do: [ :e |
				lastError := -1.
				^ -1 ].
	stream := self openStreamOn: ref.
	stream ifNil: [
			lastError := -1.
			^ -1 ].
	handle := nextHandle.
	nextHandle := nextHandle + 1.
	fileHandles at: handle put: stream.
	^ handle
]

{ #category : 'file operations' }
ST80FileSystem >> deleteFile: fileName [
	"Delete the named file from the root directory. Return true on success, false on error."

	| ref |
	ref := rootDirectory / fileName.
	^ [
		  ref delete.
		  true ]
		  on: Error
		  do: [ :e |
				  lastError := -1.
				  false ]
]

{ #category : 'file operations' }
ST80FileSystem >> enumerateFilesDo: aBlock [
	"Evaluate aBlock with the basename String of each non-directory file in the root directory."
	rootDirectory children do: [ :each |
		each isFile ifTrue: [ aBlock value: each basename ] ]
]

{ #category : 'error handling' }
ST80FileSystem >> errorText: code [
	"Return a human-readable string for the given error code."
	^ 'File system error: ', code printString
]

{ #category : 'file operations' }
ST80FileSystem >> fileFlush: handle [
	"Flush buffered data to disk for the given handle. Return true on success, false on error."

	| stream |
	stream := fileHandles at: handle ifAbsent: [ ^ false ].
	^ [
		  stream flush.
		  true ]
		  on: Error
		  do: [ :e |
				  lastError := -1.
				  false ]
]

{ #category : 'file operations' }
ST80FileSystem >> fileSize: handle [
	"Return the size in bytes of the open file, or -1 on error."
	| stream |
	stream := fileHandles at: handle ifAbsent: [ ^ -1 ].
	[ ^ stream size ]
	on: Error do: [ :e | lastError := -1. ^ -1 ]
]

{ #category : 'initialization' }
ST80FileSystem >> initialize [
	"Initialize with an empty file handle table and default snapshot file name."
	super initialize.
	fileHandles := Dictionary new.
	nextHandle := 1.
	lastError := 0.
	snapshotFileName := 'snapshot.im'
]

{ #category : 'initialization' }
ST80FileSystem >> initializeWithRoot: aFileReference [
	"Initialize with the given root directory FileReference."
	self initialize.
	rootDirectory := aFileReference
]

{ #category : 'error handling' }
ST80FileSystem >> lastError [
	"Return the last error code (-1 on file errors, 0 if no error)"
	^ lastError
]

{ #category : 'file operations' }
ST80FileSystem >> openFile: fileName [
	"Open an existing file for binary read/write access, falling back to read-only
	when the file is not writable. Return an integer file handle on success, or -1 if
	not found or on error."

	| ref stream handle |
	ref := rootDirectory / fileName.
	ref exists ifFalse: [
			lastError := -1.
			^ -1 ].
	stream := self openStreamOn: ref.
	stream ifNil: [
			lastError := -1.
			^ -1 ].
	handle := nextHandle.
	nextHandle := nextHandle + 1.
	fileHandles at: handle put: stream.
	^ handle
]

{ #category : 'private' }
ST80FileSystem >> openStreamOn: aFileReference [
	"Answer a seekable binary stream on aFileReference opened for reading and writing,
	or opened read-only if the file is not writable. Answer nil on failure.
	Pharo 13 FileReference has no binaryReadWriteStream, so we use File >> openForWrite:
	which answers a BinaryFileStream that supports position:, next:, truncate: and size."

	| file |
	file := File named: aFileReference fullName.
	^ [ file openForWrite: aFileReference isWritable ]
		  on: Error
		  do: [ :e | nil ]
]

{ #category : 'file operations' }
ST80FileSystem >> read: handle into: aByteArray count: byteCount [
	"Read up to byteCount bytes from the file into aByteArray (1-based indexing).
	Return the number of bytes actually read, or -1 on error."
	| stream bytes n |
	stream := fileHandles at: handle ifAbsent: [ ^ -1 ].
	[ bytes := stream next: byteCount.
	  n := bytes size.
	  1 to: n do: [ :i | aByteArray at: i put: (bytes at: i) ].
	  ^ n ]
	on: Error do: [ :e | lastError := -1. ^ -1 ]
]

{ #category : 'file operations' }
ST80FileSystem >> renameFile: oldName to: newName [
	"Rename a file within the root directory. Return true on success, false on error."

	| ref |
	ref := rootDirectory / oldName.
	^ [
		  ref renameTo: newName.
		  true ]
		  on: Error
		  do: [ :e |
				  lastError := -1.
				  false ]
]

{ #category : 'accessing' }
ST80FileSystem >> rootDirectory [
	^ rootDirectory
]

{ #category : 'file operations' }
ST80FileSystem >> seekTo: handle position: position [
	"Seek to the given absolute byte position. Return the new position, or -1 on error."
	| stream |
	stream := fileHandles at: handle ifAbsent: [ ^ -1 ].
	[ stream position: position. ^ position ]
	on: Error do: [ :e | lastError := -1. ^ -1 ]
]

{ #category : 'accessing' }
ST80FileSystem >> snapshotFileName [
	"Return the snapshot file name relative to root directory. Default: 'snapshot.im'."
	^ snapshotFileName
]

{ #category : 'accessing' }
ST80FileSystem >> snapshotFileName: aName [
	"Set the snapshot file name (relative to root directory)"
	snapshotFileName := aName
]

{ #category : 'file operations' }
ST80FileSystem >> tell: handle [
	"Return the current byte position in the file, or -1 on error."
	| stream |
	stream := fileHandles at: handle ifAbsent: [ ^ -1 ].
	[ ^ stream position ]
	on: Error do: [ :e | lastError := -1. ^ -1 ]
]

{ #category : 'file operations' }
ST80FileSystem >> truncateTo: handle length: byteCount [
	"Truncate the file to byteCount bytes. Return true on success, false on error."

	| stream succeeded |
	stream := fileHandles at: handle ifAbsent: [ nil ].
	succeeded := stream isNotNil and: [
			             [
				             stream truncate: byteCount.
				             true ]
				             on: Error
				             do: [ :e | false ] ].
	succeeded ifFalse: [ lastError := -1 ].
	^ succeeded
]

{ #category : 'file operations' }
ST80FileSystem >> write: handle from: aByteArray count: byteCount [
	"Write byteCount bytes from aByteArray to the file. Return bytes written, or -1 on error."
	| stream |
	stream := fileHandles at: handle ifAbsent: [ ^ -1 ].
	[ stream nextPutAll: (aByteArray copyFrom: 1 to: byteCount).
	  ^ byteCount ]
	on: Error do: [ :e | lastError := -1. ^ -1 ]
]
