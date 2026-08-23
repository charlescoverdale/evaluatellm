# Collect Results into a Table

Flattens one or more `evalkit` results into a plain data frame with a
common set of columns, ready for a paper table or a plot.

## Usage

``` r
ev_table(...)
```

## Arguments

- ...:

  One or more `evalkit` result objects, or a single list of them. Names,
  where given, become the `label` column.

## Value

A data frame with columns `label`, `term`, `estimate`, `se`, `conf_low`,
`conf_high`, `p_value`, and `n`.

## See also

Other reporting:
[`ev_plot()`](https://charlescoverdale.github.io/evalkit/reference/ev_plot.md)

## Examples

``` r
set.seed(14)
d <- data.frame(
  q = rep(1:300, 2),
  m = rep(c("new", "old"), each = 300),
  correct = rbinom(600, 1, rep(c(0.74, 0.68), each = 300))
)
e <- as_eval(d, score = correct, item = q, model = m)
ev_table(
  new = ev_score(e, model = "new"),
  old = ev_score(e, model = "old"),
  gain = ev_paired(e, model_a = "new", model_b = "old")
)
#>   label                term   estimate         se     conf_low conf_high
#> 1   new               score 0.75333333 0.02492948  0.704273869 0.8023928
#> 2   old               score 0.69000000 0.02674667  0.637364425 0.7426356
#> 3  gain difference (paired) 0.06333333 0.03530354 -0.006141542 0.1328082
#>      p_value   n
#> 1         NA 300
#> 2         NA 300
#> 3 0.07382889 300
```
