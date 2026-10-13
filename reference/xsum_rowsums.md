# Exactly rounded row, column and grouped sums

`xsum_rowsums()` and `xsum_colsums()` are exact versions of
[`rowSums()`](https://rdrr.io/r/base/colSums.html) and
[`colSums()`](https://rdrr.io/r/base/colSums.html): every row or column
sum is the correctly rounded exact sum. `xsum_by()` is an exact version
of [`rowsum()`](https://rdrr.io/r/base/rowsum.html): the rows of `x` are
summed within each group, and the result has one row per group, sorted.

## Usage

``` r
xsum_rowsums(x, na.rm = FALSE)

xsum_colsums(x, na.rm = FALSE)

xsum_by(x, group, na.rm = FALSE)
```

## Arguments

- x:

  A numeric or logical matrix, or a data frame of numeric or logical
  columns. For `xsum_by()`, also a vector.

- na.rm:

  Remove `NA` and `NaN` values before summing?

- group:

  A vector with one value per row of `x` (per element, for a vector).
  `NA` is a group of its own, sorted last, as in
  [`rowsum()`](https://rdrr.io/r/base/rowsum.html).

## Value

`xsum_rowsums()` and `xsum_colsums()` return a double vector named by
the row or column names. `xsum_by()` returns a double matrix with one
row per group (named by the group) and one column per column of `x`.

## Details

Special values follow the table in
[`xsum()`](https://pedrobtz.github.io/zuexact/reference/xsum.md), cell
by cell. Row sums are computed a block of rows at a time, so the extra
memory they need does not grow with the number of rows.

## Examples

``` r
m <- cbind(a = c(1e20, 1), b = c(1, 1e20), c = c(-1e20, -1e20))
rowSums(m)
#> [1] 0 0
xsum_rowsums(m)
#> [1] 1 1
xsum_colsums(m)
#>      a      b      c 
#>  1e+20  1e+20 -2e+20 

xsum_by(c(1e20, 1, 2, -1e20), c("x", "y", "y", "x"))
#>   [,1]
#> x    0
#> y    3
```
