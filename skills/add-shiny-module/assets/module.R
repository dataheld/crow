#' MODULE module
#'
#' @name MODULE
NULL

#' @describeIn MODULE Test app
#' @param ... Passed to `crow::module2app()`.
#' @export
MODULE_app <- function(...) {
  crow::module2app(
    module_ui = MODULE_ui,
    module_server = MODULE_server,
    ...
  )
}

#' @describeIn MODULE Module UI
#' @inheritParams shiny::NS
#' @export
MODULE_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::verbatimTextOutput(ns("out"))
  )
}

#' @describeIn MODULE Module Server
#' @export
MODULE_server <- function(id) {
  shiny::moduleServer(
    id,
    function(input, output, session) {
      res <- shiny::reactive(NULL)
      output$out <- shiny::renderPrint(res())
      res
    }
  )
}
