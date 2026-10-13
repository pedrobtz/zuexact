# Stage 3: exactly rounded means (design §2, §5, §16 question 1).

test_that("the mean is the exact sum divided once", {
  # Neal's example: base mean() is accurate to three digits here.
  expect_identical(xsum_mean(c(1e15, -1e15, 0.1)), 0.1 / 3)
  expect_identical(xsum_mean(c(1, 2)), 1.5)
  expect_identical(xsum_mean(1:10), 5.5)
  expect_identical(xsum_mean(c(TRUE, FALSE)), 0.5)
})

test_that("the mean of values whose sum overflows is still exact", {
  big <- .Machine$double.xmax
  expect_identical(xsum_mean(c(big, big)), big)
  expect_identical(xsum_mean(c(big, big, -big)), big / 3)
})

test_that("the mean of a third rounds correctly where sum / n does not", {
  # 0.1 + 0.2 + 0.3 is not 0.6 in doubles, but the exact sum of the three
  # doubles divided by 3 rounds to 0.2.
  x <- c(0.1, 0.2, 0.3)
  expect_identical(xsum_mean(x), 0.2)
})

test_that("special values follow the table of xsum()", {
  expect_identical(xsum_mean(double()), NaN)
  expect_identical(xsum_mean(c(1, NA)), NA_real_)
  expect_identical(xsum_mean(c(1, NaN)), NaN)
  expect_identical(xsum_mean(c(Inf, 1)), Inf)
  expect_identical(xsum_mean(c(Inf, -Inf)), NaN)
  expect_identical(xsum_mean(c(1L, NA)), NA_real_)
  expect_identical(xsum_mean(c(NA, NaN, 3), na.rm = TRUE), 3)
  expect_identical(xsum_mean(c(NA_real_, NA_real_), na.rm = TRUE), NaN)
  expect_identical(xsum_mean(c(-0, -0)), 0)
})

test_that("na.rm = TRUE divides by the number of terms kept", {
  expect_identical(xsum_mean(c(1, NA, 2, NaN), na.rm = TRUE), 1.5)
  expect_identical(xsum_mean(c(1L, NA, 4L), na.rm = TRUE), 2.5)
  x <- rep(c(1, NA, 2), 1000)
  expect_identical(xsum_mean(x, na.rm = TRUE), 1.5)
})

test_that("complex means are two exact means", {
  expect_identical(xsum_mean(c(1 + 1i, 2 + 3i)), 1.5 + 2i)
  expect_identical(xsum_mean(complex()), complex(real = NaN, imaginary = NaN))
})

test_that("more than 2^32 - 1 terms signals zuexact_count_error", {
  # A compact sequence: refused from its length, before any summing.
  x <- seq_len(2^32)
  expect_error(xsum_mean(x), class = "zuexact_count_error")
  expect_error(xsum_mean(x), class = "zuexact_error")
})

test_that("invalid input signals zuexact_invalid_argument", {
  expect_error(xsum_mean("a"), class = "zuexact_invalid_argument")
  expect_error(xsum_mean(NULL), class = "zuexact_invalid_argument")
  expect_error(xsum_mean(1, na.rm = NA), class = "zuexact_invalid_argument")
})

test_that("the weighted mean divides two exact sums", {
  expect_identical(xsum_weighted_mean(c(1e16, 1, -1e16), c(1, 1, 1)), 1 / 3)
  expect_identical(xsum_weighted_mean(c(1, 3), c(3, 1)), 1.5)
  expect_identical(
    xsum_weighted_mean(c(1, NA, 3), c(1, 5, 1), na.rm = TRUE), 2
  )
  expect_identical(xsum_weighted_mean(c(1, NA), c(1, 1)), NA_real_)
  expect_error(xsum_weighted_mean(1:2, 1), class = "zuexact_invalid_argument")
  expect_error(xsum_weighted_mean("a", 1), class = "zuexact_invalid_argument")
})
