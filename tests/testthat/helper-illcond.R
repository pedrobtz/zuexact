# Ill-conditioned sums and dot products of a prescribed condition number,
# after Ogita, Rump and Oishi, "Accurate sum and dot product", SIAM J. Sci.
# Comput. 26 (2005), algorithms 6.1 (GenDot) and the GenSum variant shipped
# by accupy (generate_ill_conditioned_sum) and AccurateArithmetic.jl
# (generate_sum). Half the terms span exponents up to log2(cond) / 2; the
# other half are chosen so that the running exact result is tiny, which is
# what makes compensated methods fail. The exact partial results come from
# xsum itself; correctness is judged separately by the rational oracle.

ill_sum <- function(n, cond) {
  stopifnot(n >= 6)
  n2 <- round(n / 2)
  b <- log2(cond)
  x <- double(n)
  e <- round(stats::runif(n2) * b / 2)
  e[1] <- round(b / 2) + 1
  e[n2] <- 0
  x[seq_len(n2)] <- (2 * stats::runif(n2) - 1) * 2^e
  e2 <- round(seq(b / 2, 0, length.out = n - n2))
  for (k in (n2 + 1):n) {
    x[k] <- (2 * stats::runif(1) - 1) * 2^e2[k - n2]
    x[k] <- x[k] - xsum(x[seq_len(k)])
  }
  sample(x)
}

ill_dot <- function(n, cond) {
  stopifnot(n >= 6)
  n2 <- round(n / 2)
  b <- log2(cond)
  x <- double(n)
  y <- double(n)
  e <- round(stats::runif(n2) * b / 2)
  e[1] <- round(b / 2) + 1
  e[n2] <- 0
  x[seq_len(n2)] <- (2 * stats::runif(n2) - 1) * 2^e
  y[seq_len(n2)] <- (2 * stats::runif(n2) - 1) * 2^e
  e2 <- round(seq(b / 2, 0, length.out = n - n2))
  for (k in (n2 + 1):n) {
    x[k] <- (2 * stats::runif(1) - 1) * 2^e2[k - n2]
    y[k] <- ((2 * stats::runif(1) - 1) * 2^e2[k - n2] -
      xsum_dot(x[seq_len(k - 1)], y[seq_len(k - 1)])) / x[k]
  }
  i <- sample(n)
  list(x = x[i], y = y[i])
}

# Condition number of a sum, sum(|x|) / |sum(x)|, from the exact oracle.
cond_sum <- function(x) {
  s <- abs(sum(gmp::as.bigq(x)))
  if (s == 0) {
    return(Inf)
  }
  as.double(sum(gmp::as.bigq(abs(x))) / s)
}

slow_tests <- function() {
  identical(Sys.getenv("ZUEXACT_SLOW_TESTS"), "true")
}
