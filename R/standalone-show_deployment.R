# ---
# repo: dataheld/crow
# file: standalone-show_deployment.R
# license: MIT, Copyright (c) 2024 Maximilian Held
# imports: [shiny, bslib]
# ---
#
# Docs: https://crow.maxheld.de/reference/show_deployment.html

show_deployment_navbar_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::popover(
    shiny::tags$small(
      class = "nav-text text-muted ms-2 me-auto",
      shiny::textOutput(ns("label"), inline = TRUE)
    ),
    show_deployment_ui(id),
    title = "Deployment",
    placement = "bottom",
    options = list(trigger = "hover focus")
  )
}

show_deployment_ui <- function(id) {
  ns <- shiny::NS(id)
  item <- function(label, output) {
    shiny::tagList(
      shiny::tags$dt(label),
      shiny::tags$dd(shiny::textOutput(ns(output), inline = TRUE))
    )
  }
  shiny::tags$dl(
    class = "mb-0",
    item("Commit", "sha"),
    item("Ref", "ref"),
    item("App started", "app_started"),
    item("Session started", "session_started")
  )
}

show_deployment_server <- function(id, ...) {
  info <- get_deployment(...)
  shiny::moduleServer(
    id,
    function(input, output, session) {
      output$label <- shiny::renderText(info$ref)
      output$sha <- shiny::renderText(substr(info$sha, 1, 7))
      output$ref <- shiny::renderText(info$ref)
      output$app_started <- shiny::renderText(
        format(info$app_started, usetz = TRUE)
      )
      output$session_started <- shiny::renderText(
        format(info$session_started, usetz = TRUE)
      )
      shiny::reactive(info)
    }
  )
}

get_deployment <- function(
  env = Sys.getenv("DEPLOYMENT_SOURCE"),
  tz = "Europe/Berlin"
) {
  stopifnot(tz %in% OlsonNames())
  scm <- if (nzchar(env)) {
    parse_deployment_source(env)
  } else {
    detect_deployment_source()
  }
  now <- Sys.time()
  c(
    scm,
    list(
      # R reports the seconds since its process started.
      app_started = .POSIXct(now - proc.time()[["elapsed"]], tz = tz),
      session_started = .POSIXct(now, tz = tz)
    )
  )
}

set_deployment_envvar <- function() {
  value <- paste(detect_deployment_source(), collapse = ":")
  Sys.setenv(DEPLOYMENT_SOURCE = value)
  invisible(value)
}

parse_deployment_source <- function(env) {
  # Git forbids colons in ref names.
  parts <- strsplit(env, ":", fixed = TRUE)[[1]][1:2]
  parts[parts %in% "NA"] <- NA_character_
  list(sha = parts[[1]], ref = parts[[2]])
}

detect_deployment_source <- function() {
  scm <- list(
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
  if (is.na(scm$sha)) read_git_source() else scm
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
