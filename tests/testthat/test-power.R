test_that("ev_power and ev_mde invert each other", {
  p <- ev_power(delta = 0.02, sd_diff = 0.35)
  m <- ev_mde(n_items = p$n_items, sd_diff = 0.35)
  expect_equal(m$mde, 0.02, tolerance = 1e-3)
})

test_that("the inversion survives clustering", {
  p <- ev_power(delta = 0.02, sd_diff = 0.35, icc = 0.25, cluster_size = 8)
  m <- ev_mde(n_items = p$n_items, sd_diff = 0.35, icc = 0.25, cluster_size = 8)
  expect_equal(m$mde, 0.02, tolerance = 1e-3)
  expect_equal(p$design_effect, 1 + 7 * 0.25)
})

test_that("ev_power tracks stats::power.t.test closely", {
  p <- ev_power(delta = 0.02, sd_diff = 0.35)
  ref <- power.t.test(delta = 0.02, sd = 0.35, power = 0.8, type = "one.sample")
  expect_equal(p$n_items, ceiling(ref$n), tolerance = 3)
})

test_that("clustering raises the required sample size", {
  plain <- ev_power(delta = 0.02, sd_diff = 0.35)
  clust <- ev_power(delta = 0.02, sd_diff = 0.35, icc = 0.3, cluster_size = 10)
  expect_gt(clust$n_items, plain$n_items)
  expect_equal(clust$n_clusters, ceiling(clust$n_items / 10))
})

test_that("binary entry derives the right sd of the difference", {
  p_a <- 0.72; p_b <- 0.70; rho <- 0.7
  va <- p_a * (1 - p_a); vb <- p_b * (1 - p_b)
  expected <- sqrt(va + vb - 2 * rho * sqrt(va * vb))
  r <- ev_power(delta = 0.02, p_a = p_a, p_b = p_b, correlation = rho)
  expect_equal(r$sd_diff, expected)
})

test_that("correlated models need fewer questions", {
  lo <- ev_power(delta = 0.02, p_a = 0.72, p_b = 0.70, correlation = 0)
  hi <- ev_power(delta = 0.02, p_a = 0.72, p_b = 0.70, correlation = 0.8)
  expect_lt(hi$n_items, lo$n_items)
})

test_that("a pilot comparison supplies sd_diff", {
  set.seed(10)
  a <- rbinom(300, 1, 0.72); b <- rbinom(300, 1, 0.66)
  e <- as_eval(data.frame(q = rep(1:300, 2), m = rep(c("a", "b"), each = 300),
                          s = c(a, b)), score = s, item = q, model = m)
  pilot <- ev_paired(e, "a", "b")
  p <- ev_power(delta = 0.02, pilot = pilot)
  expect_equal(p$sd_diff, sd(a - b), tolerance = 1e-8)
  expect_equal(p$sd_source, "pilot comparison")
})

test_that("planning functions validate their arguments", {
  expect_error(ev_power(delta = 0), "non-zero")
  expect_error(ev_power(delta = 0.02), "Cannot determine")
  expect_error(ev_power(delta = 0.02, sd_diff = 0.3, power = 1.2), "between 0 and 1")
  expect_error(ev_mde(n_items = 1, sd_diff = 0.3), "at least 2")
  expect_error(ev_power(delta = 0.02, sd_diff = 0.3, icc = 2), "between 0 and 1")
})
