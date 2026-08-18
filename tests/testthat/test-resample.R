test_that("ev_resample recovers a known variance decomposition", {
  set.seed(5)
  n <- 400; k <- 6
  p_i <- plogis(rnorm(n, 0.6, 1.0))
  true_between <- var(p_i)
  true_within <- mean(p_i * (1 - p_i))
  d <- data.frame(q = rep(1:n, each = k), draw = rep(1:k, n),
                  s = rbinom(n * k, 1, rep(p_i, each = k)))
  r <- ev_resample(as_eval(d, score = s, item = q, sample = draw))
  expect_equal(r$var_between, true_between, tolerance = 0.15)
  expect_equal(r$var_within, true_within, tolerance = 0.1)
  expect_equal(r$se_floor, sqrt(true_between / n), tolerance = 0.15)
})

test_that("the floor is below the achieved standard error", {
  set.seed(6)
  d <- data.frame(q = rep(1:120, each = 5), draw = rep(1:5, 120),
                  s = rbinom(600, 1, rep(plogis(rnorm(120, 0.5)), each = 5)))
  r <- ev_resample(as_eval(d, score = s, item = q, sample = draw))
  expect_lte(r$se_floor, r$se)
  expect_true(all(diff(r$projection$se[is.finite(r$projection$k)]) <= 0))
  expect_equal(min(r$projection$se), r$se_floor)
})

test_that("ev_resample needs repeated draws", {
  expect_error(ev_resample(as_eval(rbinom(50, 1, 0.5))), "single response")
})

test_that("ev_bootstrap brackets the analytic interval for a mean", {
  set.seed(7)
  s <- rbinom(500, 1, 0.65)
  a <- ev_score(s)
  b <- ev_bootstrap(s, R = 2000, seed = 1)
  expect_equal(a$estimate, b$estimate)
  expect_equal(a$se, b$se, tolerance = 0.1)
})

test_that("ev_bootstrap resamples clusters when they exist", {
  set.seed(8)
  cl <- rep(1:25, each = 8)
  s <- rbinom(200, 1, plogis(rep(rnorm(25, 0, 1.2), each = 8)))
  e <- as_eval(data.frame(q = 1:200, cl = cl, s = s), score = s, item = q, cluster = cl)
  b <- ev_bootstrap(e, R = 1000, seed = 2)
  expect_equal(b$unit, "clusters")
  expect_equal(b$n_units, 25L)
  # cluster bootstrap SE should track the analytic cluster-robust SE
  expect_equal(b$se, ev_cluster(e)$se, tolerance = 0.2)
})

test_that("ev_bootstrap handles non-mean statistics and is reproducible", {
  set.seed(9)
  s <- rbeta(300, 6, 3)
  a <- ev_bootstrap(s, statistic = median, R = 500, seed = 3)
  b <- ev_bootstrap(s, statistic = median, R = 500, seed = 3)
  expect_equal(a$conf_low, b$conf_low)
  expect_equal(a$estimate, median(s))
})
