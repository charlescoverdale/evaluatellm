# Cluster-Robust Standard Error for an Evaluation

Computes a cluster-robust standard error for a model's mean score,
together with the design effect and intra-cluster correlation that
explain how much precision the clustering costs.

## Usage

``` r
ev_cluster(data, model = NULL, level = 0.95, ...)
```

## Arguments

- data:

  An `evaluatellm_eval` object carrying a cluster column, or a data
  frame passed to
  [`as_eval()`](https://charlescoverdale.github.io/evaluatellm/reference/as_eval.md)
  along with `...`.

- model:

  Which model to score. Optional when the data holds only one.

- level:

  Confidence level. Default `0.95`.

- ...:

  Passed to
  [`as_eval()`](https://charlescoverdale.github.io/evaluatellm/reference/as_eval.md)
  when `data` is a plain data frame.

## Value

An `evaluatellm_cluster` object with elements `estimate`, `se`,
`se_naive`, `conf_low`, `conf_high`, `design_effect`, `icc`, `n_items`,
`n_clusters`, `mean_cluster_size`, `df`, and `level`.

## Details

Many evaluations draw several questions from one source: comprehension
questions about a shared passage, variants of one prompt template, or
items generated from a single seed document. Those questions are not
independent draws, and treating them as though they were understates the
standard error by a factor of `sqrt(design effect)`. With eight
questions per passage and an intra-cluster correlation of 0.3, the
honest interval is roughly 1.6 times wider than the naive one.

The estimator is the CR1-corrected cluster-robust variance of a mean,
`(G / (G - 1)) * sum_g (sum_i u_i)^2 / n^2`, where `u_i` are deviations
from the mean, `g` indexes clusters and `G` counts them. Inference uses
the t distribution on `G - 1` degrees of freedom, so results are
appropriately cautious when clusters are few.

## See also

Other single model:
[`ev_bootstrap()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_bootstrap.md),
[`ev_icc()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_icc.md),
[`ev_resample()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_resample.md),
[`ev_score()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_score.md)

## Examples

``` r
set.seed(2)
# 40 passages, 10 questions each, with a strong passage effect
passage_skill <- rnorm(40, 0, 1)
d <- data.frame(
  q       = 1:400,
  passage = rep(1:40, each = 10),
  correct = rbinom(400, 1, plogis(0.9 + rep(passage_skill, each = 10)))
)
e <- as_eval(d, score = correct, item = q, cluster = passage)
ev_cluster(e)
#> 
#> Cluster-robust evaluation score: model
#> 
#>   Estimate       0.7050
#>   Std. error     0.0372  (naive 0.0228)
#>   95% CI         [0.6298, 0.7802]
#> 
#>   Items          400
#>   Clusters       40 (mean size 10.0)
#>   Design effect  2.66
#>   ICC            0.183
#> 
#>   Ignoring clustering would understate the standard error by 1.63x.
#> 
```
