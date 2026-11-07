#' Show from which source a shiny app was deployed
#'
#' A module that shows the branch of the running app in the navbar,
#' where pkgdown websites show the version.
#' If you hover over the branch,
#' a popover shows the commit
#' and the times at which the app and the session started.
#'
#' Do not depend on crow to use this:
#' it would bring all of crow's dependencies into your deployed app.
#' Instead, copy the module into your package,
#' which then needs shiny and bslib:
#'
#' ```r
#' usethis::use_standalone("dataheld/crow", "show_deployment")
#' ```
#'
#' Run this again to update the copy.
#'
#' @section Deployment:
#' You must pass on the `DEPLOYMENT_SOURCE` environment variable yourself.
#' CI variables exist only in the CI job,
#' not on the server that runs the app,
#' and app bundles do not contain `.git`.
#' Without the variable, a deployed app shows `NA`.
#'
#' Create the variable in your deployment job,
#' with no need to install your package:
#'
#' ```sh
#' export DEPLOYMENT_SOURCE="$(Rscript -e 'source("R/import-standalone-show_deployment.R"); cat(set_deployment_envvar())')"
#' ```
#'
#' @section Sources:
#' `DEPLOYMENT_SOURCE` has the form `<sha>:<ref>`.
#' Without it, the first of these that has a commit provides `sha` and `ref`:
#'
#' 1. The variables of GitHub Actions (`GITHUB_SHA`,
#'    `GITHUB_HEAD_REF`, `GITHUB_REF_NAME`)
#'    or GitLab CI/CD (`CI_COMMIT_SHA`,
#'    `CI_MERGE_REQUEST_SOURCE_BRANCH_NAME`, `CI_COMMIT_REF_NAME`).
#'    On pull requests and merged results pipelines,
#'    the commit is the merge commit that the job checked out,
#'    not the last commit of the branch.
#' 1. `git` in the working directory, if the working tree is clean.
#'    Otherwise, the commit does not describe the running code.
#'    An app that runs from a clean tree of another repository
#'    shows the commit of that repository.
#'
#' Otherwise, both are `NA`.
#'
#' @section Times:
#' `app_started` is when the R process started,
#' which is shared by all sessions of that process.
#' If you call [shiny::runApp()] in a long-running R session,
#' this is earlier than the start of the app.
#' Servers that run several processes for an app have one time for each.
#'
#' @section Functions:
#' - `show_deployment_navbar_ui()`:
#'   Module UI as a label with a [bslib::popover()].
#'   Pass it to the `title` of [bslib::page_navbar()],
#'   as in `show_deployment_app()`.
#'   This needs Bootstrap 5.
#' - `show_deployment_ui()`:
#'   Module UI as a plain definition list, for any other UI.
#' - `show_deployment_server()`:
#'   Module server.
#'   Returns a reactive of the `get_deployment()` of the session.
#'   Shows the abbreviated commit.
#' - `get_deployment()`:
#'   A list of the full commit `sha`, the `ref`,
#'   `app_started`, and `session_started`, the time of the call.
#'   `sha` and `ref` are `NA` if unknown.
#' - `set_deployment_envvar()`:
#'   Sets `DEPLOYMENT_SOURCE` in this R process from the sources,
#'   and returns its value invisibly.
#' - `show_deployment_app()`:
#'   Example app.
#'   It is not part of the copy in your package.
#'
#' @param id
#' The module ID.
#' @param ...
#' For `show_deployment_server()`, arguments passed on to `get_deployment()`.
#' For `show_deployment_app()`, arguments passed on to [shiny::shinyApp()].
#' @param env
#' The value of `DEPLOYMENT_SOURCE`, if you do not want to read the variable.
#' @param tz
#' A timezone from [OlsonNames()] for the times.
#'
#' @usage
#' show_deployment_navbar_ui(id)
#' show_deployment_ui(id)
#' show_deployment_server(id, ...)
#' get_deployment(env = Sys.getenv("DEPLOYMENT_SOURCE"), tz = "Europe/Berlin")
#' set_deployment_envvar()
#' @aliases show_deployment_navbar_ui show_deployment_ui
#' @aliases show_deployment_server get_deployment set_deployment_envvar
#' @export show_deployment_navbar_ui
#' @export show_deployment_ui
#' @export show_deployment_server
#' @export get_deployment
#' @export set_deployment_envvar
#' @family deployment
#' @name show_deployment
#' @examplesIf interactive()
#' show_deployment_app()
NULL

#' @rdname show_deployment
#' @export
show_deployment_app <- function(...) {
  shiny::shinyApp(
    ui = bslib::page_navbar(
      title = shiny::tagList(
        "crow",
        show_deployment_navbar_ui("show_deployment")
      ),
      bslib::nav_panel("Example", "Hover over the ref in the navbar.")
    ),
    server = function(input, output, session) {
      show_deployment_server("show_deployment")
    },
    ...
  )
}
