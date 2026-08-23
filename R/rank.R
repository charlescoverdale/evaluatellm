#' Bootstrap Rank Intervals for a Leaderboard
#'
#' Resamples questions to ask how stable a leaderboard actually is. Returns each
#' model's score, its rank interval, and the probability it is genuinely the best
#' model in the table.
#'
#' Leaderboards are read as though the ordering were a fact, when it is an
#' estimate like any other. Two models separated by half a point on a
#' 400-question evaluation will often swap places on a different 400 questions.
#' The rank interval says which orderings the data actually support, and
#' `p_best` says how much confidence the top position deserves.
#'
#' Clusters are resampled whole where a cluster column exists, matching the
#' dependence structure that [ev_cluster()] handles analytically.
#'
#' @inheritParams ev_bootstrap
#' @param data An `evaluatellm_eval` object holding several models, or a data frame
#'   passed to [as_eval()] along with `...`.
#' @param R Number of bootstrap replicates. Default `2000`.
#' @param higher_better Logical. Whether a larger score means a better model.
#'   Default `TRUE`.
#'
#' @return An `evaluatellm_rank` object with element `models`, a data frame ordered
#'   best first with columns `model`, `estimate`, `se`, `conf_low`, `conf_high`,
#'   `rank`, `rank_low`, `rank_high`, and `p_best`.
#'
#' @examples
#' set.seed(12)
#' difficulty <- rnorm(300)
#' skill <- c(a = 1.0, b = 0.95, c = 0.6, d = 0.2)
#' d <- do.call(rbind, lapply(names(skill), function(m) {
#'   data.frame(q = 1:300, m = m,
#'              correct = rbinom(300, 1, plogis(skill[[m]] - difficulty)))
#' }))
#' ev_rank(as_eval(d, score = correct, item = q, model = m), R = 500, seed = 1)
#'
#' @family leaderboard
#' @export
ev_rank <- function(data, R = 2000, level = 0.95, higher_better = TRUE,
                    seed = NULL, ...) {
  x <- as_eval(data, ...)
  level <- validate_level(level)
  if (!is.numeric(R) || length(R) != 1L || R < 2) {
    cli_abort("{.arg R} must be a single number of at least 2.")
  }
  R <- as.integer(R)
  if (!is.null(seed)) set.seed(seed)

  models <- unique(x$model)
  if (length(models) < 2L) {
    cli_abort("Need at least 2 models to rank, found {length(models)}.")
  }

  # Item by model score matrix over items every model attempted.
  per <- lapply(models, function(m) item_level(one_model(x, m)))
  names(per) <- models
  common <- Reduce(intersect, lapply(per, function(z) as.character(z$item)))
  if (length(common) < 3L) {
    cli_abort(c(
      "Found {length(common)} item{?s} attempted by every model; need at least 3.",
      i = "Ranking requires a shared question set."
    ))
  }
  mat <- vapply(per, function(z) z$score[match(common, as.character(z$item))],
                numeric(length(common)))
  mat <- matrix(mat, nrow = length(common), dimnames = list(NULL, models))

  cl <- per[[1L]]$cluster
  cl <- if (!is.null(cl)) cl[match(common, as.character(per[[1L]]$item))] else NULL

  n <- nrow(mat)
  est <- colMeans(mat)

  if (!is.null(cl)) {
    groups <- split(seq_len(n), cl)
    G <- length(groups)
    draw <- function() unlist(groups[base::sample.int(G, G, replace = TRUE)],
                              use.names = FALSE)
  } else {
    draw <- function() base::sample.int(n, n, replace = TRUE)
  }

  boot <- matrix(NA_real_, nrow = R, ncol = length(models),
                 dimnames = list(NULL, models))
  ranks <- matrix(NA_real_, nrow = R, ncol = length(models),
                  dimnames = list(NULL, models))
  sgn <- if (higher_better) -1 else 1
  for (r in seq_len(R)) {
    idx <- draw()
    m <- colMeans(mat[idx, , drop = FALSE])
    boot[r, ] <- m
    ranks[r, ] <- rank(sgn * m, ties.method = "min")
  }

  a <- (1 - level) / 2
  out <- data.frame(
    model     = models,
    estimate  = as.numeric(est),
    se        = apply(boot, 2, stats::sd),
    conf_low  = apply(boot, 2, stats::quantile, probs = a, names = FALSE),
    conf_high = apply(boot, 2, stats::quantile, probs = 1 - a, names = FALSE),
    rank      = as.integer(rank(sgn * est, ties.method = "min")),
    rank_low  = apply(ranks, 2, stats::quantile, probs = a, names = FALSE),
    rank_high = apply(ranks, 2, stats::quantile, probs = 1 - a, names = FALSE),
    p_best    = colMeans(ranks == 1),
    stringsAsFactors = FALSE
  )
  out <- out[order(out$rank, -out$estimate * (if (higher_better) 1 else -1)), ]
  rownames(out) <- NULL

  new_ev_result(list(
    models  = out,
    R       = R,
    level   = level,
    n_items = n,
    clustered = !is.null(cl),
    higher_better = higher_better
  ), "evaluatellm_rank")
}

