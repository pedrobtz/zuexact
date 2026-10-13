## Submission

This is the first submission of zuexact.

zuexact computes sums of doubles exactly and rounds once, so results are
the correctly rounded true value whatever the element order, platform, or
long-double support of the R build. It vendors Radford Neal's 'xsum'
library (MIT; Neal is listed as copyright holder in Authors@R and in
inst/COPYRIGHTS). One local patch removes standard I/O and unused debugging
routines from the vendored code, so no stdio symbol reaches the shared
object; the patch and the upstream commit are recorded in the repository
under tools/, which is not part of the package.

The package registers a C interface with R_RegisterCCallable() and installs
its header in inst/include. The shared object exports R_init_zuexact only.

## Test environments

The checks below ran on the release commit in the package's continuous
integration (GitHub Actions, through pedrobtz/r-actions):

* macOS ARM64 (R release), Windows (R release), Ubuntu (R release and
  oldrel-1).
* R-hub containers with CRAN's compilers: clang 23, Ubuntu clang, Ubuntu
  GCC 16.
* R built without long doubles (CRAN's NOLD flavour).
* UBSan and ASan (GCC and clang), valgrind, LTO, gctorture, rchk, and GCC's
  -fanalyzer.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.
