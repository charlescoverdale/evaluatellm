## R CMD check results

0 errors | 0 warnings | 0 notes (local)
0 errors | 0 warnings | 1 note (win-builder, the new-submission note below)

## Test environments

- macOS Tahoe 26.5 (local, aarch64), R 4.5.2, `--as-cran --run-donttest`
- win-builder, R 4.6.1 (2026-06-24 ucrt): 1 NOTE
- win-builder, R-devel: queued at the time of writing

## Submission notes

New submission.

The package provides statistical inference for language model evaluations:
standard errors and confidence intervals for evaluation scores, cluster-robust
inference for evaluations whose questions share a source, paired and unpaired
model comparisons, variance decomposition under repeated sampling, power and
minimum detectable effect calculations, prediction-powered inference for
evaluations graded by a model judge, and Bradley-Terry ratings for pairwise
preference data.

All computation is pure. There are no API calls, no network access, and no
bundled data. Dependencies are cli, graphics, grDevices, stats and utils.

## Note on the win-builder NOTE

The only note is the expected new-submission note. It flags four words in the
Description as possibly misspelled. All four are correct:

- `Angelopoulos` is the surname of the first author of both cited
  prediction-powered inference papers.
- `et` and `al` are from the abbreviation "et al.".
- `debiases` is the standard term in this literature for correcting a biased
  estimator using a labelled subsample.

## Verification

Method references appear in the Description field with DOIs in angle brackets.

Correctness is verified against independent implementations where they exist:
`ev_score()`, `ev_paired()` and `ev_unpaired()` are checked against
`stats::t.test()`, the cluster-robust variance against `sandwich::vcovCL()`
(used conditionally via `skip_if_not_installed()`), and `ev_power()` against
`stats::power.t.test()`. The remaining estimators are checked by simulation,
including a coverage and unbiasedness check of the prediction-powered
estimator. One long-running simulation test is wrapped in `skip_on_cran()`.

There are no reverse dependencies.
