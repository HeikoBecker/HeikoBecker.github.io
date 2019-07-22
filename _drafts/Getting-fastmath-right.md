---
layout: post_template
title: "Getting Fastmath Optimizations Right"
---

---

When using gcc or clang, programmers commonly use so-called "fastmath"
optimizations to aggressively optimize floating-point programs.
So far, these optimizations have been out of reach for verified compilers
like [CompCert](https://compcert.inria.fr) or [CakeML](https://cakeml.org).

In our paper recent [CAV paper](https://i-cav.org/2019), we introduce a new
semantics for floating-point programs in verified compilers, called *Icing*[^1].
Icing semantics have three key ideas:

1. optimizations are applied nondeterministically
2. evaluation of expressions is delayed to model optimizations
3. annotations are used to give fine-grained control over where optimizations
   are applied

One of the strengths of Icing is that proving correctness of optimizations in
is simple.
It took many iterations to arrive at the current design and thus this blog post
is meant to shed some light on the different implementations and approaches
we tried (and in the end abandoned).

## Defining an appropriate interface to the optimization semantics

Icing has a single nondeterministic semantics of the form $$(cfg, E, e) \Downarrow v$$
meaning that expression $$e$$ evaluates to value $$v$$ under the environment
$$E$$ with optimizations from $$cfg$$.
Our initial plan for Icing was to have two separate semantics with simulation
proofs to ease the reasoning.
The first one would nondeterministically apply optimizations as the final one;
the second would have an additional oracle making optimization deterministic.
Our high-level goal was to make simulation proofs for optimizations easier with
this intermediate semantics.

We proved forward and backward simulation theorems.
The forward simulation showed that if we have a nonderterministic evaluation
with optimizations applied, there exists an oracle such that we can simulate the
optimizations in the semantics.
The backward simulation theorem showed that for any given oracle we can find an
equivalent nondeterministic execution.

When it came to proving correctness of a first example compiler, it turned out
that showing correctness with respect to the nondeterministic semantics was way
easier than showing correctness with respect to the oracle semantics.

Set semantics: https://gitlab.mpi-sws.org/AVA/CakeML_fastmath_Notes/commit/538c9e1fdda3c445501045e02487050abad14d38

## Finding a good representation for delayed expression evaluation

To make it possible for the semantics to the same optimizations as the compiler
we must delay evaluation of expressions.
This makes it possible to inspect the structure of a value in the semantics and
check whether it matches a rewrite.

In our first draft we implemented values as expressions annotated with rounding
operator applications.
The idea was that an optimization that introduces e.g. a FMA instruction would
in the semantics essentially only strip away an intermediate rounding operator
(i.e. $$round (round (a * b) + c)$$ would become $$round (a * b + c)$$).

As it turns out, this became very tedious when proving correct optimizations.
Our equivalence criterion for optimizations now had to reason about equivalence
between syntactic expressions and the semantic value without rounding operators
(we called this the "shape" of the value).
Whatismore, evaluation of operators now had to be defined with respect to
real-valued semantics (for addition, multiplication, ...) and applications of
rounding that go from real numbers to 64-bit floating-point words.
To make things even worse, we found that some interesting theorems were
missing in the HOL4 floating-point formalization. We could not (easily) show
that $$round (round x) = round x$$ for any floating-point number or that
$$round (to_real x) = x$$. Both of these properties were essential for
giving a proper definition of the semantics and thus we settled on not having
explicit rounding operators.

* our idea to differentiate evaluation for operators (instead of scoping applications of optimizations)
* explicit rounding operators in the semantics

Why scoping optimizations is better then operator based distinction

cluttered semantics with parameters! (true false for opts)

## Why you should limit rewrite applications with preconditions

* our introduction of preconditions to limit rewrite applications


[^1]: There is a cool rationale behind the name Icing. Our target is the
      *Cake*ML compiler and in the CakeML infrastructure it is common to give
      "cake" related metaphorical names to tools. For example CI machines are
      called ovens.
      As our semantics operates on the top-level and is supposed to make
      floating-point support of CakeML better, we called Icing.