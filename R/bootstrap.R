#' Cluster Bootstrap for an Arbitrary Statistic
#'
#' Resamples items, or whole clusters of items when a cluster column is present,
#' and recomputes a user-supplied statistic on each replicate. Use this when the
#' quantity of interest is not a mean and the analytic standard errors elsewhere
#' in the package do not apply: medians, quantiles, pass rates above a
#' threshold, or any custom score aggregation.
#'
#' Resampling clusters rather than items preserves the dependence structure, so
#' the resulting interval carries the same protection as [ev_cluster()].
#'
#' @inheritParams ev_score
#' @param statistic A function taking a numeric vector of item scores and
#'   returning a single number. Default [mean()].
#' @param R Number of bootstrap replicates. Default `2000`.
#' @param type Interval type, `"percentile"` (default) or `"basic"`.
#' @param seed Optional integer seed for reproducibility.
#'
#' @return An `evaluatellm_bootstrap` object with elements `estimate`, `se`,
#'   `conf_low`, `conf_high`, `replicates`, `R`, `type`, and `level`.
#'
#' @examples
#' set.seed(5)
#' e <- as_eval(rbeta(300, 6, 3))
#' ev_bootstrap(e, statistic = median, R = 500, seed = 1)
#'
#' @family single model
#' @export
ev_bootstrap <- function(data, model = NULL, statistic = mean, R = 2000,
                         level = 0.95, type = c("percentile", "basic"),
                         seed = NULL, ...) {
  x <- as_eval(data, ...)
  level <- validate_level(level)
  type <- match.arg(type)
  if (!is.function(statistic)) cli_abort("{.arg statistic} must be a function.")
  if (!is.numeric(R) || length(R) != 1L || R < 2) {
    cli_abort("{.arg R} must be a single number of at least 2.")
  }
  R <- as.integer(R)
  if (!is.null(seed)) set.seed(seed)

  d <- one_model(x, model)
  il <- item_level(d)
  n <- length(il$score)
  if (n < 2L) cli_abort("Need at least 2 items, found {n}.")

  est <- statistic(il$score)
  if (length(est) != 1L || !is.numeric(est)) {
    cli_abort("{.arg statistic} must return a single number.")
  }

  if (!is.null(il$cluster)) {
    groups <- split(seq_len(n), il$cluster)
    G <- length(groups)
    reps <- vapply(seq_len(R), function(i) {
      idx <- unlist(groups[base::sample.int(G, G, replace = TRUE)], use.names = FALSE)
      statistic(il$score[idx])
    }, numeric(1))
    unit <- "clusters"
    n_unit <- G
  } else {
    reps <- vapply(seq_len(R), function(i) {
      statistic(il$score[base::sample.int(n, n, replace = TRUE)])
    }, numeric(1))
    unit <- "items"
    n_unit <- n
  }

  a <- (1 - level) / 2
  qs <- stats::quantile(reps, c(a, 1 - a), names = FALSE, na.rm = TRUE)
  ci <- if (type == "percentile") qs else c(2 * est - qs[2], 2 * est - qs[1])

  out <- list(
    estimate   = est,
    se         = stats::sd(reps, na.rm = TRUE),
    conf_low   = ci[1],
    conf_high  = ci[2],
    replicates = reps,
    R          = R,
    type       = type,
    level      = level,
    unit       = unit,
    n_units    = n_unit,
    n_items    = n,
    model      = unique(d$model)
  )
  new_ev_result(out, "evaluatellm_bootstrap")
}

#' @export
print.evaluatellm_bootstrap <- function(x, ...) {
  cat("\nCluster bootstrap", if (!is.null(x$model)) paste0(": ", x$model), "\n\n", sep = "")
  cat("  Estimate   ", fmt(x$estimate), "\n", sep = "")
  cat("  Boot SE    ", fmt(x$se), "\n", sep = "")
  cat("  ", format(100 * x$level), "% CI     ", fmt_ci(x$conf_low, x$conf_high),
      " (", x$type, ")\n", sep = "")
  cat("\n  Replicates ", x$R, "\n", sep = "")
  cat("  Resampled  ", x$n_units, " ", x$unit, "\n\n", sep = "")
  invisible(x)
}
