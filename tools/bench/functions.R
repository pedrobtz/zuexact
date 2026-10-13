# R-level benchmarks against design §12's targets. Run from the package root:
#   Rscript -e 'devtools::load_all(); source("tools/bench/functions.R")'
# Prints a Markdown table of median seconds over 7 runs.
set.seed(1)
med <- function(f, times = 7) {
  stats::median(vapply(seq_len(times), function(i) system.time(f())[["elapsed"]], 0))
}
plain_sum <- compiler::cmpfun(function(x) {
  s <- 0
  for (v in x) s <- s + v
  s
})
x <- stats::rnorm(1e7)
y <- stats::rnorm(1e7)
xm <- x[1:1e6]
rows <- list(
  c("sum, 1e7", med(function() sum(x))),
  c("plain double loop (byte-compiled R), 1e7", med(function() plain_sum(x), 3)),
  c("xsum, 1e7", med(function() xsum(x))),
  c("mean, 1e7", med(function() mean(x))),
  c("xsum_mean, 1e7", med(function() xsum_mean(x))),
  c("crossprod, 1e7", med(function() crossprod(x, y))),
  c("sum(x * y), 1e7", med(function() sum(x * y))),
  c("xsum_dot, 1e7", med(function() xsum_dot(x, y))),
  c("cumsum, 1e6", med(function() cumsum(xm))),
  c("xsum_cumsum, 1e6", med(function() xsum_cumsum(xm)))
)
a <- xsum_acc(xm)
b <- xsum_acc(rev(xm))
merge_s <- med(function() for (i in 1:1e4) xsum_merge(a, b)) / 1e4
rows <- c(rows, list(c("xsum_merge (one call)", merge_s)))
cat("| Operation | seconds |\n| --- | ---: |\n")
for (r in rows) cat(sprintf("| %s | %.6f |\n", r[[1]], as.numeric(r[[2]])))
