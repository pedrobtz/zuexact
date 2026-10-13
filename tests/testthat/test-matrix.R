# Stage 5: row, column and grouped sums (design §2, §4, §5).

test_that("row and column sums equal xsum() of each slice", {
  withr::local_seed(20)
  for (dims in list(c(1, 1), c(7, 3), c(3000, 4), c(5, 2000))) {
    m <- random_matrix(dims[1], dims[2])
    expect_identical(xsum_rowsums(m), apply(m, 1, xsum), info = toString(dims))
    expect_identical(xsum_colsums(m), apply(m, 2, xsum), info = toString(dims))
  }
})

test_that("row sums cross the row-block boundary correctly", {
  withr::local_seed(21)
  m <- random_matrix(2500, 3)   # blocks of 1,024 rows: 1024, 1024, 452
  m[1024, ] <- c(1e300, 1, -1e300)
  m[1025, ] <- c(-1e300, 2, 1e300)
  r <- xsum_rowsums(m)
  expect_identical(r[1024:1025], c(1, 2))
  expect_identical(r, apply(m, 1, xsum))
})

test_that("exact where rowSums() and colSums() are not", {
  m <- cbind(a = c(1e20, 1), b = c(1, 1e20), c = c(-1e20, -1e20))
  expect_identical(xsum_rowsums(m), c(1, 1))
  expect_identical(xsum_colsums(m), c(a = 1e20, b = 1e20, c = -2e20))
  rownames(m) <- c("r1", "r2")
  expect_named(xsum_rowsums(m), c("r1", "r2"))
})

test_that("integer, logical and data frame input", {
  m <- matrix(1:6, 2)
  expect_identical(xsum_rowsums(m), c(9, 12))
  expect_identical(xsum_colsums(m), c(3, 7, 11))
  expect_identical(xsum_colsums(matrix(c(TRUE, NA, TRUE, FALSE), 2)), c(NA, 1))
  df <- data.frame(a = c(1e20, 1), b = c(-1e20, 2L))
  expect_identical(xsum_rowsums(df), c(0, 3))
  expect_identical(xsum_colsums(df), c(a = 1e20, b = -1e20 + 2))
})

test_that("special values apply cell by cell", {
  m <- rbind(
    c(1, NA, 2),
    c(1, NaN, 2),
    c(Inf, 1, -Inf),
    c(Inf, 1, 1),
    c(NA, NaN, Inf)
  )
  expect_identical(xsum_rowsums(m), c(NA, NaN, NaN, Inf, NA))
  expect_identical(xsum_rowsums(m, na.rm = TRUE), c(3, 3, NaN, Inf, Inf))
  expect_identical(xsum_colsums(m), c(NA, NA, NaN))
  expect_identical(xsum_colsums(m, na.rm = TRUE), c(Inf, 2, NaN))
  expect_identical(xsum_rowsums(matrix(1:4, 2) * NA_integer_), c(NA_real_, NA_real_))
})

test_that("empty matrices", {
  expect_identical(xsum_rowsums(matrix(0, 3, 0)), c(0, 0, 0))
  expect_identical(xsum_colsums(matrix(0, 0, 2)), c(0, 0))
  expect_identical(xsum_rowsums(matrix(0, 0, 2)), double())
})

test_that("row sums of a tall matrix need memory for a block, not per row", {
  skip_on_cran()
  m <- matrix(1, 1e7, 3)
  gc(reset = TRUE)
  before <- gc()[2, "used"]
  r <- xsum_rowsums(m)
  peak <- gc()[2, "max used"]
  # Vcells are 8 bytes. Beyond the input and the 80 MB result, row sums may
  # use well under 10 MB; one accumulator per row would need 5.6 GB.
  extra_mb <- (peak - before) * 8 / 2^20 - 8 * 1e7 / 2^20
  expect_lt(extra_mb, 10)
  expect_identical(r[c(1, 1e7)], c(3, 3))
})

test_that("xsum_by() matches rowsum() in shape and is exact", {
  x <- c(1e20, 1, 2, -1e20)
  g <- c("x", "y", "y", "x")
  expect_identical(xsum_by(x, g), matrix(c(0, 3), 2, dimnames = list(c("x", "y"), NULL)))
  withr::local_seed(22)
  m <- random_matrix(500, 3)
  colnames(m) <- c("a", "b", "c")
  g <- sample(c(5, 1, 3, NA), 500, TRUE)
  ref <- suppressWarnings(rowsum(m, g))
  out <- xsum_by(m, g)
  expect_identical(dimnames(out), dimnames(ref))
  for (k in seq_len(nrow(out))) {
    rows <- if (is.na(rownames(out)[k])) is.na(g) else g %in% as.numeric(rownames(out)[k])
    expect_identical(out[k, ], apply(m[rows, , drop = FALSE], 2, xsum))
  }
})

test_that("both grouped-sum paths give the same bits", {
  withr::local_seed(23)
  n <- 40000
  x <- stats::rnorm(n) * 2^sample(-30:30, n, TRUE)
  few <- sample(1:10, n, TRUE)        # 10 cells: one accumulator per cell
  many <- sample(1:20000, n, TRUE)    # 20,000 cells: counting sort
  expect_identical(xsum_by(x, few)[, 1], vapply(split(x, few), xsum, double(1)))
  out <- xsum_by(x, many)[, 1]
  ref <- vapply(split(x, many), xsum, double(1))
  expect_identical(out, ref)
})

test_that("grouped sums apply special values and na.rm per cell", {
  x <- c(1, NA, 2, NaN, Inf, -Inf, 5)
  g <- c(1, 1, 2, 2, 3, 3, 4)
  expect_identical(unname(xsum_by(x, g)[, 1]), c(NA, NaN, NaN, 5))
  expect_identical(unname(xsum_by(x, g, na.rm = TRUE)[, 1]), c(1, 2, NaN, 5))
  expect_identical(rownames(xsum_by(1:2, factor(c("b", "a")))), c("a", "b"))
})

test_that("invalid input signals zuexact_invalid_argument", {
  expect_error(xsum_rowsums(1:3), class = "zuexact_invalid_argument")
  expect_error(xsum_colsums(matrix("a")), class = "zuexact_invalid_argument")
  expect_error(xsum_rowsums(data.frame(a = "x")), class = "zuexact_invalid_argument")
  expect_error(xsum_by(1:3, 1:2), class = "zuexact_invalid_argument")
  expect_error(xsum_by("a", 1), class = "zuexact_invalid_argument")
  expect_error(xsum_rowsums(matrix(1), na.rm = NA), class = "zuexact_invalid_argument")
})
