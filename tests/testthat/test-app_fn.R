test_that("app_fn defers app code to the calling package's namespace", {
  fn <- app_fn(counter_button_app())
  expect_identical(environment(fn), asNamespace("crow"))
  expect_identical(body(fn), quote(counter_button_app()))
  expect_s3_class(fn(), "shiny.appobj")
})
test_that("app_fn needs a package", {
  expect_error(app_fn(1, package = NULL))
})
