# RFC 0023: `zuexact`, exactly rounded sums, means and dot products in R

- **Status:** Proposed, revision 2. Merging this file adopts the design as
  the package's `.agents/design.md`; each decision in section 15 stays the
  maintainer's until the package repository records it.
- **Date:** revision 1 2026-10-09; revision 2 2026-10-13.
- **Packages:** `zuexact` (name free on CRAN as of 2026-10-13: the package
  page returns 404; so is `zuxsum`); vendors Radford Neal's `xsum` (MIT); R
  functions use the prefix `xsum_`, with `xsum()` itself as the main entry
  point.
- **Source:** `radfordneal/xsum` at `b766b3e` (2024-11-13, "stable
  version 3"): `xsum.h` (small and large superaccumulators, `add1`, `addv`,
  `add_sqnorm`, `add_dot`, `add_accumulator`, `negate`, `round`, the
  conversions `xsum_large_to_small_accumulator` and
  `xsum_small_to_large_accumulator`, and the division functions
  `xsum_*_div_unsigned` and `xsum_*_div_int`), `xsum.c` (2,526 lines;
  compile-time options listed in §8), `api-doc`, `NEWS`, `LICENSE`; Neal,
  "Fast Exact Summation Using Small and Large Superaccumulators",
  arXiv:1505.05571; the discussion of 2026-10-09 that chose a standalone
  package over adding `xsum` to `zufast` (header-only C99, no compiled
  provider by design) or `zuint`/`decimal` (other types).
