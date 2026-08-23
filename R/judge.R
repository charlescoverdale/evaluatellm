# Wilson score interval for a proportion.
wilson_ci <- function(x, n, level = 0.95) {
  z <- stats::qnorm(1 - (1 - level) / 2)
  p <- x / n
  d <- 1 + z^2 / n
  centre <- (p + z^2 / (2 * n)) / d
  half <- z / d * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))
  c(max(0, centre - half), min(1, centre + half))
}

# Cohen's kappa with the Fleiss, Cohen and Everitt (1969) asymptotic variance.
cohen_kappa <- function(a, b) {
  lev <- sort(unique(c(a, b)))
  tab <- table(factor(a, lev), factor(b, lev))
  N <- sum(tab)
  p <- tab / N
  pi_ <- rowSums(p)   # marginals for rater 1
  p_j <- colSums(p)   # marginals for rater 2

  p_o <- sum(diag(p))
  p_e <- sum(pi_ * p_j)
  if (isTRUE(all.equal(p_e, 1))) {
    return(list(kappa = NA_real_, se = NA_real_, p_o = p_o, p_e = p_e))
  }
  k <- (p_o - p_e) / (1 - p_e)

  m <- length(lev)
  A <- sum(vapply(seq_len(m), function(i) {
    p[i, i] * ((1 - p_e) - (pi_[i] + p_j[i]) * (1 - p_o))^2
  }, numeric(1)))

  B <- 0
  for (i in seq_len(m)) {
    for (j in seq_len(m)) {
      if (i != j) B <- B + p[i, j] * (p_j[i] + pi_[j])^2
    }
  }
  B <- B * (1 - p_o)^2

  C <- (p_o * p_e - 2 * p_e + p_o)^2

  v <- (A + B - C) / (N * (1 - p_e)^4)
  list(kappa = as.numeric(k), se = sqrt(max(v, 0)), p_o = p_o, p_e = p_e)
}

