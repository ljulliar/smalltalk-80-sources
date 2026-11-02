# Developer notes
## Memory sanity checks
The virtual machine can check every access to the object memory (valid object pointer, valid field index, valid address and 16-bit value) and raise an assertion failure as soon as something is wrong. These checks are very costly (5x performance degradation !!), so they are **off by default** (`false`): with the checks on, the VM runs several times slower.

There are two independent switches, both class-side flags:

| Flag | Checks |
|---|---|
| `ObjectMemory checksEnabled:` | object and field indices (`fetchPointer:ofObject:`, `fetchWord:ofObject:`, current segment when allocating) |
| `RealWordMemory checksEnabled:` | segment and word addresses and the values stored (`segment:word:`, `segment:word:put:`, the bits and byte variants) |

Both flags are set explicitly to `false` at the start of `ST80VirtualMachine >> initializeWithImagePath:keyboard:` every time a VM is launched, so a value set in a Pharo Workspace before launching is overwritten.

If you suspect a memory corruption (for instance a wrong class pointer, an object that changed under your feet, or a crash far away from its cause), switch the checks on:
* Change `false` to `true` in the two `checksEnabled:` lines of `ST80VirtualMachine >> initializeWithImagePath:keyboard:` and launch the VM again, or
* Evaluate `ObjectMemory checksEnabled: true. RealWordMemory checksEnabled: true` from the debugger or a Workspace while a VM is running. The change takes effect immediately.

The first failed assertion stops the VM close to the faulty access, and the Pharo debugger stack shows the caller. Remember to switch the checks back off afterwards.

## Native text scanning
Displaying text spends most of its time in the guest primitive 103 (`CharacterScanner >> scanCharactersFrom:to:in:rightX:stopConditions:displaying:`), which the Blue Book lists as optional. The VM implements it natively in `Interpreter >> primitiveScanCharacters` and `ST80CharacterScanner`: the scan of a whole run of characters is done on the host side and the changed part of the screen is refreshed once, instead of once per character. Typing and erasing text is noticeably faster.

The native scan is controlled by a class-side flag, set explicitly to `true` at the start of `ST80VirtualMachine >> initializeWithImagePath:keyboard:` every time a VM is launched, just like the memory checks above:

| Flag | Effect |
|---|---|
| `ST80CharacterScanner useNativeScan:` | `true`: primitive 103 scans the characters on the host side. `false`: primitive 103 always fails and the guest Smalltalk code runs its own (slower) loop |

To compare the two or to track down a text display problem:
* Change `true` to `false` in the `useNativeScan:` line of `ST80VirtualMachine >> initializeWithImagePath:keyboard:` and launch the VM again, or
* Evaluate `ST80CharacterScanner useNativeScan: false` from a Workspace while a VM is running. The change takes effect immediately.

The native scan checks all its arguments before drawing the first character. If anything looks wrong (an unexpected object, an index out of range...) the primitive fails and the guest code runs, so the screen never shows a character twice.
