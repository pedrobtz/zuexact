# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working
with code in this repository.

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

Verified 2026-10-13: Stages 0 to 4. Exported:
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
[`zuexact_info()`](https://pedrobtz.github.io/zuexact/reference/zuexact_info.md).
xsum is vendored, patched, and checked by upstream’s own checker and
fuzzer. The C table for other packages is not built yet (Stage 6).

## Stage tracking

Progress toward 0.1.0 is tracked as GitHub sub-issues of [v0.1.0
(#2)](https://github.com/pedrobtz/zuexact/issues/2); submission is
[\#12](https://github.com/pedrobtz/zuexact/issues/12).

- **One sub-issue per roadmap stage**, titled as the roadmap titles it
  and linking to that section. Every tracking issue carries the `stage`
  label.
- **Close a stage by merging its pull request** with `Closes #<n>` in
  the body. Never close a stage whose exit criteria are not met; record
  a deviation in the roadmap first.
- **The roadmap stays authoritative.** Adding, removing or renaming a
  stage means editing the roadmap and the sub-issues in the same change.
- **Merges are merge commits.** The repository ruleset on `main`
  requires pull requests and allows only the merge method; squash is
  refused.

## Versioning

Develops at `0.0.0.9000` and targets `0.1.0` for its first CRAN release.
Set `Version: 0.1.0` and the matching `NEWS.md` heading in the last
roadmap stage. Bump to `0.1.0.9000` only after CRAN accepts it. Until
then the R API and the C table may change freely; no sibling depends on
zuexact yet (`daffiz` and `qio` are the candidate consumers of the C
table).

## Commands

Run from the package root.

``` sh
Rscript -e 'devtools::load_all()'                # compile src/ and load
Rscript -e 'devtools::document()'                # roxygen -> NAMESPACE, man/
Rscript -e 'devtools::test()'                    # full testthat suite
Rscript -e 'devtools::test(shuffle = TRUE)'      # order independence
Rscript -e 'devtools::check()'                   # R CMD check
air format .                                     # format R sources
tools/vendor/verify                              # vendored tree == upstream + patches
tools/xsum-check/run [iters [seed]]              # upstream checker and fuzzer
tools/run-benchmarks                             # small/large threshold (C, no R)
Rscript -e 'devtools::load_all(); source("tools/bench/matrix.R")'  # matrix timings
```

The first five are the development loop; the `tools/` scripts are for
vendoring changes and need `curl` and a C compiler.

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

- **TwoProduct must not be contracted** (design §9, §13). The file that
  splits products with `fma()` carries `#pragma STDC FP_CONTRACT OFF`
  and keeps `p = x*y` and `e = fma(x, y, -p)` in separate statements.

## Testing conventions

- **Self-sufficient and self-contained.** Each `test_that()` builds its
  own inputs; global state goes through `withr::local_*()`, randomised
  input through
  [`withr::local_seed()`](https://withr.r-lib.org/reference/with_seed.html).
- **Assert on condition classes**, never message text:
  `expect_error(..., class = "zuexact_invalid_argument")`.
- **Order independence.** `devtools::test(shuffle = TRUE)` is part of
  done.
- **Oracles before hand-written cases** (design §11): exact rationals
  with `gmp`, `PreciseSums::fsum()`, the `Math.sumPrecise` test262
  vectors, and the Ogita–Rump–Oishi ill-conditioned generators.
- **Helpers** live in `tests/testthat/helper-*.R`: `helper-abi.R` reads
  the shared object’s exported and undefined symbols with `nm`;
  `helper-vendor.R` defines `selftest()`, which sums through both xsum
  accumulators directly; `helper-data.R` makes random matrices spread
  over 80 binades; `helper-oracle.R` holds the exact rational oracle
  (`exact_sum()`, `exact_dot()`), whose `round_bigq()` exists because
  gmp’s [`as.double()`](https://rdrr.io/r/base/double.html) truncates
  instead of rounding.

## Definition of done

`devtools::document()` and `devtools::check()` clean: 0 errors, 0
warnings, 0 notes, apart from “New submission” before the first release.
`devtools::test(shuffle = TRUE)` green. CI green on every leg, including
`nold` (R without long doubles), which is the leg this package exists
for. A user-facing change also needs a test, roxygen documentation and a
`NEWS.md` entry.

## Releasing to CRAN

CI through `pedrobtz/r-actions` is the pre-submission check; no
win-builder, macOS builder or R-hub. `cran-comments.md` lists the CI
legs. The pretest does not read explanations, so fix every NOTE. After
acceptance: tag `0.1.0` on the commit in `CRAN-SUBMISSION`, publish the
GitHub release, bump to `0.1.0.9000`, close \#2 and \#12.

## Editing rules

- roxygen comments are the source. Never edit `man/` or `NAMESPACE` by
  hand.
- Keep prose simple and short, in en-GB.
- Wrap roxygen text at 80 characters and run `air format .` on R
  sources.
- Use `lower_snake_case`. Internal C symbols are prefixed `zxe_`; the
  public C table and header use `zuexact_`.
- Zero hard runtime dependencies.

## Continuous integration

Workflows call `pedrobtz/r-actions`: `R-CMD-check.yaml`
(`r-cmd-check.yml@v1`, quick on pull requests, full on `main`,
`nold: true`), `coverage.yaml` (`coverage.yml`, pinned to a commit
because it holds a write token; badge on `gh-pages` because `main` takes
no direct pushes), `native-checks.yaml` (sanitizers, valgrind, LTO,
gctorture, rchk, analyzers, CRAN special checks), `vendor.yaml`,
`vendor-upstream.yaml` (weekly), and `xsum-check.yaml` (upstream’s
checker, fuzzer and the threshold benchmark on three OSes, outside R).
`pkgdown.yaml` deploys with `force: false` so it does not overwrite the
badge commit. The `full-ci` label runs the full profile on a pull
request.

## Vendored native code

`xsum` by Radford M. Neal, MIT, pinned at tag `stable-version-3`, commit
`b766b3e` (2024-11-13), in `src/vendor/xsum/`.
`tools/vendor/manifest.tsv` pins it; `tools/vendor/checksums.sha256`
records the installed files; the one local patch is
`tools/patches/xsum/0001-no-stdio-exact-only.patch`. Never edit
`src/vendor/` by hand: change the patch and run `tools/vendor/fetch`.
The `vendor.yaml` workflow rejects a pull request that changes the tree
without the manifest and checksums, and `vendor-upstream.yaml` opens an
issue weekly when upstream tags a newer stable version. CRAN’s
compiled-code check applies to vendored code: no `printf`, `abort`,
`exit` or system RNG may be linked, even behind a debug switch. Remove
them with a patch, never with a justification.

## Commits and pull requests

Short, imperative, sentence-case commit subjects. Never push to `main`;
work on a branch and open a pull request. One pull request per roadmap
stage, titled as the stage, closing its sub-issue.
