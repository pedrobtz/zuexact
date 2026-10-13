/* Design §4: column sums, row sums and grouped sums of a matrix, each cell
   exactly rounded once, with the special-value rules of design §6 applied
   per cell. R matrices are column-major. */

#include "zxe_acc.h"
#include <string.h>

/* Rows summed together in one block: one small accumulator (560 bytes) and
   one flag byte per row, so a block costs about 560 KB however many rows
   the matrix has. */
#define ZXE_ROW_BLOCK 1024

/* Above this many group-by-column cells, grouped sums use a counting sort
   by group instead of one accumulator per cell (2^14 cells is about 9 MB
   of accumulators). */
#define ZXE_DIRECT_CELLS 16384

typedef struct {
  const double *d;   /* one of d, i is set */
  const int *i;
} column_data;

static column_data data_of(SEXP x) {
  column_data c = {NULL, NULL};
  if (TYPEOF(x) == REALSXP) c.d = REAL_RO(x);
  else c.i = TYPEOF(x) == LGLSXP ? LOGICAL_RO(x) : INTEGER_RO(x);
  return c;
}

/* Element k as a double; NA integers become NA_REAL. */
static inline double elt(column_data c, R_xlen_t k) {
  if (c.d) return c.d[k];
  return c.i[k] == NA_INTEGER ? NA_REAL : (double) c.i[k];
}

/* Add v to one small accumulator with its flag byte. */
static inline void add_cell(xsum_small_accumulator *a, unsigned char *f,
                            double v, int narm) {
  if (!R_FINITE(v)) {
    if (narm && ISNAN(v)) return;
    *f |= zxe_flag_of(v);
    if (ISNAN(v)) return;   /* flags decide; keep xsum's chunks finite */
  }
  xsum_small_add1(a, v);
}

static SEXP finish_status(SEXP out, int internal) {
  if (internal) {
    Rf_setAttrib(out, Rf_install("zxe_status"), Rf_mkString("overflow"));
  }
  return out;
}

/* .Call entry: column sums of an nrow x ncol double, integer or logical
   matrix. Each column is one vector: addv straight from the data when it is
   double, a block-converted copy otherwise. */
SEXP zxe_colsums(SEXP x, SEXP nrow_, SEXP ncol_, SEXP narm_) {
  R_xlen_t nr = (R_xlen_t) Rf_asReal(nrow_), nc = (R_xlen_t) Rf_asReal(ncol_);
  int narm = Rf_asLogical(narm_) == TRUE, internal = 0;
  column_data c = data_of(x);
  SEXP out = PROTECT(Rf_allocVector(REALSXP, nc));
  double buf[4096];
  for (R_xlen_t j = 0; j < nc; j++) {
    zxe_acc acc;
    const void *vmax = vmaxget();
    zxe_acc_init(&acc, nr);
    unsigned char f = 0;
    R_xlen_t base = j * nr;
    for (R_xlen_t i = 0; i < nr; i += 4096) {
      R_xlen_t m = nr - i < 4096 ? nr - i : 4096, k = 0;
      for (R_xlen_t t = 0; t < m; t++) {
        double v = elt(c, base + i + t);
        if (!R_FINITE(v)) {
          if (narm && ISNAN(v)) continue;
          f |= zxe_flag_of(v);
          if (ISNAN(v)) continue;
        }
        buf[k++] = v;
      }
      zxe_acc_addv(&acc, buf, k);
    }
    REAL(out)[j] = zxe_apply_flags(f, zxe_acc_round(&acc), &internal);
    vmaxset(vmax);
  }
  UNPROTECT(1);
  return finish_status(out, internal);
}

/* .Call entry: row sums, a block of rows at a time. For each block, every
   column's slice of the block is walked once, so memory is bounded by the
   block, not by nrow. */
SEXP zxe_rowsums(SEXP x, SEXP nrow_, SEXP ncol_, SEXP narm_) {
  R_xlen_t nr = (R_xlen_t) Rf_asReal(nrow_), nc = (R_xlen_t) Rf_asReal(ncol_);
  int narm = Rf_asLogical(narm_) == TRUE, internal = 0;
  column_data c = data_of(x);
  SEXP out = PROTECT(Rf_allocVector(REALSXP, nr));
  R_xlen_t bsize = nr < ZXE_ROW_BLOCK ? nr : ZXE_ROW_BLOCK;
  xsum_small_accumulator *acc = (xsum_small_accumulator *)
    R_alloc(bsize > 0 ? bsize : 1, sizeof(xsum_small_accumulator));
  unsigned char *flags = (unsigned char *) R_alloc(bsize > 0 ? bsize : 1, 1);
  for (R_xlen_t r0 = 0; r0 < nr; r0 += ZXE_ROW_BLOCK) {
    R_xlen_t m = nr - r0 < ZXE_ROW_BLOCK ? nr - r0 : ZXE_ROW_BLOCK;
    memset(acc, 0, m * sizeof *acc);
    memset(flags, 0, m);
    for (R_xlen_t t = 0; t < m; t++) xsum_small_init(&acc[t]);
    for (R_xlen_t j = 0; j < nc; j++) {
      R_xlen_t base = j * nr + r0;
      for (R_xlen_t t = 0; t < m; t++) {
        add_cell(&acc[t], &flags[t], elt(c, base + t), narm);
      }
    }
    for (R_xlen_t t = 0; t < m; t++) {
      REAL(out)[r0 + t] =
        zxe_apply_flags(flags[t], xsum_small_round(&acc[t]), &internal);
    }
  }
  UNPROTECT(1);
  return finish_status(out, internal);
}

