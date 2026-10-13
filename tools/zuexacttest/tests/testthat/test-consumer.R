# zuexact Stage 6 exit criteria, from a consumer's side.

test_that("the table has the expected size and accumulator size", {
  info <- ct_info()
  expect_identical(info[[2]], 560)
  expect_gte(info[[1]], 10 * 8)   # two size_t and eight function pointers
})

test_that("sums and dot products through the table equal zuexact's", {
  set.seed(1)
  for (n in c(0, 1, 10, 1000, 100000)) {
    x <- stats::rnorm(n) * 2^sample(-40:40, n, TRUE)
    y <- stats::rnorm(n)
    expect_identical(ct_sum(x), zuexact::xsum(x))
    expect_identical(ct_dot(x, y), zuexact::xsum_dot(x, y))
  }
  expect_identical(ct_sum(c(1e20, 1, -1e20)), 1)
  expect_identical(ct_dot(c(1e8 + 1, 1), c(1e8 - 1, -1e16)), -1)
})

test_that("negate and merge give exact differences; div gives exact means", {
  expect_identical(ct_diff(c(0.1, 0.2), 0.3), 2^-55)
  expect_identical(ct_mean(c(1e15, -1e15, 0.1)), 0.1 / 3)
})

test_that("merged partial accumulators equal one accumulator", {
  set.seed(2)
  x <- stats::rnorm(5000) * 10^sample(-15:15, 5000, TRUE)
  for (p in c(1L, 2L, 7L, 64L)) {
    expect_identical(ct_sum_parts(x, p), zuexact::xsum(x))
  }
})

test_that("an xsum_acc's bytes are a table accumulator", {
  acc <- zuexact::xsum_acc(c(1e20, 1, -1e20, 0.5))
  expect_identical(ct_round_acc(acc), 1.5)
})

test_that("IEEE special values through the table", {
  expect_identical(ct_sum(c(1, Inf)), Inf)
  expect_true(is.nan(ct_sum(c(Inf, -Inf))))
  expect_true(is.nan(ct_sum(c(1, NaN))))
})
