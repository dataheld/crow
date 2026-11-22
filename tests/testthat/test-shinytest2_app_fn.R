test_that("defers app code to the calling package's namespace", {
  fn <- shinytest2_app_fn(counter_button_app())
  expect_identical(environment(fn), asNamespace("crow"))
  expect_identical(body(fn), quote(counter_button_app()))
  expect_s3_class(fn(), "shiny.appobj")
})
test_that("needs a package", {
  expect_error(shinytest2_app_fn(1, package = NULL))
})
test_that("defaults to the package in the working directory outside packages", {
  withr::local_dir(withr::local_tempdir())
  writeLines("Package: crow", "DESCRIPTION")
  fn <- rlang::eval_bare(quote(shinytest2_app_fn(1)), globalenv())
  expect_identical(environment(fn), asNamespace("crow"))
})
