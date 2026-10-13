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
  zuexact_abort(
    paste0(
      "The superaccumulator overflowed (", status, "). This needs more than ",
      "2^45 additions to one accumulator; please report it."
    ),
    "zuexact_internal_error",
    call = call
  )
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