#' Bradley-Terry Ratings from Pairwise Preferences
#'
#' Fits a Bradley-Terry model to head-to-head comparison data, the format used
#' by arena-style evaluations where a judge or a human picks a winner between
#' two responses. Returns each model's strength with a standard error, on both
#' the log-odds and the Elo scale.
#'
#' Elo numbers are usually published bare, which hides how little separates
#' adjacent models. Fitting the model properly gives standard errors, so a
#' 15-point gap can be recognised as noise. The fit is a logistic regression of
#' the win indicator on signed model indicators with no intercept, estimated by
#' maximum likelihood, with the first model fixed at zero for identification.
#' Strengths are centred to sum to zero and Elo is the linear rescaling
#' `anchor + (400 / log(10)) * strength`, so `anchor` is the rating of an average
#' model. Every model carries a standard error, obtained by the delta method from
#' the fitted covariance, including the one held out for identification.
#'
#' Ties are dropped by default, since Bradley-Terry has no tie term. Set
#' `ties = "split"` to count each tie as half a win to each side.
#'
#' @param data A data frame of pairwise comparisons.
#' @param model_a,model_b Columns naming the two models in each comparison.
#' @param winner Column giving the outcome. Either the name of the winning
#'   model, or a numeric or logical column that is `1` or `TRUE` when `model_a`
#'   won. Ties are `NA`, `"tie"`, or `0.5`.
#' @param ties How to treat ties, `"drop"` (default) or `"split"`.
#' @param anchor Elo rating of the average model. Strengths are centred, so this
#'   fixes the level of the whole table. Default `1500`.
#' @param level Confidence level. Default `0.95`.
#'
#' @return An `evaluatellm_elo` object with element `models`, a data frame ordered
#'   best first with columns `model`, `strength` (centred), `se`, `elo`,
#'   `elo_low`, `elo_high`, and `n_games`.
#'
#' @references
#' Bradley, R. A. and Terry, M. E. (1952). Rank Analysis of Incomplete Block
#' Designs: I. The Method of Paired Comparisons. \emph{Biometrika}.
#' \doi{10.2307/2334029}
#'
#' @examples
#' set.seed(13)
#' strength <- c(a = 0.9, b = 0.5, c = 0.0, d = -0.6)
#' pairs <- t(replicate(1200, sample(names(strength), 2)))
#' p <- plogis(strength[pairs[, 1]] - strength[pairs[, 2]])
#' d <- data.frame(
#'   left  = pairs[, 1],
#'   right = pairs[, 2],
#'   won   = rbinom(1200, 1, p)
#' )
#' ev_elo(d, model_a = left, model_b = right, winner = won)
#'
#' @family leaderboard
#' @export
ev_elo <- function(data, model_a, model_b, winner, ties = c("drop", "split"),
                   anchor = 1500, level = 0.95) {
  ties <- match.arg(ties)
  level <- validate_level(level)
  if (!is.data.frame(data)) cli_abort("{.arg data} must be a data frame.")

  a_nm <- col_name(substitute(model_a), "model_a", data, required = TRUE)
  b_nm <- col_name(substitute(model_b), "model_b", data, required = TRUE)
  w_nm <- col_name(substitute(winner), "winner", data, required = TRUE)

  a <- as.character(data[[a_nm]])
  b <- as.character(data[[b_nm]])
  w <- data[[w_nm]]

  # Normalise the outcome to 1 (a won), 0 (b won), 0.5 (tie).
  y <- if (is.character(w) || is.factor(w)) {
    wc <- as.character(w)
    ifelse(wc == a, 1, ifelse(wc == b, 0, 0.5))
  } else {
    yy <- as.numeric(w)
    ifelse(is.na(yy), 0.5, yy)
  }
  y[is.na(y)] <- 0.5

  keep <- !is.na(a) & !is.na(b) & a != b
  if (ties == "drop") keep <- keep & y != 0.5
  a <- a[keep]; b <- b[keep]; y <- y[keep]
  if (length(y) < 10L) {
    cli_abort("Need at least 10 usable comparisons, found {length(y)}.")
  }

  models <- sort(unique(c(a, b)))
  if (length(models) < 2L) cli_abort("Need at least 2 models.")

  # Signed design matrix, reference model dropped for identification.
  X <- matrix(0, nrow = length(y), ncol = length(models),
              dimnames = list(NULL, models))
  X[cbind(seq_along(a), match(a, models))] <- 1
  X[cbind(seq_along(b), match(b, models))] <- -1
  Xd <- X[, -1L, drop = FALSE]

  fit <- suppressWarnings(
    stats::glm(y ~ Xd - 1, family = stats::binomial())
  )
  if (!isTRUE(fit$converged)) {
    cli_warn(c(
      "The Bradley-Terry fit did not converge.",
      i = "This usually means some model never won or never lost."
    ))
  }

  # Refit-free identification: the dropped model sits at zero, so build the full
  # coefficient vector and covariance, then centre. Centring by the delta method
  # gives every model a standard error, including the one held out, which a bare
  # reference parameterisation reports as an impossible zero.
  M <- length(models)
  b <- c(0, unname(stats::coef(fit)))
  V <- matrix(0, M, M)
  V[-1L, -1L] <- as.matrix(stats::vcov(fit))
  C <- diag(M) - matrix(1 / M, M, M)
  strength <- as.numeric(C %*% b)
  se_all <- sqrt(pmax(diag(C %*% V %*% t(C)), 0))
  names(strength) <- names(se_all) <- models

  scale <- 400 / log(10)
  z <- stats::qnorm(1 - (1 - level) / 2)
  games <- as.integer(table(factor(c(a, b), levels = models)))

  out <- data.frame(
    model    = models,
    strength = strength,
    se       = se_all,
    elo      = anchor + scale * strength,
    elo_low  = anchor + scale * (strength - z * se_all),
    elo_high = anchor + scale * (strength + z * se_all),
    n_games  = games,
    stringsAsFactors = FALSE
  )
  out <- out[order(-out$strength), ]
  rownames(out) <- NULL

  new_ev_result(list(
    models      = out,
    n_games     = length(y),
    n_models    = length(models),
    reference   = models[1L],
    anchor      = anchor,
    level       = level,
    ties        = ties,
    converged   = isTRUE(fit$converged)
  ), "evaluatellm_elo")
}

