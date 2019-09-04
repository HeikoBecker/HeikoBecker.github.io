---
layout: post_template
title: "Extending CakeML's floating-point support"
excerpt_separator: <!--more-->
---

[CakeML](https://cakeml.org) is an end-to-end verified compiler for a dialect of
SML.
Until recently it was not possible to write CakeML programs that used
floating-point operations.
While floating-point arithmetic was implemented throughout the backend of the
compiler, it was not exposed on the frontend.
Over the last weeks I have worked on a frontend implementation for
CakeML, making floating-point arithmetic accessible to the end user.
<!--more-->

Before my changes, CakeML floating-points were implemented from the abstract
syntax tree (AST) down to the hardware.
However, there was no way to access floating-point arithmetic in the source
syntax for two reasons:

1. The operations that were in the AST were not exposed over a library module
2. The parser did not support parsing a floating-point

For an unverified compiler, the changes sketched above would have been
relatively easy.
As CakeML is a fully verified compiler fixing these two points required then
what would have been necessary for an unverified compiler.
little more work than what would have been necessary for an unverified compiler.

In this post I will first give a brief intro to compiler verification and the
verified CakeML compiler.
The main part however will be a report of my experience working on the issues
with CakeML's floating-point arithmetic.

## Compiler Verification

There are many good papers out there explaining the ideas and techniques of
compiler verification, for example for *C*[^1] (CompCert) or *SML*[^2] (CakeML).
The rationale behind compiler verification is that the compiler is
usually the last tool that runs on source code before the code/the binary is
shipped to a client.
Consequently, compilers are an integral part of software development.
While testing had been the method of choice for evaluating compiler correctness
before, testing can only prove the presence of bugs, but never their absence.
Thus people looked into *proving the absence* of compiler bugs.
Compiler bugs here refers to the compiler dropping or adding behaviors that the
programmer did not specify.
So a high-level compiler correctness theorem is:

<p class="center-align">
<em>
For any program s, evaluating s returns the same value as running the
compiler on s and evaluating the assembly code.
</em>
</p>

A flavour of this theorem is proven for any verified compiler.

#### Implementing a Double library module

Given that the compiler had floating-point arithmetic in the AST, the compiler
correctness theorem was already proven for floating-point arithmetic.
So an obvious question to ask now is: What was the friction point if all of
the (interesting) work was already done? Can we just expose the operations in
the AST to the user over a library module?

The issue here is how the CakeML standard library is set up.
To get a true end-to-end correctness theorem, the CakeML compiler bootstraps
itself in the theorem prover logic using a so-called
"proof-producing translator".
Translator means that the tool translates objects in the theorem prover logic
(like the compiler itself) into compiler source syntax (i.e. ASTs) and the
compiler can then be run on these ASTs.
Proof-producing means that the tool produces an additional correctness theorem
that the produced CakeML source code and theorem prover object have the same
semantics.

To boostrap the compiler, the CakeML standard library is also implement with
the proof-producing translator.
This in turn meant I had to make the translator aware of double floating-point
arithmetic, implementing machinery to destruct HOL4 floating-point functions
into CakeML floating-point implementations.
With the awesome help of one of the CakeML developer's, Magnus Myreen[^3], the
extension of the translator was easy to do and relatively frictionless.

#### Supporting FMA instructions in the basis

This is where it became interesting: To make CakeML floating-points more
interesting for other tools (blatant self promotion: *Icing*[^4]) I added
support for the fused-multiply-add (FMA) instruction.
In general, FMA's are (locally) more accurate than computing a plain
multiplicaiton and addition.

For CakeML AST's, FMA instructions were not supported before I started my work,
so I had to push them through the full compiler correctness story. (Big shoutout
to Yong-Kiam Tan[^5] for helping me fix the `data_to_word` proofs.)
This in turn lead to me implementing a new compiler backend (through copy & paste)
for ARMv8 which natively supported FMA's in its HOL4 model.

### Parsing floating-point constants

In general, parsing floating-point constants from strings like "1.234" is tricky
to get right.
To sidestep the problem of implementing a verified parsing algorithm for
floating-point constants in CakeML, we chose to implement it through the
foreign function interface.

CakeML's foreign function interface (FFI) is its method of communicating with the
outside worls.
All I/O done by CakeML programs must go through this interface.
While the FFI functions themselves are implemented in C, and thus untrusted,
any library function that uses calls into the FFI is verified with a HOL4 model
of the FFI call.

Similarly, floating-point parsing is implemented with C's `scanf` and
pretty-printing with `snprintf`.
Due to some quirks of the C function CakeML does print floating-point
constants exactly but rather until 12 digits behind the dot.

## Conclusion

To wrap up, the CakeML compiler does now completely support 64-bit double
arithmetic.
Even though there were some hickups in the process, like some HOL4 CakeML
functions not typechecking SML code (looking at you `process_topdecs`)
I felt that with the awesome support from the CakeML developers
my extension was a nice exercise and well worth doing from a personal
point of view.
If you are now curious yourself on hacking on CakeML, I recommend looking at
the list of [starter issues](https://github.com/CakeML/cakeml/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)
and getting in touch with the developers on the [CakeML slack](https://cakeml.slack.com/join/shared_invite/MjM1NjEyODgxODkzLTE1MDQzNjgwMTUtYjI4YTdlM2VmMQ)
.

---

[^1]: [https://compcert.inria.fr](https://compcert.inria.fr)

[^2]: [https://cakeml.org](https://cakeml.org)

[^3]: [http://www.cse.chalmers.se/~myreen/](http://www.cse.chalmers.se/~myreen/)

[^4]: [{{ site.baseurl }}/blog/Getting-fastmath-right]({{ site.baseurl }}/blog/Getting-fastmath-right)

[^5]: [https://www.cs.cmu.edu/~yongkiat/](https://www.cs.cmu.edu/~yongkiat/)