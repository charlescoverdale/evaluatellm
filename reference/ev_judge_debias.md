# Debias a Model Judge with a Small Human Sample

Combines a large set of judge-scored items with a small set of
human-labelled items to estimate the score a full human evaluation would
have produced, with valid confidence intervals. This is
prediction-powered inference.

## Usage

``` r
ev_judge_debias(judge, gold, lambda = NULL, level = 0.95)
```

## Arguments

- judge:

  Numeric or logical vector of judge scores for every item.

- gold:

  Numeric or logical vector of human scores, the same length as `judge`,
  with `NA` where no human label exists.

- lambda:

  Optional fixed tuning coefficient in `[0, 1]`. Default `NULL`, meaning
  the variance-minimising value is estimated. `lambda = 1` gives the
  original prediction-powered estimator, `lambda = 0` the human-only
  mean.

- level:

  Confidence level. Default `0.95`.

## Value

An `evalkit_debias` object with elements `estimate`, `se`, `conf_low`,
`conf_high`, `lambda`, `estimate_classical`, `se_classical`,
`estimate_judge`, `judge_bias`, `effective_n`, `precision_gain`,
`n_labelled`, `n_unlabelled`, `correlation`, and `level`.

## Details

Grading with a model judge is cheap but biased, and the bias does not
shrink as more items are judged. Grading by hand is unbiased but small.
The prediction-powered estimator takes the judge's mean over everything
and subtracts the judge's measured error on the human-labelled subset:

`estimate = lambda * mean(judge, unlabelled) + mean(gold - lambda * judge, labelled)`

This is unbiased for any `lambda`, so no assumption about judge quality
is being smuggled in. The default tunes `lambda` to minimise variance
(Angelopoulos, Bates and Jordan 2023), which guarantees the result is
never less precise than ignoring the judge and using the human labels
alone. When the judge is uninformative `lambda` goes to zero and the
estimator falls back to the human-only mean; when the judge is good, a
few hundred human labels can carry the precision of several thousand.

The reported `effective_n` is the headline: the number of human labels
that would have been needed to reach this precision without the judge.

`gold` is expected to be `NA` for items that were not labelled by a
human. The labelled items must be a random sample of the evaluated
items. If humans were asked to label the cases the judge found hard,
this estimator is not valid.

## References

Angelopoulos, A. N., Bates, S., Fannjiang, C., Jordan, M. I., and Zrnic,
T. (2023). Prediction-powered inference. *Science*.
[doi:10.1126/science.adi6000](https://doi.org/10.1126/science.adi6000)

Angelopoulos, A. N., Bates, S., and Jordan, M. I. (2023). PPI++:
Efficient Prediction-Powered Inference.
[doi:10.48550/arXiv.2311.01453](https://doi.org/10.48550/arXiv.2311.01453)

## See also

Other judge:
[`ev_judge_agreement()`](https://charlescoverdale.github.io/evalkit/reference/ev_judge_agreement.md),
[`ev_judge_power()`](https://charlescoverdale.github.io/evalkit/reference/ev_judge_power.md)

## Examples

``` r
set.seed(11)
n_total <- 5000
truth <- rbinom(n_total, 1, 0.62)
# Judge agrees 88 per cent of the time and leans generous
judge <- ifelse(runif(n_total) < 0.88, truth, 1 - truth)
judge[truth == 0 & runif(n_total) < 0.12] <- 1

# Humans labelled a random 250 of them
gold <- rep(NA_real_, n_total)
idx <- sample(n_total, 250)
gold[idx] <- truth[idx]

ev_judge_debias(judge, gold)
#> 
#> Prediction-powered evaluation score
#> 
#>   Estimate     0.6139  [0.5628, 0.6649]
#>   Std. error   0.0260
#> 
#>   For comparison:
#>     humans only    0.5920  (SE 0.0311)
#>     judge only     0.6270  (biased by -0.0040)
#> 
#>   Items        5000 judged, 250 human-labelled
#>   Lambda       0.533 (tuned)
#>   Correlation  0.562
#> 
#>   Your 250 human labels carry the precision of 357.
#> 
```
