# Agreement Between a Model Judge and a Human Gold Standard

Quantifies how far a model judge can be trusted, by comparing its scores
against human labels on the items where both exist. Reports agreement,
chance-corrected agreement, and whether the judge is systematically
generous or harsh.

## Usage

``` r
ev_judge_agreement(judge, gold, level = 0.95)
```

## Arguments

- judge:

  Numeric or logical vector of judge scores.

- gold:

  Numeric or logical vector of human scores, the same length as `judge`.
  Entries may be `NA` where no human label exists; those items are
  ignored here.

- level:

  Confidence level. Default `0.95`.

## Value

An `evalkit_agreement` object. Always carries `n`, `type`, `bias`,
`bias_conf_low`, `bias_conf_high`, `bias_p_value`, `correlation`,
`mean_judge`, and `mean_gold`. Binary and categorical scores add
`accuracy`, `accuracy_conf_low`, `accuracy_conf_high`, `kappa`,
`kappa_se`, and, for binary, `sensitivity` and `specificity`.

## Details

Raw agreement flatters a judge whenever one label dominates: a judge
that passes everything agrees 90 per cent of the time with a gold
standard that passes 90 per cent of the time, while carrying no
information at all. Cohen's kappa corrects for that and is the number to
read.

Systematic bias matters more than noise, because noise averages out over
items while bias does not. For binary scores the McNemar test asks
whether the judge's disagreements run in one direction; a significant
result means the judge's mean score is wrong, not merely noisy, and
every evaluation graded by it inherits that error. The fix is
[`ev_judge_debias()`](https://charlescoverdale.github.io/evalkit/reference/ev_judge_debias.md),
not a better prompt.

The measurement type is detected from the data: binary when scores take
two values, categorical when they take a few, continuous otherwise.

## See also

Other judge:
[`ev_judge_debias()`](https://charlescoverdale.github.io/evalkit/reference/ev_judge_debias.md),
[`ev_judge_power()`](https://charlescoverdale.github.io/evalkit/reference/ev_judge_power.md)

## Examples

``` r
set.seed(10)
truth <- rbinom(400, 1, 0.6)
# A judge that is right 85 per cent of the time and slightly too generous
judge <- ifelse(runif(400) < 0.85, truth, 1 - truth)
judge[truth == 0 & runif(400) < 0.1] <- 1
ev_judge_agreement(judge, truth)
#> 
#> Judge agreement (binary, n = 400)
#> 
#>   Mean judge   0.6000
#>   Mean human   0.6050
#> 
#>   Agreement    0.785  [0.742, 0.822]
#>   Kappa        0.551  [0.468, 0.635]
#>   Sensitivity  0.818
#>   Specificity  0.734
#>   Correlation  0.551
#> 
#>   Bias         -0.0050  [-0.0506, 0.0406] (p = 0.830)
#>   McNemar      chi-sq 0.01 (p = 0.914)
#>                judge higher on 42 items, lower on 44
#> 
```
