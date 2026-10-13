# CLAUDE.md

<!-- markdownlint-disable-next-line MD013 -->
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

zuexact computes sums of doubles exactly and rounds once, so results are the
correctly rounded true value on every platform and in every element order. It
vendors Radford Neal's `xsum` (MIT) and exposes it as R functions with the
`xsum_` prefix (`xsum()` itself is the main entry point) and as a registered C
table for other packages. Zero hard runtime dependencies. It never does
arbitrary precision, decimals, or compensated-but-inexact summation (Kahan and
friends live in `PreciseSums`).

[`.agents/design.md`](.agents/design.md) is the specification and
[`.agents/roadmap.md`](.agents/roadmap.md) the plan to 0.1.0. They outrank this
file: `CLAUDE.md` orients, the design decides.

## Current state

Verified 2026-10-13: every roadmap stage is implemented and the package is at
version 0.1.0, ready for the CRAN-submission issue (#12). Exported: `xsum()`,
`xsum_mean()`, `xsum_weighted_mean()`, `xsum_cumsum()`, `xsum_dot()`,
`xsum_sqnorm()`, `xsum_norm()`, the accumulator values (`xsum_acc()`,
`xsum_add()`, `xsum_merge()`, `xsum_negate()`, `xsum_value()`,
`xsum_mean_value()`), `xsum_rowsums()`, `xsum_colsums()`, `xsum_by()` and
`zuexact_info()`, plus the registered C table `zuexact_api_v1`
(`inst/include/zuexact.h`). Results are proven against exact rationals,
`PreciseSums::fsum()`, the test262 vectors and ill-conditioned inputs, and
must be bit-identical on every CI leg.

## Stage tracking

Progress toward 0.1.0 is tracked as GitHub sub-issues of
[v0.1.0 (#2)](https://github.com/pedrobtz/zuexact/issues/2); submission is
[#12](https://github.com/pedrobtz/zuexact/issues/12).

- **One sub-issue per roadmap stage**, titled as the roadmap titles it and
  linking to that section. Every tracking issue carries the `stage` label.
- **Close a stage by merging its pull request** with `Closes #<n>` in the body.
  Never close a stage whose exit criteria are not met; record a deviation in
  the roadmap first.
- **The roadmap stays authoritative.** Adding, removing or renaming a stage
  means editing the roadmap and the sub-issues in the same change.
- **Merges are merge commits.** The repository ruleset on `main` requires pull
  requests and allows only the merge method; squash is refused.

## Versioning

Develops at `0.0.0.9000` and targets `0.1.0` for its first CRAN release. Set
`Version: 0.1.0` and the matching `NEWS.md` heading in the last roadmap stage.
Bump to `0.1.0.9000` only after CRAN accepts it. Until then the R API and the C
table may change freely; no sibling depends on zuexact yet (`daffiz` and `qio`
are the candidate consumers of the C table).

## Commands

Run from the package root.

```sh
Rscript -e 'devtools::load_all()'                # compile src/ and load
Rscript -e 'devtools::document()'                # roxygen -> NAMESPACE, man/
Rscript -e 'devtools::test()'                    # full testthat suite
Rscript -e 'devtools::test(shuffle = TRUE)'      # order independence
Rscript -e 'devtools::check()'                   # R CMD check
air format .                                     # format R sources
tools/vendor/verify                              # vendored tree == upstream + patches
tools/xsum-check/run [iters [seed]]              # upstream checker and fuzzer
tools/run-benchmarks                             # small/large threshold (C, no R)
R CMD INSTALL . && Rscript -e 'library(zuexact); source("tools/bench/functions.R")'
R CMD INSTALL . && Rscript -e 'library(zuexact); source("tools/bench/matrix.R")'
tools/write-bits                                 # rewrite the bits fixture (rarely)
ZUEXACT_SLOW_TESTS=true Rscript -e 'devtools::test()'  # wider oracle sweeps
```

The first five are the development loop; the `tools/` scripts are for
vendoring changes and need `curl` and a C compiler.

## Invariants that are easy to break

- **One pass, then a rescan only when the result is not finite**
  (`src/zxe_sum.c`). The rescan must skip exactly what `na.rm = TRUE`
  removed, including a complex element dropped because its *other* part is
  `NaN`; it once did not, and `xsum(c(NA, Inf), na.rm = TRUE)` gave `NA`.
- **An `xsum_acc` is 568 raw bytes**: an 8-byte header (magic `ZXAC`, layout
  version, byte order, special-value flags) and one xsum small accumulator
  (`src/zxe_accval.c`). R's `NA`/`NaN` distinction lives in the header flags,
  because xsum keeps a single NaN by payload. Changing the layout means
  bumping the version byte; the C table (Stage 6) operates on the same bytes.
  Locals are zeroed before use so no uninitialised padding is serialised.
- **Benchmark an installed package, never `load_all()`**, which compiles at
  `-O0`: it doubled `xsum_dot()`'s time when first measured.
- **`R_FINITE()` is a function call in package code** (`R_finite()`); hot
  loops use C99 `isfinite()`.
- **`tests/testthat/fixtures/bits.txt` is the cross-platform contract.** A
  changed line is a portability bug, never a reason to rerun
  `tools/write-bits`; that tool is for adding cases.
- **Cross-platform inputs never come from decimal literals that are not
  exact.** R's own parser differs between builds: on macOS ARM64 (no long
  double) `1e308` reads as `0x1.1ccf385ebc8a3p+1023`, three ulps from the
  correctly rounded `…8a0` that Linux gives. That broke the bits test once
  (2026-10-13). Build such inputs from bit patterns (`from_hex()`).
- **`ALTREP()` decides how a vector is read.** ALTREP vectors go through
  `*_GET_REGION` into a stack block; `REAL_RO()` on one would materialise it.

- **One rounding.** Every function rounds the exact value once, except where
  its documentation states the count (`xsum_norm()` two, `xsum_weighted_mean()`
  three). Never add an intermediate `double` between accumulation and the final
  round.
- **`zuexact.so` exports `R_init_zuexact` only** (`$(C_VISIBILITY)` in
  `src/Makevars` and `src/Makevars.win`), and links no stdio, `abort`, `exit`
  or RNG symbol. `tests/testthat/test-abi.R` audits both on Linux and macOS.
- **The C table is append-only** (`inst/include/zuexact.h`). Add members at
  the end and let `struct_size` tell consumers; any other change is a new
  name, `zuexact_api_v2`. `tools/zuexacttest` is the consumer that proves it
  (`consumer.yaml`).
- **Never trust a software `fma()`.** mingw-w64's (Windows, Rtools) gave
  wrong error terms. `src/zxe_twoprod.h` uses `fma()` only under
  `FP_FAST_FMA` and Dekker's splitting otherwise; define `ZXE_NO_FMA` to
  test the Dekker branch on a machine with hardware FMA.
- **TwoProduct must not be contracted** (design §9, §13). The files that
  include `zxe_twoprod.h` (`zxe_dot.c`, `zxe_api.c`) carry
  `#pragma STDC FP_CONTRACT OFF` and keep `p = x*y` and
  `e = fma(x, y, -p)` in separate statements. `-ffp-contract=off` cannot be
  used: R CMD check reports `-f` flags as non-portable.

## Testing conventions

- **Self-sufficient and self-contained.** Each `test_that()` builds its own
  inputs; global state goes through `withr::local_*()`, randomised input through
  `withr::local_seed()`.
- **Assert on condition classes**, never message text:
  `expect_error(..., class = "zuexact_invalid_argument")`.
- **Order independence.** `devtools::test(shuffle = TRUE)` is part of done.
- **Oracles before hand-written cases** (design §11): exact rationals with
  `gmp` (`helper-oracle.R`), `PreciseSums::fsum()`, the `Math.sumPrecise`
  test262 vectors (`fixtures/sumprecise/`, as bit patterns), and the
  Ogita–Rump–Oishi ill-conditioned generators (`helper-illcond.R`).
  `ZUEXACT_SLOW_TESTS=true` widens every sweep and `ZUEXACT_SKIP_HEAVY=true`
  (set by the gctorture leg) shrinks it to two inputs (family rule R7,
  `sweep_reps()` in `helper-illcond.R`).
- **Keep the CRAN suite under 15 s.** It ran in 6.6 s on 2026-10-13
  (macOS ARM64, CRAN settings).
- **Helpers** live in `tests/testthat/helper-*.R`: `helper-abi.R` reads the
  shared object's exported and undefined symbols with `nm`; `helper-vendor.R`
  defines `selftest()`, which sums through both xsum accumulators directly;
  `helper-data.R` makes random matrices spread over 80 binades;
  `helper-oracle.R` holds the exact rational oracle (`exact_sum()`,
  `exact_dot()`), whose `round_bigq()` exists because gmp's `as.double()`
  truncates instead of rounding.

## Definition of done

`devtools::document()` and `devtools::check()` clean: 0 errors, 0 warnings, 0
notes, apart from "New submission" before the first release.
`devtools::test(shuffle = TRUE)` green. CI green on every leg, including `nold`
(R without long doubles), which is the leg this package exists for. A
user-facing change also needs a test, roxygen documentation and a `NEWS.md`
entry.

## Releasing to CRAN

CI through `pedrobtz/r-actions` is the pre-submission check; no win-builder,
macOS builder or R-hub. `cran-comments.md` lists the CI legs. The pretest does
not read explanations, so fix every NOTE. After acceptance: tag `0.1.0` on the
commit in `CRAN-SUBMISSION`, publish the GitHub release, bump to `0.1.0.9000`,
close #2 and #12.

## Editing rules

- roxygen comments are the source. Never edit `man/` or `NAMESPACE` by hand.
- Keep prose simple and short, in en-GB.
- Wrap roxygen text at 80 characters and run `air format .` on R sources.
- Use `lower_snake_case`. Internal C symbols are prefixed `zxe_`; the public C
  table and header use `zuexact_`.
- Zero hard runtime dependencies.

## Continuous integration

Workflows call `pedrobtz/r-actions`: `R-CMD-check.yaml` (`r-cmd-check.yml@v1`,
quick on pull requests, full on `main`, `nold: true`), `coverage.yaml`
(`coverage.yml`, pinned to a commit because it holds a write token; badge on
`gh-pages` because `main` takes no direct pushes), `native-checks.yaml`
(sanitizers, valgrind, LTO, gctorture, rchk, analyzers, CRAN special checks),
`vendor.yaml`, `vendor-upstream.yaml` (weekly), and `xsum-check.yaml`
(upstream's checker, fuzzer and the threshold benchmark on three OSes, outside
R), `consumer.yaml` (the C table from `tools/zuexacttest`) and `fuzz.yaml`
(libFuzzer on `tools/fuzz/fuzz_xsum.c`, nightly for 30 minutes). `pkgdown.yaml` deploys with
`force: false` so it does not overwrite the badge commit. The `full-ci` label
runs the full profile on a pull request.

## Vendored native code

`xsum` by Radford M. Neal, MIT, pinned at tag `stable-version-3`, commit
`b766b3e` (2024-11-13), in `src/vendor/xsum/`. `tools/vendor/manifest.tsv`
pins it; `tools/vendor/checksums.sha256` records the installed files; the one
local patch is `tools/patches/xsum/0001-no-stdio-exact-only.patch`. Never edit
`src/vendor/` by hand: change the patch and run `tools/vendor/fetch`. The
`vendor.yaml` workflow rejects a pull request that changes the tree without
the manifest and checksums, and `vendor-upstream.yaml` opens an issue weekly
when upstream tags a newer stable version. CRAN's
compiled-code check applies to vendored code: no `printf`, `abort`, `exit` or
system RNG may be linked, even behind a debug switch. Remove them with a patch,
never with a justification.

## Commits and pull requests

Short, imperative, sentence-case commit subjects. Never push to `main`; work on
a branch and open a pull request. One pull request per roadmap stage, titled as
the stage, closing its sub-issue.
