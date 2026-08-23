# Build an Evaluation Object

Wraps evaluation scores in the long-format structure the `ev_*()`
functions expect: one row per scored response, identified by item,
model, and optionally cluster and sample.

## Usage

``` r
as_eval(
  data,
  score = NULL,
  item = NULL,
  model = NULL,
  cluster = NULL,
  sample = NULL
)
```

## Arguments

- data:

  A data frame of evaluation results, one row per scored response.
  Alternatively a bare numeric or logical vector of scores, in which
  case items are numbered sequentially and a single model is assumed.

- score:

  Column holding the score. Numeric, or logical for pass or fail
  grading. Given unquoted, or as a string.

- item:

  Column identifying the question. Defaults to `NULL`, meaning row
  order, which is correct only when each row is a distinct question.

- model:

  Column identifying the model. Defaults to `NULL`, meaning a single
  unnamed model.

- cluster:

  Column identifying groups of items that share structure, for example
  several questions asked about one reading passage, or several
  paraphrases of one prompt. Supply this whenever it exists: ignoring it
  understates standard errors, often severely.

- sample:

  Column identifying repeated draws for the same item and model. Only
  needed if the same item and model appear on several rows and you want
  [`ev_resample()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_resample.md)
  to decompose the variance.

## Value

An `evaluatellm_eval` object: a data frame with columns `item`, `model`,
`score`, and, when supplied, `cluster` and `sample`.

## Details

Every function in this package treats the *item* as the sampling unit,
on the view that an evaluation is a sample of questions drawn from an
unseen super-population of questions someone could have written (Miller
2024). Repeated responses to the same item are averaged within the item
before inference, so drawing more responses per item never inflates the
apparent sample size.

## References

Miller, E. (2024). Adding Error Bars to Evals: A Statistical Approach to
Language Model Evaluations.
[doi:10.48550/arXiv.2411.00640](https://doi.org/10.48550/arXiv.2411.00640)

## Examples

``` r
# A bare vector of pass or fail results
set.seed(1)
as_eval(rbinom(200, 1, 0.7))
#> <evaluatellm_eval>
#>   rows    200
#>   items   200
#>   models  1 (model)

# A full evaluation with clustered questions and two models
d <- data.frame(
  q       = rep(1:100, times = 2),
  passage = rep(rep(1:20, each = 5), times = 2),
  m       = rep(c("a", "b"), each = 100),
  correct = rbinom(200, 1, 0.6)
)
as_eval(d, score = correct, item = q, model = m, cluster = passage)
#> <evaluatellm_eval>
#>   rows    200
#>   items   100
#>   models  2 (a, b)
#>   clusters 20 
```
