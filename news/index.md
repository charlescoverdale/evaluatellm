# Changelog

## evaluatellm 0.1.0

CRAN release: 2026-09-15

Pre-submission audit fixes, ahead of the first CRAN release.

- [`ev_bootstrap()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_bootstrap.md)
  and
  [`ev_rank()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_rank.md)
  called [`set.seed()`](https://rdrr.io/r/base/Random.html) on the
  global random stream and left it altered. A user who passed `seed` to
  make one call reproducible found every later random draw in their
  session silently shifted. The seed now applies for the duration of the
  call only and the user’s `.Random.seed` is restored on exit. Seeded
  calls remain reproducible and unseeded calls still vary.

- [`ev_score()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_score.md)
  and
  [`ev_cluster()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_cluster.md)
  now warn when the interval has degenerated. A slice where every item
  passes gives a zero standard error, so the Wald interval collapses to
  a point and appears to claim certainty: 50 of 50 correct reported
  `[1.0000, 1.0000]` where Wilson gives about `[0.93, 1.00]`. Too few
  clusters pushes a pass rate’s interval outside `[0, 1]`. Both are
  properties of the normal approximation rather than errors, so they
  warn rather than abort, and the binary case quotes the Wilson interval
  for comparison.

- README gains a Limitations section covering the interval method and
  where it degrades, the cluster-count requirement, the random-sampling
  assumption behind prediction-powered inference, and the difference
  between judge agreement and judge accuracy.

First release.

Statistical inference for language model evaluations, following Miller
(2024) <doi:10.48550/arXiv.2411.00640> for the core standard error and
experiment design results, and the prediction-powered inference
literature for the model judge functions.

### Scoring

- [`as_eval()`](https://charlescoverdale.github.io/evaluatellm/reference/as_eval.md)
  builds the long-format evaluation object every other function
  consumes, from a data frame or a bare vector of scores.
- [`ev_score()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_score.md)
  reports a mean score with a central limit theorem standard error and
  confidence interval, switching to cluster-robust inference
  automatically when a cluster column is present.
- [`ev_cluster()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_cluster.md)
  gives the cluster-robust standard error with the design effect and
  intra-cluster correlation that explain it, and
  [`ev_icc()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_icc.md)
  returns the intra-cluster correlation on its own.
- [`ev_resample()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_resample.md)
  separates between-item variance from response sampling noise when
  several responses are drawn per question, and projects the standard
  error achievable at any number of responses per item.
- [`ev_bootstrap()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_bootstrap.md)
  provides a cluster bootstrap for statistics that are not means.

### Comparison

- [`ev_paired()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_paired.md)
  compares two models on the same questions and reports the variance
  saved by pairing.
- [`ev_unpaired()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_unpaired.md)
  handles disjoint question sets with a Welch interval.
- [`ev_variance_reduction()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_variance_reduction.md)
  applies a control variate from a reference model with a known score on
  the full question bank.
- [`ev_multi()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_multi.md)
  adjusts across a benchmark suite, pools by inverse variance, and tests
  heterogeneity.

### Planning

- [`ev_power()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_power.md)
  and
  [`ev_mde()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_mde.md)
  size a comparison and report its minimum detectable effect, both
  accounting for clustering.

### Model judges

- [`ev_judge_agreement()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_judge_agreement.md)
  reports accuracy, Cohen’s kappa, and a McNemar test for systematic
  judge bias.
- [`ev_judge_debias()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_judge_debias.md)
  implements the power-tuned prediction-powered estimator, combining
  many judge scores with a small human sample.
- [`ev_judge_power()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_judge_power.md)
  sizes the human labelling budget.

### Leaderboards

- [`ev_rank()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_rank.md)
  gives bootstrap rank intervals and the probability each model is best.
- [`ev_elo()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_elo.md)
  fits Bradley-Terry ratings with standard errors on the Elo scale.

### Reporting

- [`ev_table()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_table.md)
  and
  [`ev_plot()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_plot.md)
  collect results into a table and draw them with error bars.