#' Agreement Between a Model Judge and a Human Gold Standard
#'
#' Quantifies how far a model judge can be trusted, by comparing its scores
#' against human labels on the items where both exist. Reports agreement,
#' chance-corrected agreement, and whether the judge is systematically generous
#' or harsh.
#'
#' Raw agreement flatters a judge whenever one label dominates: a judge that
#' passes everything agrees 90 per cent of the time with a gold standard that
#' passes 90 per cent of the time, while carrying no information at all. Cohen's
#' kappa corrects for that and is the number to read.
#'
#' Systematic bias matters more than noise, because noise averages out over items
#' while bias does not. For binary scores the McNemar test asks whether the
#' judge's disagreements run in one direction; a significant result means the
#' judge's mean score is wrong, not merely noisy, and every evaluation graded by
#' it inherits that error. The fix is [ev_judge_debias()], not a better prompt.
#'
#' The measurement type is detected from the data: binary when scores take two
#' values, categorical when they take a few, continuous otherwise.
#'
#' @param judge Numeric or logical vector of judge scores.
#' @param gold Numeric or logical vector of human scores, the same length as
#'   `judge`. Entries may be `NA` where no human label exists; those items are
#'   ignored here.
#' @param level Confidence level. Default `0.95`.
#'
#' @return An `evaluatellm_agreement` object. Always carries `n`, `type`, `bias`,
#'   `bias_conf_low`, `bias_conf_high`, `bias_p_value`, `correlation`,
#'   `mean_judge`, and `mean_gold`. Binary and categorical scores add
#'   `accuracy`, `accuracy_conf_low`, `accuracy_conf_high`, `kappa`, `kappa_se`,
#'   and, for binary, `sensitivity` and `specificity`.
#'
#' @examples
#' set.seed(10)
#' truth <- rbinom(400, 1, 0.6)
#' # A judge that is right 85 per cent of the time and slightly too generous
#' judge <- ifelse(runif(400) < 0.85, truth, 1 - truth)
#' judge[truth == 0 & runif(400) < 0.1] <- 1
#' ev_judge_agreement(judge, truth)
#'
#' @family judge
#' @export
ev_judge_agreement <- function(judge, gold, level = 0.95) {
  level <- validate_level(level)
  if (is.logical(judge)) judge <- as.numeric(judge)
  if (is.logical(gold)) gold <- as.numeric(gold)
  if (!is.numeric(judge) || !is.numeric(gold)) {
    cli_abort("{.arg judge} and {.arg gold} must be numeric or logical.")
  }
  if (length(judge) != length(gold)) {
    cli_abort("{.arg judge} ({length(judge)}) and {.arg gold} ({length(gold)}) must be the same length.")
  }
  ok <- is.finite(judge) & is.finite(gold)
  j <- judge[ok]; g <- gold[ok]
  n <- length(j)
  if (n < 3L) cli_abort("Need at least 3 items scored by both, found {n}.")

  vals <- unique(c(j, g))
  type <- if (length(vals) == 2L) "binary" else
    if (length(vals) <= 10L && all(vals == round(vals))) "categorical" else "continuous"

  d <- j - g
  bias <- mean(d)
  se_bias <- stats::sd(d) / sqrt(n)
  tcrit <- crit_value(level, n - 1)
  tstat <- if (se_bias > 0) bias / se_bias else NA_real_

  out <- list(
    n             = n,
    type          = type,
    mean_judge    = mean(j),
    mean_gold     = mean(g),
    bias          = bias,
    bias_se       = se_bias,
    bias_conf_low = bias - tcrit * se_bias,
    bias_conf_high = bias + tcrit * se_bias,
    bias_p_value  = p_from_t(tstat, n - 1),
    correlation   = if (stats::sd(j) > 0 && stats::sd(g) > 0) stats::cor(j, g) else NA_real_,
    level         = level
  )

  if (type %in% c("binary", "categorical")) {
    agree <- sum(j == g)
    ci <- wilson_ci(agree, n, level)
    kp <- cohen_kappa(g, j)
    out$accuracy <- agree / n
    out$accuracy_conf_low <- ci[1]
    out$accuracy_conf_high <- ci[2]
    out$kappa <- kp$kappa
    out$kappa_se <- kp$se
    if (is.finite(kp$kappa) && is.finite(kp$se) && kp$se > 0) {
      z <- stats::qnorm(1 - (1 - level) / 2)
      out$kappa_conf_low <- kp$kappa - z * kp$se
      out$kappa_conf_high <- kp$kappa + z * kp$se
    }
    if (type == "binary") {
      pos <- max(vals); neg <- min(vals)
      b <- sum(j == pos & g == neg)   # judge says yes, human says no
      c_ <- sum(j == neg & g == pos)  # judge says no, human says yes
      out$sensitivity <- if (sum(g == pos) > 0) sum(j == pos & g == pos) / sum(g == pos) else NA_real_
      out$specificity <- if (sum(g == neg) > 0) sum(j == neg & g == neg) / sum(g == neg) else NA_real_
      out$mcnemar_statistic <- if (b + c_ > 0) (abs(b - c_) - 1)^2 / (b + c_) else NA_real_
      out$mcnemar_p_value <- if (is.finite(out$mcnemar_statistic)) {
        stats::pchisq(out$mcnemar_statistic, 1, lower.tail = FALSE)
      } else NA_real_
      out$discordant <- c(judge_high = b, judge_low = c_)
    }
  } else {
    out$spearman <- suppressWarnings(stats::cor(j, g, method = "spearman"))
    lim <- 1.96 * stats::sd(d)
    out$loa_low <- bias - lim
    out$loa_high <- bias + lim
  }

  new_ev_result(out, "evaluatellm_agreement")
}

