# A matrix of doubles spread over 80 binades, for exactness tests.
random_matrix <- function(nr, nc) {
  x <- stats::rnorm(nr * nc) * 2^sample(-40:40, nr * nc, TRUE)
  matrix(x, nr, nc)
}
