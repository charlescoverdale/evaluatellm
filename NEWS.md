# evalkit 0.1.0

First release.

Statistical inference for language model evaluations, following Miller (2024)
<doi:10.48550/arXiv.2411.00640> for the core standard error and experiment
design results, and the prediction-powered inference literature for the model
judge functions.

## Scoring

* `as_eval()` builds the long-format evaluation object every other function
  consumes, from a data frame or a bare vector of scores.
* `ev_score()` reports a mean score with a central limit theorem standard error
  and confidence interval, switching to cluster-robust inference automatically
  when a cluster column is present.
* `ev_cluster()` gives the cluster-robust standard error with the design effect
  and intra-cluster correlation that explain it, and `ev_icc()` returns the
  intra-cluster correlation on its own.
* `ev_resample()` separates between-item variance from response sampling noise
  when several responses are drawn per question, and projects the standard
  error achievable at any number of responses per item.
* `ev_bootstrap()` provides a cluster bootstrap for statistics that are not
  means.

## Comparison

* `ev_paired()` compares two models on the same questions and reports the
  variance saved by pairing.
* `ev_unpaired()` handles disjoint question sets with a Welch interval.
* `ev_variance_reduction()` applies a control variate from a reference model
  with a known score on the full question bank.
* `ev_multi()` adjusts across a benchmark suite, pools by inverse variance, and
  tests heterogeneity.

## Planning

* `ev_power()` and `ev_mde()` size a comparison and report its minimum
  detectable effect, both accounting for clustering.

## Model judges

* `ev_judge_agreement()` reports accuracy, Cohen's kappa, and a McNemar test
  for systematic judge bias.
* `ev_judge_debias()` implements the power-tuned prediction-powered estimator,
  combining many judge scores with a small human sample.
* `ev_judge_power()` sizes the human labelling budget.

## Leaderboards

* `ev_rank()` gives bootstrap rank intervals and the probability each model is
  best.
* `ev_elo()` fits Bradley-Terry ratings with standard errors on the Elo scale.

## Reporting

* `ev_table()` and `ev_plot()` collect results into a table and draw them with
  error bars.