#' Debias a Model Judge with a Small Human Sample
#'
#' Combines a large set of judge-scored items with a small set of human-labelled
#' items to estimate the score a full human evaluation would have produced,
#' with valid confidence intervals. This is prediction-powered inference.
#'
#' Grading with a model judge is cheap but biased, and the bias does not shrink
#' as more items are judged. Grading by hand is unbiased but small. The
#' prediction-powered estimator takes the judge's mean over everything and
#' subtracts the judge's measured error on the human-labelled subset:
#'
#' `estimate = lambda * mean(judge, unlabelled) + mean(gold - lambda * judge, labelled)`
#'
#' This is unbiased for any `lambda`, so no assumption about judge quality is
#' being smuggled in. The default tunes `lambda` to minimise variance
#' (Angelopoulos, Bates and Jordan 2023), which guarantees the result is never
#' less precise than ignoring the judge and using the human labels alone. When
#' the judge is uninformative `lambda` goes to zero and the estimator falls back
#' to the human-only mean; when the judge is good, a few hundred human labels can
#' carry the precision of several thousand.
#'
#' The reported `effective_n` is the headline: the number of human labels that
#' would have been needed to reach this precision without the judge.
#'
#' `gold` is expected to be `NA` for items that were not labelled by a human. The
#' labelled items must be a random sample of the evaluated items. If humans were
#' asked to label the cases the judge found hard, this estimator is not valid.
#'
#' @param judge Numeric or logical vector of judge scores for every item.
#' @param gold Numeric or logical vector of human scores, the same length as
#'   `judge`, with `NA` where no human label exists.
#' @param lambda Optional fixed tuning coefficient in `[0, 1]`. Default `NULL`,
#'   meaning the variance-minimising value is estimated. `lambda = 1` gives the
#'   original prediction-powered estimator, `lambda = 0` the human-only mean.
#' @param level Confidence level. Default `0.95`.
#'
#' @return An `evaluatellm_debias` object with elements `estimate`, `se`,
#'   `conf_low`, `conf_high`, `lambda`, `estimate_classical`, `se_classical`,
#'   `estimate_judge`, `judge_bias`, `effective_n`, `precision_gain`,
#'   `n_labelled`, `n_unlabelled`, `correlation`, and `level`.
#'
#' @references
#' Angelopoulos, A. N., Bates, S., Fannjiang, C., Jordan, M. I., and Zrnic, T.
#' (2023). Prediction-powered inference. \emph{Science}.
#' \doi{10.1126/science.adi6000}
#'
#' Angelopoulos, A. N., Bates, S., and Jordan, M. I. (2023). PPI++: Efficient
#' Prediction-Powered Inference. \doi{10.48550/arXiv.2311.01453}
#'
#' @examples
#' set.seed(11)
#' n_total <- 5000
#' truth <- rbinom(n_total, 1, 0.62)
#' # Judge agrees 88 per cent of the time and leans generous
#' judge <- ifelse(runif(n_total) < 0.88, truth, 1 - truth)
#' judge[truth == 0 & runif(n_total) < 0.12] <- 1
#'
#' # Humans labelled a random 250 of them
#' gold <- rep(NA_real_, n_total)
#' idx <- sample(n_total, 250)
#' gold[idx] <- truth[idx]
#'
#' ev_judge_debias(judge, gold)
#'
#' @family judge
#' @export
ev_judge_debias <- function(judge, gold, lambda = NULL, level = 0.95) {
  level <- validate_level(level)
  if (is.logical(judge)) judge <- as.numeric(judge)
  if (is.logical(gold)) gold <- as.numeric(gold)
  if (!is.numeric(judge) || !is.numeric(gold)) {
    cli_abort("{.arg judge} and {.arg gold} must be numeric or logical.")
  }
  if (length(judge) != length(gold)) {
    cli_abort("{.arg judge} ({length(judge)}) and {.arg gold} ({length(gold)}) must be the same length.")
  }
  if (any(!is.finite(judge))) {
    cli_abort("{.arg judge} must be scored for every item, with no missing values.")
  }

  lab <- !is.na(gold) & is.finite(gold)
  n <- sum(lab)
  nu <- sum(!lab)
  if (n < 3L) {
    cli_abort(c(
      "Found {n} human-labelled item{?s}; need at least 3.",
      i = "{.arg gold} should be {.code NA} for unlabelled items and a score for labelled ones."
    ))
  }

  y <- gold[lab]
  fl <- judge[lab]
  fu <- judge[!lab]

  var_y <- stats::var(y)
  se_classical <- sqrt(var_y / n)

  if (nu == 0L) {
    cli_warn(c(
      "Every item is human-labelled, so the judge adds nothing.",
      i = "Returning the human-only mean."
    ))
    lam <- 0
  } else {
    var_f <- stats::var(fl)
    cov_yf <- stats::cov(y, fl)
    if (is.null(lambda)) {
      lam <- if (var_f > 0) cov_yf * nu / (var_f * (n + nu)) else 0
      lam <- min(max(lam, 0), 1)
    } else {
      if (!is.numeric(lambda) || length(lambda) != 1L || !is.finite(lambda)) {
        cli_abort("{.arg lambda} must be a single finite number.")
      }
      lam <- lambda
    }
  }

  mean_fu <- if (nu > 0L) mean(fu) else 0
  est <- lam * mean_fu + mean(y - lam * fl)

  v <- if (nu > 0L) lam^2 * stats::var(fu) / nu else 0
  v <- v + stats::var(y - lam * fl) / n
  se <- sqrt(v)

  z <- stats::qnorm(1 - (1 - level) / 2)
  gain <- if (se > 0) (se_classical / se)^2 else NA_real_

  out <- list(
    estimate           = est,
    se                 = se,
    conf_low           = est - z * se,
    conf_high          = est + z * se,
    lambda             = lam,
    lambda_estimated   = is.null(lambda),
    estimate_classical = mean(y),
    se_classical       = se_classical,
    estimate_judge     = mean(judge),
    judge_bias         = mean(fl) - mean(y),
    effective_n        = if (is.finite(gain)) n * gain else NA_real_,
    precision_gain     = gain,
    n_total            = length(judge),
    n_labelled         = n,
    n_unlabelled       = nu,
    correlation        = if (stats::sd(y) > 0 && stats::sd(fl) > 0) stats::cor(y, fl) else NA_real_,
    level              = level
  )
  new_ev_result(out, "evaluatellm_debias")
}

