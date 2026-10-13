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

The exact answer is 1, everywhere. zuexact's `xsum()` will return it on every
platform.

**Status:** under development; nothing is implemented yet. The design is in
[`.agents/design.md`](.agents/design.md) and the plan to the first CRAN
release in [`.agents/roadmap.md`](.agents/roadmap.md).

## Installation

You can install the development version of zuexact from
[GitHub](https://github.com/pedrobtz/zuexact) with:

``` r
# install.packages("pak")
pak::pak("pedrobtz/zuexact")
```
