# Plot Results with Error Bars

Draws the results as a horizontal interval plot, the format this package
exists to make routine. Accepts the same input as
[`ev_table()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_table.md),
and also plots
[`ev_rank()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_rank.md)
and
[`ev_multi()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_multi.md)
objects directly.

## Usage

``` r
ev_plot(x, ..., reference = NULL, xlab = NULL, main = NULL, col = "#1b365d")
```

## Arguments

- x:

  An `evaluatellm` result, a list of them, or a data frame from
  [`ev_table()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_table.md).

- ...:

  Further results, or graphical parameters passed to
  [`graphics::plot()`](https://rdrr.io/r/graphics/plot.default.html).

- reference:

  Optional vertical reference line, for example `0` for differences.
  Default `NULL`, which draws none.

- xlab, main:

  Axis and title labels.

- col:

  Colour for points and intervals.

## Value

The plotted data frame, invisibly.

## See also

Other reporting:
[`ev_table()`](https://charlescoverdale.github.io/evaluatellm/reference/ev_table.md)

## Examples

``` r
set.seed(15)
runs <- lapply(1:5, function(i) {
  d <- data.frame(
    q = rep(1:200, 2),
    m = rep(c("new", "old"), each = 200),
    correct = rbinom(400, 1, rep(c(0.72, 0.68), each = 200))
  )
  ev_paired(as_eval(d, score = correct, item = q, model = m),
            model_a = "new", model_b = "old")
})
names(runs) <- paste0("task ", 1:5)
ev_plot(runs, reference = 0)

```
