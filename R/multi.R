#' Multiplicity Adjustment Across a Benchmark Suite
#'
#' Takes the per-task comparisons that make up a benchmark suite and reports
#' them together: multiplicity-adjusted p-values, simultaneous confidence
#' intervals, a pooled effect, and a heterogeneity check on whether the tasks
#' are telling the same story.
#'
#' Running a model against twelve tasks and reporting the two that reached
#' significance is a recipe for false positives: at the five per cent level,
#' better than one task in two will produce at least one spurious win by chance
#' across twelve independent nulls. Adjustment fixes this. Holm controls the
#' family-wise error rate and is the default, appropriate when a single false
#' win would be embarrassing. Benjamini-Hochberg controls the false discovery
#' rate and is more permissive, appropriate for screening many tasks.
#'
#' The pooled estimate is inverse-variance weighted, which is the
#' minimum-variance combination when the tasks estimate a common effect.
#' Cochran's Q and `i_squared` test that assumption: a large `i_squared` means
#' the per-task effects genuinely differ and the pooled number is hiding
#' something, so read the per-task rows instead.
#'
#' @param results A list of objects from [ev_paired()] or [ev_unpaired()],
#'   optionally named by task. Alternatively a data frame with columns
#'   `estimate` and `se`, and optionally `task` and `df`.
#' @param method Multiplicity adjustment passed to [stats::p.adjust()]. One of
#'   `"holm"` (default), `"BH"`, `"bonferroni"`, `"hochberg"`, `"BY"`,
#'   `"hommel"`, or `"none"`.
#' @param level Confidence level for the per-task intervals. Default `0.95`.
#'   Simultaneous intervals use `1 - (1 - level) / k`.
#'
#' @return An `evaluatellm_multi` object with elements `tasks` (a data frame),
#'   `pooled`, `pooled_se`, `pooled_conf_low`, `pooled_conf_high`,
#'   `pooled_p_value`, `q_statistic`, `q_p_value`, `i_squared`, `n_tasks`,
#'   `n_significant`, `method`, and `level`.
#'
#' @examples
#' set.seed(9)
#' # Six tasks, a small true gain on each
#' runs <- lapply(1:6, function(i) {
#'   difficulty <- rnorm(250)
#'   d <- data.frame(
#'     q = rep(1:250, 2),
#'     m = rep(c("new", "old"), each = 250),
#'     correct = rbinom(500, 1,
#'       plogis(c(0.8, 0.65)[rep(1:2, each = 250)] - rep(difficulty, 2)))
#'   )
#'   ev_paired(as_eval(d, score = correct, item = q, model = m),
#'             model_a = "new", model_b = "old")
#' })
#' names(runs) <- paste0("task_", 1:6)
#' ev_multi(runs)
#'
#' @family comparison
#' @export
ev_multi <- function(results, method = "holm", level = 0.95) {
  level <- validate_level(level)
  valid <- c("holm", "BH", "bonferroni", "hochberg", "BY", "hommel", "none",
             "fdr", "hommel")
  if (!method %in% valid) {
    cli_abort("{.arg method} must be one of {.val {unique(valid)}}.")
  }

  tab <- as_effect_table(results)
  k <- nrow(tab)
  if (k < 1L) cli_abort("{.arg results} is empty.")

  tab$p_value <- ifelse(
    is.finite(tab$df),
    mapply(p_from_t, tab$estimate / tab$se, tab$df),
    2 * stats::pnorm(-abs(tab$estimate / tab$se))
  )
  tab$p_adjusted <- stats::p.adjust(tab$p_value, method = method)

  tcrit <- ifelse(is.finite(tab$df), stats::qt(1 - (1 - level) / 2, tab$df),
                  stats::qnorm(1 - (1 - level) / 2))
  tab$conf_low  <- tab$estimate - tcrit * tab$se
  tab$conf_high <- tab$estimate + tcrit * tab$se

  # Simultaneous intervals at the Bonferroni-adjusted level.
  sim_level <- 1 - (1 - level) / k
  scrit <- ifelse(is.finite(tab$df), stats::qt(1 - (1 - sim_level) / 2, tab$df),
                  stats::qnorm(1 - (1 - sim_level) / 2))
  tab$sim_low  <- tab$estimate - scrit * tab$se
  tab$sim_high <- tab$estimate + scrit * tab$se

  # Inverse-variance pooled effect.
  w <- 1 / tab$se^2
  pooled <- sum(w * tab$estimate) / sum(w)
  pooled_se <- sqrt(1 / sum(w))
  z <- pooled / pooled_se
  zcrit <- stats::qnorm(1 - (1 - level) / 2)

  # Cochran's Q and I-squared.
  q <- sum(w * (tab$estimate - pooled)^2)
  qdf <- k - 1
  q_p <- if (qdf > 0) stats::pchisq(q, qdf, lower.tail = FALSE) else NA_real_
  i2 <- if (qdf > 0 && q > 0) max(0, (q - qdf) / q) else 0

  out <- list(
    tasks            = tab,
    pooled           = pooled,
    pooled_se        = pooled_se,
    pooled_conf_low  = pooled - zcrit * pooled_se,
    pooled_conf_high = pooled + zcrit * pooled_se,
    pooled_p_value   = 2 * stats::pnorm(-abs(z)),
    q_statistic      = q,
    q_df             = qdf,
    q_p_value        = q_p,
    i_squared        = i2,
    n_tasks          = k,
    n_significant    = sum(tab$p_adjusted < 1 - level, na.rm = TRUE),
    n_nominal        = sum(tab$p_value < 1 - level, na.rm = TRUE),
    method           = method,
    level            = level
  )
  new_ev_result(out, "evaluatellm_multi")
}

