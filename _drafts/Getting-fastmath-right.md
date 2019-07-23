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
2. expressions are evaluated lazily to model optimizations
3. annotations are used for fine-grained control over which expressions are
   optimized

One of the strengths of Icing is that proving an optimization correct is
relatively easy.
However, it took us many iterations to arrive at its current design and in this
blog post I want to shed some light on the different implementations and
approaches we tried (and in the end abandoned).

## Interfacing between semantics and optimizations

Icing has a single nondeterministic semantics of the form
$$(cfg, E, e) \Downarrow v$$ meaning that expression $$e$$ evaluates to value
$$v$$ under the environment $$E$$ with optimizations from $$cfg$$.
Any proof for Icing is always done with respect to this nondeterministic
semantics.

In contrast, our initial supiciion was that separating the nondeterminism from
the proof interface would simplify reasoning.
Thus we designed two separate semantics for Icing:
The first one would nondeterministically apply optimizations as the current,
final one;
whereas the second would have an additional oracle making optimization
deterministic.

To relate the nondeterministic and deterministic semantics with each other we
proved forward and backward simulation theorems.
The forward simulation showed that if we have a nondeterministic evaluation
with optimizations applied, there exists an oracle such that we can simulate the
optimizations in the semantics.
The backward simulation theorem showed that for any given oracle we can find an
equivalent nondeterministic execution.

When we tried to prove correct a first example compiler we first tried showing
its correctness for the deterministic oracle semantics.
However, it turned out that showing correctness with respect to the
nondeterministic semantics was way easier than showing correctness with respect
to the oracle semantics.
Thus we abandoned the intermediate oracle semantics.

As a side remark:
We also separately tried following the CakeML approach, giving a functional
big-step semantics[^2].
Given that our semantics was nondeterministic we implement it as function that
would return the (infinite) set of all possible optimization results.
We found this semantics not easy to maintain and read in comparison to the
relational semantics we settled on in the end.

## Smartly representations for lazy values

To make it possible for the semantics to the same optimizations as the compiler
we must delay evaluation of expressions.
This makes it possible to inspect the structure of a value in the semantics and
check whether it matches a rewrite.

In our first draft we implemented values as expressions annotated with rounding
operator applications.
The idea was that an optimization that introduces e.g. a FMA instruction would
in the semantics essentially only strip away an intermediate rounding operator
(i.e. $$round\;(round\;(a * b) + c)$$ would become $$round\;(a * b + c)$$).

As it turns out, this became very tedious when proving correct optimizations.
Our equivalence criterion for optimizations had to reason about equivalence
between syntactic expressions and the semantic value without rounding operators
(we called this the "shape" of the value).
What is more, evaluation of operators had to be defined with respect to
real-valued semantics (for addition, multiplication, ...), applications of
rounding from real numbers to 64-bit floating-point words, and rounding back
from 64-bit words to reals to make the HOL4 type checker happy.
To make things even worse, we found that some necessary theorems were
missing in the HOL4 floating-point formalization. We could not (easily) show
that $$round\;(round\;x) = round\;x$$ for any floating-point number or that
$$round\;(to\_real\;x) = x$$.
Both of these properties would be essential for giving a proper definition of
the semantics with respect to real numbers.

In the end we settled for not having explicit rounding operators because an
additional artifact was that the source semantics could now exhibit "floating-point
instructions" that are not representable on hardware
(like a Fused-Multiply-Add-Add $$round\;(a * b + c + d)$$).
Taking both these points into account, we settled on a value representation that
remains close to the actual hardware.

# Limiting applications of optimizations

The `-ffast-math` flag is a global all-or-nothing flag which either pulls in the
full fast-math optimizations for the full compiler input or none at all.
In contrast, our goal was to make sure that non-critical code could be optimized
while it is possible to ensure IEEE754 preservation for program parts.

Our first try was to explicitly differentiate between optimized and unoptimized
operators.
Take for example addition: We supported an unoptimized addtion ($$+$$) and an
optimized version ($$\tilde{+}$$).
Consequently every operator that could be optimized occurred twice in the syntax,
and thus also in the semantics.
While the cases were simple, this unnecessarily blew up the amount of cases
for inductions on the structure of an expression, case analysis on expressions,
and rule induction on the semantics.

Our alternative solution are the scope annotations ($$opt:(a + b)$$), where we
have a single rule in the semantics that switches an optimization flag on and
off.
Evaluating an operator then either nondeterministically picks an optimized
result or leaves the resulting value as is if no optimizations are allowed.

# Conclusion

As a conclusion I want to point out that I learned two important lessons on this
project:

- Striving for simplicity and rethinking designs can be quite fruitful and allow for further extensions

- While a design may look nice on paper it always pays off to check a "MVP"
  before implementing a fully fledged tool to evaluate the design

[^1]: There is a cool rationale behind the name Icing. Our target is the
      *Cake*ML compiler and in the CakeML infrastructure it is common to give
      "cake" related metaphorical names to tools. For example CI machines are
      called ovens.
      As our semantics operates on the top-level and is supposed to make
      floating-point support of CakeML better, we called Icing.

[^2]: TODO: Fun Big-step paper