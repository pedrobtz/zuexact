# Accumulators: exact sums built in pieces

An accumulator holds an exact sum in progress. Add vectors to it in any
order and in any number of pieces, merge accumulators built elsewhere,
and read the correctly rounded value at any time. The result is the same
as [`xsum()`](https://pedrobtz.github.io/zuexact/reference/xsum.md) of
all the pieces together, bit for bit.

## Usage

``` r
xsum_acc(x = NULL, na.rm = FALSE)

xsum_add(acc, x, na.rm = FALSE)

xsum_merge(acc, other)

xsum_negate(acc)

xsum_value(acc)

xsum_mean_value(acc, n)
```

## Arguments

- x:

  A numeric or logical vector (`NULL` for none).

- na.rm:

  Remove `NA` and `NaN` values before summing?

- acc, other:

  Accumulators, from `xsum_acc()`.

- n:

  The number of terms the accumulator holds, for the mean.

## Value

`xsum_acc()`, `xsum_add()`, `xsum_merge()` and `xsum_negate()` return an
accumulator. `xsum_value()` and `xsum_mean_value()` return a double of
length one.

## Details

Accumulators are ordinary R values (raw vectors of class `"xsum_acc"`,
568 bytes): `xsum_add()`, `xsum_merge()` and `xsum_negate()` return a
new accumulator and leave their argument unchanged. Because they are
values, they serialise: an accumulator built on a worker by `parallel`,
`mirai` or `future` comes back to the caller and merges there.
`Reduce(xsum_merge, accs)` combines a list of them in any order.

`xsum_negate()` changes the sign of the sum, so
`xsum_merge(a, xsum_negate(b))` is the exact difference of two sums,
rounded once.

An accumulator does not count its terms; `xsum_mean_value()` takes the
count. Special values follow the table in
[`xsum()`](https://pedrobtz.github.io/zuexact/reference/xsum.md); an
accumulator remembers whether it has seen `NA`, `NaN`, `Inf` or `-Inf`.

Accumulator bytes are those of the machine that made them. Every CRAN
platform is little-endian; an accumulator from a big-endian machine
signals a `zuexact_accumulator_error`.

## Examples

``` r
acc <- xsum_acc()
acc <- xsum_add(acc, c(1e20, 1))
acc <- xsum_add(acc, -1e20)
xsum_value(acc)
#> [1] 1

# Pieces in any order, merged in any order.
chunks <- split(c(1e100, 1:10, -1e100), rep(1:3, length.out = 12))
accs <- lapply(chunks, xsum_acc)
xsum_value(Reduce(xsum_merge, rev(accs)))
#> [1] 55

# The exact difference of two sums.
a <- xsum_acc(c(0.1, 0.2))
b <- xsum_acc(0.3)
xsum_value(xsum_merge(a, xsum_negate(b)))
#> [1] 2.775558e-17
```
