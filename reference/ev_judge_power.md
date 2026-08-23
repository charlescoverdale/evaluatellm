# How Many Human Labels a Debiased Evaluation Needs

Sizes the human-labelling budget for an evaluation graded by a model
judge. Given how many items the judge will score and how well it tracks
human labels, returns the number of human labels needed to hit a target
precision.

## Usage

``` r
ev_judge_power(
  n_total,
  correlation = NULL,
  target_se = NULL,
  target_mde = NULL,
  sd_gold = 0.5,
  sd_judge = NULL,
  pilot = NULL,
  power = 0.8,
  alpha = 0.05
)
```

## Arguments

- n_total:

  Number of items the judge will score.

- correlation:

  Correlation between judge and human scores, from a pilot. A fitted
  [`ev_judge_debias()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_judge_debias.md)
  result may be passed instead via `pilot`.

- target_se:

  Target standard error for the final estimate. Supply this or
  `target_mde`.

- target_mde:

  Target minimum detectable effect, converted to a standard error at the
  given `power` and `alpha`.

- sd_gold:

  Standard deviation of the human scores. Defaults to `0.5`, the maximum
  for a binary score, which is conservative.

- sd_judge:

  Standard deviation of the judge scores. Defaults to `sd_gold`.

- pilot:

  Optional
  [`ev_judge_debias()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_judge_debias.md)
  result to take `correlation`, `sd_gold` and `sd_judge` from.

- power, alpha:

  Used only when `target_mde` is supplied. Defaults `0.8` and `0.05`.

## Value

An `evaluatellm_judge_power` object with elements `n_labels`,
`n_labels_without_judge`, `saving`, `achieved_se`, `target_se`,
`correlation`, `lambda`, and `n_total`.

## Details

This is the question that actually has a budget attached, since human
labels are the expensive input. The function evaluates the variance of
the tuned prediction-powered estimator across candidate label counts and
returns the smallest one that meets the target, alongside the number of
labels that would have been needed without a judge.

A judge correlated at 0.8 with human labels typically cuts the required
labelling budget by around two thirds. Below about 0.4 the judge is
barely worth the pipeline.

## See also

Other judge:
[`ev_judge_agreement()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_judge_agreement.md),
[`ev_judge_debias()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_judge_debias.md)

## Examples

``` r
# 20,000 judge-scored items, judge correlates 0.8 with humans,
# want a standard error of 0.01
ev_judge_power(n_total = 20000, correlation = 0.8, target_se = 0.01)
#> 
#> Human labels required
#> 
#>   Human labels     979
#>   Without a judge  2500
#>   Saving           61%
#> 
#>   Target SE        0.0100
#>   Achieved SE      0.0100
#>   Judge-scored     20000
#>   Correlation      0.80
#>   Lambda           0.761
#> 

# A weaker judge needs far more human labels
ev_judge_power(n_total = 20000, correlation = 0.4, target_se = 0.01)
#> 
#> Human labels required
#> 
#>   Human labels     2143
#>   Without a judge  2500
#>   Saving           14%
#> 
#>   Target SE        0.0100
#>   Achieved SE      0.0100
#>   Judge-scored     20000
#>   Correlation      0.40
#>   Lambda           0.357
#> 
```
