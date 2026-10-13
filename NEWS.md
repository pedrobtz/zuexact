# zuexact 0.0.0.9000

Development version of the first release, 0.1.0. This heading becomes
`# zuexact 0.1.0` in the last roadmap stage.

* Package identity: real `DESCRIPTION`, licence and copyright files, hidden
  symbols, and CI on the R build without long doubles.

* Vendors Radford Neal's 'xsum' (stable version 3), patched so that no
  standard I/O reaches the compiled code; upstream's checker and fuzzer run
  against the vendored copy in CI.

* `xsum()` returns the exactly rounded sum of double, integer, logical and
  complex vectors, with `na.rm`, applying the same special-value rules on
  every platform. ALTREP vectors are read in blocks, never materialised.

* `zuexact_info()` reports the vendored 'xsum' version, the accumulator
  threshold, SIMD and FMA support, and whether R has long doubles.

* `xsum_mean()` divides the exact sum by the count with one rounding;
  `xsum_weighted_mean()` divides two exact sums.

* `xsum_dot()`, `xsum_sqnorm()` and `xsum_norm()` include each product's
  rounding error (TwoProduct with `fma()`), so dot products are exactly
  rounded too.

* `xsum_cumsum()` rounds every prefix sum exactly.

* Accumulators as R values: `xsum_acc()`, `xsum_add()`, `xsum_merge()`,
  `xsum_negate()`, `xsum_value()` and `xsum_mean_value()` build exact sums
  in pieces, in any order, and across processes (they serialise).