#' How Many Human Labels a Debiased Evaluation Needs
#'
#' Sizes the human-labelling budget for an evaluation graded by a model judge.
#' Given how many items the judge will score and how well it tracks human
#' labels, returns the number of human labels needed to hit a target precision.
#'
#' This is the question that actually has a budget attached, since human labels
#' are the expensive input. The function evaluates the variance of the tuned
#' prediction-powered estimator across candidate label counts and returns the
#' smallest one that meets the target, alongside the number of labels that
#' would have been needed without a judge.
#'
#' A judge correlated at 0.8 with human labels typically cuts the required
#' labelling budget by around two thirds. Below about 0.4 the judge is barely
#' worth the pipeline.
#'
#' @param n_total Number of items the judge will score.
#' @param correlation Correlation between judge and human scores, from a pilot.
#'   A fitted [ev_judge_debias()] result may be passed instead via `pilot`.
#' @param target_se Target standard error for the final estimate. Supply this or
#'   `target_mde`.
#' @param target_mde Target minimum detectable effect, converted to a standard
#'   error at the given `power` and `alpha`.
#' @param sd_gold Standard deviation of the human scores. Defaults to `0.5`, the
#'   maximum for a binary score, which is conservative.
#' @param sd_judge Standard deviation of the judge scores. Defaults to `sd_gold`.
#' @param pilot Optional [ev_judge_debias()] result to take `correlation`,
#'   `sd_gold` and `sd_judge` from.
#' @param power,alpha Used only when `target_mde` is supplied. Defaults `0.8`
#'   and `0.05`.
#'
#' @return An `evaluatellm_judge_power` object with elements `n_labels`,
#'   `n_labels_without_judge`, `saving`, `achieved_se`, `target_se`,
#'   `correlation`, `lambda`, and `n_total`.
#'
#' @examples
#' # 20,000 judge-scored items, judge correlates 0.8 with humans,
#' # want a standard error of 0.01
#' ev_judge_power(n_total = 20000, correlation = 0.8, target_se = 0.01)
#'
#' # A weaker judge needs far more human labels
#' ev_judge_power(n_total = 20000, correlation = 0.4, target_se = 0.01)
#'
#' @family judge
#' @export
ev_judge_power <- function(n_total, correlation = NULL, target_se = NULL,
                           target_mde = NULL, sd_gold = 0.5, sd_judge = NULL,
                           pilot = NULL, power = 0.8, alpha = 0.05) {
  if (!is.numeric(n_total) || length(n_total) != 1L || n_total < 10) {
    cli_abort("{.arg n_total} must be a single number of at least 10.")
  }
  if (!is.null(pilot)) {
    if (!inherits(pilot, "evaluatellm_debias")) {
      cli_abort("{.arg pilot} must be a result from {.fn ev_judge_debias}.")
    }
    correlation <- correlation %||% pilot$correlation
  }
  if (is.null(correlation) || !is.numeric(correlation) ||
      length(correlation) != 1L || abs(correlation) > 1) {
    cli_abort("{.arg correlation} must be a single number between -1 and 1.")
  }
  if (is.null(target_se) && is.null(target_mde)) {
    cli_abort("Supply one of {.arg target_se} or {.arg target_mde}.")
  }
  if (is.null(target_se)) {
    if (!is.numeric(target_mde) || length(target_mde) != 1L || target_mde <= 0) {
      cli_abort("{.arg target_mde} must be a single positive number.")
    }
    z <- stats::qnorm(1 - alpha / 2) + stats::qnorm(power)
    target_se <- target_mde / z
  }
  if (!is.numeric(target_se) || length(target_se) != 1L || target_se <= 0) {
    cli_abort("{.arg target_se} must be a single positive number.")
  }
  sd_judge <- sd_judge %||% sd_gold
  vy <- sd_gold^2
  vf <- sd_judge^2
  cyf <- correlation * sd_gold * sd_judge

  # Variance of the tuned estimator at a given number of human labels.
  var_at <- function(n) {
    nu <- n_total - n
    if (nu <= 0) return(vy / n)
    lam <- if (vf > 0) cyf * nu / (vf * (n + nu)) else 0
    lam <- min(max(lam, 0), 1)
    v_resid <- vy - 2 * lam * cyf + lam^2 * vf
    lam^2 * vf / nu + v_resid / n
  }

  grid <- seq_len(as.integer(n_total))
  ses <- sqrt(vapply(grid, var_at, numeric(1)))
  hit <- which(ses <= target_se)
  n_lab <- if (length(hit)) grid[hit[1L]] else NA_integer_

  n_plain <- ceiling(vy / target_se^2)
  nu <- if (is.na(n_lab)) NA_real_ else n_total - n_lab
  lam <- if (is.na(n_lab) || nu <= 0) 0 else {
    min(max(cyf * nu / (vf * (n_lab + nu)), 0), 1)
  }

  out <- list(
    n_labels               = n_lab,
    n_labels_without_judge = n_plain,
    saving                 = if (is.na(n_lab)) NA_real_ else 1 - n_lab / n_plain,
    achieved_se            = if (is.na(n_lab)) min(ses) else ses[hit[1L]],
    best_possible_se       = min(ses),
    target_se              = target_se,
    correlation            = correlation,
    lambda                 = lam,
    sd_gold                = sd_gold,
    sd_judge               = sd_judge,
    n_total                = n_total
  )
  new_ev_result(out, "evaluatellm_judge_power")
}