#' @export
print.evaluatellm_rank <- function(x, ...) {
  cat("\nLeaderboard with bootstrap rank intervals\n\n")
  m <- x$models
  w <- max(nchar(m$model), 5)
  cat("  ", formatC("model", width = -w), "  score     ",
      format(100 * x$level), "% CI          rank   p(best)\n", sep = "")
  for (i in seq_len(nrow(m))) {
    cat("  ", formatC(m$model[i], width = -w), "  ",
        fmt(m$estimate[i]), "  ",
        formatC(fmt_ci(m$conf_low[i], m$conf_high[i]), width = -18), " ",
        formatC(paste0(m$rank_low[i], "-", m$rank_high[i]), width = 5), "  ",
        formatC(fmt(m$p_best[i], 2), width = 6), "\n", sep = "")
  }
  cat("\n  Items      ", x$n_items, "\n", sep = "")
  cat("  Replicates ", x$R, if (x$clustered) " (clusters resampled)" else "", "\n", sep = "")
  top <- m$p_best[1L]
  if (top < 0.9) {
    cat("\n  The top position is not settled: ", m$model[1L],
        " leads on only ", format(round(100 * top)),
        "% of resamples.\n", sep = "")
  }
  cat("\n")
  invisible(x)
}

#' @export
print.evaluatellm_elo <- function(x, ...) {
  cat("\nBradley-Terry ratings (", x$n_games, " comparisons, ",
      x$n_models, " models)\n\n", sep = "")
  m <- x$models
  w <- max(nchar(m$model), 5)
  cat("  ", formatC("model", width = -w), "   elo      ",
      format(100 * x$level), "% CI           games\n", sep = "")
  for (i in seq_len(nrow(m))) {
    cat("  ", formatC(m$model[i], width = -w), "  ",
        formatC(format(round(m$elo[i])), width = 5), "   ",
        formatC(paste0("[", round(m$elo_low[i]), ", ", round(m$elo_high[i]), "]"),
                width = -16), " ",
        formatC(m$n_games[i], width = 5), "\n", sep = "")
  }
  cat("\n  Centred    average model at ", x$anchor, "\n", sep = "")
  cat("  Ties       ", x$ties, "\n", sep = "")
  if (nrow(m) >= 2) {
    gap <- m$elo[1L] - m$elo[2L]
    pooled <- sqrt(m$se[1L]^2 + m$se[2L]^2) * 400 / log(10)
    if (is.finite(pooled) && pooled > 0 && gap < 1.96 * pooled) {
      cat("\n  The top two are ", round(gap),
          " Elo apart, inside the ", round(1.96 * pooled),
          " point noise band.\n", sep = "")
    }
  }
  cat("\n")
  invisible(x)
}
