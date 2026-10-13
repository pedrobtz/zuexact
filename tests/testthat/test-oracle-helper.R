# The oracle itself must round correctly, or every test built on it lies.

test_that("round_bigq() rounds to nearest, ties to even", {
  skip_if_not_installed("gmp")
  q <- function(x) gmp::as.bigq(x)
  expect_identical(round_bigq(q(1) + q(2)^-53), 1)            # tie, even below
  expect_identical(round_bigq(q(1) + q(3) * q(2)^-53), 1 + 2^-51) # tie, even above
  expect_identical(round_bigq(q(1) + q(2)^-53 + q(2)^-80), 1 + 2^-52)
  expect_identical(round_bigq(-(q(1) + q(2)^-53 + q(2)^-80)), -(1 + 2^-52))
  expect_identical(round_bigq(q(1) / q(3)), 1 / 3)
  expect_identical(round_bigq(q(0)), 0)
  expect_identical(round_bigq(q(2)^-1075 * 3), 2 * 2^-1074)   # subnormal tie
})
