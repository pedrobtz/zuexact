# Exactly rounded dot products and norms

`xsum_dot()` returns the correctly rounded value of the exact dot
product `sum(x * y)`, products included: each product is split into its
rounded value and its exact rounding error with `fma()`, and both are
added exactly. One rounding.

## Usage

``` r
xsum_dot(x, y)

xsum_sqnorm(x)

xsum_norm(x)
```

## Arguments

- x, y:

  Numeric or logical vectors of the same length.

## Value

A double of length one.

## Details

`xsum_sqnorm()` is `xsum_dot(x, x)`, the exactly rounded squared
Euclidean norm. `xsum_norm()` is its square root, so it has **two**
roundings: the squared norm and the square root.

## Limits

The product error is exact only while each product is above about 2^-970
in magnitude (about 1e-292). Below that, the low bits of the error are
lost to underflow, so a dot product made only of such tiny products can
be off in its last bits. A product whose magnitude exceeds the largest
double is `Inf` even if the exact dot product would be finite.

## Special values

Any `NA` in `x` or `y` gives `NA`. Otherwise a `NaN` product (a `NaN`
input, or `0 * Inf`) gives `NaN`; infinite products of both signs give
`NaN`; infinite products of one sign give that infinity.

## Examples

``` r
# (1e8 + 1) * (1e8 - 1) is 1e16 - 1, which rounds to 1e16 as a double.
x <- c(1e8 + 1, 1)
y <- c(1e8 - 1, -1e16)
sum(x * y)
#> [1] 0
xsum_dot(x, y)
#> [1] -1

xsum_norm(c(3, 4))
#> [1] 5
```
