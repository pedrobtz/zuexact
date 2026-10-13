#' Exactly rounded dot products and norms
#'
#' `xsum_dot()` returns the correctly rounded value of the exact dot product
#' `sum(x * y)`, products included: each product is split into its rounded
#' value and its exact rounding error with `fma()`, and both are added
#' exactly. One rounding.
#'
#' `xsum_sqnorm()` is `xsum_dot(x, x)`, the exactly rounded squared
#' Euclidean norm. `xsum_norm()` is its square root, so it has **two**
#' roundings: the squared norm and the square root.
#'
#' @section Limits:
#' The product error is exact only while each product is above about
#' 2^-970 in magnitude (about 1e-292). Below that, the low bits of the error
#' are lost to underflow, so a dot product made only of such tiny products
#' can be off in its last bits. A product whose magnitude exceeds the
#' largest double is `Inf` even if the exact dot product would be finite.
#'
#' @section Special values:
#' Any `NA` in `x` or `y` gives `NA`. Otherwise a `NaN` product (a `NaN`
#' input, or `0 * Inf`) gives `NaN`; infinite products of both signs give
#' `NaN`; infinite products of one sign give that infinity.
#'
#' @param x,y Numeric or logical vectors of the same length.
#' @return A double of length one.
#' @export
#' @examples
#' # (1e8 + 1) * (1e8 - 1) is 1e16 - 1, which rounds to 1e16 as a double.
#' x <- c(1e8 + 1, 1)
#' y <- c(1e8 - 1, -1e16)
#' sum(x * y)
#' xsum_dot(x, y)
#'
#' xsum_norm(c(3, 4))
xsum_dot <- function(x, y) {
  check_real(x, "x")
  check_real(y, "y")
  check_same_length(x, y, "x", "y")
  .Call(zxe_dot, x, y)
}

#' @rdname xsum_dot
#' @export
xsum_sqnorm <- function(x) {
  check_real(x, "x")
  .Call(zxe_dot, x, x)
}

#' @rdname xsum_dot
#' @export
xsum_norm <- function(x) {
  sqrt(xsum_sqnorm(x))
}
