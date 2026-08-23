# Unpaired Comparison of Two Models

Compares two models evaluated on different question sets, using a Welch
two-sample interval that does not assume equal variances.

## Usage

``` r
ev_unpaired(data, model_a = NULL, model_b = NULL, level = 0.95, ...)
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

- ...:

  Passed to
  [`as_eval()`](https://charlescoverdale.github.io/evaluatellm/reference/as_eval.md)
  when `data` is a plain data frame.

## Value

An `evaluatellm_unpaired` object with elements `estimate`, `se`,
`conf_low`, `conf_high`, `statistic`, `p_value`, `mean_a`, `mean_b`,
`n_a`, `n_b`, `df`, and `level`.

## Details

Prefer
[`ev_paired()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_paired.md)
whenever both models were run on the same questions. This function
exists for the case where they were not, for instance when comparing a
published score against your own run, and it will be substantially less
powerful because item difficulty is left in the error term.

## See also

Other comparison:
[`ev_multi()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_multi.md),
[`ev_paired()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_paired.md),
[`ev_variance_reduction()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_variance_reduction.md)

## Examples

``` r
set.seed(7)
d <- data.frame(
  q = 1:600,
  m = rep(c("a", "b"), each = 300),
  correct = rbinom(600, 1, rep(c(0.72, 0.65), each = 300))
)
ev_unpaired(as_eval(d, score = correct, item = q, model = m),
            model_a = "a", model_b = "b")
#> 
#> Unpaired comparison: a vs b
#> 
#>   a  0.6833  (n = 300)
#>   b  0.6633  (n = 300)
#> 
#>   Difference   0.0200  [-0.0553, 0.0953] (p = 0.602)
#>   Std. error   0.0383
#>   t = 0.522 on 597.9 df (Welch)
#> 
#>   If both models saw the same questions, use ev_paired() instead.
#> 
```
