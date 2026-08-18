test_that("ev_score reproduces t.test exactly", {
  set.seed(42)
  s <- rbinom(400, 1, 0.7)
  r <- ev_score(s)
  t <- t.test(s)
  expect_equal(r$estimate, unname(t$estimate))
  expect_equal(r$se, unname(t$stderr))
  expect_equal(c(r$conf_low, r$conf_high), as.numeric(t$conf.int))
  expect_equal(r$df, 399)
})

test_that("ev_score honours the confidence level", {
  set.seed(1)
  s <- rbinom(200, 1, 0.5)
  wide <- ev_score(s, level = 0.99)
  narrow <- ev_score(s, level = 0.90)
  expect_gt(wide$conf_high - wide$conf_low, narrow$conf_high - narrow$conf_low)
})

test_that("ev_score switches to cluster-robust when clusters exist", {
  set.seed(2)
  cl <- rep(1:20, each = 10)
  s <- rbinom(200, 1, plogis(rep(rnorm(20), each = 10)))
  e <- as_eval(data.frame(q = 1:200, cl = cl, s = s), score = s, item = q, cluster = cl)
  a <- ev_score(e)
  b <- ev_score(e, cluster = FALSE)
  expect_true(a$clustered)
  expect_false(b$clustered)
  expect_equal(a$estimate, b$estimate)
  expect_equal(a$df, 19)
})

test_that("ev_score needs at least two items", {
  expect_error(ev_score(c(1)), "at least 2 items")
})

test_that("counting is by item, not by response", {
  set.seed(3)
  d <- data.frame(q = rep(1:50, each = 4), s = rbinom(200, 1, 0.6))
  r <- ev_score(as_eval(d, score = s, item = q))
  expect_equal(r$n_items, 50L)
  expect_equal(r$n_responses, 200L)
})
