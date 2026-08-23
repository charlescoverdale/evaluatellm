# Number of Questions Needed to Detect a Difference

Plans a paired model comparison: given the size of the gain worth
detecting and the variability of the per-item difference, returns how
many questions the evaluation needs.

## Usage

``` r
ev_power(
  delta,
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

- delta:

  The difference worth detecting, on the score scale.

- sd_diff:

  Standard deviation of the per-item difference.

- pilot:

  A result from
  [`ev_paired()`](https://charlescoverdale.github.io/evalkit/reference/ev_paired.md)
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
  [`ev_icc()`](https://charlescoverdale.github.io/evalkit/reference/ev_icc.md).
  Default `0`.

- cluster_size:

  Questions per cluster. Default `1`, meaning no clustering.

## Value

An `evalkit_power` object with elements `n_items`, `n_clusters`,
`delta`, `sd_diff`, `power`, `alpha`, `design_effect`, and `icc`.

## Details

The calculation is the standard one for a paired mean,
`n = (z_alpha/2 + z_beta)^2 * sd_diff^2 / delta^2`, multiplied by the
design effect `1 + (cluster_size - 1) * icc` when questions come in
clusters. Normal quantiles are used, which is conventional for planning
and slightly optimistic for very small `n`.

Getting `sd_diff` right is the whole exercise. It is the standard
deviation of the per-question difference, not of the scores, and it is
much smaller than people expect because the two models face the same
questions. The reliable way to get it is a pilot run passed through
[`ev_paired()`](https://charlescoverdale.github.io/evalkit/reference/ev_paired.md)
and handed back here as `pilot`. Failing that, supply `p_a`, `p_b` and a
correlation for binary scoring: a correlation of 0.7 is typical for
models of similar capability.

## See also

Other planning:
[`ev_mde()`](https://charlescoverdale.github.io/evalkit/reference/ev_mde.md)

## Examples

``` r
# Detect a 2 point gain, binary scoring, models correlated at 0.7
ev_power(delta = 0.02, p_a = 0.72, p_b = 0.70, correlation = 0.7)
#> 
#> Evaluation size required
#> 
#>   Questions      2425
#> 
#>   To detect      0.0200
#>   SD of diff     0.3515 (binary scores)
#>   Power          80%
#>   Alpha          0.05 two-sided
#> 

# The same target, but questions come 8 to a passage
ev_power(delta = 0.02, p_a = 0.72, p_b = 0.70, correlation = 0.7,
         icc = 0.25, cluster_size = 8)
#> 
#> Evaluation size required
#> 
#>   Questions      6667
#>   Clusters       834 of 8
#> 
#>   To detect      0.0200
#>   SD of diff     0.3515 (binary scores)
#>   Power          80%
#>   Alpha          0.05 two-sided
#>   Design effect  2.75 (ICC 0.25, 8 per cluster)
#> 
#>   Clustering costs 4243 extra questions.
#> 
```
