#' Embed a shiny app in a pkgdown site
#'
#' Shows a deployed shiny app in an iframe
#' that fills the browser window below the navbar.
#' This hides the header and footer of the page,
#' so use it in an article which contains only the app.
#' Works only for HTML output.
#'
#' @param src URL of the shiny app.
#' @return A `div` tag as from [htmltools::tags],
#' with a stylesheet as an [htmltools::htmlDependency()].
#' @examples
#' include_app2("https://example.com")
#' @family documentation
#' @export
include_app2 <- function(src) {
  checkmate::assert_string(src)
  htmltools::div(
    class = "shiny-embed-pkgdown",
    htmltools::tags$iframe(src = src),
    htmltools::htmlDependency(
      name = "crow",
      version = utils::packageVersion("crow"),
      src = "css",
      package = "crow",
      stylesheet = "embed_pkgdown.css"
    )
  )
}
