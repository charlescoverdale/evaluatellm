#' Build an Evaluation Object
#'
#' Wraps evaluation scores in the long-format structure the `ev_*()` functions
#' expect: one row per scored response, identified by item, model, and
#' optionally cluster and sample.
#'
#' Every function in this package treats the *item* as the sampling unit, on the
#' view that an evaluation is a sample of questions drawn from an unseen
#' super-population of questions someone could have written (Miller 2024).
#' Repeated responses to the same item are averaged within the item before
#' inference, so drawing more responses per item never inflates the apparent
#' sample size.
#'
#' @param data A data frame of evaluation results, one row per scored response.
#'   Alternatively a bare numeric or logical vector of scores, in which case
#'   items are numbered sequentially and a single model is assumed.
#' @param score Column holding the score. Numeric, or logical for pass or fail
#'   grading. Given unquoted, or as a string.
#' @param item Column identifying the question. Defaults to `NULL`, meaning row
#'   order, which is correct only when each row is a distinct question.
#' @param model Column identifying the model. Defaults to `NULL`, meaning a
#'   single unnamed model.
#' @param cluster Column identifying groups of items that share structure, for
#'   example several questions asked about one reading passage, or several
#'   paraphrases of one prompt. Supply this whenever it exists: ignoring it
#'   understates standard errors, often severely.
#' @param sample Column identifying repeated draws for the same item and model.
#'   Only needed if the same item and model appear on several rows and you want
#'   [ev_resample()] to decompose the variance.
#'
#' @return An `evaluatellm_eval` object: a data frame with columns `item`, `model`,
#'   `score`, and, when supplied, `cluster` and `sample`.
#'
#' @references
#' Miller, E. (2024). Adding Error Bars to Evals: A Statistical Approach to
#' Language Model Evaluations. \doi{10.48550/arXiv.2411.00640}
#'
#' @examples
#' # A bare vector of pass or fail results
#' set.seed(1)
#' as_eval(rbinom(200, 1, 0.7))
#'
#' # A full evaluation with clustered questions and two models
#' d <- data.frame(
#'   q       = rep(1:100, times = 2),
#'   passage = rep(rep(1:20, each = 5), times = 2),
#'   m       = rep(c("a", "b"), each = 100),
#'   correct = rbinom(200, 1, 0.6)
#' )
#' as_eval(d, score = correct, item = q, model = m, cluster = passage)
#'
#' @family core
#' @export
as_eval <- function(data, score = NULL, item = NULL, model = NULL,
                    cluster = NULL, sample = NULL) {
  if (inherits(data, "evaluatellm_eval")) return(data)

  if (is.numeric(data) || is.logical(data)) {
    s <- validate_scores(data)
    out <- data.frame(
      item  = seq_along(s),
      model = "model",
      score = s,
      stringsAsFactors = FALSE
    )
    return(structure(out, class = c("evaluatellm_eval", "data.frame")))
  }

  if (!is.data.frame(data)) {
    cli_abort("{.arg data} must be a data frame or a numeric vector, not {.cls {class(data)[1]}}.")
  }

  score_nm   <- col_name(substitute(score), "score", data, required = TRUE)
  item_nm    <- col_name(substitute(item), "item", data)
  model_nm   <- col_name(substitute(model), "model", data)
  cluster_nm <- col_name(substitute(cluster), "cluster", data)
  sample_nm  <- col_name(substitute(sample), "sample", data)

  s <- validate_scores(data[[score_nm]], score_nm)

  out <- data.frame(
    item  = if (is.null(item_nm)) seq_len(nrow(data)) else data[[item_nm]],
    model = if (is.null(model_nm)) "model" else as.character(data[[model_nm]]),
    score = s,
    stringsAsFactors = FALSE
  )
  if (!is.null(cluster_nm)) out$cluster <- data[[cluster_nm]]
  if (!is.null(sample_nm))  out$sample  <- data[[sample_nm]]

  if (is.null(item_nm) && anyDuplicated(paste(out$item, out$model))) {
    cli_warn(c(
      "Repeated item and model pairs found but {.arg item} was not supplied.",
      i = "Row order is being used as the item identifier, which is probably wrong."
    ))
  }

  structure(out, class = c("evaluatellm_eval", "data.frame"))
}

# Resolve an unquoted or string column reference against a data frame.
col_name <- function(sub, arg, data, required = FALSE) {
  if (is.null(sub)) {
    if (required) cli_abort("{.arg {arg}} is required.")
    return(NULL)
  }
  nm <- if (is.character(sub)) sub else deparse(sub)
  nm <- gsub('^"|"$', "", nm)
  if (identical(nm, "NULL")) {
    if (required) cli_abort("{.arg {arg}} is required.")
    return(NULL)
  }
  if (!nm %in% names(data)) {
    cli_abort(c(
      "Column {.val {nm}} not found in {.arg data}.",
      i = "Available columns: {.val {names(data)}}."
    ))
  }
  nm
}

# Extract a single model's item-level scores from an eval object.
one_model <- function(x, model = NULL, arg = "model") {
  models <- unique(x$model)
  if (is.null(model)) {
    if (length(models) > 1L) {
      cli_abort(c(
        "{.arg data} holds {length(models)} models but {.arg {arg}} was not supplied.",
        i = "Models present: {.val {models}}."
      ))
    }
    model <- models[1L]
  }
  if (!model %in% models) {
    cli_abort(c(
      "Model {.val {model}} not found.",
      i = "Models present: {.val {models}}."
    ))
  }
  x[x$model == model, , drop = FALSE]
}

# Collapse repeated samples to one row per item, carrying cluster through.
item_level <- function(d) {
  if (!anyDuplicated(d$item)) {
    return(list(
      item    = d$item,
      score   = d$score,
      cluster = if (!is.null(d$cluster)) d$cluster else NULL,
      k       = rep(1L, nrow(d))
    ))
  }
  f <- factor(d$item, levels = unique(d$item))
  cl <- NULL
  if (!is.null(d$cluster)) {
    cl <- tapply(seq_len(nrow(d)), f, function(i) d$cluster[i[1L]])
    cl <- unname(unlist(cl, use.names = FALSE))
  }
  list(
    item    = levels(f),
    score   = as.numeric(tapply(d$score, f, mean)),
    cluster = cl,
    k       = as.integer(tapply(d$score, f, length))
  )
}

#' @export
print.evaluatellm_eval <- function(x, ...) {
  n_item  <- length(unique(x$item))
  n_model <- length(unique(x$model))
  cat("<evaluatellm_eval>\n")
  cat("  rows    ", nrow(x), "\n", sep = "")
  cat("  items   ", n_item, "\n", sep = "")
  cat("  models  ", n_model, " (", paste(utils::head(unique(x$model), 4),
      collapse = ", "),
      if (n_model > 4) ", ..." else "", ")\n", sep = "")
  if (!is.null(x$cluster)) {
    cat("  clusters", length(unique(x$cluster)), "\n", sep = " ")
  }
  k <- nrow(x) / (n_item * n_model)
  if (isTRUE(all.equal(k, round(k))) && k > 1) {
    cat("  samples per item ", round(k), "\n", sep = "")
  }
  invisible(x)
}
