#' Exactly rounded row, column and grouped sums
#'
#' `xsum_rowsums()` and `xsum_colsums()` are exact versions of [rowSums()]
#' and [colSums()]: every row or column sum is the correctly rounded exact
#' sum. `xsum_by()` is an exact version of [rowsum()]: the rows of `x` are
#' summed within each group, and the result has one row per group, sorted.
#'
#' Special values follow the table in [xsum()], cell by cell. Row sums are
#' computed a block of rows at a time, so the extra memory they need does not
#' grow with the number of rows.
#'
#' @param x A numeric or logical matrix, or a data frame of numeric or
#'   logical columns. For `xsum_by()`, also a vector.
#' @param group A vector with one value per row of `x` (per element, for a
#'   vector). `NA` is a group of its own, sorted last, as in [rowsum()].
#' @inheritParams xsum
#' @return `xsum_rowsums()` and `xsum_colsums()` return a double vector named
#'   by the row or column names. `xsum_by()` returns a double matrix with one
#'   row per group (named by the group) and one column per column of `x`.
#' @export
#' @examples
#' m <- cbind(a = c(1e20, 1), b = c(1, 1e20), c = c(-1e20, -1e20))
#' rowSums(m)
#' xsum_rowsums(m)
#' xsum_colsums(m)
#'
#' xsum_by(c(1e20, 1, 2, -1e20), c("x", "y", "y", "x"))
xsum_rowsums <- function(x, na.rm = FALSE) {
  check_flag(na.rm, "na.rm")
  x <- as_sum_matrix(x, "x")
  out <- check_status(.Call(
    zxe_rowsums, x, as.double(nrow(x)), as.double(ncol(x)), na.rm
  ))
  names(out) <- rownames(x)
  out
}

#' @rdname xsum_rowsums
#' @export
xsum_colsums <- function(x, na.rm = FALSE) {
  check_flag(na.rm, "na.rm")
  x <- as_sum_matrix(x, "x")
  out <- check_status(.Call(
    zxe_colsums, x, as.double(nrow(x)), as.double(ncol(x)), na.rm
  ))
  names(out) <- colnames(x)
  out
}

#' @rdname xsum_rowsums
#' @export
xsum_by <- function(x, group, na.rm = FALSE) {
  check_flag(na.rm, "na.rm")
  if (is.null(dim(x)) && !is.data.frame(x)) {
    check_real(x, "x")
    x <- matrix(x, ncol = 1L)
  } else {
    x <- as_sum_matrix(x, "x")
  }
  if (length(group) != nrow(x)) {
    zuexact_abort(
      sprintf(
        "`group` must have one value per row of `x` (%d), not %d.",
        nrow(x), length(group)
      ),
      "zuexact_invalid_argument"
    )
  }
  if (is.factor(group)) {
    group <- as.character(group)
  }
  levels <- sort(unique(group), na.last = TRUE)
  code <- match(group, levels)
  out <- check_status(.Call(
    zxe_by, x, as.double(nrow(x)), as.double(ncol(x)), code,
    as.double(length(levels)), na.rm
  ))
  dimnames(out) <- list(as.character(levels), colnames(x))
  out
}

as_sum_matrix <- function(x, arg, call = sys.call(-1)) {
  if (is.data.frame(x)) {
    ok <- vapply(
      x,
      function(col) typeof(col) %in% c("double", "integer", "logical") &&
        !is.factor(col),
      logical(1)
    )
    if (!all(ok)) {
      zuexact_abort(
        sprintf("Every column of `%s` must be numeric or logical.", arg),
        "zuexact_invalid_argument",
        call = call
      )
    }
    x <- as.matrix(x)
  }
  if (!is.matrix(x) ||
    !typeof(x) %in% c("double", "integer", "logical")) {
    zuexact_abort(
      sprintf("`%s` must be a numeric or logical matrix.", arg),
      "zuexact_invalid_argument",
      call = call
    )
  }
  x
}
