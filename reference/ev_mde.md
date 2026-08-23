# Smallest Difference an Evaluation Can Detect

The mirror of
[`ev_power()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_power.md).
Given the number of questions available, returns the smallest true
difference the evaluation has a decent chance of detecting.

## Usage

``` r
ev_mde(
  n_items,
  sd_diff = NULL,
  pilot = NULL,
  p_a = NULL,
  p_b = NULL,
  correlation = NULL,
  power = 0.8,
  alpha = 0.05,
  icc = 0,
  cluster_size = 1
)
```

## Arguments

- n_items:

  Number of questions available.

- sd_diff:

  Standard deviation of the per-item difference.

- pilot:

  A result from
  [`ev_paired()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_paired.md)
  to take `sd_diff` from.

- p_a, p_b:

  Expected scores of the two models, for binary grading.

- correlation:

  Expected correlation between the two models' item scores. Used with
  `p_a` and `p_b`. Default `0`, which is conservative.

- power:

  Target power. Default `0.8`.

- alpha:

  Two-sided significance level. Default `0.05`.

- icc:

  Intra-cluster correlation, from
  [`ev_icc()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_icc.md).
  Default `0`.

- cluster_size:

  Questions per cluster. Default `1`, meaning no clustering.

## Value

An `evaluatellm_mde` object with elements `mde`, `n_items`,
`n_effective`, `sd_diff`, `power`, `alpha`, `design_effect`, and `icc`.

## Details

Run this before an evaluation, not after. If the minimum detectable
effect comes back larger than the gain you expect, the evaluation cannot
answer the question and a null result will mean nothing. Reporting the
minimum detectable effect alongside a null finding is what separates
"the models are equivalent" from "this evaluation was too small to
tell".

## See also

Other planning:
[`ev_power()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_power.md)

## Examples

``` r
# 500 questions, binary scoring, models correlated at 0.7
ev_mde(n_items = 500, p_a = 0.72, p_b = 0.70, correlation = 0.7)
#> 
#> Minimum detectable effect
#> 
#>   MDE            0.0440
#> 
#>   Questions      500
#>   SD of diff     0.3515 (binary scores)
#>   Power          80%
#>   Alpha          0.05 two-sided
#> 
#>   A true difference below 0.0440 will usually be missed.
#> 

# Same questions, but clustered 8 to a passage: the MDE nearly doubles
ev_mde(n_items = 500, p_a = 0.72, p_b = 0.70, correlation = 0.7,
       icc = 0.25, cluster_size = 8)
#> 
#> Minimum detectable effect
#> 
#>   MDE            0.0730
#> 
#>   Questions      500 (effective 182)
#>   SD of diff     0.3515 (binary scores)
#>   Power          80%
#>   Alpha          0.05 two-sided
#>   Design effect  2.75
#> 
#>   A true difference below 0.0730 will usually be missed.
#> 
```
