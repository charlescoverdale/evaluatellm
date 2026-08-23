# Multiplicity Adjustment Across a Benchmark Suite

Takes the per-task comparisons that make up a benchmark suite and
reports them together: multiplicity-adjusted p-values, simultaneous
confidence intervals, a pooled effect, and a heterogeneity check on
whether the tasks are telling the same story.

## Usage

``` r
ev_multi(results, method = "holm", level = 0.95)
```

## Arguments

- results:

  A list of objects from
  [`ev_paired()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_paired.md)
  or
  [`ev_unpaired()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_unpaired.md),
  optionally named by task. Alternatively a data frame with columns
  `estimate` and `se`, and optionally `task` and `df`.

- method:

  Multiplicity adjustment passed to
  [`stats::p.adjust()`](https://rdrr.io/r/stats/p.adjust.html). One of
  `"holm"` (default), `"BH"`, `"bonferroni"`, `"hochberg"`, `"BY"`,
  `"hommel"`, or `"none"`.

- level:

  Confidence level for the per-task intervals. Default `0.95`.
  Simultaneous intervals use `1 - (1 - level) / k`.

## Value

An `evaluatellm_multi` object with elements `tasks` (a data frame),
`pooled`, `pooled_se`, `pooled_conf_low`, `pooled_conf_high`,
`pooled_p_value`, `q_statistic`, `q_p_value`, `i_squared`, `n_tasks`,
`n_significant`, `method`, and `level`.

## Details

Running a model against twelve tasks and reporting the two that reached
significance is a recipe for false positives: at the five per cent
level, better than one task in two will produce at least one spurious
win by chance across twelve independent nulls. Adjustment fixes this.
Holm controls the family-wise error rate and is the default, appropriate
when a single false win would be embarrassing. Benjamini-Hochberg
controls the false discovery rate and is more permissive, appropriate
for screening many tasks.

The pooled estimate is inverse-variance weighted, which is the
minimum-variance combination when the tasks estimate a common effect.
Cochran's Q and `i_squared` test that assumption: a large `i_squared`
means the per-task effects genuinely differ and the pooled number is
hiding something, so read the per-task rows instead.

## See also

Other comparison:
[`ev_paired()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_paired.md),
[`ev_unpaired()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_unpaired.md),
[`ev_variance_reduction()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_variance_reduction.md)

## Examples

``` r
set.seed(9)
# Six tasks, a small true gain on each
runs <- lapply(1:6, function(i) {
  difficulty <- rnorm(250)
  d <- data.frame(
    q = rep(1:250, 2),
    m = rep(c("new", "old"), each = 250),
    correct = rbinom(500, 1,
      plogis(c(0.8, 0.65)[rep(1:2, each = 250)] - rep(difficulty, 2)))
  )
  ev_paired(as_eval(d, score = correct, item = q, model = m),
            model_a = "new", model_b = "old")
})
names(runs) <- paste0("task_", 1:6)
ev_multi(runs)
#> 
#> Benchmark suite: 6 tasks
#> 
#>   task    estimate       95% CI        p     p.adj
#>   task_1   -0.0040  [-0.0825, 0.0745]   0.920  1.000
#>   task_2    0.0120  [-0.0608, 0.0848]   0.746  1.000
#>   task_3    0.1000  [0.0225, 0.1775]    0.012  0.070
#>   task_4   -0.0200  [-0.0977, 0.0577]   0.613  1.000
#>   task_5   -0.0200  [-0.0961, 0.0561]   0.605  1.000
#>   task_6    0.0480  [-0.0266, 0.1226]   0.207  1.000
#> 
#>   Adjustment    holm (0 of 6 survive, 1 nominal)
#> 
#>   Pooled        0.0194  [-0.0115, 0.0503] (p = 0.219)
#>   Heterogeneity Q = 7.18 on 5 df (p = 0.207), I2 = 30%
#> 
```
