#' Defer a shiny app to shinytest2's background process
#'
#' Wraps code that returns a shiny app into a function
#' from your package's namespace,
#' to pass to [`shinytest2::AppDriver`]'s `$new()` method.
#'
#' @details
#' Exported functions which return a `shiny.appobj`
#' (such as those created with [module2app()])
#' can be passed to `shinytest2::AppDriver$new()` as is,
#' e.g. `AppDriver$new(my_app)`.
#' shinytest2 then calls them in its background process
#' after loading your package from source,
#' as described in its
#' [package testing guide](https://rstudio.github.io/shinytest2/articles/use-package.html).
#' Use `app_fn()` when the app needs arguments,
#' or comes from other package code.
#'
#' Do not pass pre-created app objects (`my_app()`),
#' nor functions defined in a test file:
#' both can run code from an outdated, installed version of your package,
#' instead of its working tree.
#'
#' @param code
#' Code returning a shiny app,
#' evaluated in your package's namespace in the background process.
#' @param package
#' Name of your package.
#' Defaults to the package calling `app_fn()`, such as the one under test.
#' @return A function without arguments.
#' @examples
#' \dontrun{
#' shinytest2::AppDriver$new(app_fn(module2app(counter_button_ui)))
#' }
#' @family modules
#' @export
app_fn <- function(code, package = utils::packageName(rlang::caller_env())) {
  checkmate::assert_string(package)
  rlang::new_function(NULL, rlang::enexpr(code), asNamespace(package))
}
