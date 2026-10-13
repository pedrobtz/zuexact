# Stage 4: accumulator values (design §4, §5, D9).

test_that("a new accumulator is zero and 568 bytes", {
  acc <- xsum_acc()
  expect_s3_class(acc, "xsum_acc")
  expect_identical(typeof(acc), "raw")
  expect_length(unclass(acc), 568L)
  expect_identical(xsum_value(acc), 0)
  expect_identical(as.double(acc), 0)
})

test_that("chunked adds equal xsum() of the whole, across the threshold", {
  withr::local_seed(10)
  t <- zuexact_info()$large_threshold
  x <- stats::rnorm(5 * t) * 2^sample(-50:50, 5 * t, TRUE)
  for (size in c(1L, t - 1L, t, t + 1L, 3L * t)) {
    pieces <- split(x, ceiling(seq_along(x) / size))
    acc <- Reduce(xsum_add, pieces, xsum_acc())
    expect_identical(xsum_value(acc), xsum(x), info = paste("size", size))
  }
})

test_that("merging in any order gives the same bits", {
  withr::local_seed(11)
  x <- c(stats::rnorm(1000) * 10^sample(-20:20, 1000, TRUE), 1e300, -1e300)
  accs <- lapply(split(x, rep(1:7, length.out = length(x))), xsum_acc)
  ref <- xsum_value(Reduce(xsum_merge, accs))
  expect_identical(ref, xsum(x))
  for (i in 1:10) {
    expect_identical(xsum_value(Reduce(xsum_merge, sample(accs))), ref)
  }
})

test_that("operations return new values and leave arguments unchanged", {
  a <- xsum_acc(1)
  b <- xsum_add(a, 2)
  expect_identical(xsum_value(a), 1)
  expect_identical(xsum_value(b), 3)
  m <- xsum_merge(a, b)
  expect_identical(xsum_value(a), 1)
  expect_identical(xsum_value(m), 4)
  expect_identical(xsum_value(xsum_negate(a)), -1)
  expect_identical(xsum_value(a), 1)
})

test_that("merge with a negation is the exact difference", {
  a <- xsum_acc(c(0.1, 0.2))
  b <- xsum_acc(0.3)
  expect_identical(xsum_value(xsum_merge(a, xsum_negate(b))), 2^-55)
  skip_if_not_installed("gmp")
  withr::local_seed(12)
  x <- stats::rnorm(300)
  y <- stats::rnorm(200)
  expect_identical(
    xsum_value(xsum_merge(xsum_acc(x), xsum_negate(xsum_acc(y)))),
    round_bigq(sum(gmp::as.bigq(x)) - sum(gmp::as.bigq(y)))
  )
})

test_that("the mean value divides exactly by the count given", {
  acc <- xsum_acc(c(1e15, -1e15, 0.1))
  expect_identical(xsum_mean_value(acc, 3), 0.1 / 3)
  expect_identical(xsum_mean_value(acc, 3L), 0.1 / 3)
  expect_identical(xsum_mean_value(xsum_acc(), 0), NaN)
  expect_error(xsum_mean_value(acc, -1), class = "zuexact_invalid_argument")
  expect_error(xsum_mean_value(acc, 1.5), class = "zuexact_invalid_argument")
  expect_error(xsum_mean_value(acc, 2^32), class = "zuexact_count_error")
})

