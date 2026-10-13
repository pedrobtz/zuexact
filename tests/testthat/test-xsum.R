# Stage 2: xsum() and the special-value table of design §6.

test_that("§6: an empty sum is 0", {
  expect_identical(xsum(), 0)
  expect_identical(xsum(double()), 0)
  expect_identical(xsum(NULL, integer()), 0)
  expect_identical(xsum(complex()), 0 + 0i)
})

test_that("§6: any NA gives NA", {
  expect_identical(xsum(c(1, NA, 2)), NA_real_)
  expect_identical(xsum(c(NaN, NA)), NA_real_)
  expect_identical(xsum(c(NA, NaN)), NA_real_)
  expect_identical(xsum(c(Inf, NA, -Inf)), NA_real_)
  expect_identical(xsum(1L, NA_integer_), NA_real_)
  expect_identical(xsum(TRUE, NA), NA_real_)
})

test_that("§6: NaN without NA gives NaN", {
  expect_identical(xsum(c(1, NaN, 2)), NaN)
  expect_identical(xsum(c(NaN, Inf)), NaN)
})

test_that("§6: Inf and -Inf together give NaN", {
  expect_identical(xsum(c(Inf, 1, -Inf)), NaN)
  expect_identical(xsum(Inf, -Inf), NaN)
})

test_that("§6: Inf only gives Inf, -Inf only gives -Inf", {
  expect_identical(xsum(c(Inf, 1, -1e308)), Inf)
  expect_identical(xsum(c(-Inf, 1, 1e308)), -Inf)
  expect_identical(xsum(c(Inf, Inf)), Inf)
})

test_that("§6: a finite sum out of range rounds to an infinity", {
  big <- .Machine$double.xmax
  expect_identical(xsum(c(big, big)), Inf)
  expect_identical(xsum(c(-big, -big)), -Inf)
})

test_that("§6: zeros of any sign sum to +0 (D10)", {
  r <- xsum(-0)
  expect_identical(r, 0)
  expect_identical(1 / r, Inf)
  expect_identical(1 / xsum(c(-0, -0)), Inf)
  expect_identical(1 / xsum(c(1, -1)), Inf)
})

test_that("na.rm = TRUE removes NA and NaN but keeps infinities", {
  expect_identical(xsum(c(1, NA, NaN, 2), na.rm = TRUE), 3)
  expect_identical(xsum(c(NA, Inf), na.rm = TRUE), Inf)
  expect_identical(xsum(c(1L, NA_integer_, 2L), na.rm = TRUE), 3)
  expect_identical(xsum(c(NA, NaN), na.rm = TRUE), 0)
  # Long enough for the large accumulator and several blocks.
  x <- rep(c(1, NA, 0.5, NaN), 5000)
  expect_identical(xsum(x, na.rm = TRUE), 7500)
})

test_that("intermediate overflow does not spoil a finite exact sum", {
  expect_identical(xsum(c(1e308, 1e308, -1e308)), 1e308)
})

test_that("cancellation is exact where base sum() loses the small term", {
  expect_identical(xsum(c(1e20, 1, -1e20)), 1)
  expect_identical(xsum(c(1e16, 1, -1e16)), 1)
  expect_identical(xsum(c(1, 1e100, 1, -1e100)), 2)
})

test_that("subnormals are summed exactly", {
  tiny <- 2^-1074
  expect_identical(xsum(rep(tiny, 1000)), 1000 * tiny)
  expect_identical(xsum(c(tiny, 1, -1)), tiny)
})

test_that("the 2024 upstream fix holds: -DBL_MAX - 1 rounds to -DBL_MAX", {
  big <- .Machine$double.xmax
  expect_identical(xsum(-big, -1), -big)
})

