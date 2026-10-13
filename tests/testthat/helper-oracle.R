# Exact rational oracle (design §11). gmp's as.double() on a bigq truncates
# toward zero, so round_bigq() rounds a rational to the nearest double,
# ties to even, by comparing exactly with the two candidate doubles.

ulp_up <- function(a) {
  # Spacing of doubles just above a >= 0 (a finite).
  if (a < 2^-1022) {
    return(2^-1074)
  }
  2^(floor(log2(a)) - 52)
}

round_bigq <- function(q) {
  if (q == 0) {
    return(0)
  }
  neg <- q < 0
  aq <- abs(q)
  lo <- as.double(aq) # truncated: lo <= |q|
  # as.double() may land exactly on a power-of-two boundary from below;
  # recompute the binade from lo itself.
  if (gmp::as.bigq(lo) == aq) {
    return(if (neg) -lo else lo)
  }
  u <- ulp_up(lo)
  hi <- lo + u
  dlo <- aq - gmp::as.bigq(lo)
  dhi <- gmp::as.bigq(hi) - aq
  r <- if (dlo < dhi) {
    lo
  } else if (dhi < dlo) {
    hi
  } else if ((lo / u) %% 2 == 0) {
    lo
  } else {
    hi
  }
  if (neg) -r else r
}

exact_sum <- function(x) {
  round_bigq(sum(gmp::as.bigq(x)))
}

exact_dot <- function(x, y) {
  round_bigq(sum(gmp::as.bigq(x) * gmp::as.bigq(y)))
}
