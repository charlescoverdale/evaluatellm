#' Paired Comparison of Two Models
#'
#' Tests whether one model outscores another on the same set of questions. This
#' is the correct comparison whenever both models were run on the same
#' evaluation, and it is materially more powerful than comparing two independent
#' means.
#'
#' Working with the per-item difference `d_i = score_A - score_B` removes the
#' item difficulty that both models face, so the variance of the difference is
#' `var_A + var_B - 2 * cov(A, B)` rather than `var_A + var_B`. Because model
#' scores on shared questions are usually strongly correlated, the paired
#' standard error is routinely half the unpaired one or better, which is the
#' difference between detecting a real gain and reporting a null result. The
#' function reports the realised gain as `variance_reduction`.
#'
#' When the data carry a cluster column the standard error of the mean
#' difference is cluster-robust, and the test uses `G - 1` degrees of freedom.
#'
#' @inheritParams ev_score
#' @param data An `evaluatellm_eval` object holding both models, or a data frame
#'   passed to [as_eval()] along with `...`.
#' @param model_a Name of the first model. The reported difference is
#'   `model_a - model_b`.
#' @param model_b Name of the second model.
#' @param cluster Logical. Use cluster-robust standard errors when a cluster
#'   column is present. Default `TRUE`.
#'
#' @return An `evaluatellm_paired` object with elements `estimate`, `se`,
#'   `se_unpaired`, `conf_low`, `conf_high`, `statistic`, `p_value`,
#'   `correlation`, `variance_reduction`, `mean_a`, `mean_b`, `n_items`, `df`,
#'   and `level`.
#'
#' @references
#' Miller, E. (2024). Adding Error Bars to Evals: A Statistical Approach to
#' Language Model Evaluations. \doi{10.48550/arXiv.2411.00640}
#'
#' @examples
#' set.seed(6)
#' # Shared item difficulty makes the two models' scores correlate
#' difficulty <- rnorm(500)
#' d <- data.frame(
#'   q = rep(1:500, 2),
#'   m = rep(c("new", "old"), each = 500),
#'   correct = rbinom(1000, 1,
#'     plogis(c(0.9, 0.7)[rep(1:2, each = 500)] - rep(difficulty, 2)))
#' )
#' ev_paired(as_eval(d, score = correct, item = q, model = m),
#'           model_a = "new", model_b = "old")
#'
#' @family comparison
#' @export
ev_paired <- function(data, model_a = NULL, model_b = NULL, level = 0.95,
                      cluster = TRUE, ...) {
  x <- as_eval(data, ...)
  level <- validate_level(level)

  models <- unique(x$model)
  if (is.null(model_a) || is.null(model_b)) {
    if (length(models) != 2L) {
      cli_abort(c(
        "{.arg model_a} and {.arg model_b} must be supplied when the data hold {length(models)} models.",
        i = "Models present: {.val {models}}."
      ))
    }
    model_a <- model_a %||% models[1L]
    model_b <- model_b %||% models[2L]
  }
  if (identical(model_a, model_b)) {
    cli_abort("{.arg model_a} and {.arg model_b} must differ.")
  }

  a <- item_level(one_model(x, model_a, "model_a"))
  b <- item_level(one_model(x, model_b, "model_b"))

  common <- intersect(as.character(a$item), as.character(b$item))
  if (length(common) < 2L) {
    cli_abort(c(
      "Found {length(common)} item{?s} scored by both models.",
      i = "A paired comparison needs the two models run on the same questions.",
      i = "Use {.fn ev_unpaired} for disjoint question sets."
    ))
  }
  dropped <- length(unique(c(as.character(a$item), as.character(b$item)))) - length(common)
  if (dropped > 0L) {
    cli_warn("Dropped {dropped} item{?s} not scored by both models.")
  }

  ia <- match(common, as.character(a$item))
  ib <- match(common, as.character(b$item))
  sa <- a$score[ia]
  sb <- b$score[ib]
  dif <- sa - sb
  n <- length(dif)

  cl <- if (!is.null(a$cluster)) a$cluster[ia] else NULL
  use_cluster <- isTRUE(cluster) && !is.null(cl)

  est <- mean(dif)
  if (use_cluster) {
    cr <- crve_mean(dif, cl)
    se <- sqrt(cr$var)
    df <- cr$n_clusters - 1
    n_cl <- cr$n_clusters
  } else {
    se <- stats::sd(dif) / sqrt(n)
    df <- n - 1
    n_cl <- NA_integer_
  }

  se_unpaired <- sqrt(stats::var(sa) / n + stats::var(sb) / n)
  vr <- if (se > 0) (se_unpaired / se)^2 else NA_real_
  rho <- if (stats::sd(sa) > 0 && stats::sd(sb) > 0) stats::cor(sa, sb) else NA_real_

  tstat <- if (se > 0) est / se else NA_real_
  tcrit <- crit_value(level, df)

  out <- list(
    estimate           = est,
    se                 = se,
    se_unpaired        = se_unpaired,
    conf_low           = est - tcrit * se,
    conf_high          = est + tcrit * se,
    statistic          = tstat,
    p_value            = p_from_t(tstat, df),
    correlation        = rho,
    variance_reduction = vr,
    mean_a             = mean(sa),
    mean_b             = mean(sb),
    model_a            = model_a,
    model_b            = model_b,
    n_items            = n,
    n_clusters         = n_cl,
    clustered          = use_cluster,
    df                 = df,
    level              = level
  )
  new_ev_result(out, "evaluatellm_paired")
}