# Coerce a list of comparison objects, or a data frame, to a common table.
as_effect_table <- function(results) {
  if (is.data.frame(results)) {
    need <- c("estimate", "se")
    miss <- setdiff(need, names(results))
    if (length(miss)) cli_abort("{.arg results} is missing column{?s} {.val {miss}}.")
    tab <- data.frame(
      task     = if (!is.null(results$task)) as.character(results$task)
                 else paste0("task_", seq_len(nrow(results))),
      estimate = as.numeric(results$estimate),
      se       = as.numeric(results$se),
      df       = if (!is.null(results$df)) as.numeric(results$df) else Inf,
      stringsAsFactors = FALSE
    )
  } else if (is.list(results)) {
    ok <- vapply(results, function(z) {
      inherits(z, c("evaluatellm_paired", "evaluatellm_unpaired")) ||
        (is.list(z) && all(c("estimate", "se") %in% names(z)))
    }, logical(1))
    if (!all(ok)) {
      bad <- which(!ok)
      cli_abort(c(
        "Every element of {.arg results} must come from {.fn ev_paired} or {.fn ev_unpaired}.",
        i = "{cli::qty(length(bad))}Element{?s} {.val {bad}} did not."
      ))
    }
    nms <- names(results)
    if (is.null(nms) || any(nms == "")) nms <- paste0("task_", seq_along(results))
    tab <- data.frame(
      task     = nms,
      estimate = vapply(results, function(z) as.numeric(z$estimate), numeric(1)),
      se       = vapply(results, function(z) as.numeric(z$se), numeric(1)),
      df       = vapply(results, function(z) {
                   d <- z$df; if (is.null(d) || !is.finite(d)) Inf else as.numeric(d)
                 }, numeric(1)),
      stringsAsFactors = FALSE
    )
  } else {
    cli_abort("{.arg results} must be a list of comparisons or a data frame.")
  }

  if (any(!is.finite(tab$estimate)) || any(!is.finite(tab$se)) || any(tab$se <= 0)) {
    cli_abort("All estimates must be finite and all standard errors strictly positive.")
  }
  rownames(tab) <- NULL
  tab
}

#' @export
print.evaluatellm_multi <- function(x, ...) {
  alpha <- 1 - x$level
  cat("\nBenchmark suite: ", x$n_tasks, " tasks\n\n", sep = "")
  t <- x$tasks
  w <- max(nchar(t$task), 4)
  cat("  ", formatC("task", width = -w), "  estimate       ",
      format(100 * x$level), "% CI        p     p.adj\n", sep = "")
  for (i in seq_len(nrow(t))) {
    cat("  ", formatC(t$task[i], width = -w), "  ",
        formatC(fmt(t$estimate[i]), width = 8), "  ",
        formatC(fmt_ci(t$conf_low[i], t$conf_high[i]), width = -18), " ",
        formatC(formatC(t$p_value[i], digits = 3, format = "f"), width = 6), " ",
        formatC(formatC(t$p_adjusted[i], digits = 3, format = "f"), width = 6),
        if (t$p_adjusted[i] < alpha) "  *" else "",
        "\n", sep = "")
  }
  cat("\n  Adjustment    ", x$method, " (", x$n_significant, " of ", x$n_tasks,
      " survive, ", x$n_nominal, " nominal)\n", sep = "")
  cat("\n  Pooled        ", fmt(x$pooled), "  ",
      fmt_ci(x$pooled_conf_low, x$pooled_conf_high),
      p_note(x$pooled_p_value), "\n", sep = "")
  cat("  Heterogeneity Q = ", fmt(x$q_statistic, 2), " on ", x$q_df, " df",
      p_note(x$q_p_value), ", I2 = ",
      format(round(100 * x$i_squared)), "%\n", sep = "")
  if (x$i_squared > 0.5) {
    cat("\n  Task effects differ materially. Read the rows, not the pooled number.\n")
  }
  cat("\n")
  invisible(x)
}
