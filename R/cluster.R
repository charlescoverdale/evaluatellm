#' Cluster-Robust Standard Error for an Evaluation
#'
#' Computes a cluster-robust standard error for a model's mean score, together
#' with the design effect and intra-cluster correlation that explain how much
#' precision the clustering costs.
#'
#' Many evaluations draw several questions from one source: comprehension
#' questions about a shared passage, variants of one prompt template, or items
#' generated from a single seed document. Those questions are not independent
#' draws, and treating them as though they were understates the standard error
#' by a factor of `sqrt(design effect)`. With eight questions per passage and an
#' intra-cluster correlation of 0.3, the honest interval is roughly 1.6 times
#' wider than the naive one.
#'
#' The estimator is the CR1-corrected cluster-robust variance of a mean,
#' `(G / (G - 1)) * sum_g (sum_i u_i)^2 / n^2`, where `u_i` are deviations from
#' the mean, `g` indexes clusters and `G` counts them. Inference uses the t
#' distribution on `G - 1` degrees of freedom, so results are appropriately
#' cautious when clusters are few.
#'
#' @inheritParams ev_score
#' @param data An `evalkit_eval` object carrying a cluster column, or a data
#'   frame passed to [as_eval()] along with `...`.
#'
#' @return An `evalkit_cluster` object with elements `estimate`, `se`,
#'   `se_naive`, `conf_low`, `conf_high`, `design_effect`, `icc`, `n_items`,
#'   `n_clusters`, `mean_cluster_size`, `df`, and `level`.
#'
#' @examples
#' set.seed(2)
#' # 40 passages, 10 questions each, with a strong passage effect
#' passage_skill <- rnorm(40, 0, 1)
#' d <- data.frame(
#'   q       = 1:400,
#'   passage = rep(1:40, each = 10),
#'   correct = rbinom(400, 1, plogis(0.9 + rep(passage_skill, each = 10)))
#' )
#' e <- as_eval(d, score = correct, item = q, cluster = passage)
#' ev_cluster(e)
#'
#' @family single model
#' @export
ev_cluster <- function(data, model = NULL, level = 0.95, ...) {
  x <- as_eval(data, ...)
  level <- validate_level(level)
  d <- one_model(x, model)
  il <- item_level(d)

  if (is.null(il$cluster)) {
    cli_abort(c(
      "No cluster column found.",
      i = "Supply one via {.code as_eval(data, cluster = <column>)}."
    ))
  }
  n <- length(il$score)
  if (n < 2L) cli_abort("Need at least 2 items, found {n}.")

  cr <- crve_mean(il$score, il$cluster)
  G <- cr$n_clusters
  if (G < 2L) cli_abort("Need at least 2 clusters, found {G}.")

  est <- mean(il$score)
  se  <- sqrt(cr$var)
  v_naive <- stats::var(il$score) / n
  se_naive <- sqrt(v_naive)
  deff <- if (v_naive > 0) cr$var / v_naive else NA_real_
  df <- G - 1
  tcrit <- crit_value(level, df)

  icc <- icc_oneway(il$score, il$cluster)

  out <- list(
    estimate          = est,
    se                = se,
    se_naive          = se_naive,
    conf_low          = est - tcrit * se,
    conf_high         = est + tcrit * se,
    design_effect     = deff,
    icc               = icc,
    n_items           = n,
    n_clusters        = G,
    mean_cluster_size = n / G,
    df                = df,
    level             = level,
    model             = unique(d$model)
  )
  new_ev_result(out, "evalkit_cluster")
}

#' Intra-Cluster Correlation
#'
#' Estimates the intra-cluster correlation of evaluation scores using the
#' one-way random effects analysis of variance estimator. This is the quantity
#' [ev_power()] needs in order to size a clustered evaluation, and the quantity
#' that determines how much [ev_cluster()] will widen an interval.
#'
#' The estimator is
#' `(MSB - MSW) / (MSB + (m0 - 1) * MSW)`, with `m0` the usual unbalanced-design
#' correction for average cluster size. Sampling noise can push the raw estimate
#' below zero, in which case it is reported as zero and a note is attached.
#'
#' @inheritParams ev_score
#' @param data An `evalkit_eval` object carrying a cluster column, or a data
#'   frame passed to [as_eval()] along with `...`.
#'
#' @return A single number between 0 and 1, with attribute `raw` holding the
#'   uncensored estimate.
#'
#' @examples
#' set.seed(3)
#' passage_skill <- rnorm(30, 0, 1.2)
#' d <- data.frame(
#'   q       = 1:300,
#'   passage = rep(1:30, each = 10),
#'   correct = rbinom(300, 1, plogis(0.5 + rep(passage_skill, each = 10)))
#' )
#' ev_icc(as_eval(d, score = correct, item = q, cluster = passage))
#'
#' @family single model
#' @export
ev_icc <- function(data, model = NULL, ...) {
  x <- as_eval(data, ...)
  d <- one_model(x, model)
  il <- item_level(d)
  if (is.null(il$cluster)) {
    cli_abort(c(
      "No cluster column found.",
      i = "Supply one via {.code as_eval(data, cluster = <column>)}."
    ))
  }
  icc_oneway(il$score, il$cluster)
}

# One-way random effects ICC, handling unbalanced clusters.
icc_oneway <- function(score, cluster) {
  f <- factor(cluster)
  G <- nlevels(f)
  n <- length(score)
  if (G < 2L || n <= G) return(structure(NA_real_, raw = NA_real_))

  sizes <- as.numeric(table(f))
  grand <- mean(score)
  gmeans <- as.numeric(tapply(score, f, mean))

  msb <- sum(sizes * (gmeans - grand)^2) / (G - 1)
  msw <- sum((score - gmeans[as.integer(f)])^2) / (n - G)

  # Average cluster size correction for unbalanced designs.
  m0 <- (n - sum(sizes^2) / n) / (G - 1)

  denom <- msb + (m0 - 1) * msw
  raw <- if (denom > 0) (msb - msw) / denom else NA_real_
  val <- if (is.na(raw)) NA_real_ else min(max(raw, 0), 1)
  structure(val, raw = raw)
}

#' @export
print.evalkit_cluster <- function(x, ...) {
  cat("\nCluster-robust evaluation score",
      if (!is.null(x$model)) paste0(": ", x$model), "\n\n", sep = "")
  cat("  Estimate       ", fmt(x$estimate), "\n", sep = "")
  cat("  Std. error     ", fmt(x$se), "  (naive ", fmt(x$se_naive), ")\n", sep = "")
  cat("  ", format(100 * x$level), "% CI         ", fmt_ci(x$conf_low, x$conf_high), "\n", sep = "")
  cat("\n  Items          ", x$n_items, "\n", sep = "")
  cat("  Clusters       ", x$n_clusters, " (mean size ",
      fmt(x$mean_cluster_size, 1), ")\n", sep = "")
  if (is.finite(x$design_effect)) {
    cat("  Design effect  ", fmt(x$design_effect, 2), "\n", sep = "")
  }
  if (is.finite(x$icc)) {
    cat("  ICC            ", fmt(x$icc, 3), "\n", sep = "")
    if (!is.na(attr(x$icc, "raw")) && attr(x$icc, "raw") < 0) {
      cat("                 (raw estimate ", fmt(attr(x$icc, "raw"), 3),
          " censored at zero)\n", sep = "")
    }
  }
  if (is.finite(x$design_effect) && x$design_effect > 1) {
    cat("\n  Ignoring clustering would understate the standard error by ",
        fmt(sqrt(x$design_effect), 2), "x.\n", sep = "")
  }
  cat("\n")
  invisible(x)
}
