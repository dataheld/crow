#' Drive a shiny app in tests
#'
#' Creates a [`shinytest2::AppDriver`] for `app`,
#' which stops when `.local_envir` exits.
#'
#' To make shinytest2 run the working tree of your package,
#' instead of an outdated installed version,
#' pass a function as `app` (see [shinytest2_app_fn()]).
#'
#' @section Screenshots:
#' The driver makes screenshots independent of timing:
#' it shows the end state of transitions and animations,
#' and hides text carets and scrollbars.
#'
#' Unless you pass `screenshot_args`,
#' screenshots of the testbeds [module2app()] and [module2app_bare()]
#' show only the module UI,
#' with everything it shows outside its own box,
#' such as open dropdown menus,
#' but without what scroll containers hide.
#' The driver measures the module in the browser at each screenshot,
#' so it never calls `app` in the R process of your tests.
#'
#' @param app
#' A function without arguments that returns a shiny app,
#' such as `counter_button_app` or one from [shinytest2_app_fn()].
#' Other values passed to `app_dir` of `shinytest2::AppDriver$new()`
#' also work.
#' @param screenshot_args
#' Passed to `shinytest2::AppDriver$new()`.
#' If you pass it,
#' the driver does not measure testbed modules (see the section below).
#' @param notifications
#' Whether screenshots of testbed modules include notifications
#' (see [shiny::showNotification()]),
#' which shiny shows at the bottom right of the window.
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
  screenshot_args = rlang::missing_arg(),
  ...,
  notifications = FALSE,
  .local_envir = parent.frame()
) {
  driver <- CrowAppDriver$new(
    app,
    screenshot_args = screenshot_args,
    ...,
    notifications = notifications
  )
  withr::defer(driver$stop(), envir = .local_envir)
  driver
}

CrowAppDriver <- R6::R6Class(
  "CrowAppDriver",
  inherit = shinytest2::AppDriver,
  cloneable = FALSE,
  public = list(
    initialize = function(
      app_dir,
      ...,
      screenshot_args = rlang::missing_arg(),
      notifications = FALSE
    ) {
      checkmate::assert_flag(notifications)
      private$crow_measure <- rlang::is_missing(screenshot_args)
      private$crow_notifications <- notifications
      super$initialize(app_dir, ..., screenshot_args = screenshot_args)
      self$run_js(screenshot_js("crowFreeze()"))
    },
    get_screenshot = function(
      file = NULL,
      ...,
      screenshot_args = rlang::missing_arg(),
      delay = rlang::missing_arg(),
      selector = rlang::missing_arg()
    ) {
      self$get_js(screenshot_js("crowSettle()"))
      if (
        private$crow_measure &&
          rlang::is_missing(screenshot_args) &&
          rlang::is_missing(selector)
      ) {
        cliprect <- self$get_js(screenshot_js(sprintf(
          "crowModuleBounds(%s, %s)",
          jsonlite::toJSON(inner_module_id, auto_unbox = TRUE),
          jsonlite::toJSON(private$crow_notifications, auto_unbox = TRUE)
        )))
        if (!is.null(cliprect)) {
          # chromote ignores the selector for a cliprect,
          # but shinytest2 replaces the cliprect without one
          screenshot_args <- list(
            cliprect = unlist(cliprect),
            selector = "html"
          )
        }
      }
      super$get_screenshot(
        file,
        ...,
        screenshot_args = screenshot_args,
        delay = delay,
        selector = selector
      )
    }
  ),
  # prefixed, to not override fields of shinytest2's AppDriver
  private = list(crow_measure = NULL, crow_notifications = NULL)
)

screenshot_js <- function(call) {
  path <- system.file("js", "screenshot.js", package = "crow")
  paste(c(readLines(path, warn = FALSE), call), collapse = "\n")
}
