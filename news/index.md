# Changelog

## zuexact 0.0.0.9000

Development version of the first release, 0.1.0. This heading becomes
`# zuexact 0.1.0` in the last roadmap stage.

- Package identity: real `DESCRIPTION`, licence and copyright files,
  hidden symbols, and CI on the R build without long doubles.

- Vendors Radford Neal’s ‘xsum’ (stable version 3), patched so that no
  standard I/O reaches the compiled code; upstream’s checker and fuzzer
  run against the vendored copy in CI.

- [`xsum()`](https://pedrobtz.github.io/zuexact/reference/xsum.md)
  returns the exactly rounded sum of double, integer, logical and
  complex vectors, with `na.rm`, applying the same special-value rules
  on every platform. ALTREP vectors are read in blocks, never
  materialised.

- [`zuexact_info()`](https://pedrobtz.github.io/zuexact/reference/zuexact_info.md)
  reports the vendored ‘xsum’ version, the accumulator threshold, SIMD
  and FMA support, and whether R has long doubles.

- [`xsum_mean()`](https://pedrobtz.github.io/zuexact/reference/xsum_mean.md)
  divides the exact sum by the count with one rounding;
  [`xsum_weighted_mean()`](https://pedrobtz.github.io/zuexact/reference/xsum_weighted_mean.md)
  divides two exact sums.

- [`xsum_dot()`](https://pedrobtz.github.io/zuexact/reference/xsum_dot.md),
  [`xsum_sqnorm()`](https://pedrobtz.github.io/zuexact/reference/xsum_dot.md)
  and
  [`xsum_norm()`](https://pedrobtz.github.io/zuexact/reference/xsum_dot.md)
  include each product’s rounding error (TwoProduct with `fma()`), so
  dot products are exactly rounded too.

- [`xsum_cumsum()`](https://pedrobtz.github.io/zuexact/reference/xsum_cumsum.md)
  rounds every prefix sum exactly.

- Accumulators as R values:
  [`xsum_acc()`](https://pedrobtz.github.io/zuexact/reference/xsum_acc.md),
  [`xsum_add()`](https://pedrobtz.github.io/zuexact/reference/xsum_acc.md),
  [`xsum_merge()`](https://pedrobtz.github.io/zuexact/reference/xsum_acc.md),
  [`xsum_negate()`](https://pedrobtz.github.io/zuexact/reference/xsum_acc.md),
  [`xsum_value()`](https://pedrobtz.github.io/zuexact/reference/xsum_acc.md)
  and
  [`xsum_mean_value()`](https://pedrobtz.github.io/zuexact/reference/xsum_acc.md)
  build exact sums in pieces, in any order, and across processes (they
  serialise).
