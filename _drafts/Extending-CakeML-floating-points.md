---
layout: post_template
title: "Extending CakeML's floating-point support (Experience Report)"
excerpt_separator: <!--more-->
---

[CakeML](https://cakeml.org) is an end-to-end verified compiler for a dialect of
SML.
Until recently CakeML did not expose floating-point operations to the user.
Floating-point arithmetic was only implemented in the backend of the compiler
but not in its frontend.
In this blog post I will first give a brief intro to what compiler verification
is (for the CakeML compiler) and delve a bit into the CakeML ecosystem.
But the main part will be an experience report on how I implemented frontend
support for floating-point arithmetic in CakeML.
<!--more-->

## Compiler Verification (an opinionated explanation)
There are many good papers out there explaining the ideas and techniques of
compiler verification for *C*[^1] (CompCert) or *SML*[^2] (CakeML).
The general rationale behind compiler verification is that the compiler is
usually the last tool that runs on source code before it is shipped to a client.
Given that compilers are an integral part of software development it is
(in my opinion) unquestionably desirable to show that the compiler will not
alter the behavior of the source code it is run on.
While testing had been the method of choice for years, testing can only prove
the presence of bugs, but never their absence.
Thus people looked into proving the absence of *compiler bugs*.
Compiler bugs here refers to the compiler dropping or adding behaviors that the
programmer did not specify.
So a high-level compiler correctness theorem is:

For any program s, evaluating s returns the same value as running the
compiler on s and evaluating.

Any verified compiler will prove the above theorem one way or another.

## Floating-point support in CakeML

Before my changes, CakeML floating-points were implemented in the abstract
syntax tree (AST) but there was no way to access floating-point arithmetic in the
source syntax for two reasons:

1. The operations that were in the AST were not exposed over a library module
2. The parser did not support parsing a floating-point constant

## Implementing a Double library module
Given that the compiler had floating-point arithmetic in the AST the compiler
correctness theorem was already proven for floating-point arithmetic.
So an obvious question to ask now is: What is the friction point then if all of
the work is already done? Just expose the operations in the AST to the user.

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
With the awesome help of one of the CakeML developer's (Magnus Myreen[^3]) the
extension of the translator was easy to do and relatively frictionless.

### Supporting FMA instructions in the basis

This is where it became interesting: To make CakeML floating-points more
interesting for other tools (blatant self promotion: *Icing*[^4]) I added
support for the fused-multiply-add (FMA) instruction.
In general, FMA's are (locally) more accurate than computing a plain
multiplicaiton and addition.

For CakeML AST's, FMA instructions were not supported before I started my work,
so I had to push them through the full compiler correctness story. (Big shoutout
to Yong-Kiam Tan[^5] for helping me fix the `data_to_word` proofs.)
This in turn lead to me implementing a new compiler backend (through copy & paste)
for ARMv8 which natively supported FMA's in its HOL4 formalization.

## Parsing floating-point constants

- supported in "AST" formalization, not in the parsed syntax
-> floating-point parsing is hard

- Trick 1: Rely on FFI to implement parsing (unverified!)

- The story behind making CakeML FFI calls a little more trustworthy

---

[^1]: [https://compcert.inria.fr](https://compcert.inria.fr)

[^2]: [https://cakeml.org](https://cakeml.org)

[^3]: [http://www.cse.chalmers.se/~myreen/](http://www.cse.chalmers.se/~myreen/)

[^4]: [{{ site.baseurl }}/blog/Getting-fastmath-right]({{ site.baseurl }}/blog/Getting-fastmath-right)

[^5]: TODO