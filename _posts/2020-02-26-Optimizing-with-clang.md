---
layout: post_template
title: "Optimizing Programs with clang and LLVM"
excerpt_separator: <!--more-->
---

When working with optimizing compilers, it is sometimes beneficial to inspect
intermediate results to figure out whether an optimization has fired or not.
While taking a dive into LLVM's fast-math semantics I recently encountered
a subtle quirk that may affect others as well.
<!--more-->

**<TL;DR>**

When compiling with `clang` to generate LLVM output (`-emit-llvm -S`) without
specifying an optimization level (`-Ox`) or when setting `-O0`, add
`-Xclang -disable-O0-optnone` to allow optimizations to be performed later by
LLVM.

**</TL;DR>**

### Long Story

I was looking into the LLVM fast-math implementation to figure out what
optimizations are applied depending on which `ffast-math` specific flag is set.
To confirm my intuition from the skimming the source-code files, I wanted to run
some actual C code through clang/LLVM and inspect the optimized program.

I started with the following program:

    double f (double x) {
      return -x + x;
    }

    int main (void) {
      f(2.5);
      return 0;
    }

According to LLVM's InstructionSimplify implementation
([link](https://github.com/llvm/llvm-project/blob/b03f3fbd6a6b8843469865b16c9eb3af8adc2d3a/llvm/lib/Analysis/InstructionSimplify.cpp)),
if `-ffast-math` is given, function `f` should be optimized into an LLVM
statement equivalent to `return 0.0;`.

However, after generating LLVM output with clang, using `clang -emit-llvm -S -ffast-math test.c`,
and running `opt-7 -enable-no-nans-fp-math -O3 -S` I got back the initial `.ll`
file without any optimizations having fired.

I found this unintuitive because I was assuming that `clang` would produce
LLVM IR that can be optimized using `opt`.
This would allow me to see per optimization effects on the program.

After asking some colleagues[^1] for help, I learned the following:
Since LLVM 5, `clang` will annotate **every** function in the produced LLVM
bytecode with `optnone`, if no optimization flag (or `-O0`) is set when invoking
`clang`.

If this `optnone` flag is present on any function in LLVM IR, the function is
not optimized by LLVM.
A simple way of preventing this issue is of course to use `-O1`, `-O2` or `-O3`
as flags for `clang`.
This was unsatisfactory, as I wanted to inspect the effect of the LLVM
optimizations on a small program, and thus I wanted to have an unoptimized
version of the LLVM IR.
The solution I arrived at was:
If `clang` should not perform optimizations from the get go, the only way to
prevent this issue is to use a special **internal** compiler flag
`clang -ffast-math -emit-llvm -Xclang -disable-O0-optnone -S`.

Using these flags, the resulting LLVM IR did not have the `optnone` annotation
and `opt` happily optimized the program the way I expected it to.

---

 [^1]: A big thank you to Tina Jung ([website](http://compilers.cs.uni-saarland.de/people/jung/)) and Fabian Ritter ([website](http://compilers.cs.uni-saarland.de/people/ritter/)) for solving a problem in 5 minutes that would have taken me hours to figure out otherwise.