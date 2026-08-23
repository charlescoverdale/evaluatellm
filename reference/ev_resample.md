# Variance Decomposition for Repeated Sampling

When an evaluation draws several responses per question, the observed
spread of question means mixes two sources: genuine variation between
questions, and sampling noise in the model's own responses. This
function separates them, and reports how far more sampling can take you.

## Usage

``` r
ev_resample(
  data,
  model = NULL,
  level = 0.95,
  k_grid = c(1, 2, 4, 8, 16, Inf),
  ...
)
```

## Arguments

- data:

  An `evaluatellm_eval` object with several rows per item and model, or
  a data frame passed to
  [`as_eval()`](https://charlescoverdale.github.io/evaluatellm/reference/as_eval.md)
  along with `...`.

- model:

  Which model to score. Optional when the data holds only one.

- level:

  Confidence level. Default `0.95`.

- k_grid:

  Integer vector of `k` values at which to report the projected standard
  error. Default `c(1, 2, 4, 8, 16, Inf)`.

- ...:

  Passed to
  [`as_eval()`](https://charlescoverdale.github.io/evaluatellm/reference/as_eval.md)
  when `data` is a plain data frame.

## Value

An `evaluatellm_resample` object with elements `estimate`, `se`,
`se_floor`, `var_between`, `var_within`, `share_within`, `n_items`,
`k_mean`, `projection`, `df`, and `level`.

## Details

Writing `s_ij` for the score of response `j` to item `i`, the estimator
is the equal-weighted mean of item means. Its variance is
`var(item means) / n`, which is unbiased whatever `k` is. The
decomposition uses
`E[var(item means)] = var_between + E[var_within / k]`, so

`var_between = var(item means) - mean(var_within / k)`

The practical consequence is that more responses per question buys
precision only against the within-question term, and there is a floor at
`sqrt(var_between / n)` that no amount of resampling can beat. Reaching
below it requires more questions. Sampling noise can push the estimated
between component below zero, in which case it is reported as zero.

## References

Miller, E. (2024). Adding Error Bars to Evals: A Statistical Approach to
Language Model Evaluations.
[doi:10.48550/arXiv.2411.00640](https://doi.org/10.48550/arXiv.2411.00640)

## See also

Other single model:
[`ev_bootstrap()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_bootstrap.md),
[`ev_cluster()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_cluster.md),
[`ev_icc()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_icc.md),
[`ev_score()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_score.md)

## Examples

``` r
set.seed(4)
# 150 questions, 8 sampled responses each, item difficulty varies
diff <- plogis(rnorm(150, 0.8, 1.1))
d <- data.frame(
  q       = rep(1:150, each = 8),
  draw    = rep(1:8, times = 150),
  correct = rbinom(1200, 1, rep(diff, each = 8))
)
ev_resample(as_eval(d, score = correct, item = q, sample = draw))
#> 
#> Repeated-sampling variance decomposition: model
#> 
#>   Estimate     0.6667
#>   Std. error   0.0219
#>   95% CI       [0.6234, 0.7099]
#> 
#>   Items        150
#>   Responses    1200 (mean k = 8.0)
#> 
#>   Var between  0.0503
#>   Var within   0.172
#>   Share of observed spread that is sampling noise: 30%
#> 
#>   Projected standard error by responses per item:
#> 
#>     k =    1   SE 0.0385   (150 responses)
#>     k =    2   SE 0.0302   (300 responses)
#>     k =    4   SE 0.0250   (600 responses)
#>     k =    8   SE 0.0219   (1200 responses)
#>     k =   16   SE 0.0202   (2400 responses)
#>     k =  Inf   SE 0.0183   (floor)
#> 
#>   More responses per item cannot beat SE 0.0183.
#>   Going below that requires more items.
#> 
```