test_that("special values follow design §6 and survive merges", {
  expect_identical(xsum_value(xsum_acc(c(1, NA))), NA_real_)
  expect_identical(xsum_value(xsum_acc(c(1, NaN))), NaN)
  expect_identical(xsum_value(xsum_acc(c(NaN, NA))), NA_real_)
  expect_identical(xsum_value(xsum_acc(c(Inf, 1))), Inf)
  expect_identical(xsum_value(xsum_acc(c(1L, NA))), NA_real_)
  inf <- xsum_acc(Inf)
  ninf <- xsum_acc(-Inf)
  expect_identical(xsum_value(xsum_merge(inf, ninf)), NaN)
  expect_identical(xsum_value(xsum_negate(inf)), -Inf)
  expect_identical(xsum_value(xsum_merge(inf, xsum_negate(inf))), NaN)
  na <- xsum_acc(NA_real_)
  expect_identical(xsum_value(xsum_negate(na)), NA_real_)
  expect_identical(xsum_value(xsum_merge(xsum_acc(NaN), na)), NA_real_)
  expect_identical(xsum_value(xsum_acc(c(1, NA, NaN), na.rm = TRUE)), 1)
  expect_identical(xsum_value(xsum_acc(c(NA, Inf), na.rm = TRUE)), Inf)
  long <- c(rep(1, 1000), NA)
  expect_identical(xsum_value(xsum_acc(long)), NA_real_)
  expect_identical(xsum_value(xsum_acc(long, na.rm = TRUE)), 1000)
})

test_that("accumulators serialise and unserialise unchanged", {
  acc <- xsum_acc(c(1e20, 1, -1e20, 2^-1074))
  back <- unserialize(serialize(acc, NULL))
  expect_identical(back, acc)
  expect_identical(xsum_value(back), 1)
  path <- withr::local_tempfile(fileext = ".rds")
  saveRDS(acc, path)
  expect_identical(xsum_value(readRDS(path)), xsum_value(acc))
})

test_that("accumulators built on parallel workers merge on the caller", {
  skip_on_cran()
  skip_if_not_installed("parallel")
  # Workers load the installed package; under devtools::load_all() there is
  # none (R CMD check and CI install it).
  pkg <- find.package("zuexact")
  skip_if(!dir.exists(file.path(pkg, "libs")), "zuexact is not installed")
  withr::local_seed(13)
  x <- stats::rnorm(4000) * 10^sample(-15:15, 4000, TRUE)
  chunks <- split(x, rep(1:4, each = 1000))
  cl <- parallel::makePSOCKcluster(2)
  on.exit(parallel::stopCluster(cl), add = TRUE)
  lib <- dirname(pkg)
  parallel::clusterCall(cl, function(lib) .libPaths(c(lib, .libPaths())), lib)
  accs <- parallel::parLapply(cl, chunks, function(v) zuexact::xsum_acc(v))
  expect_identical(xsum_value(Reduce(xsum_merge, accs)), xsum(x))
})

test_that("invalid accumulators signal zuexact_accumulator_error", {
  acc <- xsum_acc(1)
  bytes <- unclass(acc)
  bad_magic <- bytes
  bad_magic[1] <- as.raw(0)
  expect_error(xsum_value(new_acc(bad_magic)), class = "zuexact_accumulator_error")
  bad_order <- bytes
  bad_order[6] <- as.raw(if (bytes[6] == as.raw(1)) 2 else 1)
  expect_error(xsum_value(new_acc(bad_order)), class = "zuexact_accumulator_error")
  bad_version <- bytes
  bad_version[5] <- as.raw(99)
  expect_error(xsum_merge(acc, new_acc(bad_version)), class = "zuexact_accumulator_error")
  expect_error(xsum_value(new_acc(bytes[1:10])), class = "zuexact_accumulator_error")
  expect_error(xsum_value(new_acc(bytes[1:10])), class = "zuexact_error")
})

test_that("non-accumulators and bad input signal zuexact_invalid_argument", {
  expect_error(xsum_value(1), class = "zuexact_invalid_argument")
  expect_error(xsum_add(xsum_acc(), "a"), class = "zuexact_invalid_argument")
  expect_error(xsum_add(xsum_acc(), 1i), class = "zuexact_invalid_argument")
  expect_error(xsum_merge(xsum_acc(), raw(568)), class = "zuexact_invalid_argument")
  expect_error(xsum_acc(1, na.rm = NA), class = "zuexact_invalid_argument")
})

test_that("print and format show the rounded value", {
  acc <- xsum_acc(c(1e20, 1, -1e20))
  expect_identical(format(acc), "<xsum_acc> 1")
  expect_output(print(acc), "<xsum_acc> 1", fixed = TRUE)
})
