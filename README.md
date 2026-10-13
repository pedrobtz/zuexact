# zuexact

<!-- badges: start -->
[![R-CMD-check](https://github.com/pedrobtz/zuexact/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/pedrobtz/zuexact/actions/workflows/R-CMD-check.yaml)
[![coverage](https://raw.githubusercontent.com/pedrobtz/zuexact/gh-pages/badges/coverage.svg)](https://github.com/pedrobtz/zuexact/actions/workflows/coverage.yaml)
<!-- badges: end -->

zuexact computes sums of doubles exactly and rounds once, at the end. The
result is the correctly rounded true sum. It does not depend on the order of
the elements, on the platform, or on how R was built. It is built on Radford
Neal's [xsum](https://github.com/radfordneal/xsum) superaccumulators.

Base R's `sum()` accumulates in `long double`. That is 80-bit on x86-64 Linux
and Windows, but the same as `double` on Apple Silicon and on R built without
long doubles. So the same call gives different answers on different machines:

``` r
sum(c(1e16, 1, -1e16))
#> 1 on x86-64 Linux and Windows
#> 0 on Apple Silicon
```

The exact answer is 1, everywhere, and `xsum()` returns it on every platform:

``` r
library(zuexact)
xsum(c(1e16, 1, -1e16))
#> [1] 1
xsum(c(1e20, 1, -1e20))      # wrong on every platform with sum()
#> [1] 1
xsum_mean(c(1e15, -1e15, 0.1))
#> [1] 0.03333333
```

## Sums in pieces, and across processes

An accumulator holds an exact sum in progress. It is an ordinary R value, so
an accumulator built on a worker comes back to the caller and merges there,
in any order, with the same bits as summing everything at once:

``` r
chunks <- split(x, rep(1:8, length.out = length(x)))
accs <- parallel::mclapply(chunks, xsum_acc)
xsum_value(Reduce(xsum_merge, accs)) == xsum(x)
#> [1] TRUE
```

The same works for Arrow record batches, DuckDB result chunks or files read
in pieces: `acc <- xsum_add(acc, chunk)` for each one, then `xsum_value(acc)`.
`xsum_merge(a, xsum_negate(b))` is the exact difference of two sums.

## What else is in the package

* `xsum_mean()`, `xsum_weighted_mean()`: exact means.
* `xsum_dot()`, `xsum_sqnorm()`, `xsum_norm()`: dot products and norms with
  each product's rounding error included.
* `xsum_cumsum()`, `xsum_rowsums()`, `xsum_colsums()`, `xsum_by()`: exact
  versions of `cumsum()`, `rowSums()`, `colSums()` and `rowsum()`.
* A registered C interface, `<zuexact.h>`, for other packages' compiled code.

`vignette("exact-summation")` explains the details. For compensated
summation (Kahan, Neumaier, pairwise), which is faster but not exact, see
[PreciseSums](https://CRAN.R-project.org/package=PreciseSums).

## Installation

You can install the development version of zuexact from
[GitHub](https://github.com/pedrobtz/zuexact) with:

``` r
# install.packages("pak")
pak::pak("pedrobtz/zuexact")
```
