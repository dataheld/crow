#' Show from which source a shiny app was deployed
#'
#' Shows the branch of the running app.
#' If you hover over the branch,
#' a popover shows the commit
#' and the times at which the app and the session started.
#'
#' @section Functions:
#' - `show_deployment()`:
#'   A label with a [bslib::popover()].
#'   Pass it to the `title` of [bslib::page_navbar()],
#'   as in `show_deployment_app()`.
#'   This needs Bootstrap 5.
#' - `show_deployment_details()`:
#'   The content of the popover, as an HTML description list, for any other UI.
#' - `get_deployment()`:
#'   A list of the full commit `sha`, the `ref`,
#'   `app_started`, and `session_started`, the time of the call.
#'   `sha` and `ref` are `NA` if unknown.
#' - `show_deployment_app()`:
#'   Example app.
#'
#' @section Sources:
#' The first of these provides `sha` and `ref`:
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
#' 1. The `DEPLOYMENT_SOURCE` environment variable,
#'    an arbitrary string that is shown as the `ref`.
#'
#' Otherwise, both are `NA`.
#'
#' @section Deployment:
#' Creating `DEPLOYMENT_SOURCE` on the server is your responsibility,
#' if the running app has neither of the other sources.
#'
#' @section Times:
#' `app_started` is when the R process started.
#' If you call [shiny::runApp()] in a long-running R session,
#' this is earlier than the start of the app.
#' Servers that run several processes for an app have one time for each.
#'
#' `session_started` is when the server rendered the page for the session.
#'
#' @section Use without crow:
#' You can also copy these functions into your package,
#' except for `show_deployment_app()`,
#' so that it does not depend on crow:
#'
#' ```r
#' usethis::use_standalone("dataheld/crow", "show_deployment")
#' ```
#'
#' @param tz
#' The time zone of the times.
#' Defaults to `""`, the current time zone of R.
#' @param ...
#' Arguments passed on to [shiny::shinyApp()].
#'
#' @usage
#' show_deployment(tz = "")
#' show_deployment_details(tz = "")
#' get_deployment(tz = "")
#' @aliases show_deployment_details get_deployment
#' @export show_deployment
#' @export show_deployment_details
#' @export get_deployment
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
      title = shiny::tagList("crow", show_deployment()),
      bslib::nav_panel("Example", "Hover over the ref in the navbar.")
    ),
    server = function(input, output) {},
    ...
  )
}
