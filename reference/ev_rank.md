# Bootstrap Rank Intervals for a Leaderboard

Resamples questions to ask how stable a leaderboard actually is. Returns
each model's score, its rank interval, and the probability it is
genuinely the best model in the table.

## Usage

``` r
ev_rank(data, R = 2000, level = 0.95, higher_better = TRUE, seed = NULL, ...)
```

## Arguments

- data:

  An `evalkit_eval` object holding several models, or a data frame
  passed to
  [`as_eval()`](https://charlescoverdale.github.io/evalkit/reference/as_eval.md)
  along with `...`.

- R:

  Number of bootstrap replicates. Default `2000`.

- level:

  Confidence level. Default `0.95`.

- higher_better:

  Logical. Whether a larger score means a better model. Default `TRUE`.

- seed:

  Optional integer seed for reproducibility.

- ...:

  Passed to
  [`as_eval()`](https://charlescoverdale.github.io/evalkit/reference/as_eval.md)
  when `data` is a plain data frame.

## Value

An `evalkit_rank` object with element `models`, a data frame ordered
best first with columns `model`, `estimate`, `se`, `conf_low`,
`conf_high`, `rank`, `rank_low`, `rank_high`, and `p_best`.

## Details

Leaderboards are read as though the ordering were a fact, when it is an
estimate like any other. Two models separated by half a point on a
400-question evaluation will often swap places on a different 400
questions. The rank interval says which orderings the data actually
support, and `p_best` says how much confidence the top position
deserves.

Clusters are resampled whole where a cluster column exists, matching the
dependence structure that
[`ev_cluster()`](https://charlescoverdale.github.io/evalkit/reference/ev_cluster.md)
handles analytically.

## See also

Other leaderboard:
[`ev_elo()`](https://charlescoverdale.github.io/evalkit/reference/ev_elo.md)

## Examples

``` r
set.seed(12)
difficulty <- rnorm(300)
skill <- c(a = 1.0, b = 0.95, c = 0.6, d = 0.2)
d <- do.call(rbind, lapply(names(skill), function(m) {
  data.frame(q = 1:300, m = m,
             correct = rbinom(300, 1, plogis(skill[[m]] - difficulty)))
}))
ev_rank(as_eval(d, score = correct, item = q, model = m), R = 500, seed = 1)
#> 
#> Leaderboard with bootstrap rank intervals
#> 
#>   model  score     95% CI          rank   p(best)
#>   a      0.7400  [0.6900, 0.7867]     1-1    0.99
#>   b      0.6567  [0.6033, 0.7067]     2-3    0.01
#>   c      0.6400  [0.5916, 0.6933]     2-3    0.01
#>   d      0.5800  [0.5216, 0.6300]     3-4    0.00
#> 
#>   Items      300
#>   Replicates 500
#> 
```
