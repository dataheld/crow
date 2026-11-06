source_pef <- function(...) {
  elf::source_pef(..., package = "crow")
}

#' Example shiny apps
#'
#' These are the example apps shipping with shiny as `shiny.appobj`.
#' Also shows screenshot in documentation.
#' @crowExamplesShiny
#' examples_app()
#' @inheritParams shiny::runExample
#' @family screenshot
#' @keywords internal
#' @export
examples_app <- function(example = "01_hello") {
  # library calls and others make noise
  res <- suppressMessages(
    source(fs::path_package("shiny", "examples-shiny", example, "app.R"))
  )
  res$value
}

skip_example_screenshots <- function() {
  testthat::skip(
    message = paste(
      "Setting up example screenshots.",
      "These need not be tested themselves, but are used in other tests."
    )
  )
}
