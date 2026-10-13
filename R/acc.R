#' Accumulators: exact sums built in pieces
#'
#' An accumulator holds an exact sum in progress. Add vectors to it in any
#' order and in any number of pieces, merge accumulators built elsewhere,
#' and read the correctly rounded value at any time. The result is the same
#' as [xsum()] of all the pieces together, bit for bit.
#'
#' Accumulators are ordinary R values (raw vectors of class `"xsum_acc"`,
#' 568 bytes): `xsum_add()`, `xsum_merge()` and `xsum_negate()` return a new
#' accumulator and leave their argument unchanged. Because they are values,
#' they serialise: an accumulator built on a worker by `parallel`, `mirai`
#' or `future` comes back to the caller and merges there.
#' `Reduce(xsum_merge, accs)` combines a list of them in any order.
#'
#' `xsum_negate()` changes the sign of the sum, so
#' `xsum_merge(a, xsum_negate(b))` is the exact difference of two sums,
#' rounded once.
#'
#' An accumulator does not count its terms; `xsum_mean_value()` takes the
#' count. Special values follow the table in [xsum()]; an accumulator
#' remembers whether it has seen `NA`, `NaN`, `Inf` or `-Inf`.
#'
#' Accumulator bytes are those of the machine that made them. Every CRAN
#' platform is little-endian; an accumulator from a big-endian machine
#' signals a `zuexact_accumulator_error`.
#'
#' @param x A numeric or logical vector (`NULL` for none).
#' @param acc,other Accumulators, from `xsum_acc()`.
#' @param n The number of terms the accumulator holds, for the mean.
#' @inheritParams xsum
#' @return `xsum_acc()`, `xsum_add()`, `xsum_merge()` and `xsum_negate()`
#'   return an accumulator. `xsum_value()` and `xsum_mean_value()` return a
#'   double of length one.
#' @export
#' @examples
#' acc <- xsum_acc()
#' acc <- xsum_add(acc, c(1e20, 1))
#' acc <- xsum_add(acc, -1e20)
#' xsum_value(acc)
#'
#' # Pieces in any order, merged in any order.
#' chunks <- split(c(1e100, 1:10, -1e100), rep(1:3, length.out = 12))
#' accs <- lapply(chunks, xsum_acc)
#' xsum_value(Reduce(xsum_merge, rev(accs)))
#'
#' # The exact difference of two sums.
#' a <- xsum_acc(c(0.1, 0.2))
#' b <- xsum_acc(0.3)
#' xsum_value(xsum_merge(a, xsum_negate(b)))
xsum_acc <- function(x = NULL, na.rm = FALSE) {
  acc <- new_acc(.Call(zxe_acc_new))
  if (is.null(x)) {
    return(acc)
  }
  xsum_add(acc, x, na.rm = na.rm)
}

#' @rdname xsum_acc
#' @export
xsum_add <- function(acc, x, na.rm = FALSE) {
  check_acc(acc, "acc")
  check_flag(na.rm, "na.rm")
  if (is.null(x)) {
    return(acc)
  }
  check_real(x, "x")
  new_acc(acc_status(.Call(zxe_acc_add, unclass(acc), x, na.rm)))
}

#' @rdname xsum_acc
#' @export
xsum_merge <- function(acc, other) {
  check_acc(acc, "acc")
  check_acc(other, "other")
  new_acc(acc_status(.Call(zxe_acc_merge, unclass(acc), unclass(other))))
}

#' @rdname xsum_acc
#' @export
xsum_negate <- function(acc) {
  check_acc(acc, "acc")
  new_acc(acc_status(.Call(zxe_acc_negate, unclass(acc))))
}

#' @rdname xsum_acc
#' @export
xsum_value <- function(acc) {
  check_acc(acc, "acc")
  check_status(acc_status(.Call(zxe_acc_value, unclass(acc), -1)))
}

#' @rdname xsum_acc
#' @export
xsum_mean_value <- function(acc, n) {
  check_acc(acc, "acc")
  if (!is.numeric(n) || length(n) != 1L || is.na(n) || n < 0 ||
    n != trunc(n)) {
    zuexact_abort(
      "`n` must be a single non-negative whole number.",
      "zuexact_invalid_argument"
    )
  }
  if (n == 0) {
    return(NaN)
  }
  if (n > 2^32 - 1) {
    check_status(structure(NA_real_, zxe_status = "count"))
  }
  check_status(acc_status(.Call(zxe_acc_value, unclass(acc), as.double(n))))
}

#' @export
as.double.xsum_acc <- function(x, ...) {
  xsum_value(x)
}

#' @export
format.xsum_acc <- function(x, ...) {
  paste0("<xsum_acc> ", format(xsum_value(x), digits = 17, ...))
}

#' @export
print.xsum_acc <- function(x, ...) {
  cat(format(x, ...), "\n", sep = "")
  invisible(x)
}

new_acc <- function(bytes) {
  structure(bytes, class = "xsum_acc")
}

check_acc <- function(acc, arg, call = sys.call(-1)) {
  if (!inherits(acc, "xsum_acc") || typeof(acc) != "raw") {
    zuexact_abort(
      sprintf("`%s` must be an accumulator from xsum_acc().", arg),
      "zuexact_invalid_argument",
      call = call
    )
  }
}

# A "zxe_status" on a raw result from C means the input bytes were not a
# valid accumulator; on a double it is passed on to check_status().
acc_status <- function(value, call = sys.call(-1)) {
  status <- attr(value, "zxe_status", exact = TRUE)
  if (is.null(status) || is.double(value)) {
    return(value)
  }
  zuexact_abort(
    sprintf("Invalid accumulator: %s.", status),
    "zuexact_accumulator_error",
    call = call
  )
}
