test_that("Cohen's kappa matches a hand-computed value", {
  # 2x2 with 40 / 10 / 15 / 35
  g <- c(rep(1, 50), rep(0, 50))
  j <- c(rep(1, 40), rep(0, 10), rep(1, 15), rep(0, 35))
  r <- ev_judge_agreement(j, g)
  p_o <- 0.75
  p_e <- 0.5 * 0.55 + 0.5 * 0.45
  expect_equal(r$accuracy, p_o)
  expect_equal(r$kappa, (p_o - p_e) / (1 - p_e))
})

test_that("the analytic kappa standard error matches a bootstrap", {
  set.seed(99)
  truth <- rbinom(500, 1, 0.55)
  j <- ifelse(runif(500) < 0.82, truth, 1 - truth)
  r <- ev_judge_agreement(j, truth)
  boot <- replicate(1500, {
    i <- sample(500, 500, TRUE)
    ev_judge_agreement(j[i], truth[i])$kappa
  })
  expect_equal(r$kappa_se, sd(boot), tolerance = 0.1)
})

test_that("a perfect judge gives kappa of one", {
  g <- rbinom(200, 1, 0.5)
  r <- ev_judge_agreement(g, g)
  expect_equal(r$accuracy, 1)
  expect_equal(r$kappa, 1)
  expect_equal(r$bias, 0)
})

test_that("McNemar catches a systematically generous judge", {
  set.seed(12)
  truth <- rbinom(600, 1, 0.5)
  j <- truth
  flip <- which(truth == 0)[1:120]
  j[flip] <- 1
  r <- ev_judge_agreement(j, truth)
  expect_gt(r$bias, 0)
  expect_lt(r$mcnemar_p_value, 0.001)
  expect_equal(unname(r$discordant[["judge_low"]]), 0L)
})

test_that("continuous scores take the continuous path", {
  set.seed(13)
  g <- rbeta(200, 5, 3)
  j <- pmin(1, pmax(0, g + rnorm(200, 0.05, 0.1)))
  r <- ev_judge_agreement(j, g)
  expect_equal(r$type, "continuous")
  expect_true(is.null(r$kappa))
  expect_true(is.finite(r$loa_low))
  expect_gt(r$correlation, 0.8)
})

test_that("ev_judge_debias has the structural properties it claims", {
  set.seed(2026)
  N <- 4000; n_lab <- 250
  truth <- rbinom(N, 1, 0.62)
  jd <- ifelse(runif(N) < 0.87, truth, 1 - truth)
  jd[truth == 0 & runif(N) < 0.15] <- 1
  gold <- rep(NA_real_, N)
  idx <- sample(N, n_lab)
  gold[idx] <- truth[idx]
  r <- ev_judge_debias(jd, gold)
  expect_lt(r$se, r$se_classical)
  expect_gt(r$precision_gain, 1)
  expect_true(r$lambda >= 0 && r$lambda <= 1)
  expect_equal(r$n_labelled, n_lab)
  expect_equal(r$n_unlabelled, N - n_lab)
  expect_equal(r$n_total, N)
})

test_that("ev_judge_debias beats a heavily biased judge", {
  set.seed(303)
  N <- 6000; n_lab <- 600
  truth <- rbinom(N, 1, 0.55)
  jd <- truth
  jd[truth == 0] <- rbinom(sum(truth == 0), 1, 0.45)  # bias of roughly 0.20
  gold <- rep(NA_real_, N)
  idx <- sample(N, n_lab)
  gold[idx] <- truth[idx]
  r <- ev_judge_debias(jd, gold)
  expect_gt(abs(r$judge_bias), 0.1)
  expect_lt(abs(r$estimate - mean(truth)), abs(r$estimate_judge - mean(truth)))
})

test_that("ev_judge_debias is unbiased across replications", {
  skip_on_cran()
  set.seed(404)
  mu <- 0.62
  reps <- t(vapply(seq_len(300), function(i) {
    N <- 3000; n_lab <- 200
    truth <- rbinom(N, 1, mu)
    jd <- ifelse(runif(N) < 0.87, truth, 1 - truth)
    jd[truth == 0 & runif(N) < 0.15] <- 1
    gold <- rep(NA_real_, N)
    idx <- sample(N, n_lab)
    gold[idx] <- truth[idx]
    r <- ev_judge_debias(jd, gold)
    c(r$estimate, r$se, r$conf_low, r$conf_high, r$estimate_judge)
  }, numeric(5)))
  # Debiased estimator is centred on the truth; the judge alone is not
  expect_equal(mean(reps[, 1]), mu, tolerance = 0.01)
  expect_gt(abs(mean(reps[, 5]) - mu), 0.01)
  # Reported standard errors match the realised spread, and intervals cover
  expect_equal(mean(reps[, 2]), sd(reps[, 1]), tolerance = 0.1)
  expect_gt(mean(reps[, 3] <= mu & reps[, 4] >= mu), 0.90)
})

test_that("lambda zero reproduces the human-only estimate", {
  set.seed(14)
  N <- 800
  truth <- rbinom(N, 1, 0.6)
  jd <- ifelse(runif(N) < 0.8, truth, 1 - truth)
  gold <- rep(NA_real_, N); idx <- sample(N, 200); gold[idx] <- truth[idx]
  r <- ev_judge_debias(jd, gold, lambda = 0)
  expect_equal(r$estimate, mean(truth[idx]))
  expect_equal(r$se, sd(truth[idx]) / sqrt(200))
})

test_that("an uninformative judge drives lambda to zero", {
  set.seed(15)
  N <- 3000
  truth <- rbinom(N, 1, 0.6)
  jd <- rbinom(N, 1, 0.5)          # pure noise
  gold <- rep(NA_real_, N); idx <- sample(N, 300); gold[idx] <- truth[idx]
  r <- ev_judge_debias(jd, gold)
  expect_lt(r$lambda, 0.15)
  expect_lte(r$se, r$se_classical * 1.02)
})

test_that("ev_judge_debias validates its inputs", {
  expect_error(ev_judge_debias(1:10, 1:5), "same length")
  expect_error(ev_judge_debias(c(1, NA), c(1, 1)), "no missing values")
  expect_error(ev_judge_debias(rep(1, 10), c(1, rep(NA, 9))), "at least 3")
})

test_that("ev_judge_power falls with judge quality", {
  weak <- ev_judge_power(n_total = 20000, correlation = 0.3, target_se = 0.01)
  strong <- ev_judge_power(n_total = 20000, correlation = 0.9, target_se = 0.01)
  expect_lt(strong$n_labels, weak$n_labels)
  expect_lte(strong$achieved_se, 0.01)
  expect_lt(strong$n_labels, strong$n_labels_without_judge)
})

test_that("ev_judge_power reports an unreachable target", {
  r <- ev_judge_power(n_total = 50, correlation = 0.5, target_se = 1e-5)
  expect_true(is.na(r$n_labels))
  expect_true(is.finite(r$best_possible_se))
})
