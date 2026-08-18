test_that("ev_rank orders models and bounds ranks", {
  set.seed(16)
  difficulty <- rnorm(300)
  skill <- c(a = 1.2, b = 0.9, c = 0.3, d = -0.4)
  d <- do.call(rbind, lapply(names(skill), function(m) {
    data.frame(q = 1:300, m = m,
               s = rbinom(300, 1, plogis(skill[[m]] - difficulty)))
  }))
  r <- ev_rank(as_eval(d, score = s, item = q, model = m), R = 400, seed = 1)
  expect_equal(r$models$model[1], "a")
  expect_equal(r$models$rank, 1:4)
  expect_true(all(r$models$rank_low <= r$models$rank_high))
  # Ranks use the minimum method, so ties let p_best sum above one.
  expect_gte(sum(r$models$p_best), 1)
  expect_lt(sum(r$models$p_best), 1.2)
})

test_that("indistinguishable models split the top probability", {
  set.seed(17)
  d <- do.call(rbind, lapply(c("a", "b"), function(m) {
    data.frame(q = 1:200, m = m, s = rbinom(200, 1, 0.6))
  }))
  r <- ev_rank(as_eval(d, score = s, item = q, model = m), R = 500, seed = 2)
  expect_lt(max(r$models$p_best), 0.95)
})

test_that("ev_rank needs shared items and several models", {
  d <- data.frame(q = 1:10, m = "a", s = 1)
  expect_error(ev_rank(as_eval(d, score = s, item = q, model = m)), "at least 2 models")
  d2 <- data.frame(q = 1:20, m = rep(c("a", "b"), each = 10), s = 1)
  expect_error(ev_rank(as_eval(d2, score = s, item = q, model = m)),
               "shared question set")
})

test_that("ev_elo recovers known Bradley-Terry strengths", {
  set.seed(21)
  strength <- c(a = 0.9, b = 0.5, c = 0.0, d = -0.6)
  pairs <- t(replicate(6000, sample(names(strength), 2)))
  p <- plogis(strength[pairs[, 1]] - strength[pairs[, 2]])
  d <- data.frame(left = pairs[, 1], right = pairs[, 2],
                  won = rbinom(6000, 1, p))
  r <- ev_elo(d, model_a = left, model_b = right, winner = won)
  m <- r$models[match(names(strength), r$models$model), ]
  centred <- m$strength - m$strength[1]
  expect_equal(centred, unname(strength - strength[["a"]]), tolerance = 0.15)
  expect_equal(r$models$model[1], "a")
  # Centring gives every model a positive standard error, the reference included
  expect_true(all(r$models$se > 0))
  expect_true(all(r$models$elo_low < r$models$elo))
  expect_equal(sum(r$models$strength), 0, tolerance = 1e-8)
})

test_that("ev_elo accepts a winner column naming the model", {
  set.seed(22)
  a <- sample(c("x", "y"), 400, TRUE)
  b <- ifelse(a == "x", "y", "x")
  w <- ifelse(runif(400) < 0.65, "x", "y")
  d <- data.frame(left = a, right = b, winner = w)
  r <- ev_elo(d, model_a = left, model_b = right, winner = winner)
  expect_equal(r$models$model[1], "x")
  expect_equal(r$n_models, 2L)
})

test_that("ties are dropped or split as requested", {
  set.seed(23)
  a <- rep("x", 200); b <- rep("y", 200)
  w <- c(rep(1, 80), rep(0, 60), rep(0.5, 60))
  d <- data.frame(left = a, right = b, won = w)
  drop <- ev_elo(d, model_a = left, model_b = right, winner = won, ties = "drop")
  split <- ev_elo(d, model_a = left, model_b = right, winner = won, ties = "split")
  expect_equal(drop$n_games, 140)
  expect_equal(split$n_games, 200)
  gap <- function(z) diff(range(z$models$strength))
  # Counting ties as half a win pulls the two models closer together
  expect_lt(gap(split), gap(drop))
})

test_that("ev_elo needs enough comparisons", {
  d <- data.frame(left = "a", right = "b", won = 1)
  expect_error(ev_elo(d, model_a = left, model_b = right, winner = won),
               "at least 10")
})
