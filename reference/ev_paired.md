# Paired Comparison of Two Models

Tests whether one model outscores another on the same set of questions.
This is the correct comparison whenever both models were run on the same
evaluation, and it is materially more powerful than comparing two
independent means.

## Usage

``` r
ev_paired(
  data,
  model_a = NULL,
  model_b = NULL,
  level = 0.95,
  cluster = TRUE,
  ...
)
```

## Arguments

- data:

  An `evaluatellm_eval` object holding both models, or a data frame
  passed to
  [`as_eval()`](https://charlescoverdale.github.io/evaluatellm/reference/as_eval.md)
  along with `...`.

- model_a:

  Name of the first model. The reported difference is
  `model_a - model_b`.

- model_b:

  Name of the second model.

- level:

  Confidence level. Default `0.95`.

- cluster:

  Logical. Use cluster-robust standard errors when a cluster column is
  present. Default `TRUE`.

- ...:

  Passed to
  [`as_eval()`](https://charlescoverdale.github.io/evaluatellm/reference/as_eval.md)
  when `data` is a plain data frame.

## Value

An `evaluatellm_paired` object with elements `estimate`, `se`,
`se_unpaired`, `conf_low`, `conf_high`, `statistic`, `p_value`,
`correlation`, `variance_reduction`, `mean_a`, `mean_b`, `n_items`,
`df`, and `level`.

## Details

Working with the per-item difference `d_i = score_A - score_B` removes
the item difficulty that both models face, so the variance of the
difference is `var_A + var_B - 2 * cov(A, B)` rather than
`var_A + var_B`. Because model scores on shared questions are usually
strongly correlated, the paired standard error is routinely half the
unpaired one or better, which is the difference between detecting a real
gain and reporting a null result. The function reports the realised gain
as `variance_reduction`.

When the data carry a cluster column the standard error of the mean
difference is cluster-robust, and the test uses `G - 1` degrees of
freedom.

## References

Miller, E. (2024). Adding Error Bars to Evals: A Statistical Approach to
Language Model Evaluations.
[doi:10.48550/arXiv.2411.00640](https://doi.org/10.48550/arXiv.2411.00640)

## See also

Other comparison:
[`ev_multi()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_multi.md),
[`ev_unpaired()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_unpaired.md),
[`ev_variance_reduction()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_variance_reduction.md)

## Examples

``` r
set.seed(6)
# Shared item difficulty makes the two models' scores correlate
difficulty <- rnorm(500)
d <- data.frame(
  q = rep(1:500, 2),
  m = rep(c("new", "old"), each = 500),
  correct = rbinom(1000, 1,
    plogis(c(0.9, 0.7)[rep(1:2, each = 500)] - rep(difficulty, 2)))
)
ev_paired(as_eval(d, score = correct, item = q, model = m),
          model_a = "new", model_b = "old")
#> 
#> Paired comparison: new vs old
#> 
#>   new  0.6900
#>   old  0.6200
#> 
#>   Difference   0.0700  [0.0174, 0.1226] (p = 0.009)
#>   Std. error   0.0268
#>   t = 2.617 on 499 df
#> 
#>   Items        500
#>   Correlation  0.206
#>   Pairing cut the variance by 1.3x versus an unpaired comparison
#>   (unpaired SE would be 0.0300).
#> 
```