/* .Call entry: grouped sums in the shape of base rowsum(). code holds the
   1-based group of each row (in 1..ng, no NA: the R side maps NA groups to a
   code of their own). Returns an ng x ncol matrix of doubles. */
SEXP zxe_by(SEXP x, SEXP nrow_, SEXP ncol_, SEXP code_, SEXP ng_, SEXP narm_) {
  R_xlen_t nr = (R_xlen_t) Rf_asReal(nrow_), nc = (R_xlen_t) Rf_asReal(ncol_);
  R_xlen_t ng = (R_xlen_t) Rf_asReal(ng_);
  int narm = Rf_asLogical(narm_) == TRUE, internal = 0;
  const int *code = INTEGER_RO(code_);
  column_data c = data_of(x);
  SEXP out = PROTECT(Rf_allocMatrix(REALSXP, (int) ng, (int) nc));
  double *po = REAL(out);

  if ((double) ng * (double) nc <= ZXE_DIRECT_CELLS) {
    /* One accumulator per cell, one pass over the data. */
    R_xlen_t cells = ng * nc > 0 ? ng * nc : 1;
    xsum_small_accumulator *acc = (xsum_small_accumulator *)
      R_alloc(cells, sizeof(xsum_small_accumulator));
    unsigned char *flags = (unsigned char *) R_alloc(cells, 1);
    memset(acc, 0, cells * sizeof *acc);
    memset(flags, 0, cells);
    for (R_xlen_t k = 0; k < ng * nc; k++) xsum_small_init(&acc[k]);
    for (R_xlen_t j = 0; j < nc; j++) {
      for (R_xlen_t i = 0; i < nr; i++) {
        R_xlen_t cell = j * ng + (code[i] - 1);
        add_cell(&acc[cell], &flags[cell], elt(c, j * nr + i), narm);
      }
    }
    for (R_xlen_t k = 0; k < ng * nc; k++) {
      po[k] = zxe_apply_flags(flags[k], xsum_small_round(&acc[k]), &internal);
    }
  } else {
    /* Counting sort of row indices by group, then each group's rows of each
       column are gathered in blocks and summed as one vector. */
    R_xlen_t *start = (R_xlen_t *) R_alloc(ng + 1, sizeof(R_xlen_t));
    R_xlen_t *perm = (R_xlen_t *) R_alloc(nr > 0 ? nr : 1, sizeof(R_xlen_t));
    memset(start, 0, (ng + 1) * sizeof *start);
    for (R_xlen_t i = 0; i < nr; i++) start[code[i]]++;
    for (R_xlen_t g = 1; g <= ng; g++) start[g] += start[g - 1];
    R_xlen_t *next = (R_xlen_t *) R_alloc(ng > 0 ? ng : 1, sizeof(R_xlen_t));
    memcpy(next, start, ng * sizeof *next);
    for (R_xlen_t i = 0; i < nr; i++) perm[next[code[i] - 1]++] = i;
    double buf[4096];
    for (R_xlen_t j = 0; j < nc; j++) {
      R_xlen_t base = j * nr;
      for (R_xlen_t g = 0; g < ng; g++) {
        const void *vmax = vmaxget();
        R_xlen_t lo = start[g], hi = start[g + 1];
        zxe_acc acc;
        zxe_acc_init(&acc, hi - lo);
        unsigned char f = 0;
        for (R_xlen_t i = lo; i < hi; i += 4096) {
          R_xlen_t m = hi - i < 4096 ? hi - i : 4096, k = 0;
          for (R_xlen_t t = 0; t < m; t++) {
            double v = elt(c, base + perm[i + t]);
            if (!R_FINITE(v)) {
              if (narm && ISNAN(v)) continue;
              f |= zxe_flag_of(v);
              if (ISNAN(v)) continue;
            }
            buf[k++] = v;
          }
          zxe_acc_addv(&acc, buf, k);
        }
        po[j * ng + g] = zxe_apply_flags(f, zxe_acc_round(&acc), &internal);
        vmaxset(vmax);
      }
    }
  }
  UNPROTECT(1);
  return finish_status(out, internal);
}
