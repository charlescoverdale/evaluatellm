# Cluster Bootstrap for an Arbitrary Statistic

Resamples items, or whole clusters of items when a cluster column is
present, and recomputes a user-supplied statistic on each replicate. Use
this when the quantity of interest is not a mean and the analytic
standard errors elsewhere in the package do not apply: medians,
quantiles, pass rates above a threshold, or any custom score
aggregation.

## Usage

``` r
ev_bootstrap(
  data,
  model = NULL,
  statistic = mean,
  R = 2000,
  level = 0.95,
  type = c("percentile", "basic"),
  seed = NULL,
  ...
)
```

## Arguments

- data:

  An `evalkit_eval` object from
  [`as_eval()`](https://charlescoverdale.github.io/evalkit/reference/as_eval.md),
  a data frame, or a bare numeric or logical vector of scores.

- model:

  Which model to score. Optional when the data holds only one.

- statistic:

  A function taking a numeric vector of item scores and returning a
  single number. Default [`mean()`](https://rdrr.io/r/base/mean.html).

- R:

  Number of bootstrap replicates. Default `2000`.

- level:

  Confidence level. Default `0.95`.

- type:

  Interval type, `"percentile"` (default) or `"basic"`.

- seed:

  Optional integer seed for reproducibility.

- ...:

  Passed to
  [`as_eval()`](https://charlescoverdale.github.io/evalkit/reference/as_eval.md)
  when `data` is a plain data frame.

## Value

An `evalkit_bootstrap` object with elements `estimate`, `se`,
`conf_low`, `conf_high`, `replicates`, `R`, `type`, and `level`.

## Details

Resampling clusters rather than items preserves the dependence
structure, so the resulting interval carries the same protection as
[`ev_cluster()`](https://charlescoverdale.github.io/evalkit/reference/ev_cluster.md).

## See also

Other single model:
[`ev_cluster()`](https://charlescoverdale.github.io/evalkit/reference/ev_cluster.md),
[`ev_icc()`](https://charlescoverdale.github.io/evalkit/reference/ev_icc.md),
[`ev_resample()`](https://charlescoverdale.github.io/evalkit/reference/ev_resample.md),
[`ev_score()`](https://charlescoverdale.github.io/evalkit/reference/ev_score.md)

## Examples

``` r
set.seed(5)
e <- as_eval(rbeta(300, 6, 3))
ev_bootstrap(e, statistic = median, R = 500, seed = 1)
#> 
#> Cluster bootstrap: model
#> 
#>   Estimate   0.6872
#>   Boot SE    0.0092
#>   95% CI     [0.6706, 0.7037] (percentile)
#> 
#>   Replicates 500
#>   Resampled  300 items
#> 
```
