# Exactly rounded cumulative sums

Each element of `xsum_cumsum(x)` is the exactly rounded sum of `x[1:i]`.
Unlike base [`cumsum()`](https://rdrr.io/r/base/cumsum.html), no
rounding error carries from one element to the next. Special values
follow the table in
[`xsum()`](https://pedrobtz.github.io/zuexact/reference/xsum.md),
applied to each prefix: once an `NA` appears, every later element is
`NA`.

## Usage

``` r
xsum_cumsum(x)
```

## Arguments

- x:

  A numeric or logical vector.

## Value

A double vector of the same length as `x`.

## Details

This is the slowest function in the package: every prefix is rounded,
which costs a scan of the accumulator per element.

## Examples

``` r
x <- c(1e20, 1, -1e20, 1)
cumsum(x)
#> [1] 1e+20 1e+20 0e+00 1e+00
xsum_cumsum(x)
#> [1] 1e+20 1e+20 1e+00 2e+00
```
