#' Show from which source a shiny app was deployed
#'
#' Finds the commit and ref of the running app,
#' and the time at which its session was launched.
#' Use `deploy_info_card_ui()` with [bslib](https://rstudio.github.io/bslib/),
#' `deploy_info_ui()` with any other UI,
#' or `deploy_info()` to render the values yourself.
#'
#' @section Sources:
#' The first of these that has a commit provides `sha` and `ref`:
#'
#' 1. The variables of GitHub Actions (`GITHUB_SHA`,
#'    `GITHUB_HEAD_REF`, `GITHUB_REF_NAME`)
#'    or GitLab CI (`CI_COMMIT_SHA`, `CI_COMMIT_REF_NAME`).
#'    On GitHub pull requests,
#'    `GITHUB_SHA` is the merge commit that the job checked out,
#'    not the last commit of the branch.
#' 1. `git` in the working directory, if the working tree is clean.
#'    Otherwise, the commit does not describe the running code.
#'    An app that runs from a clean tree of another repository
#'    shows the commit of that repository.
#'
#' Otherwise, both are `NA`.
#'
#' @section Deployment:
#' CI variables exist only in the CI job,
#' not on the server that runs the app,
#' and bundles do not contain `.git`.
#' Pass the variables on when you deploy,
#' or a deployed app shows `NA`:
#'
#' - Posit Connect:
#'   `rsconnect::deployApp(envVars = c("GITHUB_SHA", "GITHUB_REF_NAME"))`.
#' - shinyapps.io:
#'   write them to a `.Renviron` file in the app directory before you deploy.
#' - Containers:
#'   set them as `ENV` in the image, or when you start the container.
#'
#' These functions run in the deployed app,
#' so the app must have crow in `Imports`, unlike crow's other helpers.
#' @family deployment
#' @name deploy_info
#' @examplesIf interactive()
#' deploy_info_app()
NULL

#' @describeIn deploy_info Test app
#' @param module_ui
#' The module UI to show: `deploy_info_card_ui` or `deploy_info_ui`.
#' @inheritParams module2app_ui
#' @inheritDotParams module2app
#' @export
deploy_info_app <- function(
  module_ui = deploy_info_card_ui,
  ui_wrapper = bslib::page_fluid,
  ...
) {
  module2app(
    module_ui = module_ui,
    module_server = deploy_info_server,
    ui_wrapper = ui_wrapper,
    ...
  )
}

#' @describeIn deploy_info Module UI as a [bslib::card()]
#' @inheritParams shiny::NS
#' @export
deploy_info_card_ui <- function(id) {
  rlang::check_installed("bslib")
  bslib::card(
    bslib::card_header("Deployment"),
    bslib::card_body(deploy_info_ui(id))
  )
}

#' @describeIn deploy_info Module UI as a plain definition list
#' @inheritParams shiny::NS
#' @export
deploy_info_ui <- function(id) {
  ns <- shiny::NS(id)
  item <- function(label, output) {
    shiny::tagList(
      shiny::tags$dt(class = "col-sm-3", label),
      shiny::tags$dd(class = "col-sm-9", output)
    )
  }
  shiny::tags$dl(
    class = "row mb-0",
    item("Commit", shiny::textOutput(ns("sha"), container = shiny::tags$code)),
    item("Ref", shiny::textOutput(ns("ref"), inline = TRUE)),
    item("Launched", shiny::textOutput(ns("launched"), inline = TRUE))
  )
}

#' @describeIn deploy_info
#' Module server.
#' Returns a reactive of the `deploy_info()` of the session.
#' Shows the abbreviated commit.
#' @param ... Arguments passed on to `deploy_info()`.
#' @inheritParams shiny::moduleServer
#' @export
deploy_info_server <- function(id, ...) {
  info <- deploy_info(...)
  shiny::moduleServer(
    id,
    function(input, output, session) {
      output$sha <- shiny::renderText(substr(info$sha, 1, 7))
      output$ref <- shiny::renderText(info$ref)
      output$launched <- shiny::renderText(
        format(info$launched, usetz = TRUE)
      )
      shiny::reactive(info)
    }
  )
}

#' @describeIn deploy_info
#' A list of the full commit `sha`, the `ref`, and the `launched` time.
#' `sha` and `ref` are `NA` if unknown.
#' @param tz
#' A timezone from [OlsonNames()] for the time.
#' @export
deploy_info <- function(tz = "Europe/Berlin") {
  checkmate::assert_choice(tz, OlsonNames())
  scm <- scm_ci()
  if (is.na(scm$sha)) {
    scm <- scm_git()
  }
  c(scm, list(launched = .POSIXct(Sys.time(), tz = tz)))
}

scm_ci <- function() {
  list(
    sha = first_set_envvar(c("GITHUB_SHA", "CI_COMMIT_SHA")),
    ref = first_set_envvar(
      c("GITHUB_HEAD_REF", "GITHUB_REF_NAME", "CI_COMMIT_REF_NAME")
    )
  )
}

first_set_envvar <- function(names) {
  values <- Sys.getenv(names)
  c(values[nzchar(values)], NA_character_)[[1]]
}

scm_git <- function() {
  unknown <- list(sha = NA_character_, ref = NA_character_)
  if (!nzchar(Sys.which("git"))) {
    return(unknown)
  }
  sha <- git("rev-parse", "HEAD")
  clean <- identical(git("status", "--porcelain"), character())
  if (is.null(sha) || !clean) {
    return(unknown)
  }
  list(sha = sha, ref = c(git("branch", "--show-current"), NA_character_)[[1]])
}

git <- function(...) {
  out <- suppressWarnings(
    system2("git", c(...), stdout = TRUE, stderr = FALSE)
  )
  if (is.null(attr(out, "status"))) out
}
