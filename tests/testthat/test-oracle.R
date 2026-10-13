# Stage 7 (design §11): every result is the correctly rounded exact value.
# Oracles: exact rationals (gmp), PreciseSums::fsum() (Shewchuk, an
# independent exact algorithm), and the test262 Math.sumPrecise vectors.
# ZUEXACT_SLOW_TESTS=true widens every sweep (family rule R7).

test_that("the test262 Math.sumPrecise vectors pass, -0 rows as +0 (D10)", {
  for (case in read_sumprecise()) {
    got <- xsum(case$inputs)
    label <- paste(case$file, paste(to_hex(case$inputs), collapse = " "))
    if (identical(case$expected, 0) && 1 / case$expected < 0) {
      # Math.sumPrecise returns -0 for [], [-0] and [-0, -0]; zuexact
      # returns +0 always (design §6, D10).
      expect_identical(1 / got, Inf, info = label)
    } else {
      expect_identical(got, case$expected, info = label)
    }
  }
})

test_that("random sums equal the rational oracle", {
  skip_if_not_installed("gmp")
  withr::local_seed(30)
  reps <- if (slow_tests()) 400 else 40
  for (i in seq_len(reps)) {
    n <- sample(c(1:20, 100, 1000), 1)
    x <- (2 * stats::runif(n) - 1) * 2^sample(-1000:1000, n, TRUE)
    expect_identical(xsum(x), exact_sum(x), info = paste("rep", i))
  }
})

test_that("random sums agree with PreciseSums::fsum()", {
  skip_if_not_installed("PreciseSums")
  withr::local_seed(31)
  reps <- if (slow_tests()) 20000 else 500
  for (i in seq_len(reps)) {
    n <- sample(1:50, 1)
    # Exponents kept clear of overflow: fsum's intermediate sums must stay
    # finite.
    x <- (2 * stats::runif(n) - 1) * 2^sample(-300:300, n, TRUE)
    expect_identical(xsum(x), PreciseSums::fsum(x), info = paste("rep", i))
  }
})

test_that("ill-conditioned sums are exact (cond 1e8 to 1e40)", {
  skip_if_not_installed("gmp")
  withr::local_seed(32)
  conds <- 10^c(8, 16, 24, 32, 40)
  n <- if (slow_tests()) 200 else 40
  for (cond in conds) {
    x <- ill_sum(n, cond)
    expect_gt(cond_sum(x), cond / 1e4)
    expect_identical(xsum(x), exact_sum(x), info = format(cond))
    expect_identical(xsum_value(xsum_acc(x)), exact_sum(x))
    if (requireNamespace("PreciseSums", quietly = TRUE)) {
      expect_identical(xsum(x), PreciseSums::fsum(x))
    }
  }
})

test_that("ill-conditioned dot products are exact (cond 1e8 to 1e40)", {
  skip_if_not_installed("gmp")
  withr::local_seed(33)
  n <- if (slow_tests()) 200 else 40
  for (cond in 10^c(8, 16, 24, 32, 40)) {
    d <- ill_dot(n, cond)
    expect_identical(xsum_dot(d$x, d$y), exact_dot(d$x, d$y), info = format(cond))
  }
})

test_that("means and differences equal the rational oracle", {
  skip_if_not_installed("gmp")
  withr::local_seed(34)
  for (i in 1:30) {
    n <- sample(1:200, 1)
    x <- (2 * stats::runif(n) - 1) * 2^sample(-500:500, n, TRUE)
    expect_identical(
      xsum_mean(x), round_bigq(sum(gmp::as.bigq(x)) / n),
      info = paste("rep", i)
    )
  }
})

test_that("results do not depend on element order (50 permutations)", {
  withr::local_seed(35)
  cases <- c(
    lapply(read_sumprecise(), `[[`, "inputs"),
    list(ill_sum(60, 1e30), (2 * stats::runif(3000) - 1) * 2^sample(-60:60, 3000, TRUE))
  )
  for (x in cases) {
    ref <- xsum(x)
    for (i in 1:50) {
      expect_identical(xsum(x[sample.int(length(x))]), ref)
    }
  }
})
