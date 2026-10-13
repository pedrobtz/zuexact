# Weighted mean from exact sums

`xsum_weighted_mean()` computes `sum(w * x)` and `sum(w)` exactly, each
rounded once, and divides. The result therefore has **three** roundings:
the two sums and the division. Each sum is exact, which removes the
cancellation and accumulation error that dominates
`sum(w * x) / sum(w)`; an exact ratio of two superaccumulators is not
available.

## Usage

``` r
xsum_weighted_mean(x, w, na.rm = FALSE)
```

## Arguments

- x:

  A numeric or logical vector.

- w:

  Weights, of the same length as `x`.

- na.rm:

  Remove `NA` and `NaN` values before summing?

## Value

A double of length one.

## Details

With `na.rm = TRUE`, pairs where `x` is `NA` or `NaN` are removed, as in
[`stats::weighted.mean()`](https://rdrr.io/r/stats/weighted.mean.html);
`NA` weights are not removed.

## See also

Other means:
[`xsum_mean()`](https://pedrobtz.github.io/zuexact/reference/xsum_mean.md)

## Examples

``` r
xsum_weighted_mean(c(1e16, 1, -1e16), c(1, 1, 1))
#> [1] 0.3333333
```
