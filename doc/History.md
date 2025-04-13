# Bits of history

The Smalltalk-80 book series published by Xerox Parc in the early 80s was the culminating point of an incredibly productive decade of research that gave birth to most of the hardware and software inventions and concepts of the IT world as we know it today.

One particular book in the series titled "Smalltalk-80 The language and its implementation" authored by Adele Goldberg and Dave Robson quickly became so famous in the computer science community that it was given a nick name, the "Blue Book", referring to the color of its cover.

In 600 pages, the book covers the complete Smalltalk-80 programming system comprising the specification of the Smalltalk-80 language (at the origin of most of today's fully object oriented programming languages), a comprehensive and reflective object model, a rich set of standard libraries (or classes), the description of a full graphic environment and UI interactions and some sample applications. But as this wasn't enough, the last part of the Blue Book also explained how to implement the virtual machine that would running the entire programming environment on the harwdware platform of your choice. 

As a testimonial to the power of the Smalltalk language, the virtual machine is entirely specified in the Blue book using the Smalltalk language itself !

## Implementations of the VM
With the publication of the Blue Book came a flurry of Smalltalk-80 implementations from various companies like HP, DEC, Tektronix in the eighties. Later the book would also sparkled various open source (Little Smalltalk, GNU Smalltalk, Squeak,...) or commercial Smalltalk implementations and also inspire the very first version of the Sun Java VM.

More recently to celebrate the 40th anniversary of the book, several open source projects reimplemented the Smalltalk-80 VM using various languages like Lua, C# or C++.
But amazingly enough very few attempts were made, if any, to actually use the Smalltalk code provided in the Blue Book and run it in a modern Smalltalk evironment to answer the question: does this specification of the VM written in Smalltalk actually works ?

## Objectives of the project.

The answer to the question above is: yes it does! Or it does at 90% :-) The goal of this project is to provide the missing 10% and deliver a fully working Smalltalk implementation of Smalltalk.
What are those 10% made of ? Read on more about this project [implementation](Implementation.md]
