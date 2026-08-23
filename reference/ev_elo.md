# Bradley-Terry Ratings from Pairwise Preferences

Fits a Bradley-Terry model to head-to-head comparison data, the format
used by arena-style evaluations where a judge or a human picks a winner
between two responses. Returns each model's strength with a standard
error, on both the log-odds and the Elo scale.

## Usage

``` r
ev_elo(
  data,
  model_a,
  model_b,
  winner,
  ties = c("drop", "split"),
  anchor = 1500,
  level = 0.95
)
```

## Arguments

- data:

  A data frame of pairwise comparisons.

- model_a, model_b:

  Columns naming the two models in each comparison.

- winner:

  Column giving the outcome. Either the name of the winning model, or a
  numeric or logical column that is `1` or `TRUE` when `model_a` won.
  Ties are `NA`, `"tie"`, or `0.5`.

- ties:

  How to treat ties, `"drop"` (default) or `"split"`.

- anchor:

  Elo rating of the average model. Strengths are centred, so this fixes
  the level of the whole table. Default `1500`.

- level:

  Confidence level. Default `0.95`.

## Value

An `evaluatellm_elo` object with element `models`, a data frame ordered
best first with columns `model`, `strength` (centred), `se`, `elo`,
`elo_low`, `elo_high`, and `n_games`.

## Details

Elo numbers are usually published bare, which hides how little separates
adjacent models. Fitting the model properly gives standard errors, so a
15-point gap can be recognised as noise. The fit is a logistic
regression of the win indicator on signed model indicators with no
intercept, estimated by maximum likelihood, with the first model fixed
at zero for identification. Strengths are centred to sum to zero and Elo
is the linear rescaling `anchor + (400 / log(10)) * strength`, so
`anchor` is the rating of an average model. Every model carries a
standard error, obtained by the delta method from the fitted covariance,
including the one held out for identification.

Ties are dropped by default, since Bradley-Terry has no tie term. Set
`ties = "split"` to count each tie as half a win to each side.

## References

Bradley, R. A. and Terry, M. E. (1952). Rank Analysis of Incomplete
Block Designs: I. The Method of Paired Comparisons. *Biometrika*.
[doi:10.2307/2334029](https://doi.org/10.2307/2334029)

## See also

Other leaderboard:
[`ev_rank()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_rank.md)

## Examples

``` r
set.seed(13)
strength <- c(a = 0.9, b = 0.5, c = 0.0, d = -0.6)
pairs <- t(replicate(1200, sample(names(strength), 2)))
p <- plogis(strength[pairs[, 1]] - strength[pairs[, 2]])
d <- data.frame(
  left  = pairs[, 1],
  right = pairs[, 2],
  won   = rbinom(1200, 1, p)
)
ev_elo(d, model_a = left, model_b = right, winner = won)
#> 
#> Bradley-Terry ratings (1200 comparisons, 4 models)
#> 
#>   model   elo      95% CI           games
#>   a       1621   [1598, 1645]       288
#>   b       1535   [1513, 1557]       300
#>   c       1483   [1460, 1505]       324
#>   d       1361   [1337, 1385]       288
#> 
#>   Centred    average model at 1500
#>   Ties       drop
#> 
```
