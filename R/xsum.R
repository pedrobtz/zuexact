#' Exactly rounded sum
#'
#' `xsum()` adds its arguments exactly and rounds once, to the nearest double
#' (ties to even). The result is the correctly rounded value of the true sum,
#' so it does not depend on the order of the elements, on the platform, or
#' on whether R was built with long doubles. Base [sum()] accumulates in
#' `long double`, which is 80-bit on x86-64 Linux and Windows and 64-bit on
#' Apple Silicon, so its result varies between machines.
#'
#' Integers and logicals are converted to double exactly; the result is
#' always a double, or a complex if any argument is complex. Complex values
#' are summed as two exact sums, of the real and of the imaginary parts.
#'
#' @section Special values:
#' With `na.rm = FALSE`, the rules are the same on every platform:
#'
#' | Input contains | Result |
#' | --- | --- |
#' | nothing | `0` |
#' | any `NA` | `NA` |
#' | no `NA`, any other `NaN` | `NaN` |
#' | both `Inf` and `-Inf` | `NaN` |
#' | `Inf` (and finite values) | `Inf` |
#' | `-Inf` (and finite values) | `-Inf` |
#' | finite values whose exact sum is out of range | `Inf` or `-Inf` |
#' | only zeros, of any sign | `0` (never `-0`) |
#'
#' `na.rm = TRUE` removes `NA` and `NaN`, as [sum()] does; infinities stay.
#' For complex input, each part follows the table, and an element is removed
#' when either of its parts is `NA` or `NaN`.
#'
#' @param ... Numeric, integer, logical or complex vectors, or `NULL`.
#' @param na.rm Remove `NA` and `NaN` values before summing?
#' @return A double of length one, or a complex if any argument is complex.
#' @seealso [zuexact_info()] for the build's accumulator threshold.
#' @export
#' @examples
#' # Base sum() gives 1 on x86-64 and 0 on Apple Silicon; xsum() gives 1.
#' xsum(c(1e16, 1, -1e16))
#'
#' # Neither platform's sum() gets this one right.
#' sum(c(1e20, 1, -1e20))
#' xsum(c(1e20, 1, -1e20))
#'
#' # The order of the terms never matters.
#' x <- c(1, 1e100, 1, -1e100)
#' xsum(x) == xsum(rev(x))
#'
#' # Several arguments are summed together.
#' xsum(1:10, c(0.5, 0.25), TRUE)
xsum <- function(..., na.rm = FALSE) {
  check_flag(na.rm, "na.rm")
  args <- list(...)
  ok <- vapply(args, is_summable, logical(1))
  if (!all(ok)) {
    bad <- which(!ok)[[1]]
    zuexact_abort(
      sprintf(
        "Argument %d must be a numeric, logical or complex vector, not %s.",
        bad, class(args[[bad]])[[1]]
      ),
      "zuexact_invalid_argument"
    )
  }
  check_status(.Call(zxe_sum, args, na.rm))
}
