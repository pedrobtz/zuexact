# IEEE 754 binary64 bit patterns as 16 hex digits, big-endian. Used for the
# test262 fixture and the cross-platform bits fixture, so that no decimal
# parsing or printing (which can differ between builds) is involved.

from_hex <- function(hex) {
  if (length(hex) == 0L) {
    return(double())
  }
  vapply(hex, function(h) {
    bytes <- as.raw(strtoi(substring(h, seq(1, 15, 2), seq(2, 16, 2)), 16L))
    readBin(bytes, "double", n = 1L, size = 8L, endian = "big")
  }, double(1), USE.NAMES = FALSE)
}

to_hex <- function(x) {
  vapply(x, function(v) {
    paste(format(writeBin(v, raw(), size = 8L, endian = "big")), collapse = "")
  }, character(1), USE.NAMES = FALSE)
}

read_sumprecise <- function() {
  path <- test_path("fixtures", "sumprecise", "cases.tsv")
  cases <- utils::read.delim(path, comment.char = "#", colClasses = "character")
  lapply(seq_len(nrow(cases)), function(i) {
    list(
      file = cases$file[[i]],
      inputs = from_hex(strsplit(cases$inputs[[i]], " ", fixed = TRUE)[[1]]),
      expected = from_hex(cases$expected[[i]])
    )
  })
}

# Results of every exact function on fixed inputs, as "name<TAB>hex" lines.
# Inputs come from the Mersenne Twister (exact on every platform) scaled by
# exact powers of two, plus the test262 vectors; no libm call that could
# differ between platforms is involved. tools/write-bits writes the
# reference file; test-bits.R compares on every CI leg (design §11).
bits_results <- function() {
  old <- if (exists(".Random.seed", globalenv())) get(".Random.seed", globalenv())
  on.exit(if (!is.null(old)) assign(".Random.seed", old, globalenv()))
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(20261013)
  u <- function(n, lo, hi) (2 * stats::runif(n) - 1) * 2^sample(lo:hi, n, TRUE)
  out <- character()
  add <- function(name, value) {
    out <<- c(out, paste(name, paste(to_hex(as.double(value)), collapse = " "), sep = "\t"))
  }
  for (n in c(1, 2, 3, 10, 100, 127, 128, 129, 383, 384, 385, 1000, 10000)) {
    x <- u(n, -1000, 1000)
    y <- u(n, -400, 400)
    z <- u(n, -400, 400)
    add(paste0("xsum/", n), xsum(x))
    add(paste0("xsum_mean/", n), xsum_mean(x))
    add(paste0("xsum_dot/", n), xsum_dot(y, z))
    add(paste0("xsum_sqnorm/", n), xsum_sqnorm(y))
    add(paste0("xsum_norm/", n), xsum_norm(y))
    add(paste0("xsum_weighted_mean/", n), xsum_weighted_mean(y, abs(z)))
    add(paste0("xsum_acc/", n), xsum_value(Reduce(
      xsum_merge, lapply(split(x, seq_along(x) %% 7), xsum_acc)
    )))
  }
  w <- u(200, -60, 60)
  add("xsum_cumsum/200", xsum_cumsum(w))
  m <- matrix(u(3000, -200, 200), 1500, 2)
  add("xsum_rowsums/1500x2", xsum_rowsums(m))
  add("xsum_colsums/1500x2", xsum_colsums(m))
  add("xsum_by/1500x2", xsum_by(m, rep(1:30, 50)))
  # 1e16 and 1e20 are exact powers of ten in binary64, parsed the same
  # everywhere. 1e308 is not: R's decimal parser gives a different double on
  # builds without long doubles, so it is built from its bit pattern.
  e308 <- from_hex("7fe1ccf385ebc8a0")
  add("xsum/hard", c(
    xsum(c(1e16, 1, -1e16)), xsum(c(1e20, 1, -1e20)),
    xsum(c(e308, e308, -e308)), xsum(rep(2^-1074, 3))
  ))
  for (i in seq_along(cases <- read_sumprecise())) {
    add(paste0("sumprecise/", i), xsum(cases[[i]]$inputs))
  }
  out
}
