# Variance Reduction with a Reference Model

Uses a reference model whose score on the full question bank is already
known to shrink the standard error of a new model's score, without
changing what is being estimated.

## Usage

``` r
ev_variance_reduction(
  data,
  model = NULL,
  reference = NULL,
  mu_reference = NULL,
  theta = NULL,
  level = 0.95,
  ...
)
```

## Arguments

- data:

  An `evaluatellm_eval` object holding both models, or a data frame
  passed to
  [`as_eval()`](https://charlescoverdale.github.io/evaluatellm/reference/as_eval.md)
  along with `...`.

- model:

  The model being scored.

- reference:

  The reference model used as the control variate.

- mu_reference:

  The reference model's known mean score on the full question bank.

- theta:

  Optional fixed coefficient. Default `NULL`, meaning the
  variance-minimising value is estimated from the data.

- level:

  Confidence level. Default `0.95`.

- ...:

  Passed to
  [`as_eval()`](https://charlescoverdale.github.io/evaluatellm/reference/as_eval.md)
  when `data` is a plain data frame.

## Value

An `evaluatellm_vr` object with elements `estimate`, `se`, `conf_low`,
`conf_high`, `estimate_raw`, `se_raw`, `theta`, `correlation`,
`variance_reduction`, `effective_n`, `n_items`, `df`, and `level`.

## Details

The idea is the control variate. If a reference model scores `z_i` on
the same questions and its population mean `mu_reference` is known, then
the questions this evaluation happened to draw can be recognised as
easier or harder than average, and the new model's score corrected
accordingly:

`estimate = mean(y) - theta * (mean(z) - mu_reference)`

The variance-minimising coefficient is `theta = cov(y, z) / var(z)`, and
the resulting variance is `var(y) * (1 - rho^2) / n`. The adjustment is
unbiased for any `theta`, so nothing is assumed beyond `mu_reference`
being correct. Because model scores on shared questions correlate
strongly, a correlation of 0.8 removes roughly two thirds of the
variance, which is equivalent to tripling the number of questions.

`mu_reference` has to come from outside this evaluation: a reference
model run over the whole bank, or a published score on the full
benchmark. Supplying the reference model's mean on these same questions
would make the correction identically zero.

## See also

Other comparison:
[`ev_multi()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_multi.md),
[`ev_paired()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_paired.md),
[`ev_unpaired()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_unpaired.md)

## Examples

``` r
set.seed(8)
difficulty <- rnorm(200)
d <- data.frame(
  q = rep(1:200, 2),
  m = rep(c("new", "ref"), each = 200),
  correct = rbinom(400, 1,
    plogis(c(1.0, 0.6)[rep(1:2, each = 200)] - rep(difficulty, 2)))
)
e <- as_eval(d, score = correct, item = q, model = m)
# The reference model is known to score 0.63 on the full bank
ev_variance_reduction(e, model = "new", reference = "ref",
                      mu_reference = 0.63)
#> 
#> Control-variate adjusted score: new
#> 
#>   Adjusted     0.6996  [0.6384, 0.7607]
#>   Unadjusted   0.7050  (SE 0.0323)
#>   Std. error   0.0310
#> 
#>   Reference    ref
#>     known mean on full bank   0.6300
#>     observed mean here        0.6500
#>     theta                     0.271 (estimated)
#>     correlation               0.284
#> 
#>   Variance cut 1.09x. 200 items now carry the precision of 218.
#> 
```
