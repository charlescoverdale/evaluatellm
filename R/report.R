#' Collect Results into a Table
#'
#' Flattens one or more `evalkit` results into a plain data frame with a common
#' set of columns, ready for a paper table or a plot.
#'
#' @param ... One or more `evalkit` result objects, or a single list of them.
#'   Names, where given, become the `label` column.
#'
#' @return A data frame with columns `label`, `term`, `estimate`, `se`,
#'   `conf_low`, `conf_high`, `p_value`, and `n`.
#'
#' @examples
#' set.seed(14)
#' d <- data.frame(
#'   q = rep(1:300, 2),
#'   m = rep(c("new", "old"), each = 300),
#'   correct = rbinom(600, 1, rep(c(0.74, 0.68), each = 300))
#' )
#' e <- as_eval(d, score = correct, item = q, model = m)
#' ev_table(
#'   new = ev_score(e, model = "new"),
#'   old = ev_score(e, model = "old"),
#'   gain = ev_paired(e, model_a = "new", model_b = "old")
#' )
#'
#' @family reporting
#' @export
ev_table <- function(...) {
  dots <- list(...)
  if (length(dots) == 1L && is.list(dots[[1L]]) && !inherits(dots[[1L]], "ev_result")) {
    dots <- dots[[1L]]
  }
  if (!length(dots)) cli_abort("Supply at least one result.")

  nms <- names(dots)
  if (is.null(nms)) nms <- rep("", length(dots))

  rows <- lapply(seq_along(dots), function(i) {
    z <- dots[[i]]
    if (!inherits(z, "ev_result")) {
      cli_abort("Element {i} is not an {.pkg evalkit} result.")
    }
    lab <- if (nzchar(nms[i])) nms[i] else default_label(z, i)
    one_row(z, lab)
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

default_label <- function(z, i) {
  if (!is.null(z$model_a) && !is.null(z$model_b)) {
    return(paste0(z$model_a, " - ", z$model_b))
  }
  if (!is.null(z$model) && length(z$model) == 1L) return(as.character(z$model))
  paste0("result_", i)
}

one_row <- function(z, label) {
  term <- switch(
    class(z)[1L],
    evalkit_score     = "score",
    evalkit_cluster   = "score",
    evalkit_resample  = "score",
    evalkit_bootstrap = "score",
    evalkit_vr        = "score (adjusted)",
    evalkit_paired    = "difference (paired)",
    evalkit_unpaired  = "difference (unpaired)",
    evalkit_debias    = "score (debiased)",
    class(z)[1L]
  )
  n <- z$n_items %||% z$n_labelled %||% z$n %||% NA_integer_
  data.frame(
    label     = label,
    term      = term,
    estimate  = as.numeric(z$estimate %||% NA_real_),
    se        = as.numeric(z$se %||% NA_real_),
    conf_low  = as.numeric(z$conf_low %||% NA_real_),
    conf_high = as.numeric(z$conf_high %||% NA_real_),
    p_value   = as.numeric(z$p_value %||% NA_real_),
    n         = as.integer(n),
    stringsAsFactors = FALSE
  )
}

#' Plot Results with Error Bars
#'
#' Draws the results as a horizontal interval plot, the format this package
#' exists to make routine. Accepts the same input as [ev_table()], and also
#' plots [ev_rank()] and [ev_multi()] objects directly.
#'
#' @param x An `evalkit` result, a list of them, or a data frame from
#'   [ev_table()].
#' @param ... Further results, or graphical parameters passed to
#'   [graphics::plot()].
#' @param reference Optional vertical reference line, for example `0` for
#'   differences. Default `NULL`, which draws none.
#' @param xlab,main Axis and title labels.
#' @param col Colour for points and intervals.
#'
#' @return The plotted data frame, invisibly.
#'
#' @examples
#' set.seed(15)
#' runs <- lapply(1:5, function(i) {
#'   d <- data.frame(
#'     q = rep(1:200, 2),
#'     m = rep(c("new", "old"), each = 200),
#'     correct = rbinom(400, 1, rep(c(0.72, 0.68), each = 200))
#'   )
#'   ev_paired(as_eval(d, score = correct, item = q, model = m),
#'             model_a = "new", model_b = "old")
#' })
#' names(runs) <- paste0("task ", 1:5)
#' ev_plot(runs, reference = 0)
#'
#' @family reporting
#' @export
ev_plot <- function(x, ..., reference = NULL, xlab = NULL, main = NULL,
                    col = "#1b365d") {
  tab <- if (is.data.frame(x) && all(c("estimate", "conf_low") %in% names(x))) {
    if (is.null(x$label)) x$label <- paste0("row_", seq_len(nrow(x)))
    x
  } else if (inherits(x, "evalkit_rank")) {
    m <- x$models
    data.frame(label = m$model, estimate = m$estimate,
               conf_low = m$conf_low, conf_high = m$conf_high,
               stringsAsFactors = FALSE)
  } else if (inherits(x, "evalkit_multi")) {
    m <- x$tasks
    data.frame(label = m$task, estimate = m$estimate,
               conf_low = m$conf_low, conf_high = m$conf_high,
               stringsAsFactors = FALSE)
  } else if (inherits(x, "evalkit_elo")) {
    m <- x$models
    data.frame(label = m$model, estimate = m$elo,
               conf_low = m$elo_low, conf_high = m$elo_high,
               stringsAsFactors = FALSE)
  } else {
    ev_table(x, ...)
  }

  if (!nrow(tab)) cli_abort("Nothing to plot.")

  k <- nrow(tab)
  ypos <- rev(seq_len(k))
  xr <- range(c(tab$conf_low, tab$conf_high, reference), na.rm = TRUE)
  pad <- diff(xr) * 0.08
  if (!is.finite(pad) || pad == 0) pad <- 0.01

  op <- graphics::par(mar = c(4.5, max(6, max(nchar(tab$label)) * 0.6), 3, 2))
  on.exit(graphics::par(op), add = TRUE)

  plot(NA, xlim = c(xr[1] - pad, xr[2] + pad), ylim = c(0.5, k + 0.5),
       yaxt = "n", xlab = xlab %||% "estimate", ylab = "", main = main,
       bty = "n")
  graphics::axis(2, at = ypos, labels = tab$label, las = 1, tick = FALSE,
                 cex.axis = 0.9)
  graphics::abline(h = ypos, col = grDevices::grey(0.94), lwd = 8)
  if (!is.null(reference)) {
    graphics::abline(v = reference, lty = 2, col = grDevices::grey(0.45))
  }
  graphics::segments(tab$conf_low, ypos, tab$conf_high, ypos, col = col, lwd = 2)
  graphics::points(tab$estimate, ypos, pch = 19, col = col, cex = 1.1)

  invisible(tab)
}
