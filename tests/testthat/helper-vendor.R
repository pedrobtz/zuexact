# The internal entry point that sums one double vector through both of
# xsum's accumulators and returns c(small, large).
selftest <- function(x) .Call(zuexact:::zxe_selftest, as.double(x))