test_that("ties round to even", {
  # 1 + 2^-53 is exactly halfway between 1 and the next double: rounds to 1.
  expect_identical(xsum(1, 2^-53), 1)
  # 1 + 2^-52 + 2^-53 is halfway between two doubles; the even one is above.
  expect_identical(xsum(1, 2^-52, 2^-53), 1 + 2^-51)
  # Just above halfway rounds up.
  expect_identical(xsum(1, 2^-53, 2^-100), 1 + 2^-52)
})

test_that("integers and logicals convert exactly and do not overflow", {
  imax <- .Machine$integer.max
  expect_identical(xsum(c(imax, imax)), 2 * imax)
  expect_identical(xsum(c(TRUE, FALSE, TRUE)), 2)
  expect_type(xsum(1L), "double")
})

test_that("several arguments are summed together", {
  expect_identical(xsum(1:10, c(0.5, 0.25), TRUE), 56.75)
  expect_identical(xsum(1e20, 1, -1e20), 1)
})

test_that("complex input is two exact sums", {
  expect_identical(xsum(complex(real = c(1e20, 1, -1e20), imaginary = c(1, 1e20, -1e20))), 1 + 1i)
  expect_identical(xsum(1 + 2i, 3, 1L), 5 + 2i)
  expect_identical(xsum(complex(real = NA, imaginary = 1)), complex(real = NA, imaginary = 1))
  expect_identical(
    xsum(c(1 + 1i, complex(real = 1, imaginary = NaN)), na.rm = TRUE),
    1 + 1i
  )
  expect_identical(xsum(1i, NA_integer_), complex(real = NA, imaginary = NA))
})

test_that("results do not depend on element order", {
  withr::local_seed(1)
  x <- c(stats::rnorm(1000) * 10^sample(-20:20, 1000, TRUE), 1e30, -1e30)
  ref <- xsum(x)
  for (i in 1:10) {
    expect_identical(xsum(sample(x)), ref)
  }
})

test_that("small and large accumulator paths agree around the threshold", {
  withr::local_seed(2)
  t <- zuexact_info()$large_threshold
  for (n in c(t - 1L, t, t + 1L)) {
    x <- stats::runif(n) * 2^sample(-40:40, n, TRUE)
    expect_identical(xsum(x), xsum(x[seq_len(t - 2L)], x[-seq_len(t - 2L)]))
  }
})

test_that("ALTREP vectors are summed without materialising", {
  expect_identical(xsum(1:100), 5050)
  # A wrapper ALTREP (from sorting metadata) of a double vector.
  x <- sort(c(3, 1, 2))
  expect_identical(xsum(x), 6)
  skip_on_cran()
  n <- 1e8
  x <- seq_len(n)
  gc(reset = TRUE)
  r <- xsum(x)
  used <- sum(gc()[, "max used"] * c(56, 8)) / 2^20 # Ncells, Vcells in MB
  expect_identical(r, n * (n + 1) / 2)
  # Materialising as integers would need ~400 MB.
  expect_lt(used, 300)
})

test_that("invalid arguments signal zuexact_invalid_argument", {
  expect_error(xsum("a"), class = "zuexact_invalid_argument")
  expect_error(xsum(1, list(1)), class = "zuexact_invalid_argument")
  expect_error(xsum(factor("a")), class = "zuexact_invalid_argument")
  expect_error(xsum(1, na.rm = NA), class = "zuexact_invalid_argument")
  expect_error(xsum(1, na.rm = c(TRUE, FALSE)), class = "zuexact_invalid_argument")
  expect_error(xsum("a"), class = "zuexact_error")
})

test_that("zuexact_info() describes the build", {
  info <- zuexact_info()
  expect_named(info, c(
    "xsum", "xsum_commit", "large_threshold", "simd", "fma_hardware",
    "long_double"
  ))
  expect_identical(info$xsum, "stable-version-3")
  expect_match(info$xsum_commit, "^[0-9a-f]{40}$")
  expect_type(info$large_threshold, "integer")
  expect_true(info$simd %in% c("avx", "sse2", "none"))
  expect_type(info$fma_hardware, "logical")
  expect_type(info$long_double, "logical")
})
