test_that("drives an app from a factory", {
  driver <- local_app_driver(counter_button_app)
  driver$click(selector = "#test_object-button")
  expect_equal(driver$get_value(export = "res"), 1L)
})
test_that("stops the driver when the calling frame exits", {
  driver <- local({
    local_app_driver(counter_button_app)
  })
  expect_error(driver$get_value(export = "res"))
})
test_that("takes screenshot arguments from app factories and objects", {
  expect_equal(
    app_screenshot_args(counter_button_app),
    get_screenshot_args_attr(counter_button_app())
  )
  expect_equal(
    app_screenshot_args(counter_button_app()),
    get_screenshot_args_attr(counter_button_app())
  )
  expect_equal(app_screenshot_args(examples_app()), rlang::missing_arg())
})
