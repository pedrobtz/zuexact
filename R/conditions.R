# Design §10. Every condition inherits zuexact_error.

zuexact_abort <- function(message, class, call = sys.call(-1)) {
  cnd <- structure(
    class = c(class, "zuexact_error", "error", "condition"),
    list(message = message, call = call)
  )
  stop(cnd)
}

# Signal an internal error carried back from C as a "zxe_status" attribute.
check_status <- function(value, call = sys.call(-1)) {
  status <- attr(value, "zxe_status", exact = TRUE)
  if (is.null(status)) {
    return(value)
  }
  if (identical(status, "count")) {
    zuexact_abort(
      paste0(
        "An exact mean is limited to 2^32 - 1 terms; ",
        "use `xsum(x) / length(x)` for one extra rounding."
      ),
      "zuexact_count_error",
      call = call
    )
  }
  zuexact_abort(
    paste0(
      "The superaccumulator overflowed (", status, "). This needs more than ",
      "2^45 additions to one accumulator; please report it."
    ),
    "zuexact_internal_error",
    call = call
  )
}

# A single real vector: double, integer or logical, not a factor.
check_real <- function(x, arg, call = sys.call(-1)) {
  ok <- typeof(x) %in% c("double", "integer", "logical") && !is.factor(x) &&
    (!is.object(x) || inherits(x, c("difftime", "AsIs")))
  if (!ok) {
    zuexact_abort(
      sprintf(
        "`%s` must be a numeric or logical vector, not %s.",
        arg, class(x)[[1]]
      ),
      "zuexact_invalid_argument",
      call = call
    )
  }
}

check_same_length <- function(x, y, xarg, yarg, call = sys.call(-1)) {
  if (length(x) != length(y)) {
    zuexact_abort(
      sprintf(
        "`%s` and `%s` must have the same length, not %d and %d.",
        xarg, yarg, length(x), length(y)
      ),
      "zuexact_invalid_argument",
      call = call
    )
  }
}

# The inputs xsum() and friends accept: NULL, double, integer, logical and
# complex vectors that are not factors. Attributes (names, dim) are ignored.
is_summable <- function(x) {
  is.null(x) ||
    (typeof(x) %in% c("double", "integer", "logical", "complex") &&
      !is.factor(x) && !is.object(x)) ||
    (is.object(x) && typeof(x) %in% c("double", "integer") &&
      inherits(x, c("difftime", "AsIs")))
}

check_flag <- function(x, arg, call = sys.call(-1)) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    zuexact_abort(
      sprintf("`%s` must be TRUE or FALSE.", arg),
      "zuexact_invalid_argument",
      call = call
    )
  }
}
