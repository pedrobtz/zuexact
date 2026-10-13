#' Exactly rounded mean
#'
#' `xsum_mean()` divides the exact sum by the number of terms and rounds
#' once: the result is the correctly rounded value of the true mean, not
#' `xsum(x) / length(x)`, which would round twice. Base [mean()] makes a
#' second pass to correct its first estimate, but its accumulator is still
#' platform-dependent.
#'
#' Special values follow the table in [xsum()]. The mean of no values is
#' `NaN`, as in base R. xsum divides by a 32-bit count, so a mean over more
#' than 2^32 - 1 terms signals a `zuexact_count_error`.
#'
#' @param x A numeric, integer, logical or complex vector.
#' @inheritParams xsum
#' @return A double of length one (complex for complex `x`).
#' @family means
#' @export
#' @examples
#' # Base mean() is accurate to three digits here (Neal, 2015).
#' x <- c(1e15, -1e15, 0.1)
#' mean(x)
#' xsum_mean(x)
xsum_mean <- function(x, na.rm = FALSE) {
  check_flag(na.rm, "na.rm")
  if (!is_summable(x) || is.null(x)) {
    zuexact_abort(
      sprintf(
        "`x` must be a numeric, logical or complex vector, not %s.",
        class(x)[[1]]
      ),
      "zuexact_invalid_argument"
    )
  }
  check_status(.Call(zxe_mean, list(x), na.rm))
}

#' Weighted mean from exact sums
#'
#' `xsum_weighted_mean()` computes `sum(w * x)` and `sum(w)` exactly, each
#' rounded once, and divides. The result therefore has **three** roundings:
#' the two sums and the division. Each sum is exact, which removes the
#' cancellation and accumulation error that dominates `sum(w * x) / sum(w)`;
#' an exact ratio of two superaccumulators is not available.
#'
#' With `na.rm = TRUE`, pairs where `x` is `NA` or `NaN` are removed, as in
#' [stats::weighted.mean()]; `NA` weights are not removed.
#'
#' @param x A numeric or logical vector.
#' @param w Weights, of the same length as `x`.
#' @inheritParams xsum
#' @return A double of length one.
#' @family means
#' @export
#' @examples
#' xsum_weighted_mean(c(1e16, 1, -1e16), c(1, 1, 1))
xsum_weighted_mean <- function(x, w, na.rm = FALSE) {
  check_flag(na.rm, "na.rm")
  check_real(x, "x")
  check_real(w, "w")
  check_same_length(x, w, "x", "w")
  if (na.rm) {
    keep <- !is.na(x)
    x <- x[keep]
    w <- w[keep]
  }
  .Call(zxe_dot, x, w) / check_status(.Call(zxe_sum, list(w), FALSE))
}