#' @export
print.evaluatellm_agreement <- function(x, ...) {
  cat("\nJudge agreement (", x$type, ", n = ", x$n, ")\n\n", sep = "")
  cat("  Mean judge   ", fmt(x$mean_judge), "\n", sep = "")
  cat("  Mean human   ", fmt(x$mean_gold), "\n", sep = "")
  if (!is.null(x$accuracy)) {
    cat("\n  Agreement    ", fmt(x$accuracy, 3), "  ",
        fmt_ci(x$accuracy_conf_low, x$accuracy_conf_high, 3), "\n", sep = "")
    if (is.finite(x$kappa)) {
      cat("  Kappa        ", fmt(x$kappa, 3), sep = "")
      if (!is.null(x$kappa_conf_low)) {
        cat("  ", fmt_ci(x$kappa_conf_low, x$kappa_conf_high, 3), sep = "")
      }
      cat("\n")
    }
  }
  if (!is.null(x$sensitivity)) {
    cat("  Sensitivity  ", fmt(x$sensitivity, 3), "\n", sep = "")
    cat("  Specificity  ", fmt(x$specificity, 3), "\n", sep = "")
  }
  if (is.finite(x$correlation)) {
    cat("  Correlation  ", fmt(x$correlation, 3), "\n", sep = "")
  }
  if (!is.null(x$spearman) && is.finite(x$spearman)) {
    cat("  Spearman     ", fmt(x$spearman, 3), "\n", sep = "")
  }
  cat("\n  Bias         ", fmt(x$bias), "  ",
      fmt_ci(x$bias_conf_low, x$bias_conf_high), p_note(x$bias_p_value), "\n", sep = "")
  if (!is.null(x$mcnemar_p_value) && is.finite(x$mcnemar_p_value)) {
    cat("  McNemar      chi-sq ", fmt(x$mcnemar_statistic, 2),
        p_note(x$mcnemar_p_value), "\n", sep = "")
    cat("               judge higher on ", x$discordant[["judge_high"]],
        " items, lower on ", x$discordant[["judge_low"]], "\n", sep = "")
  }
  if (!is.null(x$loa_low)) {
    cat("  Limits of agreement  ", fmt_ci(x$loa_low, x$loa_high), "\n", sep = "")
  }
  sig <- !is.na(x$bias_p_value) && x$bias_p_value < (1 - x$level)
  if (sig) {
    cat("\n  The judge is systematically ",
        if (x$bias > 0) "generous" else "harsh",
        ". Every score it grades inherits this.\n", sep = "")
    cat("  Correct it with ev_judge_debias() rather than reprompting.\n")
  }
  cat("\n")
  invisible(x)
}

