# Shared engine for power and MDE ---------------------------------------

resolve_sd_diff <- function(sd_diff, pilot, p_a, p_b, correlation) {
  if (!is.null(sd_diff)) {
    if (!is.numeric(sd_diff) || length(sd_diff) != 1L || !is.finite(sd_diff) ||
        sd_diff <= 0) {
      cli_abort("{.arg sd_diff} must be a single positive number.")
    }
    return(list(sd = sd_diff, source = "supplied"))
  }
  if (!is.null(pilot)) {
    if (inherits(pilot, "evaluatellm_paired")) {
      return(list(sd = pilot$se * sqrt(pilot$n_items), source = "pilot comparison"))
    }
    cli_abort("{.arg pilot} must be a result from {.fn ev_paired}.")
  }
  if (!is.null(p_a) && !is.null(p_b)) {
    rho <- correlation %||% 0
    if (any(c(p_a, p_b) < 0) || any(c(p_a, p_b) > 1)) {
      cli_abort("{.arg p_a} and {.arg p_b} must lie between 0 and 1.")
    }
    if (rho < -1 || rho > 1) cli_abort("{.arg correlation} must lie between -1 and 1.")
    va <- p_a * (1 - p_a)
    vb <- p_b * (1 - p_b)
    v <- va + vb - 2 * rho * sqrt(va * vb)
    if (v <= 0) cli_abort("The implied variance of the difference is not positive.")
    return(list(sd = sqrt(v), source = "binary scores"))
  }
  cli_abort(c(
    "Cannot determine the standard deviation of the per-item difference.",
    i = "Supply one of {.arg sd_diff}, {.arg pilot}, or {.arg p_a} and {.arg p_b}."
  ))
}

design_effect <- function(icc, cluster_size) {
  if (!is.numeric(icc) || length(icc) != 1L || icc < 0 || icc > 1) {
    cli_abort("{.arg icc} must be a single number between 0 and 1.")
  }
  if (!is.numeric(cluster_size) || length(cluster_size) != 1L || cluster_size < 1) {
    cli_abort("{.arg cluster_size} must be a single number of at least 1.")
  }
  1 + (cluster_size - 1) * icc
}

#' Number of Questions Needed to Detect a Difference
#'
#' Plans a paired model comparison: given the size of the gain worth detecting
#' and the variability of the per-item difference, returns how many questions
#' the evaluation needs.
#'
#' The calculation is the standard one for a paired mean,
#' `n = (z_alpha/2 + z_beta)^2 * sd_diff^2 / delta^2`, multiplied by the design
#' effect `1 + (cluster_size - 1) * icc` when questions come in clusters. Normal
#' quantiles are used, which is conventional for planning and slightly
#' optimistic for very small `n`.
#'
#' Getting `sd_diff` right is the whole exercise. It is the standard deviation of
#' the per-question difference, not of the scores, and it is much smaller than
#' people expect because the two models face the same questions. The reliable
#' way to get it is a pilot run passed through [ev_paired()] and handed back here
#' as `pilot`. Failing that, supply `p_a`, `p_b` and a correlation for binary
#' scoring: a correlation of 0.7 is typical for models of similar capability.
#'
#' @param delta The difference worth detecting, on the score scale.
#' @param sd_diff Standard deviation of the per-item difference.
#' @param pilot A result from [ev_paired()] to take `sd_diff` from.
#' @param p_a,p_b Expected scores of the two models, for binary grading.
#' @param correlation Expected correlation between the two models' item scores.
#'   Used with `p_a` and `p_b`. Default `0`, which is conservative.
#' @param power Target power. Default `0.8`.
#' @param alpha Two-sided significance level. Default `0.05`.
#' @param icc Intra-cluster correlation, from [ev_icc()]. Default `0`.
#' @param cluster_size Questions per cluster. Default `1`, meaning no clustering.
#'
#' @return An `evaluatellm_power` object with elements `n_items`, `n_clusters`,
#'   `delta`, `sd_diff`, `power`, `alpha`, `design_effect`, and `icc`.
#'
#' @examples
#' # Detect a 2 point gain, binary scoring, models correlated at 0.7
#' ev_power(delta = 0.02, p_a = 0.72, p_b = 0.70, correlation = 0.7)
#'
#' # The same target, but questions come 8 to a passage
#' ev_power(delta = 0.02, p_a = 0.72, p_b = 0.70, correlation = 0.7,
#'          icc = 0.25, cluster_size = 8)
#'
#' @family planning
#' @export
ev_power <- function(delta, sd_diff = NULL, pilot = NULL, p_a = NULL, p_b = NULL,
                     correlation = NULL, power = 0.8, alpha = 0.05,
                     icc = 0, cluster_size = 1) {
  if (!is.numeric(delta) || length(delta) != 1L || !is.finite(delta) || delta == 0) {
    cli_abort("{.arg delta} must be a single non-zero number.")
  }
  if (!is.numeric(power) || length(power) != 1L || power <= 0 || power >= 1) {
    cli_abort("{.arg power} must be a single number strictly between 0 and 1.")
  }
  if (!is.numeric(alpha) || length(alpha) != 1L || alpha <= 0 || alpha >= 1) {
    cli_abort("{.arg alpha} must be a single number strictly between 0 and 1.")
  }

  s <- resolve_sd_diff(sd_diff, pilot, p_a, p_b, correlation)
  deff <- design_effect(icc, cluster_size)

  z <- stats::qnorm(1 - alpha / 2) + stats::qnorm(power)
  n <- z^2 * s$sd^2 / delta^2 * deff

  out <- list(
    n_items       = ceiling(n),
    n_clusters    = if (cluster_size > 1) ceiling(n / cluster_size) else NA_integer_,
    delta         = delta,
    sd_diff       = s$sd,
    sd_source     = s$source,
    power         = power,
    alpha         = alpha,
    design_effect = deff,
    icc           = icc,
    cluster_size  = cluster_size
  )
  new_ev_result(out, "evaluatellm_power")
}

