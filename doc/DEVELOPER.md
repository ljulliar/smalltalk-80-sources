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

## Testing
The virtual machine has a suite of 457 SUnit tests in the `Smalltalk-80 VM-Tests` package. None of them needs the Smalltalk-80 image, the display or a running VM: each test builds its own small object memory, and the interpreter tests use a stand-in for the host (see below).

### Test suites
| Test class | Tests | What it covers |
|---|---|---|
| `InterpreterTest` | 368 | The interpreter (Blue Book ch. 27 to 30): bytecodes, message sends, special selectors, blocks, returns, every primitive family (arithmetic, float, object access, streams, files, input/output, timer), process scheduling and semaphores |
| `ObjectMemoryTest` | 60 | The object table and heap manager (Blue Book ch. 30): allocation, reference counting, garbage collection, snapshot |
| `RealWordMemoryTest` | 29 | The 16-bit word store under the object memory (segments, words, bytes, bits) |

`ObjectMemoryTestCase` is the abstract fixture shared by `InterpreterTest` and `ObjectMemoryTest`: it builds the small hand-built memory each test runs on. `InterpreterTestHAL`, `InterpreterTestClockHAL`, `InterpreterTestVM` and `ObjectMemoryTestInterpreter` are stand-ins for the hardware layer, the hardware layer with a clock set by the test, the virtual machine and the interpreter. They contain no tests.

Four tests of `InterpreterTest` (protocol `tests - VM bugs`) are marked with the `<expectedFailure>` pragma. They describe what a primitive *should* do where the Blue Book code has a known limit that was kept as it is (for instance a non-integer index given to `at:put:` ends in a host `MessageNotUnderstood` instead of a primitive failure, because `primitiveFail` answers the interpreter). SUnit counts them as successes, and they will start to report an unexpected pass the day the limit is fixed.

### Running the tests from the Pharo UI
* In the System Browser, select the `Smalltalk-80 VM-Tests` package, a test class or a single test method, right-click and choose the *Run tests* entry. Green and red marks appear next to the tests.
* Or open the Test Runner (DrTests) from the Pharo menu, select the `Smalltalk-80 VM-Tests` package and run it.
* Both tools can debug a failing test: the debugger opens on the failed assertion, with the test fixture in the stack.

### Running the tests from a Playground
Select the expression and *Print it* (or *Inspect it* to browse the result).

```smalltalk
"Every test of a suite"
InterpreterTest suite run.
ObjectMemoryTest suite run.
RealWordMemoryTest suite run.

"A single test"
(InterpreterTest selector: #testSignalAtTick) run.

"A single test in the debugger"
InterpreterTest debug: #testSignalAtTick.

"All the suites together"
| suite |
suite := TestSuite named: 'Smalltalk-80 VM'.
{ InterpreterTest. ObjectMemoryTest. RealWordMemoryTest }
	do: [ :each | suite addTests: each suite tests ].
suite run.
```

`run` answers a `TestResult`. For all the suites together its print string reads:

```
457 ran, 453 passed, 0 skipped, 4 expected failures, 0 failures, 0 errors, 0 passed unexpected
```

Send `failures` or `errors` to the result to list the tests that went wrong.

Each test builds a complete word memory, so the whole `InterpreterTest` suite takes a while (a single test takes a fraction of a second, so expect a few minutes for the 368 of them) and the Pharo UI is not responsive meanwhile. When you work on one part of the VM, run a single test or a single class first.

### Writing a new test
* A test of the interpreter goes in `InterpreterTest` (see its class comment). Useful helpers: `runPrimitive:with:` pushes the operands and runs a primitive, `assertPrimitiveFails:with:` checks that it fails and leaves the stack alone, `useHAL` gives the interpreter a stand-in host that logs what the primitives ask for (`callsTo:`), and `useClockHAL` gives it the real hardware layer with a millisecond clock that the test sets (`uptime:`), so a test of the timer never has to wait.
* A test of the memory manager goes in `ObjectMemoryTest`, a test of the word store in `RealWordMemoryTest`.
* Test names follow the existing pattern `test<WhatIsChecked>`, and each test has a comment saying the rule it checks, with the Blue Book page when there is one.
* A change to the VM should come with a test that fails without it. The freeze when running code with an unknown class, for instance, is covered by `testAsynchronousSignalIgnoresNil` and the `testTimer...` tests: a cancelled timer must never put a `nil` in the semaphore buffer of the interpreter.

## Idle loop control (host CPU usage)
The Smalltalk-80 system never really goes idle: its window scheduler and controllers poll in loops that call `Processor yield`, so left alone the VM process burns a full CPU core even when you do nothing. The host detects this and puts the interpreter to sleep. The guest image is not modified.

`Interpreter >> checkProcessSwitch` counts the process switches that happen with no outside activity in between (an idle guest does nothing but switch). Activity is an input word read, something drawn on the display, a file access, or a Semaphore signaled by the host (input event, timer). After `idleSwitchThreshold` quiet switches the guest is taken for idle, and each further quiet switch makes the interpreter sleep (`ST80HardwareAbstractionLayer >> idleFor:`) for at most `idleMilliseconds`. The sleep ends at once on a key or a mouse move, never goes past the time of a pending guest timer, and is skipped when Semaphores are waiting to be signaled.

| Setting (class side of `Interpreter`) | Meaning | Default |
|---|---|---|
| `idleMilliseconds:` | longest sleep at each quiet switch, in ms | 25 |
| `idleSwitchThreshold:` | quiet switches in a row before the guest is taken for idle. 0 switches the detection off | 50 |

Both can be changed from a Workspace while a VM is running, for instance `Interpreter idleMilliseconds: 50`, and take effect immediately. They go back to the defaults when the image is restarted: edit the defaults in `Interpreter class >> idleMilliseconds` and `idleSwitchThreshold` to keep a value.

What to expect with the guest idle on the empty desktop (Pharo alone uses about 10% of a core on the machine measured):

| `idleMilliseconds` | Pharo CPU with the VM idle |
|---|---|
| detection off (threshold 0) | about 100% |
| 5 | about 45% |
| 25 (default) | about 25 to 30% |

A longer sleep lowers the CPU further, but never down to the Pharo baseline: each wake-up still runs one pass of the guest idle loop (about 750 bytecodes). Input and guest timers wake the interpreter at once, so typing and the mouse are not affected by the value. A longer sleep only delays what the guest does on its own while idle. After changing the value, check typing, window dragging and menus. A single sleep never lasts more than 1 second (`ST80HardwareAbstractionLayer >> maximumIdleMilliseconds`).

To tune, read `processSwitchCount`, `idleSleepCount` and `quietSwitches` on `vm interpreter` while the VM runs. With the guest idle `idleSleepCount` should climb as fast as `processSwitchCount`. While typing or running a long computation it should barely move.
