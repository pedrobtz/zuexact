# Exactly rounded mean

`xsum_mean()` divides the exact sum by the number of terms and rounds
once: the result is the correctly rounded value of the true mean, not
`xsum(x) / length(x)`, which would round twice. Base
[`mean()`](https://rdrr.io/r/base/mean.html) makes a second pass to
correct its first estimate, but its accumulator is still
platform-dependent.

## Usage

``` r
xsum_mean(x, na.rm = FALSE)
```

## Arguments

- x:

  A numeric, integer, logical or complex vector.

- na.rm:

  Remove `NA` and `NaN` values before summing?

## Value

A double of length one (complex for complex `x`).

## Details

Special values follow the table in
[`xsum()`](https://pedrobtz.github.io/zuexact/reference/xsum.md). The
mean of no values is `NaN`, as in base R. xsum divides by a 32-bit
count, so a mean over more than 2^32 - 1 terms signals a
`zuexact_count_error`.

## See also

Other means:
[`xsum_weighted_mean()`](https://pedrobtz.github.io/zuexact/reference/xsum_weighted_mean.md)

## Examples

``` r
# Base mean() is accurate to three digits here (Neal, 2015).
x <- c(1e15, -1e15, 0.1)
mean(x)
#> [1] 0.03333876
xsum_mean(x)
#> [1] 0.03333333
```
