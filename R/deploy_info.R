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
#' usethis::use_standalone("dataheld/crow", "deploy_info")
#' ```
#'
#' Run this again to update the copy.
#'
#' @section Deployment:
#' You must pass on the `DEPLOY_INFO` environment variable yourself.
#' CI variables exist only in the CI job,
#' not on the server that runs the app,
#' and app bundles do not contain `.git`.
#' Without the variable, a deployed app shows `NA`.
#'
#' Create the variable in your deployment job,
#' with no need to install your package:
#'
#' ```sh
#' export DEPLOY_INFO="$(Rscript -e 'source("R/import-standalone-deploy_info.R"); cat(deploy_info_set_env())')"
#' ```
#'
#' Then, how you pass it on depends on the deployment method.
#' For example:
#'
#' - Posit Connect:
#'   `rsconnect::deployApp(envVars = "DEPLOY_INFO")`.
#' - shinyapps.io:
#'   `echo "DEPLOY_INFO=$DEPLOY_INFO" >> .Renviron` in the app directory,
#'   before you deploy.
#' - Containers:
#'   set the variable as `ENV` in the image,
#'   or when you start the container.
#'
#' @section Sources:
#' `DEPLOY_INFO` has the form `<sha>:<ref>`.
#' Without it, the first of these that has a commit provides `sha` and `ref`:
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
#' @section Times:
#' `app_started` is when the R process started,
#' which is shared by all sessions of that process.
#' If you call [shiny::runApp()] in a long-running R session,
#' this is earlier than the start of the app.
#' Servers that run several processes for an app have one time for each.
#'
#' @section Functions:
#' - `deploy_info_navbar_ui()`:
#'   Module UI as a label with a [bslib::popover()].
#'   Pass it to the `title` of [bslib::page_navbar()],
#'   as in `deploy_info_app()`.
#'   This needs Bootstrap 5.
#' - `deploy_info_ui()`:
#'   Module UI as a plain definition list, for any other UI.
#' - `deploy_info_server()`:
#'   Module server.
#'   Returns a reactive of the `deploy_info()` of the session.
#'   Shows the abbreviated commit.
#' - `deploy_info()`:
#'   A list of the full commit `sha`, the `ref`,
#'   `app_started`, and `session_started`, the time of the call.
#'   `sha` and `ref` are `NA` if unknown.
#' - `deploy_info_set_env()`:
#'   Sets `DEPLOY_INFO` in this R process from the sources,
#'   and returns its value invisibly.
#' - `deploy_info_app()`:
#'   Example app.
#'   It is not part of the copy in your package.
#'
#' @param id
#' The module ID.
#' @param ...
#' For `deploy_info_server()`, arguments passed on to `deploy_info()`.
#' For `deploy_info_app()`, arguments passed on to [shiny::shinyApp()].
#' @param env
#' The value of `DEPLOY_INFO`, if you do not want to read the variable.
#' @param tz
#' A timezone from [OlsonNames()] for the times.
#'
#' @usage
#' deploy_info_navbar_ui(id)
#' deploy_info_ui(id)
#' deploy_info_server(id, ...)
#' deploy_info(env = Sys.getenv("DEPLOY_INFO"), tz = "Europe/Berlin")
#' deploy_info_set_env()
#' @aliases deploy_info_navbar_ui deploy_info_ui deploy_info_server
#' @aliases deploy_info_set_env
#' @export deploy_info_navbar_ui
#' @export deploy_info_ui
#' @export deploy_info_server
#' @export deploy_info
#' @export deploy_info_set_env
#' @family deployment
#' @name deploy_info
#' @examplesIf interactive()
#' deploy_info_app()
NULL

#' @rdname deploy_info
#' @export
deploy_info_app <- function(...) {
  shiny::shinyApp(
    ui = bslib::page_navbar(
      title = shiny::tagList("crow", deploy_info_navbar_ui("deploy_info")),
      bslib::nav_panel("Example", "Hover over the ref in the navbar.")
    ),
    server = function(input, output, session) {
      deploy_info_server("deploy_info")
    },
    ...
  )
}
