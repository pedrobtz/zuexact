# Stage 3: exact dot products with TwoProduct (design §9), norms and
# cumulative sums.

test_that("dot products include the products' rounding errors", {
  # (1e8 + 1) * (1e8 - 1) = 1e16 - 1, which is not a double.
  x <- c(1e8 + 1, 1)
  y <- c(1e8 - 1, -1e16)
  expect_identical(sum(x * y), 0)
  expect_identical(xsum_dot(x, y), -1)
})

test_that("TwoProduct canary: contraction would lose the error term", {
  # x * x = 1 + 2^-26 + 2^-54 exactly; the rounded product drops 2^-54.
  # Only a correct fma() error term recovers it. If the compiler fused or
  # reassociated p = x*x and e = fma(x, x, -p), e would be 0 and the
  # result would equal the rounded product.
  x <- 1 + 2^-27
  p <- x * x
  expect_identical(p, 1 + 2^-26)
  expect_identical(xsum_dot(c(x, 1), c(x, -(1 + 2^-26))), 2^-54)
})

test_that("dot products are exact on cancelling sums of products", {
  withr::local_seed(3)
  x <- stats::rnorm(200)
  y <- stats::rnorm(200)
  # The dot product of (x, -x) with (y, y) is exactly zero.
  expect_identical(xsum_dot(c(x, -x), c(y, y)), 0)
  # And appending a small term recovers it exactly.
  expect_identical(xsum_dot(c(x, -x, 1), c(y, y, 2^-60)), 2^-60)
})

test_that("dot products match the gmp rational oracle", {
  skip_if_not_installed("gmp")
  withr::local_seed(4)
  for (n in c(5, 50, 500)) {
    x <- stats::rnorm(n) * 2^sample(-30:30, n, TRUE)
    y <- stats::rnorm(n) * 2^sample(-30:30, n, TRUE)
    expect_identical(xsum_dot(x, y), exact_dot(x, y), info = paste("n =", n))
  }
})

test_that("special values in dot products", {
  expect_identical(xsum_dot(c(1, NA), c(1, 1)), NA_real_)
  expect_identical(xsum_dot(c(1, 1), c(NA, NaN)), NA_real_)
  expect_identical(xsum_dot(c(1, NaN), c(1, 1)), NaN)
  expect_identical(xsum_dot(c(0, 1), c(Inf, 1)), NaN)
  expect_identical(xsum_dot(c(Inf, 1), c(1, 1)), Inf)
  expect_identical(xsum_dot(c(Inf, Inf), c(1, -1)), NaN)
  expect_identical(xsum_dot(c(-Inf, 2), c(1, 1)), -Inf)
  expect_identical(xsum_dot(double(), double()), 0)
})

test_that("a product beyond the double range is infinite (design §9)", {
  expect_identical(xsum_dot(c(1e200, 1e200), c(1e200, -1e200)), NaN)
  expect_identical(xsum_dot(1e200, 1e200), Inf)
})

test_that("tiny products lose error bits only below the underflow bound", {
  skip_if_not_installed("gmp")
  # Above 2^-970 the error term is exact.
  x <- (1 + 2^-30) * 2^-480
  expect_identical(xsum_dot(x, x), exact_dot(x, x))
  # Far below, the product itself underflows; the result is still the
  # correctly rounded value of the rounded product, documented as a limit.
  y <- 2^-540
  expect_identical(xsum_dot(y, y), 0)
})

test_that("integers and logicals are accepted", {
  expect_identical(xsum_dot(1:3, 4:6), 32)
  expect_identical(xsum_dot(c(TRUE, TRUE), c(2, 3)), 5)
  expect_identical(xsum_dot(c(NA, 1L), 1:2), NA_real_)
})

test_that("invalid arguments signal zuexact_invalid_argument", {
  expect_error(xsum_dot(1:2, 1:3), class = "zuexact_invalid_argument")
  expect_error(xsum_dot("a", 1), class = "zuexact_invalid_argument")
  expect_error(xsum_sqnorm(list(1)), class = "zuexact_invalid_argument")
})

test_that("squared norm and norm", {
  expect_identical(xsum_sqnorm(c(3, 4)), 25)
  expect_identical(xsum_norm(c(3, 4)), 5)
  # The squared norm of (x, y) includes both squares' rounding errors:
  # x^2 - y^2 with x = 1 + 2^-27, y^2 = 1 + 2^-26 would need a dot product,
  # so check via a sum of squares that cancels to the error term.
  x <- 1 + 2^-27
  expect_identical(xsum_dot(c(x, 1), c(x, -(1 + 2^-26))), 2^-54)
  expect_identical(xsum_sqnorm(c(1e-200, 1e-200)), 2e-400 * 1)
  expect_identical(xsum_sqnorm(double()), 0)
  expect_identical(xsum_sqnorm(c(1e200)), Inf)
})

test_that("cumulative sums round every prefix exactly", {
  expect_identical(xsum_cumsum(c(1e20, 1, -1e20, 1)), c(1e20, 1e20, 1, 2))
  expect_identical(xsum_cumsum(double()), double())
  expect_identical(xsum_cumsum(1:4), c(1, 3, 6, 10))
  expect_identical(xsum_cumsum(c(a = 1, b = 2)), c(a = 1, b = 3))
})

test_that("cumulative sums apply the special-value rules per prefix", {
  expect_identical(xsum_cumsum(c(1, NA, 2)), c(1, NA, NA))
  expect_identical(xsum_cumsum(c(1, NaN, NA)), c(1, NaN, NA))
  expect_identical(xsum_cumsum(c(Inf, 1, -Inf)), c(Inf, Inf, NaN))
  expect_identical(xsum_cumsum(c(1L, NA, 2L)), c(1, NA, NA))
})

test_that("cumulative sums match xsum() of every prefix", {
  withr::local_seed(5)
  x <- stats::rnorm(100) * 10^sample(-15:15, 100, TRUE)
  expect_identical(
    xsum_cumsum(x),
    vapply(seq_along(x), function(i) xsum(x[seq_len(i)]), double(1))
  )
})

test_that("dot products are exact for operands near the top of the range", {
  skip_if_not_installed("gmp")
  # Without hardware FMA, TwoProduct splits the operands; above 2^995 it
  # scales them first so the split cannot overflow (zxe_twoprod.h).
  withr::local_seed(6)
  x <- (2 * stats::runif(50) - 1) * 2^sample(996:1010, 50, TRUE)
  y <- (2 * stats::runif(50) - 1) * 2^sample(-1000:-990, 50, TRUE)
  expect_identical(xsum_dot(x, y), exact_dot(x, y))
  expect_identical(xsum_dot(c(x, 1), c(y, 2^-40)), exact_dot(c(x, 1), c(y, 2^-40)))
})
