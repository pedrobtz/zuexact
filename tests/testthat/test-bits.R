# Stage 7, design §11: every platform reproduces the same bits. The reference
# file was written by tools/write-bits; a difference on any CI leg (Linux,
# Windows, macOS ARM64, R without long doubles) is a portability bug.

test_that("results are bit-identical to the reference on this platform", {
  ref <- readLines(test_path("fixtures", "bits.txt"))
  ref <- ref[!startsWith(ref, "#")]
  got <- bits_results()
  expect_identical(length(got), length(ref))
  for (i in seq_along(ref)) {
    expect_identical(got[[i]], ref[[i]], info = strsplit(ref[[i]], "\t")[[1]][[1]])
  }
})
