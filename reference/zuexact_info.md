# Information about this build of zuexact

Reports the vendored 'xsum' library and how it was built.

## Usage

``` r
zuexact_info()
```

## Value

A list with elements:

- `xsum`: the upstream stable version vendored.

- `xsum_commit`: its commit in <https://github.com/radfordneal/xsum>.

- `large_threshold`: vectors with at least this many elements are summed
  with xsum's large accumulator, shorter ones with the small one. The
  choice affects speed only, never the result.

- `simd`: the SIMD instructions xsum was compiled to use: `"avx"`,
  `"sse2"` or `"none"`.

- `fma_hardware`: whether the compiler reported a hardware fused
  multiply-add. Dot products are exact either way; a software `fma()` is
  slower.

- `long_double`: whether this R has long doubles, which is what makes
  base [`sum()`](https://rdrr.io/r/base/sum.html) differ between
  platforms.

## Examples

``` r
zuexact_info()
#> $xsum
#> [1] "stable-version-3"
#> 
#> $xsum_commit
#> [1] "b766b3e104cdbd6769c8df033fb430700fce32dd"
#> 
#> $large_threshold
#> [1] 128
#> 
#> $simd
#> [1] "sse2"
#> 
#> $fma_hardware
#> [1] FALSE
#> 
#> $long_double
#> [1] TRUE
#> 
```
