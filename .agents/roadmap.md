# zuexact: roadmap

Status: draft 2026-10-13. Implements [design.md](design.md) (RFC 0023,
revision 2). Target: v0.1.0, the first CRAN release.
Tracking: [v0.1.0 (#2)](https://github.com/pedrobtz/zuexact/issues/2), with
one sub-issue per stage;
[CRAN-submission (#12)](https://github.com/pedrobtz/zuexact/issues/12).

Starting point, 2026-10-13: the `usethis` skeleton. `DESCRIPTION` carries
placeholder title, description and author; `src/zuexact.c` is two includes;
the test suite is the template's `2 * 2`. The R-CMD-check, coverage and
pkgdown workflows already call `pedrobtz/r-actions`, and `.Rbuildignore`
already excludes `.agents`. Nothing of the design is implemented.

Sequencing: the vendored C library is the one unknown (its patch, its
compile-time options under CRAN flags, the small/large threshold), so it
lands and is measured before any R function exists. Every later stage is R
surface over a library whose behaviour is already pinned by upstream's own
checker, the sanitizers and a benchmark. Accumulator values (Stage 4) come
before matrices (Stage 5) because row blocking is built from them, and
before the C table (Stage 6) because the table operates on the same bytes.

## Stages

| Stage | Title | Issue | Pull request | Done |
| --- | --- | --- | --- | --- |
| 0 | [Package identity](#stage-0--package-identity) | [#3](https://github.com/pedrobtz/zuexact/issues/3) | [#13](https://github.com/pedrobtz/zuexact/pull/13) | 2026-10-13 |
| 1 | [Vendor, patch and measure xsum](#stage-1--vendor-patch-and-measure-xsum) | [#4](https://github.com/pedrobtz/zuexact/issues/4) | [#14](https://github.com/pedrobtz/zuexact/pull/14) | 2026-10-13 |
| 2 | [Exact sums and special values](#stage-2--exact-sums-and-special-values) | [#5](https://github.com/pedrobtz/zuexact/issues/5) | [#15](https://github.com/pedrobtz/zuexact/pull/15) | 2026-10-13 |
| 3 | [Means, cumulative sums, dot products and norms](#stage-3--means-cumulative-sums-dot-products-and-norms) | [#6](https://github.com/pedrobtz/zuexact/issues/6) | | 2026-10-13 |
| 4 | [Accumulator values](#stage-4--accumulator-values) | [#7](https://github.com/pedrobtz/zuexact/issues/7) | | |
| 5 | [Matrices and grouped sums](#stage-5--matrices-and-grouped-sums) | [#8](https://github.com/pedrobtz/zuexact/issues/8) | | |
| 6 | [The C table](#stage-6--the-c-table) | [#9](https://github.com/pedrobtz/zuexact/issues/9) | | |
| 7 | [Oracles, adversarial inputs and cross-platform identity](#stage-7--oracles-adversarial-inputs-and-cross-platform-identity) | [#10](https://github.com/pedrobtz/zuexact/issues/10) | | |
| 8 | [v0.1.0 readiness](#stage-8--v010-readiness) | [#11](https://github.com/pedrobtz/zuexact/issues/11) | | |

## Stage 0 — Package identity

**Issue.** [#3](https://github.com/pedrobtz/zuexact/issues/3), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuexact/issues/2).

**Goal.** The repository says what the package is, by whom, under which
licence and R floor, and its check workflow runs the one CI leg that
matters most to this package: R built without long doubles.

**Work.**
- `DESCRIPTION`: real `Title` and `Description` (exactly rounded sums,
  means and dot products of doubles; vendored xsum); `Authors@R` with
  `cre`, `aut`, `cph` for the maintainer and `cph` for Radford M. Neal
  (xsum); `Depends: R (>= 4.1)`, `Language: en-GB`,
  `Config/roxygen2/version: 8.1.0` (family rule R2); `Version:
  0.0.0.9000` kept; `SystemRequirements: C99`; `URL` and `BugReports`.
- `LICENSE`: the real copyright holder in place of "zuexact authors";
  `LICENSE.md` unchanged (MIT).
- `inst/COPYRIGHTS` naming xsum's MIT licence and copyright years, as
  CRAN requires for vendored code.
- `src/Makevars` and `src/Makevars.win` with `PKG_CFLAGS = $(C_VISIBILITY)`
  (family rule R3); `src/zuexact.c` registers an empty routine table so
  `R_init_zuexact` exists and the package loads.
- `.github/workflows/R-CMD-check.yaml`: add `nold: true` so the full
  profile runs the no-long-double image; this is the leg on which base
  `sum()` changes its answers and zuexact must not.
- `CLAUDE.md` from `templates/package-CLAUDE.md` in `pedrobtz/packages`:
  what the package is, current state dated, stage tracking pointing at the
  v0.1.0 issue, the commands, and the native-code sections kept for xsum.
- `README.md`: the one-paragraph pitch and the `sum(c(1e16, 1, -1e16))`
  example, with "not yet implemented" stated; badges kept.
- `NEWS.md` unchanged (the development-version heading).

Already done, skipped: `.Rbuildignore` excludes `.agents`; the three
workflows call `pedrobtz/r-actions` by `@v1`; `LICENSE.md` exists;
`Config/testthat/edition: 3`.

**Exit criteria.**
- `R CMD check` passes on every r-actions leg of the full profile,
  including `nold`, with zero errors, warnings and notes.
- `DESCRIPTION` has no placeholder text; `desc::desc_get_authors()` lists
  the maintainer with `cre`.
- `nm` (or the family's symbol audit) shows `zuexact.so` exporting
  `R_init_zuexact` and nothing else.
- `CLAUDE.md` exists at the package root with every placeholder replaced.

**Design.** §3.1, §13 of design.md.

## Stage 1 — Vendor, patch and measure xsum

**Issue.** [#4](https://github.com/pedrobtz/zuexact/issues/4), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuexact/issues/2).

**Goal.** Neal's xsum compiles inside the package on every CI platform
under CRAN's flags, with no stdio symbol, verified by upstream's own
checker and by the sanitizers, and the small/large threshold has been
measured and written down. No R function yet.

**Work.**
- `src/xsum/xsum.c`, `src/xsum/xsum.h` at `radfordneal/xsum@b766b3e`;
  `src/xsum/VERSION` with the commit and a SHA-256 per file;
  `src/xsum/PATCH` holding the diff applied (design §8): drop
  `#include <stdio.h>`, the `xsum_*_display()` functions and the
  `pbinary_*` stubs; drop the non-exact comparison routines and the
  `OPT_SIMPLE_*`/`OPT_KAHAN_SUM` code from the package build, keeping them
  in `tools/bench/` for the benchmark harness. Compile-time options stay
  at upstream defaults (`USE_SIMD` on, guarded by `__SSE2__`/`__AVX__`).
- `tools/vendor-xsum` script that fetches a commit, applies the patch and
  rewrites `VERSION`, so the next upstream bump is one command; wire the
  r-actions `vendor.yml` workflow to verify the hashes.
- Upstream's `xsum-check.c` and the fuzzer, adapted to the patched copy
  and run by a `tools/check-xsum` script in CI (a job in the check
  workflow or a small dedicated workflow).
- `.github/workflows/sanitizers.yaml` calling the r-actions
  `sanitizers.yml` (UBSan and ASan over the compiled code); xsum's chunk
  arithmetic is exactly what UBSan watches.
- `tools/run-benchmarks` (design §12) with its first measurement: the
  small/large crossover on the three CI platforms for `addv`, against
  Neal's "about 1,000" and Xsum.jl's 256; the chosen constant recorded in
  design §8 and defined in `src/zxe.h`. The same run records whether an
  AVX2 copy with runtime dispatch is worth adding (design D7); the default
  answer is no.
- A hidden `.Call()` entry, `zxe_selftest()`, that sums a fixed vector
  through small and large accumulators so a testthat file exercises the
  vendored code before Stage 2 exists.

**Deviation, 2026-10-13.** File layout follows the r-actions `vendor.yml`
defaults and the family's package template rather than the paths written
above: `src/vendor/xsum/` (not `src/xsum/`); `tools/vendor/manifest.tsv` and
`tools/vendor/checksums.sha256` (not `src/xsum/VERSION`);
`tools/patches/xsum/0001-no-stdio-exact-only.patch` (not `src/xsum/PATCH`);
`tools/vendor/{fetch,verify}` (not `tools/vendor-xsum`);
`tools/xsum-check/run` (not `tools/check-xsum`). The non-exact routines are
removed by the patch and not kept under `tools/bench/`: the benchmark needs
only the exact routines. The full r-actions native-checks set (sanitizers,
valgrind, LTO, gctorture, rchk, analyzers, CRAN special checks) is adopted
instead of the sanitizers workflow alone. The threshold is per architecture (384 on ARM64, 128 elsewhere) rather
than one constant, because one constant costs 1.5× on some platform (design
§8). Scope is unchanged.

**Exit criteria.**
- `R CMD check` passes on every full-profile leg; the shared object
  contains no `printf`, `puts`, `fprintf` or other stdio symbol (audited
  by the symbol test from Stage 0, extended).
- `tools/check-xsum` runs upstream's `xsum-check` and a fixed-time fuzzer
  run green in CI on Linux, macOS ARM64 and Windows.
- The sanitizers workflow is green.
- Design §8 names the measured threshold with the numbers behind it, and
  records the AVX2 decision.

**Design.** §8, §12, §13, D7 of design.md.

## Stage 2 — Exact sums and special values

**Issue.** [#5](https://github.com/pedrobtz/zuexact/issues/5), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuexact/issues/2).

**Goal.** `xsum()` returns the correctly rounded sum of double, integer,
logical and complex vectors, with `na.rm`, applying the special-value
table of design §6 identically on every platform, reading ALTREP vectors
in blocks, in one pass.

**Work.**
- `R/xsum.R` and `src/zxe_sum.c`: `xsum(..., na.rm = FALSE)` with `...`
  as in `sum()`; blocks through `REAL_GET_REGION`,
  `INTEGER_GET_REGION` and `LOGICAL_GET_REGION`; large accumulator at or
  above the Stage 1 threshold, small below; integers and logicals
  converted exactly; complex as two sums over the interleaved storage.
- The special-value path (design §4, §6): sum first; only when the
  rounded result is non-finite, rescan to decide `NA_real_`, `NaN`,
  `±Inf`; `na.rm = TRUE` feeds a block containing any `NaN` element-wise.
  `+0` for all-zero input (D10). `xsum()` of nothing is `0`.
- Accumulator overflow detection (`xsum_value()` is Stage 4, but the
  rounding helper that recognises xsum's all-ones NaN payload is written
  here).
- `R/conditions.R`: `zuexact_error` and `zuexact_invalid_argument`,
  `zuexact_internal_error` with `rlang`-free constructors.
- `zuexact_info()`: xsum commit, threshold, SIMD paths compiled, FMA
  (`__FP_FAST_FMA`), long-double status of the running R.
- Tests: one test per row of the §6 table; the permanent hard cases of
  §11 that need only `xsum()` (`c(1e308, 1e308, -1e308)`, `c(1e20, 1,
  -1e20)`, `c(1e16, 1, -1e16)`, subnormals, `-0` only, `-DBL_MAX - 1`);
  ALTREP inputs (`1:1e6 + 0`, compact sequences, wrapped vectors);
  integer overflow beyond `.Machine$integer.max`; complex against
  `sum(Re(z))` oracle values; `devtools::test(shuffle = TRUE)` clean.
- roxygen documentation for `xsum()` and `zuexact_info()`, including the
  §6 table.

**Exit criteria.**
- Every row of the design §6 table has a passing test, on every CI leg
  including `nold`.
- `xsum(c(1e16, 1, -1e16))` is `1` on every leg, where the `nold` leg's
  base `sum()` gives `0`.
- ALTREP inputs are summed without materialising: a test with a compact
  sequence of 1e8 elements completes inside the memory of the runner.
- `R CMD check` passes on every full-profile leg; sanitizers green.

**Design.** §4, §5, §6, §10 of design.md.

## Stage 3 — Means, cumulative sums, dot products and norms

**Issue.** [#6](https://github.com/pedrobtz/zuexact/issues/6), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuexact/issues/2).

**Goal.** `xsum_mean()`, `xsum_cumsum()`, `xsum_dot()`, `xsum_sqnorm()`,
`xsum_norm()` and `xsum_weighted_mean()` exist, each with its rounding
count stated in its documentation, and the TwoProduct code cannot be
fused by any compiler the package meets.

**Work.**
- `xsum_mean()`: `xsum_*_div_unsigned()` on the accumulator; counts
  above `2^32 - 1` signal `zuexact_count_error` (open question 1 of the
  design resolved for 0.1.0 as the error; the 64-bit division waits).
  `xsum_mean()` of nothing is `NaN`.
- `xsum_cumsum()`: `add1` and `round` per element; documented as the
  slowest function.
- `src/zxe_dot.c` with `#pragma STDC FP_CONTRACT OFF` and `p = x*y; e =
  fma(x, y, -p)` in separate statements; `-ffp-contract=off` added to
  `PKG_CFLAGS` where the compiler accepts it (a `configure`-free check:
  the flag is known to GCC and clang, the only compilers R uses here).
  `xsum_dot()` and `xsum_sqnorm()` add both terms; `xsum_norm()` is
  `sqrt()` of the rounded squared norm.
- `xsum_weighted_mean()`: two exact sums and one division, documented as
  three roundings (design open question 3, resolved as "ship it").
- Tests: the second upstream 2024 fix (the small `add_dot` term); a
  TwoProduct canary that fails if contraction happens (an `x`, `y` pair
  whose `fma` error term is nonzero and whose exact dot product differs
  from the rounded-products sum); the underflow bound of §9 crossed on
  purpose, with the result compared to a high-precision oracle; product
  overflow giving `±Inf`; `xsum_mean(c(1e15, -1e15, 0.1))` equal to
  `0.1 / 3` correctly rounded (Neal's R example).

**Deviation, 2026-10-13.** `-ffp-contract=off` is not added to
`PKG_CFLAGS`: R CMD check reports any `-f` flag there as non-portable (a
NOTE). The pragma, separate statements and the canary in `test-dot.R` guard
TwoProduct instead (design §13). The rational oracle needed a correctly
rounding conversion (`helper-oracle.R`): gmp's `as.double()` on a `bigq`
truncates. `gmp` joins Suggests here rather than in Stage 7.

**Exit criteria.**
- The TwoProduct canary passes on every full-profile leg, including the
  clang containers and macOS ARM64 (clang's default contraction mode).
- Each function's documentation states its number of roundings.
- `R CMD check` passes on every full-profile leg; sanitizers green.

**Design.** §2, §5, §9, §10, §16 (questions 1 and 3) of design.md.

## Stage 4 — Accumulator values

**Issue.** [#7](https://github.com/pedrobtz/zuexact/issues/7), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuexact/issues/2).

**Goal.** Sums can be built in pieces and merged, including across
processes: `xsum_acc` is a serialisable R value, and an accumulator made on
a `parallel` worker merges correctly on the caller.

**Work.**
- `R/acc.R`, `src/zxe_acc.c`: class `xsum_acc` on a raw vector holding an
  8-byte header (magic, layout version, endianness) and one small
  accumulator (560 bytes); `xsum_acc(x = NULL)`, `xsum_add()`,
  `xsum_merge()`, `xsum_negate()`, `xsum_value()`, `xsum_mean_value(acc,
  n)`; `as.double()`, `print()` and `format()` methods. `xsum_add()` with
  a long `x` sums into a stack-allocated large accumulator and converts
  with `xsum_large_to_small_accumulator()`.
- Header validation signalling `zuexact_accumulator_error` on a wrong
  magic, version or endianness (design open question 4, resolved as
  "struct bytes plus header, little-endian only").
- `xsum_value()` recognises the all-ones NaN payload of accumulator
  overflow and signals `zuexact_internal_error`.
- Tests: chunked `xsum_add()` equals `xsum()` of the whole, for chunk
  sizes straddling the threshold; `Reduce(xsum_merge, accs)` in any
  order gives the same bits; `xsum_merge(a, xsum_negate(b))` equals the
  exact difference; `serialize()`/`unserialize()` round trip; a
  `parallel::mclapply()` (Unix) or `parLapply()` (all platforms) run
  whose accumulators merge on the caller; a corrupted header errors with
  the right class.
- A vignette section (or README section) showing the streaming pattern
  over chunks and over workers.

**Exit criteria.**
- The worker round-trip test passes on Linux, macOS and Windows legs.
- An accumulator serialised in one R session and unserialised in another
  on the same platform gives the same `xsum_value()` bits.
- `R CMD check` passes on every full-profile leg; sanitizers green.

**Design.** §4, §5, §6 (accumulator overflow), §10, D9, §16 question 4
of design.md.

## Stage 5 — Matrices and grouped sums

**Issue.** [#8](https://github.com/pedrobtz/zuexact/issues/8), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuexact/issues/2).

**Goal.** `xsum_rowsums()`, `xsum_colsums()` and `xsum_by()` return
exactly rounded sums with the shapes of `rowSums()`, `colSums()` and
`rowsum()`, with memory bounded by a row block rather than by `nrow`.

**Work.**
- `src/zxe_matrix.c`: column sums as one `addv` per column; row sums in
  blocks of rows (1,024 to start, measured), one small accumulator per
  row in the block, walking each column's slice; `na.rm` per §6 applied
  per row or column; dimnames carried.
- `xsum_by(x, group, na.rm)`: one accumulator per group up to a measured
  group count, above which rows are ordered by group and contiguous runs
  summed; `group` as factor, integer or character, result named as
  `rowsum()` names it.
- `tools/run-benchmarks` gains the matrix cases; the block size and the
  group-count switch are recorded in design §4.
- Tests: against `xsum()` applied per row, column and group; a tall
  matrix (1e7 × 3) whose row sums must not allocate 560 bytes × `nrow`
  (checked with `bench::mark()` memory or `gc()` deltas); `NA` placement
  per row; a factor with unused levels.

**Exit criteria.**
- Row sums of a 1e7 × 3 double matrix run with peak extra allocation
  below 10 MB on the Linux leg.
- Results equal `xsum()` of each slice, bit for bit, on every leg.
- `R CMD check` passes on every full-profile leg; sanitizers green.

**Design.** §2, §4, §5 of design.md.

## Stage 6 — The C table

**Issue.** [#9](https://github.com/pedrobtz/zuexact/issues/9), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuexact/issues/2).

**Goal.** Another package's C code sums exactly through
`R_GetCCallable("zuexact", "zuexact_api_v1")` with an opaque accumulator
it allocates itself, and a fixture package proves it in CI.

**Work.**
- `inst/include/zuexact.h` declaring `zuexact_api` (design §7: `init`,
  `add1`, `addv`, `add_dot`, `merge`, `negate`, `round`, `div`,
  `struct_size`, `acc_size`) and a `zuexact_api_get()` convenience macro
  around `R_GetCCallable()`; `src/zxe_api.c` registering the table in
  `R_init_zuexact`. `addv` and `add_dot` use a stack large accumulator
  above the threshold and fold it into the caller's small one.
- `tests/fixture/zuexactconsumer`: a minimal package with `LinkingTo:
  zuexact` that sums a vector and a dot product through the table and
  compares with `xsum()` and `xsum_dot()`; installed and run in a check
  job (the `abi` test pattern from `zubin`).
- The table's versioning rules (append only; rename on layout change)
  stated in `inst/include/zuexact.h` and in `CLAUDE.md`.
- A test that the bytes of an `xsum_acc` after its header are what the
  table's `round` accepts.

**Exit criteria.**
- The fixture package installs against the built zuexact and its tests
  pass in CI on Linux, macOS and Windows.
- `R_GetCCallable("zuexact", "zuexact_api_v1")` returns a table whose
  `struct_size` equals `sizeof(zuexact_api)` and whose `acc_size` is 560.
- `zuexact.so` still exports only `R_init_zuexact`.

**Design.** §7, §3.1 of design.md.

## Stage 7 — Oracles, adversarial inputs and cross-platform identity

**Issue.** [#10](https://github.com/pedrobtz/zuexact/issues/10), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuexact/issues/2).

**Goal.** Every result is proven correctly rounded against exact rational
arithmetic and an independent exact implementation, on random, ill-
conditioned and adversarial inputs; the bits are identical across the CI
platforms and across element orders; the R entry points have been fuzzed;
the performance targets are measured and recorded.

**Work.**
- `tests/testthat/helper-oracle.R`: `gmp::as.bigq()` rational sums and
  dot products with correct rounding to double (Suggests: `gmp`);
  `PreciseSums::fsum()` as the cheap second oracle (Suggests), run over
  many more random vectors; both skipped cleanly when absent (the
  `nosuggests` leg).
- `tests/testthat/helper-illcond.R`: the Ogita–Rump–Oishi generators for
  sums and dot products of a prescribed condition number (as in `accupy`
  and AccurateArithmetic.jl), used at condition numbers from 1e8 to 1e40.
- `tests/testthat/fixtures/sumprecise/`: the `Math.sumPrecise` test262
  vectors (tc39/test262 PR 4049) with their licence file, every row
  asserted except the documented `-0` rows.
- Order independence: each fixture summed in 50 random permutations gives
  the same bits.
- Cross-platform identity: a test writes the hex bits of every fixture
  result to a file compared against `tests/testthat/fixtures/bits.txt`,
  committed once from Linux; the macOS ARM64, Windows and `nold` legs
  must match it exactly.
- `.github/workflows/fuzz.yaml` calling the r-actions `fuzz.yml` with a
  libFuzzer harness over the C entry points (`zxe_sum`, `zxe_dot`,
  accumulator header parsing); a `zufuzz` script over the R entry points
  if `zufuzz` is available by then.
- `tools/run-benchmarks` completed: `xsum()` against `sum()` and a plain
  double loop; `xsum_dot()` against `crossprod()`; merge cost;
  `xsum_cumsum()` against `cumsum()`; results recorded in design §12 and
  compared with the targets, with the targets revised there if they were
  wrong.

**Exit criteria.**
- The rational oracle and `PreciseSums::fsum()` agree with every zuexact
  result on every generated input in the suite; any historical
  disagreement is recorded in a test with the rational verdict.
- `bits.txt` matches on Linux x86-64, macOS ARM64, Windows and `nold`.
- The fuzz workflow runs its fixed time budget with no crash or sanitizer
  finding.
- Design §12 holds measured numbers for every target, and the CRAN test
  suite runs in under 15 s (the oracle suites behind an opt-in variable
  per family rule R7).

**Design.** §11, §12, §17 of design.md.

## Stage 8 — v0.1.0 readiness

**Issue.** [#11](https://github.com/pedrobtz/zuexact/issues/11), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuexact/issues/2).

**Goal.** Only the submission itself is left.

**Work.**
- `Version: 0.1.0` in `DESCRIPTION` and the matching `# zuexact 0.1.0`
  heading in `NEWS.md` listing the v0.1.0 surface.
- `cran-comments.md` listing the r-actions CI legs as test environments,
  including `nold`, the sanitizers and the three OSes.
- `README.md` finished: pitch, the platform example, the streaming
  pattern, the dot-product limits, a pointer to `PreciseSums` for
  compensated methods; pkgdown reference grouped by sums, means and
  products, matrices, accumulators, the C API.
- A vignette, `exact-summation.Rmd`: why base `sum()` differs by
  platform, what one rounding buys, the special-value table, streaming
  and parallel merging, the C table for package authors.
- The `pkg-cran-review` skill run with every finding resolved;
  `urlchecker::url_check()` and `spelling::spell_check_package()` clean
  with a `WORDLIST`.
- `CLAUDE.md` current-state paragraph updated and dated; design §12
  numbers final; the RFC copy in `pedrobtz/packages` synced to this
  design.

**Exit criteria.**
- A full-profile r-actions run is green on the release commit, including
  `nold`, `nosuggests`, the sanitizers and the fixture package.
- `pkg-cran-review` reports no open finding.
- `urlchecker::url_check()` and `spelling::spell_check_package()` return
  nothing.
- `DESCRIPTION` says `0.1.0` and `NEWS.md` has the matching heading.

**Design.** §14, §17 of design.md.

## After 0.1.0

- **Exactly rounded variance and standard deviation** (design §2): needs
  TwoSum on deviations and a design of its own; no consumer has asked.
- **Correctly rounded `exp`, `log`, `pow` from CORE-MATH** (design §2):
  a second vendored library with its own licence review; separate stage
  set after 0.1.0.
- **Exact `crossprod()` for small matrices** (design §2): waits for a
  consumer.
- **Exact 64-bit division for means over 2^32 − 1 elements** (design
  §16 question 1): 0.1.0 signals `zuexact_count_error`; the long division
  is new numerics to contribute upstream first.
- **AVX2 runtime dispatch** (design D7): only if Stage 1's measurement
  shows a gain worth two copies of the hot loops.
- **`float32` input** (design §2): R has no native single-precision
  vector; revisit if `float`-package users ask.
- **A canonical cross-endian accumulator encoding** (design §16
  question 4): the header refuses foreign bytes today; an encoding waits
  for a mixed-endian user.

## Open questions

- **Threshold and AVX2** (design §8, D7): blocks nothing but is decided
  by measurement in Stage 1, and Stage 2 hard-codes the result.
- **Means over 2^32 − 1 elements** (design §16 question 1): Stage 3
  takes the recommended interim answer, an error, so the stage is not
  blocked; the 64-bit division is listed above.
- **Weighted mean** (design §16 question 3): Stage 3 ships it with the
  three roundings documented, as the design recommends; dropping it later
  is a one-line removal before 0.1.0 if the maintainer prefers.
- **Accumulator byte layout** (design §16 question 4): Stage 4 takes the
  recommended answer (struct bytes behind a header, little-endian only).
- **How the fuzzer runs in CI** (Stage 1 and Stage 7): upstream's
  `xsum-check` fuzzer and the r-actions `fuzz.yml` libFuzzer harness
  overlap; Stage 1 runs upstream's as is and Stage 7 decides whether the
  libFuzzer harness replaces or complements it.
