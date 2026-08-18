test_that("ev_table flattens mixed results", {
  set.seed(18)
  d <- data.frame(q = rep(1:200, 2), m = rep(c("new", "old"), each = 200),
                  s = rbinom(400, 1, 0.7))
  e <- as_eval(d, score = s, item = q, model = m)
  tab <- ev_table(new = ev_score(e, "new"), gain = ev_paired(e, "new", "old"))
  expect_equal(nrow(tab), 2L)
  expect_equal(tab$label, c("new", "gain"))
  expect_true(all(c("estimate", "se", "conf_low", "conf_high") %in% names(tab)))
  expect_true(is.na(tab$p_value[1]))
  expect_false(is.na(tab$p_value[2]))
})

test_that("ev_table labels results when names are absent", {
  e <- as_eval(rbinom(100, 1, 0.6))
  tab <- ev_table(ev_score(e))
  expect_equal(tab$label, "model")
})

test_that("ev_table accepts a list", {
  e <- as_eval(rbinom(100, 1, 0.6))
  tab <- ev_table(list(a = ev_score(e), b = ev_score(e)))
  expect_equal(nrow(tab), 2L)
})

test_that("ev_table rejects foreign objects", {
  expect_error(ev_table(1), "not an")
  expect_error(ev_table(), "at least one")
})

test_that("ev_plot returns the plotted frame invisibly", {
  set.seed(19)
  e <- as_eval(rbinom(200, 1, 0.65))
  f <- tempfile(fileext = ".png")
  grDevices::png(f)
  out <- ev_plot(ev_score(e), reference = 0.5)
  grDevices::dev.off()
  unlink(f)
  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 1L)
})

test_that("ev_plot handles rank, multi, and elo objects", {
  set.seed(20)
  d <- do.call(rbind, lapply(c("a", "b", "c"), function(m) {
    data.frame(q = 1:150, m = m, s = rbinom(150, 1, 0.6))
  }))
  r <- ev_rank(as_eval(d, score = s, item = q, model = m), R = 200, seed = 1)
  f <- tempfile(fileext = ".png")
  grDevices::png(f)
  o1 <- ev_plot(r)
  o2 <- ev_plot(ev_multi(data.frame(task = c("x", "y"),
                                    estimate = c(0.01, 0.02), se = c(0.01, 0.01))))
  grDevices::dev.off()
  unlink(f)
  expect_equal(nrow(o1), 3L)
  expect_equal(nrow(o2), 2L)
})

test_that("print methods run without error", {
  set.seed(21)
  d <- data.frame(q = rep(1:150, 2), cl = rep(rep(1:30, each = 5), 2),
                  m = rep(c("a", "b"), each = 150), s = rbinom(300, 1, 0.65))
  e <- as_eval(d, score = s, item = q, model = m, cluster = cl)
  expect_output(print(e), "evalkit_eval")
  expect_output(print(ev_score(e, "a")), "Evaluation score")
  expect_output(print(ev_cluster(e, "a")), "Cluster-robust")
  expect_output(print(ev_paired(e, "a", "b")), "Paired comparison")
  expect_output(print(ev_unpaired(e, "a", "b")), "Unpaired")
  expect_output(print(ev_power(delta = 0.02, sd_diff = 0.3)), "Evaluation size")
  expect_output(print(ev_mde(n_items = 500, sd_diff = 0.3)), "Minimum detectable")
  expect_output(print(ev_bootstrap(e, "a", R = 100)), "bootstrap")
  expect_output(print(ev_judge_agreement(rbinom(100, 1, .5), rbinom(100, 1, .5))),
                "Judge agreement")
  expect_output(print(ev_judge_power(n_total = 5000, correlation = 0.7,
                                     target_se = 0.02)), "Human labels")
})
