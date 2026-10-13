/* Small versus large xsum accumulator: time init + addv + round for vectors
   of length n, and report where the large accumulator starts to win.

   Built and run by tools/run-benchmarks; prints a Markdown table and a final
   "crossover: N" line. The vendored, patched xsum is linked, compiled with
   the flags given, so the numbers describe what the package ships.

   Data: doubles uniform on [-1, 1) scaled by 2^k with k uniform on [-20, 20],
   a spread of exponents typical of measured data. */

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include "xsum.h"

static double now (void)
{ return (double) clock () / CLOCKS_PER_SEC;
}

static unsigned long long state = 88172645463325252ULL;

static double draw (void)
{ state ^= state << 13; state ^= state >> 7; state ^= state << 17;
  double u = (double) (state >> 11) / 9007199254740992.0 * 2.0 - 1.0;
  int k = (int) ((state >> 3) % 41) - 20;
  return ldexp (u, k);
}

int main (void)
{
  static const long ns[] = { 8, 16, 32, 64, 96, 128, 192, 256, 384, 512,
                             768, 1024, 1536, 2048, 4096, 8192, 65536,
                             1048576 };
  const int nn = (int) (sizeof ns / sizeof ns[0]);
  const long total = 40000000L;   /* elements summed per (n, method) */
  long maxn = ns[nn - 1];
  double *x = malloc (maxn * sizeof (double));
  xsum_small_accumulator *sacc = malloc (sizeof *sacc);
  xsum_large_accumulator *lacc = malloc (sizeof *lacc);
  volatile double sink = 0;
  long crossover = -1;
  int i;

  if (!x || !sacc || !lacc) return 1;
  for (i = 0; i < maxn; i++) x[i] = draw ();

  printf ("sizeof small %zu, large %zu bytes\n\n",
          sizeof (xsum_small_accumulator), sizeof (xsum_large_accumulator));
  printf ("| n | small ns/elt | large ns/elt | large/small |\n");
  printf ("| ---: | ---: | ---: | ---: |\n");

  for (i = 0; i < nn; i++)
  { long n = ns[i], reps = total / n, r;
    double t0, ts, tl;
    if (reps < 3) reps = 3;

    t0 = now ();
    for (r = 0; r < reps; r++)
    { xsum_small_init (sacc);
      xsum_small_addv (sacc, x, n);
      sink += xsum_small_round (sacc);
    }
    ts = (now () - t0) / ((double) reps * n) * 1e9;

    t0 = now ();
    for (r = 0; r < reps; r++)
    { xsum_large_init (lacc);
      xsum_large_addv (lacc, x, n);
      sink += xsum_large_round (lacc);
    }
    tl = (now () - t0) / ((double) reps * n) * 1e9;

    printf ("| %ld | %.2f | %.2f | %.2f |\n", n, ts, tl, tl / ts);
    if (tl < ts) { if (crossover < 0) crossover = n; }
    else crossover = -1;
  }

  printf ("\ncrossover: %ld\n", crossover);
  free (x); free (sacc); free (lacc);
  return sink == 12345.0;   /* keep the sums alive */
}
