/* Definitions for shim.h. The checker calls these only when its debug flag
   is set, which tools/xsum-check/run never does. */
#include "xsum.h"
#include "shim.h"
int xsum_debug = 0;
void xsum_small_display (xsum_small_accumulator *restrict sacc) { (void) sacc; }
void xsum_large_display (xsum_large_accumulator *restrict lacc) { (void) lacc; }
