#' Variance Decomposition for Repeated Sampling
#'
#' When an evaluation draws several responses per question, the observed spread
#' of question means mixes two sources: genuine variation between questions, and
#' sampling noise in the model's own responses. This function separates them,
#' and reports how far more sampling can take you.
#'
#' Writing `s_ij` for the score of response `j` to item `i`, the estimator is the
#' equal-weighted mean of item means. Its variance is `var(item means) / n`,
#' which is unbiased whatever `k` is. The decomposition uses
#' `E[var(item means)] = var_between + E[var_within / k]`, so
#'
#' `var_between = var(item means) - mean(var_within / k)`
#'
#' The practical consequence is that more responses per question buys precision
#' only against the within-question term, and there is a floor at
#' `sqrt(var_between / n)` that no amount of resampling can beat. Reaching below
#' it requires more questions. Sampling noise can push the estimated between
#' component below zero, in which case it is reported as zero.
#'
#' @inheritParams ev_score
#' @param data An `evaluatellm_eval` object with several rows per item and model, or
#'   a data frame passed to [as_eval()] along with `...`.
#' @param k_grid Integer vector of `k` values at which to report the projected
#'   standard error. Default `c(1, 2, 4, 8, 16, Inf)`.
#'
#' @return An `evaluatellm_resample` object with elements `estimate`, `se`,
#'   `se_floor`, `var_between`, `var_within`, `share_within`, `n_items`,
#'   `k_mean`, `projection`, `df`, and `level`.
#'
#' @references
#' Miller, E. (2024). Adding Error Bars to Evals: A Statistical Approach to
#' Language Model Evaluations. \doi{10.48550/arXiv.2411.00640}
#'
#' @examples
#' set.seed(4)
#' # 150 questions, 8 sampled responses each, item difficulty varies
#' diff <- plogis(rnorm(150, 0.8, 1.1))
#' d <- data.frame(
#'   q       = rep(1:150, each = 8),
#'   draw    = rep(1:8, times = 150),
#'   correct = rbinom(1200, 1, rep(diff, each = 8))
#' )
#' ev_resample(as_eval(d, score = correct, item = q, sample = draw))
#'
#' @family single model
#' @export
ev_resample <- function(data, model = NULL, level = 0.95,
                        k_grid = c(1, 2, 4, 8, 16, Inf), ...) {
  x <- as_eval(data, ...)
  level <- validate_level(level)
  d <- one_model(x, model)

  f <- factor(d$item, levels = unique(d$item))
  n <- nlevels(f)
  if (n < 2L) cli_abort("Need at least 2 items, found {n}.")

  k <- as.integer(tapply(d$score, f, length))
  if (all(k < 2L)) {
    cli_abort(c(
      "Every item has a single response, so there is no within-item variance to estimate.",
      i = "Use {.fn ev_score} instead."
    ))
  }

  item_means <- as.numeric(tapply(d$score, f, mean))
  within_var <- as.numeric(tapply(d$score, f, function(z) {
    if (length(z) < 2L) NA_real_ else stats::var(z)
  }))

  est <- mean(item_means)
  v_obs <- stats::var(item_means)
  se <- sqrt(v_obs / n)

  # Mean within-item variance, and its contribution to var(item means).
  mean_within <- mean(within_var, na.rm = TRUE)
  contrib <- mean(within_var / k, na.rm = TRUE)

  var_between_raw <- v_obs - contrib
  var_between <- max(var_between_raw, 0)
  se_floor <- sqrt(var_between / n)

  share_within <- if (v_obs > 0) min(max(contrib / v_obs, 0), 1) else NA_real_

  proj <- data.frame(
    k  = k_grid,
    se = vapply(k_grid, function(kk) {
      sqrt((var_between + if (is.finite(kk)) mean_within / kk else 0) / n)
    }, numeric(1))
  )
  proj$responses <- ifelse(is.finite(proj$k), n * proj$k, NA_real_)

  df <- n - 1
  tcrit <- crit_value(level, df)

  out <- list(
    estimate        = est,
    se              = se,
    se_floor        = se_floor,
    conf_low        = est - tcrit * se,
    conf_high       = est + tcrit * se,
    var_between     = var_between,
    var_between_raw = var_between_raw,
    var_within      = mean_within,
    share_within    = share_within,
    n_items         = n,
    n_responses     = nrow(d),
    k_mean          = mean(k),
    projection      = proj,
    df              = df,
    level           = level,
    model           = unique(d$model)
  )
  new_ev_result(out, "evaluatellm_resample")
}

#' @export
print.evaluatellm_resample <- function(x, ...) {
  cat("\nRepeated-sampling variance decomposition",
      if (!is.null(x$model)) paste0(": ", x$model), "\n\n", sep = "")
  cat("  Estimate     ", fmt(x$estimate), "\n", sep = "")
  cat("  Std. error   ", fmt(x$se), "\n", sep = "")
  cat("  ", format(100 * x$level), "% CI       ", fmt_ci(x$conf_low, x$conf_high), "\n", sep = "")
  cat("\n  Items        ", x$n_items, "\n", sep = "")
  cat("  Responses    ", x$n_responses, " (mean k = ", fmt(x$k_mean, 1), ")\n", sep = "")
  cat("\n  Var between  ", format(x$var_between, digits = 3, scientific = FALSE), "\n", sep = "")
  cat("  Var within   ", format(x$var_within, digits = 3, scientific = FALSE), "\n", sep = "")
  if (is.finite(x$share_within)) {
    cat("  Share of observed spread that is sampling noise: ",
        format(round(100 * x$share_within), nsmall = 0), "%\n", sep = "")
  }
  if (!is.na(x$var_between_raw) && x$var_between_raw < 0) {
    cat("  (raw between-item variance was negative, censored at zero)\n")
  }
  cat("\n  Projected standard error by responses per item:\n\n")
  p <- x$projection
  for (i in seq_len(nrow(p))) {
    cat("    k = ", formatC(ifelse(is.finite(p$k[i]), p$k[i], Inf), width = 4),
        "   SE ", fmt(p$se[i]),
        if (is.finite(p$responses[i])) paste0("   (", p$responses[i], " responses)") else "   (floor)",
        "\n", sep = "")
  }
  cat("\n  More responses per item cannot beat SE ", fmt(x$se_floor),
      ".\n  Going below that requires more items.\n\n", sep = "")
  invisible(x)
}
