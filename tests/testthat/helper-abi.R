# Helpers for test-abi.R, kept out of it so that the tests run shuffled.

exported_symbols <- function(path) {
  sys <- Sys.info()[["sysname"]]
  if (sys == "Linux") {
    out <- system2("nm", c("-D", "--defined-only", shQuote(path)), stdout = TRUE)
  } else if (sys == "Darwin") {
    out <- system2("nm", c("-gU", shQuote(path)), stdout = TRUE)
  } else {
    return(NULL)
  }
  syms <- sub("^.* ", "", out)
  syms <- sub("^_(R_init)", "\\1", syms)
  # Linker-defined section markers are not code.
  setdiff(syms, c(
    "", "_edata", "_end", "__bss_start", "_init", "_fini",
    "__end__", "__bss_start__", "_bss_end__", "__bss_end__"
  ))
}

undefined_symbols <- function(path) {
  sys <- Sys.info()[["sysname"]]
  if (sys == "Linux") {
    out <- system2("nm", c("-D", "--undefined-only", shQuote(path)), stdout = TRUE)
  } else if (sys == "Darwin") {
    out <- system2("nm", c("-u", shQuote(path)), stdout = TRUE)
  } else {
    return(NULL)
  }
  syms <- sub("^.* ", "", out)
  syms <- sub("@.*$", "", syms)
  sub("^_", "", syms)
}

shared_object <- function() {
  getLoadedDLLs()[["zuexact"]][["path"]]
}

skip_if_no_symbol_audit <- function() {
  skip_on_cran()
  skip_on_os("windows")
  # covr links the gcov runtime into the shared object, which exports its own
  # symbols; that is not the object CRAN builds.
  skip_if(nzchar(Sys.getenv("R_COVR")), "coverage build")
  skip_if(!nzchar(Sys.which("nm")), "nm not available")
}