#' @export
print.evaluatellm_debias <- function(x, ...) {
  cat("\nPrediction-powered evaluation score\n\n")
  cat("  Estimate     ", fmt(x$estimate), "  ",
      fmt_ci(x$conf_low, x$conf_high), "\n", sep = "")
  cat("  Std. error   ", fmt(x$se), "\n", sep = "")
  cat("\n  For comparison:\n")
  cat("    humans only    ", fmt(x$estimate_classical),
      "  (SE ", fmt(x$se_classical), ")\n", sep = "")
  cat("    judge only     ", fmt(x$estimate_judge),
      "  (biased by ", fmt(x$judge_bias), ")\n", sep = "")
  cat("\n  Items        ", x$n_total, " judged, ", x$n_labelled,
      " human-labelled\n", sep = "")
  cat("  Lambda       ", fmt(x$lambda, 3),
      if (isTRUE(x$lambda_estimated)) " (tuned)" else " (fixed)", "\n", sep = "")
  if (is.finite(x$correlation)) {
    cat("  Correlation  ", fmt(x$correlation, 3), "\n", sep = "")
  }
  if (is.finite(x$precision_gain)) {
    cat("\n  Your ", x$n_labelled, " human labels carry the precision of ",
        round(x$effective_n), ".\n", sep = "")
  }
  cat("\n")
  invisible(x)
}

#' @export
print.evaluatellm_judge_power <- function(x, ...) {
  cat("\nHuman labels required\n\n")
  if (is.na(x$n_labels)) {
    cat("  Target standard error ", fmt(x$target_se),
        " is unreachable with ", x$n_total, " items.\n", sep = "")
    cat("  Best possible SE      ", fmt(x$best_possible_se), "\n\n", sep = "")
    return(invisible(x))
  }
  cat("  Human labels     ", x$n_labels, "\n", sep = "")
  cat("  Without a judge  ", x$n_labels_without_judge, "\n", sep = "")
  cat("  Saving           ", format(round(100 * x$saving)), "%\n", sep = "")
  cat("\n  Target SE        ", fmt(x$target_se), "\n", sep = "")
  cat("  Achieved SE      ", fmt(x$achieved_se), "\n", sep = "")
  cat("  Judge-scored     ", x$n_total, "\n", sep = "")
  cat("  Correlation      ", fmt(x$correlation, 2), "\n", sep = "")
  cat("  Lambda           ", fmt(x$lambda, 3), "\n\n", sep = "")
  invisible(x)
}
