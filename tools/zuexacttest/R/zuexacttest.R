# Thin wrappers over src/consumer.c; see tests/testthat/test-consumer.R.
ct_info <- function() .Call(ct_info_c)
ct_sum <- function(x) .Call(ct_sum_c, as.double(x))
ct_dot <- function(x, y) .Call(ct_dot_c, as.double(x), as.double(y))
ct_diff <- function(x, y) .Call(ct_diff_c, as.double(x), as.double(y))
ct_mean <- function(x) .Call(ct_mean_c, as.double(x))
ct_round_acc <- function(acc) .Call(ct_round_acc_c, unclass(acc))
ct_sum_parts <- function(x, parts) .Call(ct_sum_parts_c, as.double(x), as.integer(parts))
