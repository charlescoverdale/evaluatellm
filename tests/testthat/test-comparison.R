test_that("ev_paired reproduces a paired t-test exactly", {
  set.seed(42)
  a <- rbinom(300, 1, 0.72); b <- rbinom(300, 1, 0.66)
  e <- as_eval(data.frame(q = rep(1:300, 2), m = rep(c("a", "b"), each = 300),
                          s = c(a, b)), score = s, item = q, model = m)
  r <- ev_paired(e, "a", "b")
  tt <- t.test(a, b, paired = TRUE)
  expect_equal(r$estimate, unname(tt$estimate))
  expect_equal(r$se, unname(tt$stderr))
  expect_equal(r$p_value, tt$p.value)
  expect_equal(c(r$conf_low, r$conf_high), as.numeric(tt$conf.int))
})

test_that("ev_unpaired reproduces a Welch t-test exactly", {
  set.seed(43)
  a <- rbinom(300, 1, 0.72); b <- rbinom(300, 1, 0.66)
  e <- as_eval(data.frame(q = 1:600, m = rep(c("a", "b"), each = 300), s = c(a, b)),
               score = s, item = q, model = m)
  r <- ev_unpaired(e, "a", "b")
  tw <- t.test(a, b, var.equal = FALSE)
  expect_equal(r$se, unname(tw$stderr))
  expect_equal(r$df, unname(tw$parameter))
  expect_equal(r$p_value, tw$p.value)
})

test_that("pairing beats not pairing when scores correlate", {
  set.seed(44)
  d <- rnorm(400)
  a <- d + rnorm(400, 0.3, 0.4); b <- d + rnorm(400, 0, 0.4)
  e <- as_eval(data.frame(q = rep(1:400, 2), m = rep(c("a", "b"), each = 400),
                          s = c(a, b)), score = s, item = q, model = m)
  r <- ev_paired(e, "a", "b")
  expect_gt(r$variance_reduction, 1)
  expect_gt(r$correlation, 0.5)
  expect_lt(r$se, r$se_unpaired)
})

test_that("ev_paired drops unmatched items with a warning", {
  set.seed(45)
  d <- data.frame(q = c(1:100, 51:150), m = rep(c("a", "b"), each = 100),
                  s = rbinom(200, 1, 0.6))
  e <- as_eval(d, score = s, item = q, model = m)
  expect_warning(r <- ev_paired(e, "a", "b"), "Dropped")
  expect_equal(r$n_items, 50L)
})

test_that("ev_paired refuses disjoint item sets", {
  d <- data.frame(q = 1:20, m = rep(c("a", "b"), each = 10), s = 1)
  e <- as_eval(d, score = s, item = q, model = m)
  expect_error(ev_paired(e, "a", "b"), "same questions")
})

test_that("comparing a model with itself is an error", {
  e <- as_eval(c(1, 0, 1))
  expect_error(ev_paired(e, "model", "model"), "must differ")
})

test_that("ev_variance_reduction is unbiased and cuts variance", {
  set.seed(46)
  diff <- rnorm(300)
  y <- plogis(1.0 - diff) > runif(300)
  z <- plogis(0.6 - diff) > runif(300)
  e <- as_eval(data.frame(q = rep(1:300, 2), m = rep(c("new", "ref"), each = 300),
                          s = as.numeric(c(y, z))), score = s, item = q, model = m)
  r <- ev_variance_reduction(e, model = "new", reference = "ref",
                             mu_reference = mean(z))
  # With mu_reference equal to the observed reference mean the correction is nil
  expect_equal(r$estimate, r$estimate_raw)
  expect_lt(r$se, r$se_raw)
  expect_gt(r$variance_reduction, 1)
})

test_that("ev_variance_reduction demands an external reference mean", {
  e <- as_eval(data.frame(q = rep(1:10, 2), m = rep(c("a", "b"), each = 10),
                          s = rep(c(1, 0), 10)), score = s, item = q, model = m)
  expect_error(ev_variance_reduction(e, model = "a", reference = "b"),
               "mu_reference")
})

test_that("ev_multi adjusts, pools, and detects heterogeneity", {
  set.seed(47)
  runs <- lapply(1:6, function(i) {
    a <- rbinom(250, 1, 0.72); b <- rbinom(250, 1, 0.68)
    e <- as_eval(data.frame(q = rep(1:250, 2), m = rep(c("a", "b"), each = 250),
                            s = c(a, b)), score = s, item = q, model = m)
    ev_paired(e, "a", "b")
  })
  names(runs) <- paste0("t", 1:6)
  r <- ev_multi(runs)
  expect_equal(r$n_tasks, 6L)
  expect_true(all(r$tasks$p_adjusted >= r$tasks$p_value))
  expect_lt(r$pooled_se, min(r$tasks$se))
  expect_true(all(r$tasks$sim_high - r$tasks$sim_low >=
                    r$tasks$conf_high - r$tasks$conf_low))
})

test_that("ev_multi accepts a plain data frame", {
  d <- data.frame(task = c("a", "b"), estimate = c(0.02, 0.03), se = c(0.01, 0.01))
  r <- ev_multi(d)
  expect_equal(r$n_tasks, 2L)
  expect_true(is.finite(r$pooled))
})

test_that("ev_multi rejects malformed input", {
  expect_error(ev_multi(data.frame(estimate = 1)), "missing column")
  expect_error(ev_multi(list(1, 2)), "ev_paired")
  expect_error(ev_multi(data.frame(estimate = 1, se = 0)), "strictly positive")
})