#' Unpaired Comparison of Two Models
#'
#' Compares two models evaluated on different question sets, using a Welch
#' two-sample interval that does not assume equal variances.
#'
#' Prefer [ev_paired()] whenever both models were run on the same questions.
#' This function exists for the case where they were not, for instance when
#' comparing a published score against your own run, and it will be
#' substantially less powerful because item difficulty is left in the error
#' term.
#'
#' @inheritParams ev_paired
#'
#' @return An `evaluatellm_unpaired` object with elements `estimate`, `se`,
#'   `conf_low`, `conf_high`, `statistic`, `p_value`, `mean_a`, `mean_b`,
#'   `n_a`, `n_b`, `df`, and `level`.
#'
#' @examples
#' set.seed(7)
#' d <- data.frame(
#'   q = 1:600,
#'   m = rep(c("a", "b"), each = 300),
#'   correct = rbinom(600, 1, rep(c(0.72, 0.65), each = 300))
#' )
#' ev_unpaired(as_eval(d, score = correct, item = q, model = m),
#'             model_a = "a", model_b = "b")
#'
#' @family comparison
#' @export
ev_unpaired <- function(data, model_a = NULL, model_b = NULL, level = 0.95, ...) {
  x <- as_eval(data, ...)
  level <- validate_level(level)

  models <- unique(x$model)
  if (is.null(model_a) || is.null(model_b)) {
    if (length(models) != 2L) {
      cli_abort(c(
        "{.arg model_a} and {.arg model_b} must be supplied when the data hold {length(models)} models.",
        i = "Models present: {.val {models}}."
      ))
    }
    model_a <- model_a %||% models[1L]
    model_b <- model_b %||% models[2L]
  }
  if (identical(model_a, model_b)) {
    cli_abort("{.arg model_a} and {.arg model_b} must differ.")
  }

  sa <- item_level(one_model(x, model_a, "model_a"))$score
  sb <- item_level(one_model(x, model_b, "model_b"))$score
  na <- length(sa); nb <- length(sb)
  if (na < 2L || nb < 2L) cli_abort("Each model needs at least 2 items.")

  va <- stats::var(sa) / na
  vb <- stats::var(sb) / nb
  est <- mean(sa) - mean(sb)
  se <- sqrt(va + vb)

  # Welch-Satterthwaite degrees of freedom.
  df <- if (va + vb > 0) {
    (va + vb)^2 / (va^2 / (na - 1) + vb^2 / (nb - 1))
  } else NA_real_

  tstat <- if (se > 0) est / se else NA_real_
  tcrit <- crit_value(level, df)

  out <- list(
    estimate  = est,
    se        = se,
    conf_low  = est - tcrit * se,
    conf_high = est + tcrit * se,
    statistic = tstat,
    p_value   = p_from_t(tstat, df),
    mean_a    = mean(sa),
    mean_b    = mean(sb),
    model_a   = model_a,
    model_b   = model_b,
    n_a       = na,
    n_b       = nb,
    df        = df,
    level     = level
  )
  new_ev_result(out, "evaluatellm_unpaired")
}

`%||%` <- function(x, y) if (is.null(x)) y else x

#' @export
print.evaluatellm_paired <- function(x, ...) {
  cat("\nPaired comparison: ", x$model_a, " vs ", x$model_b, "\n\n", sep = "")
  cat("  ", x$model_a, "  ", fmt(x$mean_a), "\n", sep = "")
  cat("  ", x$model_b, "  ", fmt(x$mean_b), "\n", sep = "")
  cat("\n  Difference   ", fmt(x$estimate), "  ",
      fmt_ci(x$conf_low, x$conf_high), p_note(x$p_value), "\n", sep = "")
  cat("  Std. error   ", fmt(x$se), sep = "")
  if (isTRUE(x$clustered)) {
    cat("  (cluster-robust, ", x$n_clusters, " clusters)", sep = "")
  }
  cat("\n")
  cat("  t = ", fmt(x$statistic, 3), " on ", fmt(x$df, 0), " df\n", sep = "")
  cat("\n  Items        ", x$n_items, "\n", sep = "")
  if (is.finite(x$correlation)) {
    cat("  Correlation  ", fmt(x$correlation, 3), "\n", sep = "")
  }
  if (is.finite(x$variance_reduction)) {
    cat("  Pairing cut the variance by ", fmt(x$variance_reduction, 1),
        "x versus an unpaired comparison\n", sep = "")
    cat("  (unpaired SE would be ", fmt(x$se_unpaired), ").\n", sep = "")
  }
  cat("\n")
  invisible(x)
}

#' @export
print.evaluatellm_unpaired <- function(x, ...) {
  cat("\nUnpaired comparison: ", x$model_a, " vs ", x$model_b, "\n\n", sep = "")
  cat("  ", x$model_a, "  ", fmt(x$mean_a), "  (n = ", x$n_a, ")\n", sep = "")
  cat("  ", x$model_b, "  ", fmt(x$mean_b), "  (n = ", x$n_b, ")\n", sep = "")
  cat("\n  Difference   ", fmt(x$estimate), "  ",
      fmt_ci(x$conf_low, x$conf_high), p_note(x$p_value), "\n", sep = "")
  cat("  Std. error   ", fmt(x$se), "\n", sep = "")
  cat("  t = ", fmt(x$statistic, 3), " on ", fmt(x$df, 1), " df (Welch)\n", sep = "")
  cat("\n  If both models saw the same questions, use ev_paired() instead.\n\n")
  invisible(x)
}