#' Smallest Difference an Evaluation Can Detect
#'
#' The mirror of [ev_power()]. Given the number of questions available, returns
#' the smallest true difference the evaluation has a decent chance of detecting.
#'
#' Run this before an evaluation, not after. If the minimum detectable effect
#' comes back larger than the gain you expect, the evaluation cannot answer the
#' question and a null result will mean nothing. Reporting the minimum
#' detectable effect alongside a null finding is what separates "the models are
#' equivalent" from "this evaluation was too small to tell".
#'
#' @inheritParams ev_power
#' @param n_items Number of questions available.
#'
#' @return An `evaluatellm_mde` object with elements `mde`, `n_items`,
#'   `n_effective`, `sd_diff`, `power`, `alpha`, `design_effect`, and `icc`.
#'
#' @examples
#' # 500 questions, binary scoring, models correlated at 0.7
#' ev_mde(n_items = 500, p_a = 0.72, p_b = 0.70, correlation = 0.7)
#'
#' # Same questions, but clustered 8 to a passage: the MDE nearly doubles
#' ev_mde(n_items = 500, p_a = 0.72, p_b = 0.70, correlation = 0.7,
#'        icc = 0.25, cluster_size = 8)
#'
#' @family planning
#' @export
ev_mde <- function(n_items, sd_diff = NULL, pilot = NULL, p_a = NULL, p_b = NULL,
                   correlation = NULL, power = 0.8, alpha = 0.05,
                   icc = 0, cluster_size = 1) {
  if (!is.numeric(n_items) || length(n_items) != 1L || n_items < 2) {
    cli_abort("{.arg n_items} must be a single number of at least 2.")
  }
  if (!is.numeric(power) || length(power) != 1L || power <= 0 || power >= 1) {
    cli_abort("{.arg power} must be a single number strictly between 0 and 1.")
  }
  if (!is.numeric(alpha) || length(alpha) != 1L || alpha <= 0 || alpha >= 1) {
    cli_abort("{.arg alpha} must be a single number strictly between 0 and 1.")
  }

  s <- resolve_sd_diff(sd_diff, pilot, p_a, p_b, correlation)
  deff <- design_effect(icc, cluster_size)
  n_eff <- n_items / deff

  z <- stats::qnorm(1 - alpha / 2) + stats::qnorm(power)
  mde <- z * s$sd / sqrt(n_eff)

  out <- list(
    mde           = mde,
    n_items       = n_items,
    n_effective   = n_eff,
    sd_diff       = s$sd,
    sd_source     = s$source,
    power         = power,
    alpha         = alpha,
    design_effect = deff,
    icc           = icc,
    cluster_size  = cluster_size
  )
  new_ev_result(out, "evaluatellm_mde")
}

#' @export
print.evaluatellm_power <- function(x, ...) {
  cat("\nEvaluation size required\n\n")
  cat("  Questions      ", x$n_items, "\n", sep = "")
  if (!is.na(x$n_clusters)) {
    cat("  Clusters       ", x$n_clusters, " of ", x$cluster_size, "\n", sep = "")
  }
  cat("\n  To detect      ", fmt(x$delta), "\n", sep = "")
  cat("  SD of diff     ", fmt(x$sd_diff), " (", x$sd_source, ")\n", sep = "")
  cat("  Power          ", format(100 * x$power), "%\n", sep = "")
  cat("  Alpha          ", x$alpha, " two-sided\n", sep = "")
  if (x$design_effect > 1) {
    cat("  Design effect  ", fmt(x$design_effect, 2), " (ICC ", x$icc,
        ", ", x$cluster_size, " per cluster)\n", sep = "")
    cat("\n  Clustering costs ", ceiling(x$n_items - x$n_items / x$design_effect),
        " extra questions.\n", sep = "")
  }
  cat("\n")
  invisible(x)
}

#' @export
print.evaluatellm_mde <- function(x, ...) {
  cat("\nMinimum detectable effect\n\n")
  cat("  MDE            ", fmt(x$mde), "\n", sep = "")
  cat("\n  Questions      ", x$n_items, sep = "")
  if (x$design_effect > 1) {
    cat(" (effective ", fmt(x$n_effective, 0), ")", sep = "")
  }
  cat("\n")
  cat("  SD of diff     ", fmt(x$sd_diff), " (", x$sd_source, ")\n", sep = "")
  cat("  Power          ", format(100 * x$power), "%\n", sep = "")
  cat("  Alpha          ", x$alpha, " two-sided\n", sep = "")
  if (x$design_effect > 1) {
    cat("  Design effect  ", fmt(x$design_effect, 2), "\n", sep = "")
  }
  cat("\n  A true difference below ", fmt(x$mde),
      " will usually be missed.\n\n", sep = "")
  invisible(x)
}
