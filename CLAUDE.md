# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

## Shared conventions

The portfolio’s shared rules are synced into `.claude/shared/` from
`pedrobtz/packages:claude/shared/`. Never edit them here. Where this
file and a shared file disagree, this file wins for this package.

@.claude/shared/workflow.md @.claude/shared/r-package.md
@.claude/shared/ci.md @.claude/shared/native-code.md
@.claude/shared/correctness.md @.claude/shared/assurance.md

## What this is

zuexact computes sums of doubles exactly and rounds once, so results are
the correctly rounded true value on every platform and in every element
order. It vendors Radford Neal’s `xsum` (MIT) and exposes it as R
functions with the `xsum_` prefix
([`xsum()`](https://pedrobtz.github.io/zuexact/reference/xsum.md) itself
is the main entry point) and as a registered C table for other packages.
Zero hard runtime dependencies. It never does arbitrary precision,
decimals, or compensated-but-inexact summation (Kahan and friends live
in `PreciseSums`).

[`.agents/design.md`](https://pedrobtz.github.io/zuexact/.agents/design.md)
is the specification and
[`.agents/roadmap.md`](https://pedrobtz.github.io/zuexact/.agents/roadmap.md)
the plan to 0.1.0. They outrank this file: `CLAUDE.md` orients, the
design decides.

## Current state

0.1.0 is on CRAN, published 2026-10-22; `main` is at `0.1.0.9000`
(verified 2026-11-11). Exported:
[`xsum()`](https://pedrobtz.github.io/zuexact/reference/xsum.md),
[`xsum_mean()`](https://pedrobtz.github.io/zuexact/reference/xsum_mean.md),
[`xsum_weighted_mean()`](https://pedrobtz.github.io/zuexact/reference/xsum_weighted_mean.md),
[`xsum_cumsum()`](https://pedrobtz.github.io/zuexact/reference/xsum_cumsum.md),
[`xsum_dot()`](https://pedrobtz.github.io/zuexact/reference/xsum_dot.md),
[`xsum_sqnorm()`](https://pedrobtz.github.io/zuexact/reference/xsum_dot.md),
[`xsum_norm()`](https://pedrobtz.github.io/zuexact/reference/xsum_dot.md),
the accumulator values
([`xsum_acc()`](https://pedrobtz.github.io/zuexact/reference/xsum_acc.md),
[`xsum_add()`](https://pedrobtz.github.io/zuexact/reference/xsum_acc.md),
[`xsum_merge()`](https://pedrobtz.github.io/zuexact/reference/xsum_acc.md),
[`xsum_negate()`](https://pedrobtz.github.io/zuexact/reference/xsum_acc.md),
[`xsum_value()`](https://pedrobtz.github.io/zuexact/reference/xsum_acc.md),
[`xsum_mean_value()`](https://pedrobtz.github.io/zuexact/reference/xsum_acc.md)),
[`xsum_rowsums()`](https://pedrobtz.github.io/zuexact/reference/xsum_rowsums.md),
[`xsum_colsums()`](https://pedrobtz.github.io/zuexact/reference/xsum_rowsums.md),
[`xsum_by()`](https://pedrobtz.github.io/zuexact/reference/xsum_rowsums.md)
and
[`zuexact_info()`](https://pedrobtz.github.io/zuexact/reference/zuexact_info.md),
plus the registered C table `zuexact_api_v1` (`inst/include/zuexact.h`).
Results are proven against exact rationals,
[`PreciseSums::fsum()`](https://rdrr.io/pkg/PreciseSums/man/fsum.html),
the test262 vectors and ill-conditioned inputs, and must be
bit-identical on every CI leg.

## Versions and dependents

The current version’s parent issue is [v0.1.1
(#25)](https://github.com/pedrobtz/zuexact/issues/25). The 0.1.0 parent
was [\#2](https://github.com/pedrobtz/zuexact/issues/2) and its
submission issue [\#12](https://github.com/pedrobtz/zuexact/issues/12).
No sibling depends on zuexact yet; `daffiz` and `qio` are the candidate
consumers of the C table, which is why it is append-only (see
Invariants).

**Merges are merge commits.** The repository ruleset on `main` requires
pull requests and allows only the merge method; squash is refused.

## Commands

Run from the package root. The everyday `devtools` loop is in
`.claude/shared/r-package.md`; these are the package’s own.

``` sh
tools/vendor/verify                  # vendored tree == upstream + patches
tools/xsum-check/run [iters [seed]]  # upstream checker and fuzzer
tools/run-benchmarks                 # small/large threshold (C, no R)
R CMD INSTALL .                      # benchmarks need an installed build
Rscript -e 'library(zuexact); source("tools/bench/functions.R")'
Rscript -e 'library(zuexact); source("tools/bench/matrix.R")'
tools/write-bits                     # rewrite the bits fixture (rarely)
ZUEXACT_SLOW_TESTS=true Rscript -e 'devtools::test()'  # wider oracle sweeps
```

The `tools/` scripts are for vendoring changes and need `curl` and a C
compiler.

## Invariants that are easy to break

- **One pass, then a rescan only when the result is not finite**
  (`src/zxe_sum.c`). The rescan must skip exactly what `na.rm = TRUE`
  removed, including a complex element dropped because its *other* part
  is `NaN`; it once did not, and `xsum(c(NA, Inf), na.rm = TRUE)` gave
  `NA`.
- **An `xsum_acc` is 568 raw bytes**: an 8-byte header (magic `ZXAC`,
  layout version, byte order, special-value flags) and one xsum small
  accumulator (`src/zxe_accval.c`). R’s `NA`/`NaN` distinction lives in
  the header flags, because xsum keeps a single NaN by payload. Changing
  the layout means bumping the version byte; the C table (Stage 6)
  operates on the same bytes. Locals are zeroed before use so no
  uninitialised padding is serialised.
- **Benchmark an installed package, never `load_all()`**, which compiles
  at `-O0`: it doubled
  [`xsum_dot()`](https://pedrobtz.github.io/zuexact/reference/xsum_dot.md)’s
  time when first measured.
- **`R_FINITE()` is a function call in package code** (`R_finite()`);
  hot loops use C99 `isfinite()`.
- **`tests/testthat/fixtures/bits.txt` is the cross-platform contract.**
  A changed line is a portability bug, never a reason to rerun
  `tools/write-bits`; that tool is for adding cases.
- **Cross-platform inputs never come from decimal literals that are not
  exact.** R’s own parser differs between builds: on macOS ARM64 (no
  long double) `1e308` reads as `0x1.1ccf385ebc8a3p+1023`, three ulps
  from the correctly rounded `…8a0` that Linux gives. That broke the
  bits test once (2026-10-13). Build such inputs from bit patterns
  (`from_hex()`).
- **`ALTREP()` decides how a vector is read.** ALTREP vectors go through
  `*_GET_REGION` into a stack block; `REAL_RO()` on one would
  materialise it.
- **One rounding.** Every function rounds the exact value once, except
  where its documentation states the count
  ([`xsum_norm()`](https://pedrobtz.github.io/zuexact/reference/xsum_dot.md)
  two,
  [`xsum_weighted_mean()`](https://pedrobtz.github.io/zuexact/reference/xsum_weighted_mean.md)
  three). Never add an intermediate `double` between accumulation and
  the final round.
- **`zuexact.so` exports `R_init_zuexact` only** (`$(C_VISIBILITY)` in
  `src/Makevars` and `src/Makevars.win`), and links no stdio, `abort`,
  `exit` or RNG symbol. `tests/testthat/test-abi.R` audits both on Linux
  and macOS.
- **The C table is append-only** (`inst/include/zuexact.h`). Add members
  at the end and let `struct_size` tell consumers; any other change is a
  new name, `zuexact_api_v2`. `tools/zuexacttest` is the consumer that
  proves it (`consumer.yaml`).
- **Never trust a software `fma()`.** mingw-w64’s (Windows, Rtools) gave
  wrong error terms. `src/zxe_twoprod.h` uses `fma()` only under
  `FP_FAST_FMA` and Dekker’s splitting otherwise; define `ZXE_NO_FMA` to
  test the Dekker branch on a machine with hardware FMA.
- **TwoProduct must not be contracted** (design §9, §13). The files that
  include `zxe_twoprod.h` (`zxe_dot.c`, `zxe_api.c`) carry
  `#pragma STDC FP_CONTRACT OFF` and keep `p = x*y` and
  `e = fma(x, y, -p)` in separate statements. `-ffp-contract=off` cannot
  be used: R CMD check reports `-f` flags as non-portable.
- **Symbol prefixes.** Internal C symbols are prefixed `zxe_`; the
  public C table and header use `zuexact_`.
- **Condition classes** are named `zuexact_<kind>`, for example
  `zuexact_invalid_argument`, not the `<pkg>_<kind>_error` pattern of
  `.claude/shared/r-package.md`. Tests assert on these classes.
- **Prose is en-GB**, in roxygen and Markdown alike.

## Testing

- **Oracles before hand-written cases** (design §11): exact rationals
  with `gmp` (`helper-oracle.R`),
  [`PreciseSums::fsum()`](https://rdrr.io/pkg/PreciseSums/man/fsum.html),
  the `Math.sumPrecise` test262 vectors (`fixtures/sumprecise/`, as bit
  patterns), and the Ogita–Rump–Oishi ill-conditioned generators
  (`helper-illcond.R`). `ZUEXACT_SLOW_TESTS=true` widens every sweep and
  `ZUEXACT_SKIP_HEAVY=true` (set by the gctorture leg) shrinks it to two
  inputs (family rule R7, `sweep_reps()` in `helper-illcond.R`).
- **Keep the CRAN suite under 15 s.** It ran in 6.6 s on 2026-10-13
  (macOS ARM64, CRAN settings).
- **Helpers** live in `tests/testthat/helper-*.R`: `helper-abi.R` reads
  the shared object’s exported and undefined symbols with `nm`;
  `helper-vendor.R` defines `selftest()`, which sums through both xsum
  accumulators directly; `helper-data.R` makes random matrices spread
  over 80 binades; `helper-oracle.R` holds the exact rational oracle
  (`exact_sum()`, `exact_dot()`), whose `round_bigq()` exists because
  gmp’s [`as.double()`](https://rdrr.io/r/base/double.html) truncates
  instead of rounding.
- **Done includes the `nold` leg** (R without long doubles) being green:
  it is the leg this package exists for.

## Continuous integration

Workflows call `pedrobtz/r-actions`: `R-CMD-check.yaml`
(`r-cmd-check.yml@v1`, `nold: true`), `coverage.yaml` (`coverage.yml`,
pinned to a commit because it holds a write token; badge on `gh-pages`
because `main` takes no direct pushes), `native-checks.yaml`
(sanitizers, valgrind, LTO, gctorture, rchk, analyzers, CRAN special
checks), `vendor.yaml`, `vendor-upstream.yaml` (weekly), and
`xsum-check.yaml` (upstream’s checker, fuzzer and the threshold
benchmark on three OSes, outside R), `consumer.yaml` (the C table from
`tools/zuexacttest`) and `fuzz.yaml` (libFuzzer on
`tools/fuzz/fuzz_xsum.c`: two minutes on pull requests, 30 minutes
weekly on Sundays). `pkgdown.yaml` deploys with `force: false` so it
does not overwrite the badge commit.

**Deviation from `.claude/shared/ci.md`:** `R-CMD-check.yaml` and
`native-checks.yaml` choose the profile themselves rather than passing
`profile: auto`. They run quick on pull requests and **full on every
push to `main`**, so a merge does start the full set here. The `full-ci`
label runs the full profile on a pull request.

## Vendored native code

`xsum` by Radford M. Neal, MIT, pinned at tag `stable-version-3`, commit
`b766b3e` (2024-11-13), in `src/vendor/xsum/`.
`tools/vendor/manifest.tsv` pins it; `tools/vendor/checksums.sha256`
records the installed files; the one local patch is
`tools/patches/xsum/0001-no-stdio-exact-only.patch`. Never edit
`src/vendor/` by hand: change the patch and run `tools/vendor/fetch`.
The `vendor.yaml` workflow rejects a pull request that changes the tree
without the manifest and checksums, and `vendor-upstream.yaml` opens an
issue weekly when upstream tags a newer stable version.
