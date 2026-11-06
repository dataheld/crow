#' Drive a shiny app in tests
#'
#' Creates a [`shinytest2::AppDriver`] for `app`,
#' which screenshots only what the app's `crow_screenshot_args` attribute
#' selects (see [get_screenshot_args_attr()]),
#' such as the module UI of [module2app()].
#' The driver stops when `.local_envir` exits.
#'
#' To make shinytest2 run the working tree of your package,
#' instead of an outdated installed version,
#' pass a function as `app` (see [shinytest2_app_fn()]).
#'
#' @param app
#' A function without arguments that returns a shiny app,
#' such as `counter_button_app` or one from [shinytest2_app_fn()].
#' Other values passed to `app_dir` of `shinytest2::AppDriver$new()`
#' also work.
#' @param screenshot_args
#' Passed to `shinytest2::AppDriver$new()`.
#' @param ...
#' Passed to `shinytest2::AppDriver$new()`.
#' @param .local_envir
#' The environment whose exit stops the driver.
#' @return A [`shinytest2::AppDriver`].
#' @examples
#' \dontrun{
#' test_that("counter counts", {
#'   driver <- local_app_driver(counter_button_app)
#'   driver$click(selector = "#test_object-button")
#'   expect_equal(driver$get_value(export = "res"), 1L)
#' })
#' }
#' @family shinytest2
#' @export
local_app_driver <- function(
  app,
  screenshot_args = app_screenshot_args(app),
  ...,
  .local_envir = parent.frame()
) {
  driver <- shinytest2::AppDriver$new(
    app,
    screenshot_args = screenshot_args,
    ...
  )
  withr::defer(driver$stop(), envir = .local_envir)
  driver
}

app_screenshot_args <- function(app) {
  if (is.function(app)) {
    app <- app()
  }
  get_screenshot_args_attr(app)
}
