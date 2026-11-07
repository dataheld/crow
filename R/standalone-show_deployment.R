# ---
# repo: dataheld/crow
# file: standalone-show_deployment.R
# license: MIT, Copyright (c) 2024 Maximilian Held
# imports: [bslib, htmltools]
# ---
#
# Docs: https://crow.maxheld.de/reference/show_deployment.html

show_deployment <- function(tz = "") {
  bslib::popover(
    htmltools::tags$small(
      class = "nav-text text-muted ms-2 me-auto",
      get_deployment_source()$ref
    ),
    show_deployment_details(tz),
    title = "Deployment",
    placement = "bottom",
    options = list(trigger = "hover focus")
  )
}

show_deployment_details <- function(tz = "") {
  # Shiny renders tag functions on each page load, even in a static UI.
  htmltools::tagFunction(function() {
    info <- get_deployment(tz)
    items <- list(
      Commit = substr(info$sha, 1, 7),
      Ref = info$ref,
      `App started` = format(info$app_started, usetz = TRUE),
      `Session started` = format(info$session_started, usetz = TRUE)
    )
    htmltools::tags$dl(
      class = "mb-0",
      unname(Map(
        function(term, value) {
          htmltools::tagList(
            htmltools::tags$dt(term),
            htmltools::tags$dd(value)
          )
        },
        names(items),
        items
      ))
    )
  })
}

get_deployment <- function(tz = "") {
  now <- Sys.time()
  c(
    get_deployment_source(),
    list(
      # R reports the seconds since its process started.
      app_started = .POSIXct(now - proc.time()[["elapsed"]], tz = tz),
      session_started = .POSIXct(now, tz = tz)
    )
  )
}

get_deployment_source <- function() {
  ci <- read_ci_source()
  if (!is.na(ci$sha)) {
    return(ci)
  }
  git <- read_git_source()
  if (!is.na(git$sha)) {
    return(git)
  }
  list(sha = NA_character_, ref = get_first_envvar("DEPLOYMENT_SOURCE"))
}

read_ci_source <- function() {
  list(
    sha = get_first_envvar(c("GITHUB_SHA", "CI_COMMIT_SHA")),
    ref = get_first_envvar(
      c(
        "GITHUB_HEAD_REF",
        "GITHUB_REF_NAME",
        "CI_MERGE_REQUEST_SOURCE_BRANCH_NAME",
        "CI_COMMIT_REF_NAME"
      )
    )
  )
}

get_first_envvar <- function(names) {
  values <- Sys.getenv(names)
  c(values[nzchar(values)], NA_character_)[[1]]
}

read_git_source <- function() {
  unknown <- list(sha = NA_character_, ref = NA_character_)
  if (!nzchar(Sys.which("git"))) {
    return(unknown)
  }
  git <- function(...) {
    out <- suppressWarnings(
      system2("git", c(...), stdout = TRUE, stderr = FALSE)
    )
    if (is.null(attr(out, "status"))) out
  }
  sha <- git("rev-parse", "HEAD")
  clean <- identical(git("status", "--porcelain"), character())
  if (is.null(sha) || !clean) {
    return(unknown)
  }
  list(sha = sha, ref = c(git("branch", "--show-current"), NA_character_)[[1]])
}
