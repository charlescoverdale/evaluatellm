# Intra-Cluster Correlation

Estimates the intra-cluster correlation of evaluation scores using the
one-way random effects analysis of variance estimator. This is the
quantity
[`ev_power()`](https://charlescoverdale.github.io/evalkit/reference/ev_power.md)
needs in order to size a clustered evaluation, and the quantity that
determines how much
[`ev_cluster()`](https://charlescoverdale.github.io/evalkit/reference/ev_cluster.md)
will widen an interval.

## Usage

``` r
ev_icc(data, model = NULL, ...)
```

## Arguments

- data:

  An `evalkit_eval` object carrying a cluster column, or a data frame
  passed to
  [`as_eval()`](https://charlescoverdale.github.io/evalkit/reference/as_eval.md)
  along with `...`.

- model:

  Which model to score. Optional when the data holds only one.

- ...:

  Passed to
  [`as_eval()`](https://charlescoverdale.github.io/evalkit/reference/as_eval.md)
  when `data` is a plain data frame.

## Value

A single number between 0 and 1, with attribute `raw` holding the
uncensored estimate.

## Details

The estimator is `(MSB - MSW) / (MSB + (m0 - 1) * MSW)`, with `m0` the
usual unbalanced-design correction for average cluster size. Sampling
noise can push the raw estimate below zero, in which case it is reported
as zero and a note is attached.

## See also

Other single model:
[`ev_bootstrap()`](https://charlescoverdale.github.io/evalkit/reference/ev_bootstrap.md),
[`ev_cluster()`](https://charlescoverdale.github.io/evalkit/reference/ev_cluster.md),
[`ev_resample()`](https://charlescoverdale.github.io/evalkit/reference/ev_resample.md),
[`ev_score()`](https://charlescoverdale.github.io/evalkit/reference/ev_score.md)

## Examples

``` r
set.seed(3)
passage_skill <- rnorm(30, 0, 1.2)
d <- data.frame(
  q       = 1:300,
  passage = rep(1:30, each = 10),
  correct = rbinom(300, 1, plogis(0.5 + rep(passage_skill, each = 10)))
)
ev_icc(as_eval(d, score = correct, item = q, cluster = passage))
#> [1] 0.1492336
#> attr(,"raw")
#> [1] 0.1492336
```
