#' Information about this build of zuexact
#'
#' Reports the vendored 'xsum' library and how it was built.
#'
#' @return A list with elements:
#' * `xsum`: the upstream stable version vendored.
#' * `xsum_commit`: its commit in <https://github.com/radfordneal/xsum>.
#' * `large_threshold`: vectors with at least this many elements are summed
#'   with xsum's large accumulator, shorter ones with the small one. The
#'   choice affects speed only, never the result.
#' * `simd`: the SIMD instructions xsum was compiled to use: `"avx"`,
#'   `"sse2"` or `"none"`.
#' * `fma_hardware`: whether the compiler reported a hardware fused
#'   multiply-add. Dot products are exact either way; a software `fma()` is
#'   slower.
#' * `long_double`: whether this R has long doubles, which is what makes
#'   base [sum()] differ between platforms.
#' @export
#' @examples
#' zuexact_info()
zuexact_info <- function() {
  info <- .Call(zxe_info)
  info$long_double <- unname(capabilities("long.double"))
  info
}
