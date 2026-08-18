#' Evaluation Score with a Standard Error
#'
#' Reports the mean score of a model together with the standard error and
#' confidence interval implied by treating the questions as a sample. This is
#' the number that belongs next to every headline evaluation result, and the
#' one most often omitted.
#'
#' The standard error follows the central limit theorem applied to the item
#' means: `sd(score) / sqrt(n)`, where `n` counts items, not responses. When
#' `cluster` is present in the data the calculation switches to a
#' cluster-robust standard error, since questions sharing a passage or a source
#' document are not independent draws. See [ev_cluster()] for the detail.
#'
#' Confidence intervals use the t distribution with `n - 1` degrees of freedom,
#' or `G - 1` when clustered, which is slightly wider than the normal interval
#' used in Miller (2024) and better behaved on the short evaluations that
#' appear in practice.
#'
#' @param data An `evalkit_eval` object from [as_eval()], a data frame, or a
#'   bare numeric or logical vector of scores.
#' @param model Which model to score. Optional when the data holds only one.
#' @param level Confidence level. Default `0.95`.
#' @param cluster Logical. Use cluster-robust standard errors when a cluster
#'   column is present. Default `TRUE`. Set to `FALSE` to force the independent
#'   calculation, which is useful only for comparison.
#' @param ... Passed to [as_eval()] when `data` is a plain data frame.
#'
#' @return An `evalkit_score` object with elements `estimate`, `se`, `conf_low`,
#'   `conf_high`, `n_items`, `n_responses`, `df`, `level`, `clustered`, and,
#'   when clustered, `n_clusters` and `design_effect`.
#'
#' @references
#' Miller, E. (2024). Adding Error Bars to Evals: A Statistical Approach to
#' Language Model Evaluations. \doi{10.48550/arXiv.2411.00640}
#'
#' @examples
#' set.seed(1)
#' # 400 questions, 72 per cent correct
#' ev_score(rbinom(400, 1, 0.72))
#'
#' # The same accuracy, but questions come in groups of 8 per passage
#' d <- data.frame(
#'   q       = 1:400,
#'   passage = rep(1:50, each = 8),
#'   correct = rbinom(400, 1, 0.72)
#' )
#' ev_score(as_eval(d, score = correct, item = q, cluster = passage))
#'
#' @family single model
#' @export
ev_score <- function(data, model = NULL, level = 0.95, cluster = TRUE, ...) {
  x <- as_eval(data, ...)
  level <- validate_level(level)
  d <- one_model(x, model)
  il <- item_level(d)

  n <- length(il$score)
  if (n < 2L) cli_abort("Need at least 2 items to compute a standard error, found {n}.")

  est <- mean(il$score)
  use_cluster <- isTRUE(cluster) && !is.null(il$cluster)

  if (use_cluster) {
    cr <- crve_mean(il$score, il$cluster)
    se <- sqrt(cr$var)
    df <- cr$n_clusters - 1
    deff <- if (stats::var(il$score) > 0) cr$var / (stats::var(il$score) / n) else NA_real_
    n_cl <- cr$n_clusters
  } else {
    se <- stats::sd(il$score) / sqrt(n)
    df <- n - 1
    deff <- NA_real_
    n_cl <- NA_integer_
  }

  tcrit <- crit_value(level, df)
  out <- list(
    estimate      = est,
    se            = se,
    conf_low      = est - tcrit * se,
    conf_high     = est + tcrit * se,
    n_items       = n,
    n_responses   = nrow(d),
    n_clusters    = n_cl,
    design_effect = deff,
    df            = df,
    level         = level,
    clustered     = use_cluster,
    model         = unique(d$model)
  )
  new_ev_result(out, "evalkit_score")
}

#' @export
print.evalkit_score <- function(x, ...) {
  cat("\nEvaluation score", if (!is.null(x$model)) paste0(": ", x$model), "\n\n", sep = "")
  cat("  Estimate   ", fmt(x$estimate), "\n", sep = "")
  cat("  Std. error ", fmt(x$se), "\n", sep = "")
  cat("  ", format(100 * x$level), "% CI     ", fmt_ci(x$conf_low, x$conf_high), "\n", sep = "")
  cat("\n  Items      ", x$n_items, sep = "")
  if (x$n_responses > x$n_items) {
    cat(" (", x$n_responses, " responses)", sep = "")
  }
  cat("\n")
  if (isTRUE(x$clustered)) {
    cat("  Clusters   ", x$n_clusters, "\n", sep = "")
    if (is.finite(x$design_effect)) {
      cat("  Design eff ", fmt(x$design_effect, 2),
          " (SE is ", fmt(sqrt(x$design_effect), 2),
          "x the independent estimate)\n", sep = "")
    }
    cat("  Cluster-robust standard error, t on ", x$df, " df.\n", sep = "")
  } else {
    cat("  Independent standard error, t on ", x$df, " df.\n", sep = "")
  }
  cat("\n")
  invisible(x)
}
