test_that("cluster-robust variance matches the sandwich estimator", {
  skip_if_not_installed("sandwich")
  set.seed(7)
  G <- 40; m <- 10
  sc <- rbinom(G * m, 1, plogis(0.5 + rep(rnorm(G), each = m)))
  cl <- rep(1:G, each = m)
  e <- as_eval(data.frame(q = seq_along(sc), cl = cl, s = sc),
               score = s, item = q, cluster = cl)
  r <- ev_cluster(e)
  V <- sandwich::vcovCL(lm(sc ~ 1), cluster = cl, type = "HC0", cadjust = TRUE)
  expect_equal(r$se, sqrt(V[1, 1]))
})

test_that("clustering widens the interval when the ICC is positive", {
  set.seed(8)
  G <- 30; m <- 10
  sc <- rbinom(G * m, 1, plogis(0.4 + rep(rnorm(G, 0, 1.2), each = m)))
  cl <- rep(1:G, each = m)
  e <- as_eval(data.frame(q = seq_along(sc), cl = cl, s = sc),
               score = s, item = q, cluster = cl)
  r <- ev_cluster(e)
  expect_gt(r$se, r$se_naive)
  expect_gt(r$design_effect, 1)
  expect_gt(r$icc, 0)
  expect_equal(r$n_clusters, G)
})

test_that("singleton clusters reproduce the independent standard error", {
  set.seed(9)
  s <- rbinom(100, 1, 0.6)
  e <- as_eval(data.frame(q = 1:100, cl = 1:100, s = s),
               score = s, item = q, cluster = cl)
  r <- ev_cluster(e)
  # With one item per cluster the CR1 correction cancels the (n - 1) divisor,
  # so the cluster-robust standard error is exactly the classical one.
  expect_equal(r$se, r$se_naive)
  expect_equal(r$design_effect, 1)
})

test_that("ev_icc recovers a known intra-cluster correlation", {
  set.seed(10)
  G <- 200; m <- 8
  u <- rnorm(G, 0, 1)
  sc <- rep(u, each = m) + rnorm(G * m, 0, 1)
  cl <- rep(1:G, each = m)
  e <- as_eval(data.frame(q = seq_along(sc), cl = cl, s = sc),
               score = s, item = q, cluster = cl)
  expect_equal(as.numeric(ev_icc(e)), 0.5, tolerance = 0.08)
})

test_that("cluster functions require a cluster column", {
  expect_error(ev_cluster(c(1, 0, 1)), "No cluster column")
  expect_error(ev_icc(c(1, 0, 1)), "No cluster column")
})
