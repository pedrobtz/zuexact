# Stage 1: the vendored xsum, reached through the internal self-test entry
# point. Both accumulators must give the correctly rounded sum.

selftest <- function(x) .Call(zuexact:::zxe_selftest, as.double(x))

test_that("both accumulators sum cancelling terms exactly", {
  expect_identical(selftest(c(1e20, 1, -1e20)), c(1, 1))
  expect_identical(selftest(c(1e16, 1, -1e16)), c(1, 1))
  expect_identical(selftest(c(1e308, 1e308, -1e308)), c(1e308, 1e308))
})

test_that("the empty sum is zero in both accumulators", {
  expect_identical(selftest(double()), c(0, 0))
})

test_that("small and large accumulators agree bit for bit", {
  withr::local_seed(20261013)
  for (n in c(1, 2, 10, 383, 384, 385, 5000)) {
    x <- stats::runif(n, -1, 1) * 2^sample(-60:60, n, replace = TRUE)
    r <- selftest(x)
    expect_identical(r[[1]], r[[2]], info = paste("n =", n))
  }
})

test_that("the 2024 upstream rounding fix holds (-DBL_MAX - 1)", {
  # NEWS, stable version 3: rounding of negative values with an all-ones
  # mantissa overflowed to -Inf for -DBL_MAX - 1.
  dbl_max <- .Machine$double.xmax
  expect_identical(selftest(c(-dbl_max, -1)), c(-dbl_max, -dbl_max))
})

test_that("a sum is independent of element order", {
  withr::local_seed(42)
  x <- c(1e20, stats::rnorm(500), -1e20, 3.5, 2^-1074)
  ref <- selftest(x)
  for (i in 1:20) {
    expect_identical(selftest(sample(x)), ref)
  }
})
