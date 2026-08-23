# CRAN submission comments: evalkit 0.1.0

## New submission

This is a first submission. evalkit treats language model evaluations as
statistical experiments and supplies the inference they require:
standard errors, model comparisons, variance decomposition, multiplicity
adjustment, power and minimum detectable effect calculations, judge
agreement statistics, prediction-powered inference, and leaderboard
ranking with uncertainty.

19 exported functions, all prefixed `ev_` apart from the `as_eval()`
constructor. One vignette, and 69 tests across 9 files.

## Why this package

Evaluation results are routinely reported as bare accuracy percentages
with no interval, and compared across models with no test. The
statistical machinery for doing it properly exists in the literature but
not in an R package: the closest R package, `vitals`, runs evaluations
and deliberately leaves inference out of scope. evalkit takes scores
from any harness, `vitals` included, and does the inference.

## Methods and references

The methods implemented are from the published literature, and every
reference in the Description carries a DOI:

* Central limit theorem and cluster-robust standard errors, paired and
  unpaired comparisons, variance reduction, and power analysis follow
  Miller (2024) <doi:10.48550/arXiv.2411.00640>.
* Prediction-powered inference follows Angelopoulos et al. (2023)
  <doi:10.1126/science.adi6000>, with the power-tuned estimator of
  Angelopoulos, Bates and Jordan (2023)
  <doi:10.48550/arXiv.2311.01453>.
* Leaderboard ratings use Bradley and Terry (1952)
  <doi:10.2307/2334029>.

## R CMD check results

0 errors | 0 warnings | 0 notes

I expect the usual "New submission" NOTE from the CRAN incoming
feasibility check, which does not run locally.

Local check: macOS (aarch64), R 4.5.2, `devtools::check(cran = TRUE)`
with `--run-donttest`.

## Notes on scope

The package makes no network calls and bundles no data. It is pure
computation on evaluation scores the user supplies, so nothing is
downloaded, cached, or written outside the session. Imports are `cli`
and base R graphics and stats only.

## Downstream dependencies

None. This is a new package.
