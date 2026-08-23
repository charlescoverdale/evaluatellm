# Internal helpers -------------------------------------------------------

# Two-sided p-value from a t statistic.
p_from_t <- function(t, df) {
  if (!is.finite(t) || !is.finite(df) || df <= 0) return(NA_real_)
  2 * stats::pt(-abs(t), df = df)
}

# Critical value for a confidence interval. Uses t when df is finite and
# positive, otherwise the normal quantile.
crit_value <- function(level, df = Inf) {
  a <- (1 - level) / 2
  if (is.finite(df) && df > 0) stats::qt(1 - a, df = df) else stats::qnorm(1 - a)
}

validate_level <- function(level) {
  if (!is.numeric(level) || length(level) != 1L || !is.finite(level) ||
      level <= 0 || level >= 1) {
    cli_abort("{.arg level} must be a single number strictly between 0 and 1.")
  }
  level
}

validate_scores <- function(x, arg = "score") {
  if (is.logical(x)) x <- as.numeric(x)
  if (!is.numeric(x)) {
    cli_abort("{.arg {arg}} must be numeric or logical, not {.cls {class(x)[1]}}.")
  }
  if (length(x) == 0L) cli_abort("{.arg {arg}} has length zero.")
  if (any(!is.finite(x))) {
    cli_abort("{.arg {arg}} contains missing or non-finite values. Drop or impute them first.")
  }
  as.numeric(x)
}

# Cluster-robust variance of a mean (CR1 corrected). Returns the variance,
# not the standard error.
crve_mean <- function(score, cluster, correct = TRUE) {
  n <- length(score)
  u <- score - mean(score)
  g_sums <- tapply(u, cluster, sum)
  G <- length(g_sums)
  v <- sum(g_sums^2) / n^2
  # CR1 finite-cluster correction, G / (G - 1) * (n - 1) / (n - K). Estimating
  # a mean means K = 1, so the second factor is exactly 1 and drops out.
  if (correct && G > 1L) {
    v <- v * (G / (G - 1))
  }
  list(var = v, n_clusters = G, cluster_sizes = as.integer(table(cluster)))
}

# Format a number for printing without scientific notation surprises.
fmt <- function(x, digits = 4) {
  formatC(x, digits = digits, format = "f")
}

fmt_ci <- function(lo, hi, digits = 4) {
  paste0("[", fmt(lo, digits), ", ", fmt(hi, digits), "]")
}

# Stars-free significance note used across print methods.
p_note <- function(p) {
  if (is.na(p)) return("")
  if (p < 0.001) return(" (p < 0.001)")
  paste0(" (p = ", formatC(p, digits = 3, format = "f"), ")")
}

new_ev_result <- function(x, class) {
  structure(x, class = c(class, "ev_result"))
}

# Set the RNG seed for the duration of the calling function only, restoring
# the user's .Random.seed on exit. A package should not leave the global
# random stream altered as a side effect of being called: a user who passes
# `seed` to make one call reproducible would otherwise find every subsequent
# random draw in their session silently shifted.
#
# Touching globalenv() here is deliberate and is the only way to do this:
# .Random.seed lives there by definition. This preserves the user's state
# rather than adding to it, which is the opposite of the pattern CRAN
# objects to.
local_seed <- function(seed, frame = parent.frame()) {
  if (is.null(seed)) {
    return(invisible(NULL))
  }
  if (!is.numeric(seed) || length(seed) != 1L || !is.finite(seed)) {
    cli_abort("{.arg seed} must be a single finite number or {.code NULL}.")
  }
  had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  restore <- if (had_seed) {
    old <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
    substitute(
      assign(".Random.seed", value, envir = globalenv()),
      list(value = old)
    )
  } else {
    # No stream existed before the call, so leave none behind.
    quote(suppressWarnings(rm(".Random.seed", envir = globalenv())))
  }
  do.call(on.exit, list(restore, add = TRUE, after = FALSE), envir = frame)
  set.seed(seed)
  invisible(NULL)
}

# Warn when a normal-approximation interval has degenerated.
#
# Two cases bite in practice on evaluation data. A slice where every item
# passes gives a zero standard error, so the Wald interval collapses to a
# point and appears to claim certainty it does not have. And with very few
# clusters the t multiplier is large enough to push a proportion's interval
# outside [0, 1], which is not a possible range for the quantity.
#
# Both are known properties of the normal-approximation interval that
# Miller (2024) uses, not errors, so these are warnings rather than aborts.
# The user needs to know the number in front of them is not usable.
warn_degenerate_ci <- function(est, se, lo, hi, score, n_items) {
  binary <- all(is.finite(score)) && all(score %in% c(0, 1))

  if (is.finite(se) && se == 0) {
    extra <- if (binary && n_items > 0) {
      z <- stats::qnorm(0.975)
      p <- est
      centre <- (p + z^2 / (2 * n_items)) / (1 + z^2 / n_items)
      half <- z * sqrt(p * (1 - p) / n_items + z^2 / (4 * n_items^2)) /
        (1 + z^2 / n_items)
      paste0("A Wilson interval on the same data gives roughly ",
             fmt_ci(max(0, centre - half), min(1, centre + half)), ".")
    } else {
      "The interval width is not a statement about precision here."
    }
    cli::cli_warn(c(
      "Standard error is zero, so the confidence interval has no width.",
      "i" = "Every score is identical, which collapses the normal-approximation
             interval to a point. It does not mean the estimate is certain.",
      "i" = extra
    ))
    return(invisible(NULL))
  }

  if (binary && (lo < 0 || hi > 1)) {
    cli::cli_warn(c(
      "Confidence interval {fmt_ci(lo, hi)} falls outside {.val {c(0, 1)}}.",
      "i" = "The scores are pass or fail, so the quantity cannot lie outside
             that range. The normal approximation is unreliable at this sample
             size.",
      "i" = "Treat the interval as uninformative rather than clipping it."
    ))
  }
  invisible(NULL)
}
