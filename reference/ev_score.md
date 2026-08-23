# Evaluation Score with a Standard Error

Reports the mean score of a model together with the standard error and
confidence interval implied by treating the questions as a sample. This
is the number that belongs next to every headline evaluation result, and
the one most often omitted.

## Usage

``` r
ev_score(data, model = NULL, level = 0.95, cluster = TRUE, ...)
```

## Arguments

- data:

  An `evaluatellm_eval` object from
  [`as_eval()`](https://charlescoverdale.github.io/evaluatellm/reference/as_eval.md),
  a data frame, or a bare numeric or logical vector of scores.

- model:

  Which model to score. Optional when the data holds only one.

- level:

  Confidence level. Default `0.95`.

- cluster:

  Logical. Use cluster-robust standard errors when a cluster column is
  present. Default `TRUE`. Set to `FALSE` to force the independent
  calculation, which is useful only for comparison.

- ...:

  Passed to
  [`as_eval()`](https://charlescoverdale.github.io/evaluatellm/reference/as_eval.md)
  when `data` is a plain data frame.

## Value

An `evaluatellm_score` object with elements `estimate`, `se`,
`conf_low`, `conf_high`, `n_items`, `n_responses`, `df`, `level`,
`clustered`, and, when clustered, `n_clusters` and `design_effect`.

## Details

The standard error follows the central limit theorem applied to the item
means: `sd(score) / sqrt(n)`, where `n` counts items, not responses.
When `cluster` is present in the data the calculation switches to a
cluster-robust standard error, since questions sharing a passage or a
source document are not independent draws. See
[`ev_cluster()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_cluster.md)
for the detail.

Confidence intervals use the t distribution with `n - 1` degrees of
freedom, or `G - 1` when clustered, which is slightly wider than the
normal interval used in Miller (2024) and better behaved on the short
evaluations that appear in practice.

## References

Miller, E. (2024). Adding Error Bars to Evals: A Statistical Approach to
Language Model Evaluations.
[doi:10.48550/arXiv.2411.00640](https://doi.org/10.48550/arXiv.2411.00640)

## See also

Other single model:
[`ev_bootstrap()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_bootstrap.md),
[`ev_cluster()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_cluster.md),
[`ev_icc()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_icc.md),
[`ev_resample()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_resample.md)

## Examples

``` r
set.seed(1)
# 400 questions, 72 per cent correct
ev_score(rbinom(400, 1, 0.72))
#> 
#> Evaluation score: model
#> 
#>   Estimate   0.7400
#>   Std. error 0.0220
#>   95% CI     [0.6968, 0.7832]
#> 
#>   Items      400
#>   Independent standard error, t on 399 df.
#> 

# The same accuracy, but questions come in groups of 8 per passage
d <- data.frame(
  q       = 1:400,
  passage = rep(1:50, each = 8),
  correct = rbinom(400, 1, 0.72)
)
ev_score(as_eval(d, score = correct, item = q, cluster = passage))
#> 
#> Evaluation score: model
#> 
#>   Estimate   0.7125
#>   Std. error 0.0215
#>   95% CI     [0.6693, 0.7557]
#> 
#>   Items      400
#>   Clusters   50
#>   Design eff 0.90 (SE is 0.95x the independent estimate)
#>   Cluster-robust standard error, t on 49 df.
#> 
```
