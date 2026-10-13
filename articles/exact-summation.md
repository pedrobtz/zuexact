# Exact summation

``` r

library(zuexact)
```

## Why `sum()` differs between machines

Every floating-point addition rounds. Base R’s
[`sum()`](https://rdrr.io/r/base/sum.html) keeps its running total in a
`long double` to round less often. On x86-64 Linux and Windows that is
an 80-bit number with 64 bits of precision. On Apple Silicon, on Windows
ARM64, and on R built without long doubles, it is an ordinary double. So
the same call gives different answers on different machines:

``` r

x <- c(1e16, 1, -1e16)
sum(x) # 1 with 80-bit long doubles, 0 without
#> [1] 1
capabilities("long.double")
#> long.double 
#>        TRUE
```

Neither kind of accumulator gets this one right:

``` r

sum(c(1e20, 1, -1e20))
#> [1] 0
```

The order of the terms matters too, because each partial sum is rounded:

``` r

y <- c(1, 1e100, 1, -1e100)
c(sum(y), sum(rev(y)))
#> [1] 0 1
```

## One rounding, at the end

zuexact adds the numbers exactly, in a superaccumulator wide enough to
hold any sum of doubles, and rounds once. The result is the correctly
rounded value of the true sum. Because nothing is rounded along the way,
order, platform and build cannot change it.

``` r

xsum(x)
#> [1] 1
xsum(c(1e20, 1, -1e20))
#> [1] 1
c(xsum(y), xsum(rev(y)))
#> [1] 2 2
```

The superaccumulators are Radford Neal’s ‘xsum’ library (Neal, 2015,
<https://arxiv.org/abs/1505.05571>). They make exact summation cheap: on
long vectors
[`xsum()`](https://pedrobtz.github.io/zuexact/reference/xsum.md) costs
about one and a half times [`sum()`](https://rdrr.io/r/base/sum.html).

Means divide the exact sum by the count, with one rounding:

``` r

z <- c(1e15, -1e15, 0.1)
mean(z)
#> [1] 0.03333876
xsum_mean(z)
#> [1] 0.03333333
```

Dot products include the rounding error of each product, computed
exactly with a fused multiply-add, so they are correctly rounded too:

``` r

a <- c(1e8 + 1, 1)
b <- c(1e8 - 1, -1e16)
sum(a * b)
#> [1] 0
xsum_dot(a, b)
#> [1] -1
```

[`xsum_cumsum()`](https://pedrobtz.github.io/zuexact/reference/xsum_cumsum.md),
[`xsum_rowsums()`](https://pedrobtz.github.io/zuexact/reference/xsum_rowsums.md),
[`xsum_colsums()`](https://pedrobtz.github.io/zuexact/reference/xsum_rowsums.md)
and
[`xsum_by()`](https://pedrobtz.github.io/zuexact/reference/xsum_rowsums.md)
(the exact [`rowsum()`](https://rdrr.io/r/base/rowsum.html)) round each
of their results once in the same way.

## Special values

R tells `NA` from other `NaN`s, and base
[`sum()`](https://rdrr.io/r/base/sum.html) propagates them in ways that
depend on the platform. zuexact applies one table everywhere:

| Input contains                                | Result           |
|-----------------------------------------------|------------------|
| nothing                                       | `0`              |
| any `NA`                                      | `NA`             |
| no `NA`, any other `NaN`                      | `NaN`            |
| both `Inf` and `-Inf`                         | `NaN`            |
| `Inf` (and finite values)                     | `Inf`            |
| `-Inf` (and finite values)                    | `-Inf`           |
| finite values whose exact sum is out of range | `Inf` or `-Inf`  |
| only zeros, of any sign                       | `0` (never `-0`) |

``` r

xsum(c(1, NaN, NA))
#> [1] NA
xsum(c(Inf, -Inf))
#> [1] NaN
xsum(c(1e308, 1e308))
#> [1] Inf
xsum(c(1e308, 1e308, -1e308)) # the intermediate overflow does not matter
#> [1] 1e+308
```

## Sums in pieces, and across processes

An accumulator holds an exact sum in progress. Add data to it in pieces,
in any order, and read the rounded value when you need it:

``` r

acc <- xsum_acc()
acc <- xsum_add(acc, c(1e20, 1))
acc <- xsum_add(acc, -1e20)
xsum_value(acc)
#> [1] 1
```

Accumulators are ordinary R values: every operation returns a new one,
and they serialise. An accumulator built in another process comes back
and merges, and the result is the same bits as summing everything at
once:

``` r

set.seed(1)
v <- (2 * runif(1e5) - 1) * 10^sample(-15:15, 1e5, TRUE)
chunks <- split(v, rep(1:8, length.out = length(v)))
accs <- lapply(chunks, xsum_acc) # or parallel::mclapply(), mirai, future
identical(xsum_value(Reduce(xsum_merge, rev(accs))), xsum(v))
#> [1] TRUE
```

The same pattern sums Arrow record batches, DuckDB result chunks or
files read in pieces. `xsum_merge(a, xsum_negate(b))` is the exact
difference of two sums, rounded once, which is the comparison
reconciliation needs:

``` r

xsum_value(xsum_merge(xsum_acc(c(0.1, 0.2)), xsum_negate(xsum_acc(0.3))))
#> [1] 2.775558e-17
```

## From C, in other packages

zuexact registers a table of C functions so that other packages’
compiled code can use the same accumulators. In the consumer’s
`DESCRIPTION`:

    LinkingTo: zuexact
    Imports: zuexact

and in its C:

``` c
#include <zuexact.h>

const zuexact_api *zx = zuexact_api_get();
double acc[128];               /* zx->acc_size bytes, aligned as a double */
zx->init(acc);
zx->addv(acc, x, n);           /* exact */
zx->add_dot(acc, x, y, n);     /* exact, products included */
double s = zx->round(acc);     /* correctly rounded */
```

An accumulator is plain memory owned by the caller, so the functions are
safe from any thread with its own accumulator. The table follows IEEE
rules for special values; the R functions add R’s rules on top. See
`inst/include/zuexact.h` for the full interface and its versioning
rules.