- **Prior art read for revision 2** (§3.2 compares them): Julia
  `JuliaMath/Xsum.jl` (Steven G. Johnson); Python `xsum` 2.0.0 on PyPI
  (Yaser Afshar; a header-only C++11 rewrite with NumPy bindings and an MPI
  reduction), `accupy` (Nico Schlömer), `math.fsum` and `math.sumprod` in
  the Python standard library; the TC39 `Math.sumPrecise` proposal (Stage
  3, Kevin Gibbons, who also wrote xsum's fuzzer); the Rust `xsum` crate;
  and CRAN's `PreciseSums` 0.7 (Matthew Fidler), which revision 1 missed.

**What revision 2 changes**, each with its reason in the section named:

1. `PreciseSums` exists on CRAN and its `fsum()` is an exactly rounded
   Shewchuk sum; revision 1 said no such package existed (§3.2).
2. The accumulator exposed to R is a *value* (a classed raw vector holding
   a small accumulator, 560 bytes), not an external pointer: external
   pointers cannot cross the process boundary the streaming use case
   (`mirai`, `parallel`) depends on, and copy semantics is how R works
   (§4, §5, D9). Revision 1 also called the large accumulator "a few
   kilobytes"; it is about 41 KB.
3. One pass over the data, not two: xsum follows IEEE rules for `Inf` and
   `NaN`, so the R-specific scan for `NA` versus `NaN` runs only when the
   rounded result is non-finite (§4).
4. Signed zero: xsum never returns `-0`, nor does base `sum()`; revision 1
   promised `-0` for a sum of `-0`s. Decided: `+0`, no patch (§6, D10).
5. The TwoProduct claim is qualified: exact except when a product
   underflows or overflows, which is the same guarantee Python's
   `math.sumprod()` gives (§9).
6. The vendoring patch is corrected: `USE_SIMD` is *on* upstream and
   already guarded by `__SSE2__`/`__AVX__`; the unconditional `printf`s are
   in the `xsum_*_display` functions, not only under `xsum_debug`;
   `string.h` must stay (§8, D7 revised).
7. Row sums and grouped sums need blocking because R matrices are
   column-major and an accumulator is 560 bytes (§4).
8. `xsum_weighted_mean()` and `xsum_norm()` are described honestly as
   two or three roundings, not one (§2, §5).
9. Complex vectors (base `sum()` accepts them; Xsum.jl sums them
   component-wise) and `xsum_negate()` (exactly rounded differences of
   sums, the reconciliation case) join the v0.1.0 scope (§2, D11).
10. Testing gains the Ogita–Rump–Oishi ill-conditioned generators
    (`accupy` and AccurateArithmetic.jl ship them), `PreciseSums::fsum()`
    as a second independent oracle, and the `Math.sumPrecise` test262
    vectors (§11).
11. The contraction guard is the C99 pragma, with the compiler flag as
    belt and braces (§13).
12. Stage 0 measures the small/large threshold against two published
    values: Neal's "about 1,000" and Xsum.jl's empirical 256 (§8).

## 1. What zuexact is

`zuexact` computes sums of doubles **exactly**, then rounds once to the
nearest double. The result is the correctly rounded value of the true
sum: independent of the order of the elements, of the platform, and of
how R was built.

Base R's `sum()` accumulates in `long double`, which is 80-bit extended
precision on x86-64 Linux and Windows but the same as `double` on Apple
Silicon, on Windows ARM64 and on builds configured without long doubles.
The same `sum()` call can therefore give different results on a laptop
and a server: `sum(c(1e16, 1, -1e16))` is `1` where the accumulator is
80-bit and `0` where it is a plain double, and neither platform gets
`sum(c(1e20, 1, -1e20))` right. For reconciliation, model validation,
regression testing of numerical code and anything audited, that is the
wrong property.

Other languages have settled this. Python has had `math.fsum()` since
2.6 and added `math.sumprod()` in 3.12; JavaScript is standardising
`Math.sumPrecise()` (Stage 3), whose specification mandates "the exact
value rounded once" and leaves the algorithm free; Julia has `Xsum.jl`.
R has `PreciseSums::fsum()`, a port of Python's Shewchuk algorithm, but
nothing built on superaccumulators and nothing that streams or merges.

xsum's superaccumulators make exact summation cheap: the small
accumulator costs a small multiple of a naive loop, and the large one
approaches naive speed on long vectors (Neal's paper measures both;
Xsum.jl's README reports "a few times slower" than Julia's pairwise
`sum`).

The one-line statement that governs every decision below:

> **One rounding, at the end, the same on every machine.**

## 2. Scope

**In v0.1.0:**

- `xsum()`: the exactly rounded sum of numeric, integer, logical and
  complex vectors, with `na.rm`. Complex input is summed as two exact
  sums, real and imaginary (Xsum.jl does the same).
- `xsum_mean()`: the exactly rounded mean (xsum's division of the
  superaccumulator by the count, not `sum / n`).
- `xsum_cumsum()`: each prefix sum exactly rounded.
- `xsum_dot()`: the exactly rounded dot product *including* the products:
  each product is split exactly into its rounded value and error with
  `fma()` (TwoProduct), and both go into the accumulator (§9 states the
  underflow and overflow limits).
- `xsum_sqnorm()`: the exactly rounded squared norm. `xsum_norm()` is its
  square root: two roundings, documented as such.
- `xsum_weighted_mean()`: two exactly rounded sums and one correctly
  rounded division; three roundings, documented as such (§16).
- `xsum_rowsums()`, `xsum_colsums()` for matrices, and `xsum_by()` for
  grouped sums (the shape of base `rowsum()`).
- Accumulators as R values for streaming and parallel work: `xsum_acc()`,
  `xsum_add()`, `xsum_merge()`, `xsum_negate()`, `xsum_value()`,
  `xsum_mean_value()`, so sums over chunks (Arrow batches, DuckDB result
  chunks, files read in pieces, workers in `mirai` or `parallel`) are
  exact and order-independent, and an exactly rounded *difference* of two
  sums costs one merge.
- A registered C table so other packages' C code can use the same
  accumulators (§7).

**Later, when asked:**

- Exactly rounded variance and standard deviation (an exact mean, then
  exactly accumulated squared deviations with the deviation errors
  carried by TwoSum).
- Correctly rounded `exp`, `log`, `pow` from CORE-MATH, the other half of
  "bitwise reproducible numerics".
- Exact `crossprod()` for small matrices.
- `float32` input (Xsum.jl and the Rust crate both decline it today;
  R has no native single-precision vector).

**Never:**

- Arbitrary-precision arithmetic (`Rmpfr`, `gmp`), or exact decimals
  (`decimal`). zuexact works on doubles and returns doubles.
- Compensated-but-inexact methods (Kahan, Neumaier, pairwise, K-fold):
  `PreciseSums` and `accupy` cover that ground, and they contradict the
  one-line statement.

## 3. Position in the `zu*` family

### 3.1 The family rows

| | zuexact |
| --- | --- |
| Role | provider (C table); R API |
| R prefix | `xsum_` (and `xsum()`) |
| Info function | `zuexact_info()` (the package name, as R1 recommends) |
| Root condition class | `zuexact_error` |
| Public C prefix | `zuexact_` for the registered table; internal `zxe_` |
| From C | `R_GetCCallable("zuexact", "zuexact_api_v1")` |
| Hides symbols | yes (R3) |
| Vendored code | `xsum` (MIT) |
| `Depends: R` | 4.1 (R2) |
| Language | en-GB (R2) |

**Relationships, as decided rather than as hoped:**

- **`zufast`** stays header-only C99 and does not carry xsum (its design
  forbids a compiled provider and a function table). If several family
  packages later need exact sums in C, zufast may document zuexact's
  table rather than duplicate it.
- **`zuint`** (RFC 0009) does exact *integer* accumulation in int128;
  zuexact does exact *double* accumulation. They meet in `daffiz`-style
  comparisons and in aggregations over DuckDB and Arrow data.
- **`decimal`** is exact decimal arithmetic; zuexact never converts to
  decimal and never returns anything but doubles.
- **`daffiz`** (numeric regression comparison) and **`qio`** (Parquet
  column statistics) are the first candidate consumers of the C table.

### 3.2 What exists elsewhere, and what zuexact takes from each

| Where | What | Exact? | Streaming / merge | Taken for zuexact |
| --- | --- | --- | --- | --- |
| Base R `sum()`, `mean()`, `cumsum()`, `rowsum()` | `long double` accumulation | no, platform-dependent | no | the function shapes (`...`, `na.rm`) |
| CRAN `PreciseSums` 0.7 (GPL ≥ 2) | `fsum()` (Shewchuk, ported from Python), `kahanSum()`, `neumaierSum()`, `pairwiseSum()`, `psSum()`/`psProd()` with a settable default, C function pointers | `fsum()` yes; the rest no | no | a second, independent exact oracle in tests (§11); its C-pointer export confirms demand for a C-level API |
| Python `math.fsum()` | Shewchuk partials | yes | no | its special-value rules: it *raises* on `Inf − Inf` and on intermediate overflow; zuexact returns `NaN` and `±Inf` instead, as R does |
| Python `math.sumprod()` (3.12) | `fma()` product split into a triple-length accumulator | yes, barring product under/overflow | no | the TwoProduct design of §9 and its stated limits |
| Python `xsum` 2.0.0 (LGPL) | C++11 rewrite of Neal's code; `xsum_add(acc, ndarray)`, `xsum_round(acc)`; classes `xsum_small`/`xsum_large` with `.add()`/`.round()`; an MPI `Allreduce` over accumulators | yes | yes, by reduction over accumulator bytes | accumulators must be *transportable* between processes (§4, D9) |
| Python `accupy` | `kahan_sum`, `fsum`, `ksum(K)`, `fdot`, `kdot`; `generate_ill_conditioned_sum(n, cond)` and `..._dot_product` | `fsum`/`fdot` yes | no | the Ogita–Rump–Oishi generators for tests (§11) |
| Julia `Xsum.jl` | `xsum(itr)`, `xsum(f, itr)`, `XAccumulator` (a *small* accumulator), `accumulate!`, `float()`, `+`/`-`, `negate!`; complex component-wise; threshold 256 | yes | yes, in-process | the accumulator object holds a small accumulator and uses a large one as a temporary for long chunks; complex support; negation; the 256 threshold to measure against |
| Julia `AccurateArithmetic.jl` | `sum_oro`, `sum_kbn`, `dot_oro`, `two_sum`, `two_prod`, `generate_sum(n, cond)` | no (twice working precision) | no | nothing to vendor; its SIMD `dot_oro` is the speed bar for `xsum_dot()` |
| JavaScript `Math.sumPrecise()` (Stage 3) | specification: exact value rounded once; polyfill: Shewchuk with overflow handling; test262 suite | yes | no | the test262 vectors as fixtures (§11); its `-0` rules as the documented alternative to D10 |
| Rust `xsum` crate | `XsumSmall`, `XsumLarge`, `XsumAuto` (switches at runtime), threshold 1,000 | yes | yes, in-process | confirmation that "choose by n" is the common design |
| Neal's `pqR` | xsum inside the interpreter | yes | n/a | the evidence that exact `sum()` is practical in R itself (§18) |
| `Rmpfr`, `gmp` | big numbers | yes | no | the primary oracle (§11) |

No CRAN package provides superaccumulator summation, exact means, exact
dot products, or accumulators that merge across workers.

## 4. Architecture

```text
R vector (double / integer / logical / complex), optional NA removal
   |
   v
xsum (vendored), one pass, blocks read through *_GET_REGION
   - large accumulator when the block count is >= threshold (Stage 0
     measures; Neal says ~1,000, Xsum.jl found 256), small below
   - na.rm = TRUE: a block containing NaN is fed element-wise, skipping
   |
   v
round once  (xsum_*_round, or xsum_*_div_unsigned for means)
   |
   v
finite?  --yes-->  double result
   |
   no
   v
rescan for R's special values (§6): NA vs NaN vs Inf; decide the result
```

- **One pass in the common case.** xsum applies IEEE rules to `Inf` and
  `NaN` itself (api-doc), so the only R-specific work, telling `NA_real_`
  from other `NaN`s, is deferred until the result is non-finite. The
  rescan is cheap and rare.
- **ALTREP** vectors (compact sequences, wrappers) are read through
  `REAL_GET_REGION`/`INTEGER_GET_REGION` in blocks, never materialised.
- **Integers and logicals** are converted to double exactly (every int32
  is representable) and summed by the same path; results are always
  double. **Complex** vectors are two sums over the interleaved storage.
- **Accumulator sizes** govern the rest. A small accumulator is 67
  64-bit chunks plus `Inf`, `NaN` and a counter: 560 bytes. A large
  accumulator is 4,096 chunks, 4,096 16-bit counts, used-flags and an
  embedded small accumulator: about 41 KB. Both are plain memory with no
  pointers.
- **The R accumulator is a value.** `xsum_acc` objects are classed raw
  vectors holding one small accumulator behind an 8-byte header (magic,
  layout version, endianness). `xsum_add(acc, x)` copies 560 bytes and
  returns the new value; a long `x` is summed into a stack-allocated large
  accumulator, converted with `xsum_large_to_small_accumulator()` and
  merged (Xsum.jl's pattern). Values serialise, so an accumulator built
  on a `mirai` or `parallel` worker travels back and merges on the
  caller; an external pointer would not survive the trip. Copy-on-modify
  also means no finaliser, no aliasing surprises and `Reduce(xsum_merge,
  accs)` as the natural parallel reduction (the MPI pattern in the Python
  binding).
- **Row sums over column-major storage.** One accumulator per row would
  cost 560 bytes × `nrow`, so `xsum_rowsums()` processes rows in blocks
  of 1,024 (560 KB of accumulators) and walks each column's slice of the
  block. A 1e7 × 3 matrix needs under 10 MB beyond its result
  (`test-matrix.R`). Measured 2026-10-13 on macOS ARM64, 1e6 × 10
  doubles: `xsum_rowsums()` 0.26 s, `xsum_colsums()` 0.06 s (`rowSums()`
  0.003 s, `colSums()` 0.009 s). Row sums are dominated by initialising
  and rounding one accumulator per row, about 250 ns a row; column sums are
  long vectors and use the large accumulator. `xsum_by()` keeps one
  accumulator per group and column while there are at most 16,384 such
  cells (9 MB), in one pass; above that it counting-sorts the rows by
  group and sums each group's run as one vector. On 1e6 doubles it takes
  0.026 s with 10 or 1,000 groups, 0.048 and 0.050 s either side of the
  switch, 0.115 s with 1e5 groups and 0.156 s with 1e6 (`rowsum()`: 0.010,
  0.009, 0.030, 0.030, 0.088 and 0.072 s). `tools/bench/matrix.R`
  reproduces these.
- **Cumulative sums** round after every element; a round scans the
  chunks, so `xsum_cumsum()` is O(n × chunks) and is documented as the
  slowest function in the package (§12).

## 5. Public R API (complete v0.1.0 surface)

```r
xsum(..., na.rm = FALSE)
xsum_mean(x, na.rm = FALSE)
xsum_weighted_mean(x, w, na.rm = FALSE)   # three roundings, documented
xsum_cumsum(x)
xsum_dot(x, y)
xsum_sqnorm(x); xsum_norm(x)              # norm: two roundings, documented
xsum_rowsums(x, na.rm = FALSE); xsum_colsums(x, na.rm = FALSE)
xsum_by(x, group, na.rm = FALSE)          # like rowsum(), exact

acc <- xsum_acc(x = NULL)                 # a value; optional initial data
acc <- xsum_add(acc, x)                   # returns the new accumulator
acc <- xsum_merge(acc, other)             # exact merge of two accumulators
acc <- xsum_negate(acc)                   # so merge(a, negate(b)) is a - b
xsum_value(acc); xsum_mean_value(acc, n)  # round, without consuming
as.double(acc); print(acc)                # S3 methods on class "xsum_acc"

zuexact_info()                            # xsum version, threshold, SIMD, FMA
```

`xsum()` takes `...` like `sum()`, so `xsum(a, b, c)` is the exact sum of
all elements. Every function returns a double (or a complex, double vector
or matrix of the natural shape). `xsum_mean_value()` takes the count
explicitly because an accumulator does not record how many terms it has
absorbed; `xsum_add()` on an accumulator does not either, deliberately,
so that merging stays a pure accumulator addition.

## 6. Special values

R distinguishes `NA_real_` (a NaN with payload 1954) from other NaNs,
and its `sum()` propagates them in ways that depend on the platform.
zuexact makes the rules explicit and identical everywhere:

| Input contains (and `na.rm = FALSE`) | Result |
| --- | --- |
| nothing (`xsum()` of an empty vector) | `0` (base `sum()`; `Math.sumPrecise([])` chooses `-0`) |
| any `NA` | `NA_real_` |
| no `NA`, any other `NaN` | `NaN` |
| `+Inf` and `-Inf` | `NaN` (Python's `fsum` raises here; R does not raise on arithmetic) |
| `+Inf` only (with finite values) | `+Inf` |
| `-Inf` only | `-Inf` |
| finite values, exact sum out of range | `±Inf` (correct rounding; `fsum` raises "intermediate overflow") |
| only zeros, any signs | `+0` (D10) |
| `xsum_mean()` of an empty vector | `NaN` (base `mean()`; xsum's division by zero of a zero accumulator) |

`na.rm = TRUE` removes `NA` and `NaN`, as base `sum()` does.

**Signed zero (D10).** xsum's rounding never returns `-0` (api-doc:
"negative zero is not representable"), and base `sum(-0)` is `+0` because
the accumulator starts at `+0`. Revision 1 promised IEEE's `-0` for a sum
of `-0`s; that would need a flag in the summation loop and a patch to the
vendored rounding for no user who has asked. Decided: `+0` always,
documented, with `Math.sumPrecise` and `math.fsum` (both return `-0`)
named as the alternative convention.

**Accumulator overflow.** Neal's api-doc: finite additions cannot overflow
a superaccumulator before 2^45 of them, after which it becomes a NaN with
an all-ones payload. One `xsum()` call cannot reach that; a streaming
accumulator fed 2^45 ≈ 3.5 × 10^13 terms could. `xsum_value()` recognises
the all-ones payload and signals `zuexact_internal_error` rather than
returning a NaN that looks like data.

## 7. The C table

```c
/* inst/include/zuexact.h; registered with
   R_RegisterCCallable("zuexact", "zuexact_api_v1", ...) */
typedef struct zuexact_api {
  size_t struct_size;
  size_t acc_size;                       /* bytes for one accumulator */
  void   (*init)(void *acc);
  void   (*add1)(void *acc, double x);
  void   (*addv)(void *acc, const double *x, ptrdiff_t n);
  void   (*add_dot)(void *acc, const double *x, const double *y,
                    ptrdiff_t n);         /* exact, with TwoProduct (§9) */
  void   (*merge)(void *acc, const void *other);
  void   (*negate)(void *acc);
  double (*round)(const void *acc);
  double (*div)(const void *acc, unsigned n); /* exactly rounded acc / n */
} zuexact_api;

static inline const zuexact_api *zuexact_api_get(void);  /* in the header */
```

- What is registered is a function returning the table, not the table:
  converting a data pointer to `DL_FUNC` is not ISO C, and `-pedantic`
  warns. `zuexact_api_get()` in the header hides this.
- The accumulator is opaque memory of `acc_size` bytes (a small
  accumulator, 560), aligned as a double, so a consumer can place one on
  the stack, in a column-statistics struct or in an array of thousands
  without seeing xsum's struct; the table follows `zuxml`'s versioning
  rules (append members; bump the name for any layout change).
- `addv` and `add_dot` use a large accumulator, from `malloc()`, when `n`
  is at or above the threshold, then fold it into the caller's small one;
  if `malloc()` fails they use the small one, slower but exact.
- `round` and `div` work on a copy, because xsum's rounding may propagate
  carries in place: the caller's accumulator is untouched, so several
  threads may read one accumulator that none is writing. `merge` copies
  `other` for the same reason.
- Pure functions on caller memory: safe from any thread, including
  OpenMP workers in a consumer, each with its own accumulator. (Neal's
  api-doc is silent on threads; the code has no global state outside the
  debug flag, which the patch removes.)
- Special values follow IEEE rules, not R's (§6): the table does not tell
  `NA` from other NaNs and has no `na.rm`. The R functions apply R's rules
  on top; a consumer that needs them tracks `NA` itself.
- The bytes after an `xsum_acc` header are exactly the memory this table
  operates on, so a consumer can hand an accumulator to R and back.
- `tools/zuexacttest` is a consumer package; the `consumer.yaml` workflow
  installs zuexact and it on Linux, macOS and Windows, R CMD checks it and
  runs its tests.

## 8. The vendored library, as zuexact uses it

- `xsum.c`, `xsum.h` and `LICENSE` at the 2024-11-13 stable version
  (`stable-version-3`, commit `b766b3e`) in `src/vendor/xsum/`; the MIT
  notice is repeated in `inst/COPYRIGHTS`. `tools/vendor/manifest.tsv`
  records the commit and the SHA-256 of each upstream file, and
  `tools/vendor/checksums.sha256` the SHA-256 of each file as installed.
  `tools/vendor/fetch` rebuilds the tree from upstream; `tools/vendor/verify`
  checks that upstream at the pinned commit plus exactly the patches in
  `tools/patches/xsum/` reproduces it (the layout r-actions' `vendor.yml`
  expects).
- **Compile-time options stay at upstream defaults.** `USE_SIMD` is `1`
  upstream, and every SIMD path is additionally guarded by `__SSE2__`
  (always defined on x86-64) or `__AVX__` (never defined under CRAN's
  baseline flags). So the build is already portable: SSE2 code on
  x86-64, scalar code on ARM64, nothing to switch off. Revision 1 planned
  to set `USE_SIMD` to `0`; that would only slow x86-64. Stage 1 measures
  whether an AVX2 copy with runtime dispatch (the same function compiled
  twice with `target` attributes) is worth adding; Neal's NEWS calls the
  SIMD gains "typically small".
- **One patch, `tools/patches/xsum/0001-no-stdio-exact-only.patch`.** The
  `#include <stdio.h>` becomes conditional on `DEBUG`; without it, `printf`
  and the two display routines are no-op macros, so the debug-only calls
  (dead code under upstream's own `#define xsum_debug 0`) compile to
  nothing at any optimisation level. The global `xsum_debug` variable
  exists only under `DEBUG`. Everything after the exact routines is
  removed: the non-exact comparison routines (`xsum_sum_double`,
  `xsum_sum_kahan`, `xsum_sum_float128`, the `_not_ordered`, `sqnorm` and
  `dot` variants) and the debugging routines (`xsum_*_display()`, which
  call `printf` unconditionally, and `xsum_*_chunks_used()`), with their
  declarations in `xsum.h`. `string.h` stays: the default `USE_MEMSET_*`
  paths and `COPY64` need `memset()` and `memcpy()`. The result compiles
  without warnings under `-Wall -Wextra -pedantic` and links only
  `memcpy`, `memset` (and the stack protector); `test-abi.R` checks no
  stdio symbol reaches `zuexact.so`.
- **Threshold, measured 2026-10-13.** Neal's api-doc says the large
  accumulator wins "when summing more than about 1,000 numbers at once";
  Xsum.jl measured 256; the Rust crate uses 1,000. `tools/run-benchmarks`
  (init, `addv` and round for each method, `-O2`, exponents spread over
  2^±20) gave, on the CI runners:

  | Platform | Crossover n | large / small at n = 128 | at n = 384 |
  | --- | ---: | ---: | ---: |
  | Linux x86-64, gcc | 192 | 1.04 | 0.54 |
  | Windows x86-64, gcc (Rtools) | 96 | 0.77 | 0.38 |
  | macOS ARM64, clang | 384 | 2.03 | 0.73 |

  The constant is chosen per architecture at compile time, since it
  changes speed and never the result: **384 on ARM64, 128 elsewhere**,
  which keeps the worst slowdown on any measured platform near 30%. A
  single constant cannot do better than about 1.5× somewhere. `zuexact_info()`
  reports the value in use. At n = 10^6 the large accumulator costs
  0.4–0.8 ns per element, the small one 3.7–5.8.
- **AVX2 (D7), decided 2026-10-13: no.** The same benchmark built with
  `-mavx2` is within noise of the baseline on both x86-64 runners (Linux
  0.41 versus 0.41 ns per element at n = 10^6; Windows 0.70 versus 0.68),
  because xsum's AVX code only touches carry propagation and the
  initialisation paths that `USE_MEMSET_*` already replaces. No runtime
  dispatch is added.
- Upstream's `xsum-check.c` and its fuzzer run in CI against the vendored,
  patched copy, compiled without `DEBUG` exactly as the package compiles
  it (`tools/xsum-check/run`, workflow `xsum-check.yaml`, on Linux, macOS
  and Windows). The test programs are fetched from upstream at the pinned
  commit, not vendored; a two-function shim supplies the debug symbols
  the checker references but never calls.

## 9. TwoProduct and FMA

`xsum_dot()` computes each product `p = x[i] * y[i]` and its exact error
`e = fma(x[i], y[i], -p)`, then adds both to the accumulator. Upstream's
`add_dot` sums only the rounded products (api-doc: the accumulator holds
"the exact sum of those rounded products, not the exact dot product");
Python's `math.sumprod()` does what zuexact does, with the same `fma()`
split. The result is the correctly rounded exact dot product under two
documented conditions:

- **No product underflows.** The error term `e` is exact only while
  `x·y` stays above about 2^-970 in magnitude (Boldo and Muller's bound
  for binary64); below that the low bits of the error fall off the bottom
  of the double range. Products of ordinary data never go there; the
  documentation states the limit, and the rational oracle (§11) checks it
  with inputs that cross it.
- **No product overflows.** A single `x·y` beyond `DBL_MAX` is `±Inf` and
  the result is `±Inf` (or `NaN`, per §6) even if the exact dot product is
  finite. Rescaling is out of scope; documented.

**Where the error term comes from (revised 2026-10-13).** Revision 2
assumed `fma()` is correct on every platform. It is not: the mingw-w64 C
runtime used by Rtools on Windows returned wrong error terms, caught by the
ill-conditioned dot-product oracle in Stage 7. So `src/zxe_twoprod.h` uses
`fma()` only when the compiler reports a hardware fused multiply-add
(`FP_FAST_FMA`: ARM64, and x86-64 built for an FMA-capable CPU). Otherwise
it uses Dekker's TwoProduct with Veltkamp's splitting, which needs only
correctly rounded multiplication and addition; an operand above 2^995 is
scaled by 2^-53 first so the split cannot overflow. Both branches agree bit
for bit on 9.5 million products across the exponent range (checked against
hardware `fma()` on ARM64), and the oracle tests run both, depending on the
CI leg. `zuexact_info()$fma_hardware` reports which branch the build uses.

## 10. Errors

Every condition inherits `zuexact_error`:

- `zuexact_invalid_argument`: non-numeric input, mismatched lengths in
  `xsum_dot()` and `xsum_weighted_mean()`, a group of the wrong length,
  a non-matrix to `xsum_rowsums()`.
- `zuexact_count_error`: a mean over more than 2^32 − 1 elements, which
  xsum's division does not cover (§16).
- `zuexact_accumulator_error`: an `xsum_acc` whose header does not match
  this build's layout version or endianness, for example one serialised
  on a big-endian machine.
- `zuexact_internal_error`: accumulator overflow (§6) and anything that
  should not happen.

## 11. Testing

- **Oracle**: exact rational arithmetic with `gmp::as.bigq()` (Suggests)
  over random vectors and adversarial ones; the result must equal the
  correctly rounded rational sum, bit for bit.
- **Second oracle**: `PreciseSums::fsum()` (Suggests), an independent
  exact algorithm; cheaper than `gmp`, so it runs over far more random
  inputs. Any disagreement is a bug in one of the two packages and is
  settled by the rational oracle.
- **Ill-conditioned generators**: the Ogita–Rump–Oishi algorithm for
  sums and dot products of a prescribed condition number, as shipped by
  `accupy` (`generate_ill_conditioned_sum`,
  `generate_ill_conditioned_dot_product`) and AccurateArithmetic.jl
  (`generate_sum`), reimplemented in `tests/testthat/helper-illcond.R`.
  These are the inputs on which compensated methods fail and an exact
  method must not.
- **Order independence**: every vector summed in many random orders gives
  the same bits.
- **Hard cases**, permanent: `c(1e308, 1e308, -1e308)` (intermediate
  overflow, finite exact sum); `c(1e20, 1, -1e20)`; sums of subnormals;
  `c(1e16, 1, -1e16)` (platform-dependent in base R); `-0` only (§6);
  mixtures of `NA`, `NaN` and infinities per §6; the two cases fixed
  upstream in 2024 (`-DBL_MAX - 1` and the small `add_dot` term); the
  TC39 test262 vectors for `Math.sumPrecise` (tc39/test262 PR 4049),
  imported as a fixture file with their licence, differing only in the
  `-0` rows (D10).
- **Cross-platform identity**: CI on x86-64 Linux, Windows and macOS
  ARM64 writes the bits of every fixture result; they must be identical.
- **Streaming**: `xsum_add()` over chunks and `xsum_merge()` across
  workers equal `xsum()` of the whole; an accumulator survives
  `serialize()`/`unserialize()` and a round trip through a `parallel`
  worker; `xsum_merge(a, xsum_negate(b))` equals the rational difference.
- **Complex**: real and imaginary parts each equal the oracle.
- Upstream's `xsum-check` and fuzzer in CI; `zufuzz` on the R entry
  points; CRAN suite under 15 s.

## 12. Performance targets

Targets, and what was measured on 2026-10-13 (macOS ARM64, R 4.6.1, the
installed package built at `-O2`; `tools/bench/functions.R`, median of
seven runs on 1e7 doubles unless stated):

| Operation | Target | Measured | Baseline |
| --- | --- | ---: | ---: |
| `xsum()` | within 3× of `sum()` | 0.024 s (1.5×) | `sum()` 0.016 s |
| `xsum_mean()` | — | 0.023 s | `mean()` 0.019 s |
| `xsum_dot()` | within 4× of `crossprod()` | 0.049 s (2.5×) | `crossprod()` 0.020 s |
| `xsum_merge()`, one call | one accumulator addition | 4 µs, mostly R call overhead | — |
| `xsum_cumsum()`, 1e6 | recorded, not targeted | 0.073 s | `cumsum()` 0.001 s |

- A plain double loop in byte-compiled R takes 0.167 s on the same data, so
  the honest "plain double" baseline is base `sum()` itself on this
  platform, where `long double` is `double`. On x86-64, base `sum()` runs
  x87 arithmetic and is slower, which only flatters `xsum()`.
- `xsum_dot()` costs a product split (`p = x*y`, `e = fma(x, y, -p)`) and
  twice as many terms; in C alone the split and both additions take 17 ms
  on 1e7 pairs, so the rest is memory traffic through R's vectors.
- Measure from an installed package: `devtools::load_all()` compiles at
  `-O0`, which doubled `xsum_dot()`'s time when first measured.
- Row, column and grouped sums are measured in §4.

## 13. Build, portability and CRAN

C99; `#pragma STDC FP_CONTRACT OFF` at the top of `src/zxe_dot.c`, the
file holding zuexact's own TwoProduct code (the C99 guarantee that
`p = x*y` and `fma(x, y, -p)` are not fused into one operation, which would
make `e` zero), with the two kept as separate statements so that no
expression holds both a multiply and an add; GCC, which ignores the pragma,
contracts only a multiply whose every use is an addition, and `p` is also
stored and negated. Revision 2 also planned `-ffp-contract=off` in
`PKG_CFLAGS`; R CMD check reports every `-f` flag there as non-portable, so
it is not used (2026-10-13). `test-dot.R` carries a canary that fails if the
error term is lost. Hidden visibility; `R_init_zuexact` the only export;
the C table registered. Stage 0 measures the small/large threshold, the
AVX2 question (§8), and the effect of CRAN's `-O2` flags on xsum's
manually optimised loops.

## 14. Roadmap

| Stage | Title | Size |
| --- | --- | --- |
| 0 | Identity; vendor and patch xsum; thresholds; benchmarks harness | S |
| 1 | `xsum()` for double, integer, logical, complex; special values; ALTREP-aware reading | M |
| 2 | Means, cumulative sums, dot products with TwoProduct, norms, weighted means | M |
| 3 | Matrices with row blocking, grouped sums, accumulator values, the C table | M |
| 4 | Oracles, ill-conditioned generators, test262 vectors, order and cross-platform tests; benchmarks | M |
| 5 | Documentation and release 0.1.0 | S |

## 15. Decisions

| # | Question | Decision |
| --- | --- | --- |
| D1 | Home | standalone package, not `zufast` |
| D2 | R names | `xsum()` and the `xsum_` prefix |
| D3 | Dot products | exact, with TwoProduct, beyond upstream's `add_dot`; limits of §9 documented |
| D4 | Special values | the explicit rules of §6, the same on every platform |
| D5 | Return type | always double (complex for complex input) |
| D6 | Provider | a registered, versioned C table with opaque accumulators |
| D7 | SIMD | upstream defaults (`USE_SIMD` on, guarded by `__SSE2__`/`__AVX__`); an AVX2 runtime-dispatched copy only if Stage 0 shows a gain |
| D8 | Info function | `zuexact_info()`, the package name (R1) |
| D9 | Accumulator object | a value: classed raw vector, small accumulator behind an 8-byte header; serialisable; copy-on-modify; no external pointer |
| D10 | Signed zero | `+0` always, as xsum and base `sum()` do; `-0` conventions of `fsum` and `Math.sumPrecise` documented as the alternative |
| D11 | Complex and negation | in v0.1.0 scope |
| D12 | The name | `zuexact` (free on CRAN, 2026-10-13); leaves room for later CORE-MATH functions under their own prefix |

## 16. Open questions

1. **Means beyond 2^32 − 1 elements.** xsum divides by a 32-bit count.
   Use an exact long division of the superaccumulator by a 64-bit count
   (a small addition to the vendored code), or round the sum and divide
   once (one extra rounding, documented)? Recommended: the exact 64-bit
   division, contributed upstream.
2. **Integer input.** Return an integer, as base `sum()` does for
   integers, when the exact result fits? Recommended: no; always double,
   so the type never depends on the values.
3. **Weighted mean.** Ship `xsum_weighted_mean()` with its documented
   three roundings, or leave it out until an exact ratio of two
   superaccumulators exists (which xsum does not provide and which would
   be new numerics)? Recommended: ship it, documented; it is still far
   better than `sum(w * x) / sum(w)` and the name does not claim more
   than `mean()` does.
4. **Accumulator byte layout.** Store the struct bytes as they are
   (little-endian, this build's layout; the header refuses anything else),
   or define a canonical cross-endian encoding? Recommended: struct bytes
   with the header; every CRAN platform is little-endian and a
   mixed-endian cluster has not been seen.

## 17. Acceptance criteria for v0.1.0

1. `R CMD check --as-cran` clean on every CI leg; no stdio symbol.
2. Every result equals the correctly rounded exact value against the
   rational oracle, on random, ill-conditioned (§11) and adversarial
   inputs, and agrees with `PreciseSums::fsum()` on every random input.
3. Results are bit-identical across the CI platforms and across element
   orders.
4. The special-value table of §6 has a test per row, and the test262
   vectors pass apart from the documented `-0` rows.
5. An accumulator serialised on a `parallel` worker merges correctly on
   the caller.
6. The C table is consumed by a fixture package in CI.

## 18. What this RFC does not decide

- Whether to propose exact summation to R itself (for example an
  `exact =` argument to `sum()`). Neal's pqR did it; a working package
  is the evidence either way.

Review prepared with assistance from generative AI.
