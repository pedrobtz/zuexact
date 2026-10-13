#include "zxe.h"
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

static const R_CallMethodDef call_methods[] = {
  {"zxe_selftest", (DL_FUNC) &zxe_selftest, 1},
  {"zxe_sum", (DL_FUNC) &zxe_sum, 2},
  {"zxe_info", (DL_FUNC) &zxe_info, 0},
  {"zxe_mean", (DL_FUNC) &zxe_mean, 2},
  {"zxe_dot", (DL_FUNC) &zxe_dot, 2},
  {"zxe_cumsum", (DL_FUNC) &zxe_cumsum, 1},
  {NULL, NULL, 0}
};

void attribute_visible R_init_zuexact(DllInfo *dll) {
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
