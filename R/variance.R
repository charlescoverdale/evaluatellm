#' Variance Reduction with a Reference Model
#'
#' Uses a reference model whose score on the full question bank is already known
#' to shrink the standard error of a new model's score, without changing what is
#' being estimated.
#'
#' The idea is the control variate. If a reference model scores `z_i` on the same
#' questions and its population mean `mu_reference` is known, then the questions
#' this evaluation happened to draw can be recognised as easier or harder than
#' average, and the new model's score corrected accordingly:
#'
#' `estimate = mean(y) - theta * (mean(z) - mu_reference)`
#'
#' The variance-minimising coefficient is `theta = cov(y, z) / var(z)`, and the
#' resulting variance is `var(y) * (1 - rho^2) / n`. The adjustment is unbiased
#' for any `theta`, so nothing is assumed beyond `mu_reference` being correct.
#' Because model scores on shared questions correlate strongly, a correlation of
#' 0.8 removes roughly two thirds of the variance, which is equivalent to
#' tripling the number of questions.
#'
#' `mu_reference` has to come from outside this evaluation: a reference model run
#' over the whole bank, or a published score on the full benchmark. Supplying the
#' reference model's mean on these same questions would make the correction
#' identically zero.
#'
#' @inheritParams ev_score
#' @param data An `evalkit_eval` object holding both models, or a data frame
#'   passed to [as_eval()] along with `...`.
#' @param model The model being scored.
#' @param reference The reference model used as the control variate.
#' @param mu_reference The reference model's known mean score on the full
#'   question bank.
#' @param theta Optional fixed coefficient. Default `NULL`, meaning the
#'   variance-minimising value is estimated from the data.
#'
#' @return An `evalkit_vr` object with elements `estimate`, `se`, `conf_low`,
#'   `conf_high`, `estimate_raw`, `se_raw`, `theta`, `correlation`,
#'   `variance_reduction`, `effective_n`, `n_items`, `df`, and `level`.
#'
#' @examples
#' set.seed(8)
#' difficulty <- rnorm(200)
#' d <- data.frame(
#'   q = rep(1:200, 2),
#'   m = rep(c("new", "ref"), each = 200),
#'   correct = rbinom(400, 1,
#'     plogis(c(1.0, 0.6)[rep(1:2, each = 200)] - rep(difficulty, 2)))
#' )
#' e <- as_eval(d, score = correct, item = q, model = m)
#' # The reference model is known to score 0.63 on the full bank
#' ev_variance_reduction(e, model = "new", reference = "ref",
#'                       mu_reference = 0.63)
#'
#' @family comparison
#' @export
ev_variance_reduction <- function(data, model = NULL, reference = NULL,
                                  mu_reference = NULL, theta = NULL,
                                  level = 0.95, ...) {
  x <- as_eval(data, ...)
  level <- validate_level(level)

  if (is.null(reference)) cli_abort("{.arg reference} must name the reference model.")
  if (is.null(mu_reference)) {
    cli_abort(c(
      "{.arg mu_reference} must be supplied.",
      i = "It is the reference model's known score on the full question bank.",
      i = "Without an external value the correction is identically zero."
    ))
  }
  if (!is.numeric(mu_reference) || length(mu_reference) != 1L ||
      !is.finite(mu_reference)) {
    cli_abort("{.arg mu_reference} must be a single finite number.")
  }

  models <- unique(x$model)
  if (is.null(model)) {
    other <- setdiff(models, reference)
    if (length(other) != 1L) {
      cli_abort(c(
        "{.arg model} must be supplied when the data hold more than two models.",
        i = "Models present: {.val {models}}."
      ))
    }
    model <- other
  }
  if (identical(model, reference)) {
    cli_abort("{.arg model} and {.arg reference} must differ.")
  }

  a <- item_level(one_model(x, model, "model"))
  b <- item_level(one_model(x, reference, "reference"))
  common <- intersect(as.character(a$item), as.character(b$item))
  if (length(common) < 3L) {
    cli_abort("Found {length(common)} item{?s} scored by both models; need at least 3.")
  }
  y <- a$score[match(common, as.character(a$item))]
  z <- b$score[match(common, as.character(b$item))]
  n <- length(y)

  vz <- stats::var(z)
  if (vz <= 0) {
    cli_abort(c(
      "The reference model has zero variance across items.",
      i = "A constant control variate carries no information."
    ))
  }
  th <- if (is.null(theta)) stats::cov(y, z) / vz else theta
  if (!is.numeric(th) || length(th) != 1L || !is.finite(th)) {
    cli_abort("{.arg theta} must be a single finite number.")
  }

  adj <- y - th * z
  est <- mean(adj) + th * mu_reference
  se  <- stats::sd(adj) / sqrt(n)

  est_raw <- mean(y)
  se_raw  <- stats::sd(y) / sqrt(n)
  rho <- stats::cor(y, z)
  vr <- if (se > 0) (se_raw / se)^2 else NA_real_

  df <- n - 1
  tcrit <- crit_value(level, df)

  out <- list(
    estimate           = est,
    se                 = se,
    conf_low           = est - tcrit * se,
    conf_high          = est + tcrit * se,
    estimate_raw       = est_raw,
    se_raw             = se_raw,
    theta              = th,
    theta_estimated    = is.null(theta),
    correlation        = rho,
    mu_reference       = mu_reference,
    mean_reference     = mean(z),
    variance_reduction = vr,
    effective_n        = if (is.finite(vr)) n * vr else NA_real_,
    n_items            = n,
    df                 = df,
    level              = level,
    model              = model,
    reference          = reference
  )
  new_ev_result(out, "evalkit_vr")
}

#' @export
print.evalkit_vr <- function(x, ...) {
  cat("\nControl-variate adjusted score: ", x$model, "\n\n", sep = "")
  cat("  Adjusted     ", fmt(x$estimate), "  ",
      fmt_ci(x$conf_low, x$conf_high), "\n", sep = "")
  cat("  Unadjusted   ", fmt(x$estimate_raw), "  (SE ", fmt(x$se_raw), ")\n", sep = "")
  cat("  Std. error   ", fmt(x$se), "\n", sep = "")
  cat("\n  Reference    ", x$reference, "\n", sep = "")
  cat("    known mean on full bank   ", fmt(x$mu_reference), "\n", sep = "")
  cat("    observed mean here        ", fmt(x$mean_reference), "\n", sep = "")
  cat("    theta                     ", fmt(x$theta, 3),
      if (isTRUE(x$theta_estimated)) " (estimated)" else " (fixed)", "\n", sep = "")
  cat("    correlation               ", fmt(x$correlation, 3), "\n", sep = "")
  if (is.finite(x$variance_reduction)) {
    cat("\n  Variance cut ", fmt(x$variance_reduction, 2), "x. ", x$n_items,
        " items now carry the precision of ", round(x$effective_n), ".\n", sep = "")
  }
  cat("\n")
  invisible(x)
}
