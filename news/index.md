# Changelog

## zuexact 0.0.0.9000

Development version of the first release, 0.1.0. This heading becomes
`# zuexact 0.1.0` in the last roadmap stage.

- Package identity: real `DESCRIPTION`, licence and copyright files,
  hidden symbols, and CI on the R build without long doubles.

- Vendors Radford Neal’s ‘xsum’ (stable version 3), patched so that no
  standard I/O reaches the compiled code; upstream’s checker and fuzzer
  run against the vendored copy in CI.
