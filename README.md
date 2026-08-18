# evalkit

<!-- badges: start -->
[![CRAN status](https://www.r-pkg.org/badges/version/evalkit)](https://CRAN.R-project.org/package=evalkit)
[![CRAN downloads](https://cranlogs.r-pkg.org/badges/grand-total/evalkit)](https://CRAN.R-project.org/package=evalkit)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
<!-- badges: end -->

Language model evaluations are experiments, and experiments have standard
errors. Almost no published evaluation reports one. `evalkit` supplies the
inference: standard errors that respect how questions were sampled, model
comparisons that use the pairing you already have, power calculations that tell
you whether an evaluation can answer its question before you run it, and
prediction-powered estimators that let a small set of human labels correct a
large set of model-judge scores.

It is a pure computation package. It runs no evaluations and calls no APIs: give
it scores from any harness and it gives you the statistics.

## Installation

```r
install.packages("evalkit")
```

Development version:

```r
# install.packages("pak")
pak::pak("charlescoverdale/evalkit")
```

## The problem in one number

Reading comprehension evaluations ask several questions about each passage. Those
questions are not independent draws, so the usual standard error is wrong. Across
1,500 simulated evaluations of 30 passages with 10 questions each, nominal 95 per
cent intervals actually covered the true value:

| Method | Coverage | Mean width |
|---|---|---|
| Cluster-robust (`ev_score` with a cluster column) | **95.1%** | 0.191 |
| Ignoring clustering | **74.5%** | 0.112 |

One evaluation in four was reporting an interval that did not contain the answer.

## Usage

```r
library(evalkit)

e <- as_eval(results, score = correct, item = q, model = model, cluster = passage)

ev_score(e, "new")
#> Evaluation score: new
#>
#>   Estimate   0.6950
#>   Std. error 0.0401
#>   95% CI     [0.6144, 0.7756]
#>
#>   Items      400
#>   Clusters   50
#>   Design eff 3.03 (SE is 1.74x the independent estimate)
#>   Cluster-robust standard error, t on 49 df.
```

Comparing two models uses the pairing automatically:

```r
ev_paired(e, model_a = "new", model_b = "old")
#> Paired comparison: new vs old
#>
#>   new  0.6950
#>   old  0.6350
#>
#>   Difference   0.0600  [-0.0035, 0.1235] (p = 0.063)
#>   Std. error   0.0316  (cluster-robust, 50 clusters)
#>   t = 1.899 on 49 df
```

Run the same comparison without the cluster column and it reports
`0.0600 [0.0000, 0.1200], p = 0.050`. The naive analysis clears the bar and the
honest one does not. Note also that clustering inflates the standard error on the
*level* by 1.74 times but the *difference* by much less, because pairing has
already removed the passage difficulty both models faced.

## Before you run an evaluation

```r
ev_mde(n_items = 500, p_a = 0.72, p_b = 0.70, correlation = 0.7,
       icc = 0.25, cluster_size = 8)
#>   MDE            0.0552
```

Five hundred clustered questions cannot detect a two point gain. Reporting a null
result from that evaluation says nothing about the models. Report the minimum
detectable effect alongside it, or run `ev_power()` first and buy enough
questions.

## Model judges

A judge that is biased stays biased however many items it grades. Measure it,
then correct it:

```r
ev_judge_agreement(judge, human)     # accuracy, Cohen's kappa, McNemar bias test
ev_judge_debias(judge, gold)         # prediction-powered estimate
ev_judge_power(n_total = 20000, correlation = 0.8, target_se = 0.01)
```

`ev_judge_debias()` takes judge scores for every item and human labels for a
random subset, marked `NA` elsewhere. It returns an estimate of what a full human
evaluation would have found, with valid intervals, and reports how many human
labels the result is worth:

```
#>   Your 250 human labels carry the precision of 400.
```

The estimator is tuned so it is never less precise than using the human labels
alone, so there is no downside to including a weak judge.

## Function reference

| | |
|---|---|
| `as_eval()` | Build the evaluation object |
| `ev_score()` | Mean score with a standard error and interval |
| `ev_cluster()`, `ev_icc()` | Cluster-robust inference, design effect, intra-cluster correlation |
| `ev_resample()` | Split between-item variance from response sampling noise |
| `ev_bootstrap()` | Cluster bootstrap for statistics that are not means |
| `ev_paired()`, `ev_unpaired()` | Compare two models |
| `ev_variance_reduction()` | Control variate from a reference model |
| `ev_multi()` | Multiplicity adjustment, pooling and heterogeneity across a suite |
| `ev_power()`, `ev_mde()` | Size an evaluation, or find what it can detect |
| `ev_judge_agreement()` | Judge against a human gold standard |
| `ev_judge_debias()` | Prediction-powered inference for judge-scored evaluations |
| `ev_judge_power()` | Size the human labelling budget |
| `ev_rank()`, `ev_elo()` | Leaderboards with rank intervals and Bradley-Terry ratings |
| `ev_table()`, `ev_plot()` | Collect and draw results |

## Validation

Every analytic result is checked against an independent implementation or a
simulation in the test suite:

* `ev_score()`, `ev_paired()` and `ev_unpaired()` reproduce `stats::t.test()` to
  machine precision, including Welch degrees of freedom.
* `ev_cluster()` reproduces `sandwich::vcovCL(type = "HC0", cadjust = TRUE)`
  exactly.
* Cohen's kappa uses the Fleiss, Cohen and Everitt (1969) asymptotic variance,
  checked against a bootstrap.
* `ev_resample()` recovers a known between and within variance decomposition.
* `ev_judge_debias()` is checked over 300 replications for unbiasedness,
  standard error accuracy and interval coverage.
* `ev_power()` agrees with `stats::power.t.test()` to within the difference
  between normal and t quantiles.

## Working with other tools

`evalkit` consumes scores, so it sits downstream of whatever produced them. The
[vitals](https://vitals.tidyverse.org/) package runs evaluations in R and its
logs pass straight into `as_eval()`; scores exported from Inspect, lm-eval-harness
or a bespoke pipeline work the same way.

## References

Miller, E. (2024). Adding Error Bars to Evals: A Statistical Approach to Language
Model Evaluations. <https://doi.org/10.48550/arXiv.2411.00640>

Angelopoulos, A. N., Bates, S., Fannjiang, C., Jordan, M. I., and Zrnic, T.
(2023). Prediction-powered inference. *Science*.
<https://doi.org/10.1126/science.adi6000>

Angelopoulos, A. N., Bates, S., and Jordan, M. I. (2023). PPI++: Efficient
Prediction-Powered Inference. <https://doi.org/10.48550/arXiv.2311.01453>

Bradley, R. A. and Terry, M. E. (1952). Rank Analysis of Incomplete Block
Designs: I. The Method of Paired Comparisons. *Biometrika*.
<https://doi.org/10.2307/2334029>

Fleiss, J. L., Cohen, J., and Everitt, B. S. (1969). Large sample standard errors
of kappa and weighted kappa. *Psychological Bulletin*.

## Licence

MIT
