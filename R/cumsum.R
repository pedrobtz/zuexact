#' Exactly rounded cumulative sums
#'
#' Each element of `xsum_cumsum(x)` is the exactly rounded sum of
#' `x[1:i]`. Unlike base [cumsum()], no rounding error carries from one
#' element to the next. Special values follow the table in [xsum()], applied
#' to each prefix: once an `NA` appears, every later element is `NA`.
#'
#' This is the slowest function in the package: every prefix is rounded,
#' which costs a scan of the accumulator per element.
#'
#' @param x A numeric or logical vector.
#' @return A double vector of the same length as `x`.
#' @export
#' @examples
#' x <- c(1e20, 1, -1e20, 1)
#' cumsum(x)
#' xsum_cumsum(x)
xsum_cumsum <- function(x) {
  check_real(x, "x")
  out <- .Call(zxe_cumsum, x)
  names(out) <- names(x)
  out
}
