# Bits of history

The Smalltalk-80 book series, published by Xerox PARC in the early 1980s, represented the culmination of an incredibly productive decade of research. This research gave rise to most of the hardware and software inventions and concepts that define the IT world as we know it today.

One particular book in the series, titled "Smalltalk-80: The Language and its Implementation" and authored by Adele Goldberg and Dave Robson, quickly became so famous within the computer science community that it was given the nickname "the Blue Book," referring to the color of its cover.

In approximately 600 pages, the book covers the complete Smalltalk-80 programming system. This includes the specification of the Smalltalk-80 language (the origin of most of today's fully object-oriented programming languages), a comprehensive and reflective object model, a rich set of standard libraries (or classes), the description of a full graphic environment and UI interactions, and some sample applications.

Furthermore, the last part of the Blue Book explained how to implement the virtual machine on the hardware platform of your choice. As a tribute to the power of the Smalltalk language, the virtual machine is entirely specified within the Blue Book using the Smalltalk language itself!

## Implementations of the VM
The publication of the Blue Book in the 1980s sparked a flurry of Smalltalk-80 implementations from various companies like HP, DEC, and Tektronix. Later, the book would also inspire various open-source (Little Smalltalk, GNU Smalltalk, Squeak, etc.) or commercial Smalltalk implementations and even influenced the very first version of the Sun Java VM.

More recently, to celebrate the 40th anniversary of the book, several open-source projects reimplemented the Smalltalk-80 VM using various languages like Lua, C#, or C++. But amazingly enough, very few attempts, if any, have been made to use the Smalltalk code provided in the Blue Book and see if it actually runs in a modern Smalltalk environment.

## Objectives of the project.
So, are the specifications of the Smalltalk-80 VM, written in Smalltalk, good enough to reimplement the whole system? As shown in this project, the answer is definitely yes, although there is still some additional work to be done so that the [implementation](Implementation.md) works for real.

* One objective was to transcribe the Smalltalk code from the Blue Book and merge all the known errata published either by Xerox between 1983 and 1985 or later by those who reimplemented the VM in other languages. This archaeology work took some time :-)
* Second, you have to write your own hardware abstraction layer (HAL) to serve as an interface between the ST-80 VM and its host. One of the benefits of hosting the VM on a Smalltalk environment (Pharo) is that I also wrote the HAL in Smalltalk, which brings a further level of abstraction to the HAL as well.

