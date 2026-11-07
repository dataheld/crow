# ---
# repo: dataheld/crow
# file: standalone-deploy_info.R
# license: MIT, Copyright (c) 2024 Maximilian Held
# imports: [shiny, bslib]
# ---
#
# Docs: https://crow.maxheld.de/reference/deploy_info.html

deploy_info_navbar_ui <- function(id) {
  ns <- shiny::NS(id)
  bslib::popover(
    shiny::tags$small(
      class = "nav-text text-muted ms-2 me-auto",
      shiny::textOutput(ns("label"), inline = TRUE)
    ),
    deploy_info_ui(id),
    title = "Deployment",
    placement = "bottom",
    options = list(trigger = "hover focus")
  )
}

deploy_info_ui <- function(id) {
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

deploy_info_server <- function(id, ...) {
  info <- deploy_info(...)
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

deploy_info <- function(
  env = Sys.getenv("DEPLOY_INFO"),
  tz = "Europe/Berlin"
) {
  stopifnot(tz %in% OlsonNames())
  scm <- if (nzchar(env)) deploy_info_parse(env) else deploy_info_scm()
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

deploy_info_set_env <- function() {
  value <- paste(deploy_info_scm(), collapse = ":")
  Sys.setenv(DEPLOY_INFO = value)
  invisible(value)
}

deploy_info_parse <- function(env) {
  # Git forbids colons in ref names.
  parts <- strsplit(env, ":", fixed = TRUE)[[1]][1:2]
  parts[parts %in% "NA"] <- NA_character_
  list(sha = parts[[1]], ref = parts[[2]])
}

deploy_info_scm <- function() {
  scm <- list(
    sha = deploy_info_first_set(c("GITHUB_SHA", "CI_COMMIT_SHA")),
    ref = deploy_info_first_set(
      c("GITHUB_HEAD_REF", "GITHUB_REF_NAME", "CI_COMMIT_REF_NAME")
    )
  )
  if (is.na(scm$sha)) deploy_info_git() else scm
}

deploy_info_first_set <- function(names) {
  values <- Sys.getenv(names)
  c(values[nzchar(values)], NA_character_)[[1]]
}

deploy_info_git <- function() {
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
