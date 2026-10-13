# Design §13 and family rule R3: zuexact.so exports R_init_zuexact and nothing
# else, and links no stdio output (CRAN's compiled-code check).

test_that("the shared object exports exactly R_init_zuexact", {
  skip_if_no_symbol_audit()
  syms <- exported_symbols(shared_object())
  skip_if(is.null(syms))
  skip_if(any(grepl("gcov|llvm_prf|llvm_profile", syms)), "instrumented build")
  expect_identical(syms, "R_init_zuexact")
})

test_that("the shared object links no stdio output", {
  skip_if_no_symbol_audit()
  syms <- undefined_symbols(shared_object())
  skip_if(is.null(syms))
  skip_if(any(grepl("gcov|llvm_prf|llvm_profile", syms)), "instrumented build")
  banned <- c(
    "printf", "fprintf", "vprintf", "vfprintf", "puts", "fputs", "putchar",
    "fputc", "putc", "fwrite", "perror", "abort", "exit", "_exit",
    "rand", "srand", "random", "srandom", "stdout", "stderr",
    "__stdoutp", "__stderrp", "__printf_chk", "__fprintf_chk"
  )
  expect_identical(intersect(syms, banned), character())
})
