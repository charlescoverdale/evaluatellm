test_that("as_eval accepts a bare vector", {
  e <- as_eval(c(1, 0, 1, 1))
  expect_s3_class(e, "evalkit_eval")
  expect_equal(nrow(e), 4L)
  expect_equal(unique(e$model), "model")
})

test_that("as_eval accepts logical scores", {
  e <- as_eval(c(TRUE, FALSE, TRUE))
  expect_equal(e$score, c(1, 0, 1))
})

test_that("as_eval resolves unquoted and quoted columns alike", {
  d <- data.frame(q = 1:4, m = "a", s = c(1, 0, 1, 1))
  a <- as_eval(d, score = s, item = q, model = m)
  b <- as_eval(d, score = "s", item = "q", model = "m")
  expect_equal(a$score, b$score)
  expect_equal(a$item, b$item)
})

test_that("as_eval is idempotent", {
  e <- as_eval(c(1, 0, 1))
  expect_identical(as_eval(e), e)
})

test_that("as_eval rejects bad input", {
  expect_error(as_eval(data.frame(x = 1), score = nope), "not found")
  expect_error(as_eval(c(1, NA, 1)), "missing or non-finite")
  expect_error(as_eval(letters), "must be a data frame")
})

test_that("repeated samples collapse to item means", {
  d <- data.frame(q = c(1, 1, 2, 2), s = c(1, 0, 1, 1))
  e <- as_eval(d, score = s, item = q)
  expect_equal(ev_score(e)$estimate, mean(c(0.5, 1)))
})

test_that("one_model errors informatively", {
  d <- data.frame(q = rep(1:3, 2), m = rep(c("a", "b"), each = 3), s = 1)
  e <- as_eval(d, score = s, item = q, model = m)
  expect_error(ev_score(e), "was not supplied")
  expect_error(ev_score(e, model = "zzz"), "not found")
})
