test_that("defers app code to the calling package's namespace", {
  fn <- shinytest2_app_fn(counter_button_app())
  expect_identical(environment(fn), asNamespace("crow"))
  expect_identical(body(fn), quote(counter_button_app()))
  expect_s3_class(fn(), "shiny.appobj")
})
test_that("needs a package", {
  expect_error(shinytest2_app_fn(1, package = NULL))
})
