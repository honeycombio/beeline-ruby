# beeline-ruby changelog

## 2.4.0 2021-01-07
### Added
- Add support for HTTP Accept-Encoding header (#125) [@irvingreid](https://github.com/irvingreid)
- Add with_field, with_trace_field wrapper methods (#51) [@ajvondrak](https://github.com/ajvondrak)

## 2.3.0 2020-11-06
### Improvements
- Custom trace header hooks (#117)
- Add rspec filter :focus for assisting with debugging tests (#120)
- Be more lenient in expected output from AWS gem (#119)

## 2.2.0 2020-09-02
### New things
- refactor parsers/propagators, add w3c and aws parsers and propagators (#104) [@katiebayes](https://github.com/katiebayes)

### Tiny fix
- Adjusted a threshold that should resolve the occasional build failures (#107) [@katiebayes](https://github.com/katiebayes)

## 2.1.2 2020-08-26
### Improvements
- reference current span in start_span (#105) [@rintaun](https://github.com/rintaun)
- switch trace and span ids over to w3c-supported formats (#100) [@katiebayes](https://github.com/katiebayes)

## 2.1.1 2020-07-28
### Fixes
- Remove children after sending | #98 | [@martin308](https://github.com/martin308)

## 2.1.0 2020-06-10
### Features
- Adding X-Forwarded-For to instrumented fields | #91 | [@paulosman](https://github.com/paulosman)
- Add request.header.accept_language field | #94 | [@timcraft](https://github.com/timcraft)
- Support custom notifications based on a regular expression | #92 | [@mrchucho](https://github.com/mrchucho)

### Fixes
- Properly pass options for Ruby 2.7 | #85 | [@terracatta](https://github.com/terracatta)
- Fix regex substitution for warden and empty? errors for Rack | #88 | [@irvingreid](https://github.com/irvingreid)

## 2.0.0 2020-03-10
See [release notes](https://github.com/honeycombio/beeline-ruby/releases/tag/v2.0.0)

## 1.3.0 2019-11-20
### Features
- redis integration | #42 | [@ajvondrak](https://github.com/ajvondrak)

## 1.2.0 2019-11-04
### Features
- aws-sdk v2 & v3 integration | #40 | [@ajvondrak](https://github.com/ajvondrak)

## 1.1.1 2019-10-10
### Fixes
- Skip params when unavailable | #39 | [@martin308](https://github.com/martin308)

## 1.1.0 2019-10-07
### Features
- Split rails and railtie integrations | #35 | [@martin308](https://github.com/martin308)

## 1.0.1 2019-09-03
### Fixes
- Set sample_hook and presend_hook on child spans | #26 | [@orangejulius](https://github.com/orangejulius)
- No-op if no client found in Faraday integration | #27 | [@Sergio-Mira](https://github.com/Sergio-Mira)

## 1.0.0 2019-07-23
Version 1 is a milestone release. A complete re-write and modernization of Honeycomb's Ruby support.
See UPGRADING.md for migrating from v0.8.0 and see https://docs.honeycomb.io for full documentation.

## 0.8.0 2019-05-06
### Enhancements
- Expose event to #span block | #17 | [@eternal44](https://github.com/eternal44)

## 0.7.0 2019-03-13
### Enhancements
- Remove default inclusion of Sequel instrumentation | #12 | [@martin308](https://github.com/martin308)

## 0.6.0 2018-11-29
### Enhancements
- Tracing API and cross-process tracing | #4 | [@samstokes](https://github.com/samstokes)

## 0.5.0 2018-11-29
### Enhancements
- Improved rails support | #3 | [@samstokes](https://github.com/samstokes)
