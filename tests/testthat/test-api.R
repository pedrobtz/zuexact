# Stage 6: the C table is registered (design §7). Its behaviour is tested
# from a consumer package, tools/zuexacttest, in the consumer workflow.

test_that("the C table is registered under zuexact_api_v1", {
  dll <- getLoadedDLLs()[["zuexact"]]
  expect_false(is.null(dll))
  # R_GetCCallable() errors when a name is not registered; reaching it via
  # getNativeSymbolInfo is not possible for registered callables, so check
  # the header the consumers compile against is installed.
  header <- system.file("include", "zuexact.h", package = "zuexact")
  skip_if(!nzchar(header), "headers not installed (load_all)")
  lines <- readLines(header)
  expect_true(any(grepl("zuexact_api_v1", lines, fixed = TRUE)))
})
