# Matrix and grouped-sum benchmarks (design §4, §12). Run from the package
# root with the package installed or loaded:
#   Rscript -e 'devtools::load_all(); source("tools/bench/matrix.R")'
set.seed(1)
med <- function(expr, times = 5) {
  e <- substitute(expr)
  t <- vapply(seq_len(times), function(i) system.time(eval(e, parent.frame(3)))[["elapsed"]], 0)
  stats::median(t)
}

cat("## Row and column sums, 1e6 x 10 doubles (seconds)\n\n")
m <- matrix(stats::rnorm(1e7), 1e6, 10)
cat(sprintf("| rowSums | %.3f |\n| xsum_rowsums | %.3f |\n| colSums | %.3f |\n| xsum_colsums | %.3f |\n",
  med(rowSums(m)), med(xsum_rowsums(m)), med(colSums(m)), med(xsum_colsums(m))))

cat("\n## Grouped sums of 1e6 doubles by number of groups (seconds)\n\n")
cat("| groups | path | rowsum | xsum_by |\n| ---: | --- | ---: | ---: |\n")
x <- stats::rnorm(1e6)
for (ng in c(10, 1000, 16384, 16385, 1e5, 1e6)) {
  g <- sample.int(ng, 1e6, TRUE)
  path <- if (ng <= 16384) "direct" else "counting sort"
  cat(sprintf("| %d | %s | %.3f | %.3f |\n", as.integer(ng), path,
    med(rowsum(x, g), 3), med(xsum_by(x, g), 3)))
}
