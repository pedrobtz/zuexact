## Submission

This is the first submission of zuexact. It vendors Radford Neal's 'xsum'
library (MIT), credited in Authors@R and inst/COPYRIGHTS, with one patch
that removes its standard I/O. The package registers a C interface with
R_RegisterCCallable() and installs its header in inst/include.

## Test environments

GitHub Actions: macOS ARM64, Windows and Ubuntu (R release; Ubuntu also
oldrel-1); r-devel with CRAN's clang 23 and GCC 16; R without long doubles;
ASan, UBSan, valgrind, LTO, gctorture and rchk.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.
