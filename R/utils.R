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
