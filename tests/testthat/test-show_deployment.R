local_envvars <- function(..., .local_envir = parent.frame()) {
  unset <- c(
    GITHUB_SHA = NA,
    GITHUB_HEAD_REF = NA,
    GITHUB_REF_NAME = NA,
    CI_COMMIT_SHA = NA,
    CI_MERGE_REQUEST_SOURCE_BRANCH_NAME = NA,
    CI_COMMIT_REF_NAME = NA,
    DEPLOYMENT_SOURCE = NA
  )
  set <- c(...)
  unset[names(set)] <- set
  withr::local_envvar(unset, .local_envir = .local_envir)
}

local_sources <- function(..., .local_envir = parent.frame()) {
  local_envvars(..., .local_envir = .local_envir)
  withr::local_dir(
    withr::local_tempdir(.local_envir = .local_envir),
    .local_envir = .local_envir
  )
}

git_test <- function(...) {
  system2(
    "git",
    c("-c", "user.name=crow", "-c", "user.email=crow@example.com", ...),
    stdout = TRUE,
    stderr = TRUE
  )
}

init_git_repo <- function() {
  skip_if(Sys.which("git") == "")
  git_test("init", "--initial-branch=feature")
  writeLines("a", "file")
  git_test("add", "file")
  git_test("commit", "--no-gpg-sign", "--message=init")
  git_test("rev-parse", "HEAD")
}

source_of <- function() get_deployment()[c("sha", "ref")]
unknown <- list(sha = NA_character_, ref = NA_character_)

test_that("get_deployment reads GitHub Actions variables", {
  local_sources(GITHUB_SHA = "abc", GITHUB_REF_NAME = "main")
  expect_equal(source_of(), list(sha = "abc", ref = "main"))
})

test_that("get_deployment prefers the source branch of pull requests", {
  local_sources(
    GITHUB_SHA = "abc",
    GITHUB_HEAD_REF = "feature",
    GITHUB_REF_NAME = "99/merge"
  )
  expect_equal(get_deployment()$ref, "feature")
})

test_that("get_deployment reads GitLab CI/CD variables", {
  local_sources(CI_COMMIT_SHA = "abc", CI_COMMIT_REF_NAME = "main")
  expect_equal(source_of(), list(sha = "abc", ref = "main"))
})

test_that("get_deployment prefers the source branch of merge requests", {
  local_sources(
    CI_COMMIT_SHA = "abc",
    CI_MERGE_REQUEST_SOURCE_BRANCH_NAME = "feature",
    CI_COMMIT_REF_NAME = "other"
  )
  expect_equal(get_deployment()$ref, "feature")
})

test_that("get_deployment prefers CI variables to git, without mixing them", {
  local_sources(GITHUB_SHA = "abc")
  init_git_repo()
  expect_equal(source_of(), list(sha = "abc", ref = NA_character_))
})

test_that("get_deployment reads a clean git working tree", {
  local_sources()
  sha <- init_git_repo()
  expect_equal(source_of(), list(sha = sha, ref = "feature"))
})

test_that("get_deployment has no ref on a detached git HEAD", {
  local_sources()
  sha <- init_git_repo()
  git_test("checkout", "--detach")
  expect_equal(source_of(), list(sha = sha, ref = NA_character_))
})

test_that("get_deployment ignores git working trees that are not clean", {
  local_sources()
  init_git_repo()
  writeLines("b", "file")
  expect_equal(source_of(), unknown)
  git_test("checkout", "file")
  writeLines("new", "untracked")
  expect_equal(source_of(), unknown)
})

test_that("get_deployment prefers clean git to the variable", {
  local_sources(DEPLOYMENT_SOURCE = "v1.2 from my script")
  sha <- init_git_repo()
  expect_equal(source_of(), list(sha = sha, ref = "feature"))
})

test_that("get_deployment falls back on the variable as an arbitrary string", {
  local_sources(DEPLOYMENT_SOURCE = "v1.2 from my script")
  expect_equal(
    source_of(),
    list(sha = NA_character_, ref = "v1.2 from my script")
  )
})

test_that("get_deployment is unknown without any source", {
  local_sources()
  expect_equal(source_of(), unknown)
  withr::local_envvar(PATH = "")
  expect_equal(source_of(), unknown)
})

test_that("get_deployment has all times, in the current time zone by default", {
  local_sources()
  withr::local_timezone("Asia/Tokyo")
  before <- Sys.time()
  info <- get_deployment(app_started = before)
  expect_lt(info$process_started, before)
  expect_equal(as.numeric(info$app_started), as.numeric(before))
  expect_gte(info$session_started, before)
  times <- c("process_started", "app_started", "session_started")
  for (time in times) {
    expect_match(format(info[[time]], usetz = TRUE), " JST$")
    expect_match(format(get_deployment("UTC")[[time]], usetz = TRUE), " UTC$")
  }
})

test_that("show_deployment_details fixes the app time when it is called", {
  local_sources()
  render_time <- function(details, label) {
    html <- htmltools::renderTags(details)$html
    pattern <- paste0(label, "</dt>\\s*<dd>([^<]+)</dd>")
    regmatches(html, regexec(pattern, html))[[1]][[2]]
  }
  details <- show_deployment_details()
  app <- render_time(details, "App started")
  session <- render_time(details, "Session started")
  Sys.sleep(1.1)
  expect_equal(render_time(details, "App started"), app)
  expect_false(render_time(details, "Session started") == session)
})

test_that("show_deployment_details renders the abbreviated commit", {
  local_sources(GITHUB_SHA = "0123456789abcdef")
  html <- htmltools::renderTags(show_deployment_details())$html
  expect_match(html, "<dd>0123456</dd>", fixed = TRUE)
  expect_match(html, "<dd>NA</dd>", fixed = TRUE)
})

test_that("the standalone file does not need the rest of crow", {
  path <- normalizePath(
    test_path("..", "..", "R", "standalone-show_deployment.R"),
    mustWork = FALSE
  )
  skip_if_not(file.exists(path))
  local_sources(GITHUB_SHA = "abc")
  vendored <- new.env(parent = baseenv())
  sys.source(path, envir = vendored)
  expect_match(
    htmltools::renderTags(vendored$show_deployment_details())$html,
    "<dd>abc</dd>",
    fixed = TRUE
  )
})

test_that("hovering over the ref in the navbar shows the details", {
  skip_if_not_installed("bslib")
  local_envvars(GITHUB_SHA = "0123456789abcdef", GITHUB_REF_NAME = "main")
  driver <- local_app_driver(show_deployment_app)
  expect_equal(driver$get_text(".nav-text"), "main")
  expect_true(driver$get_js("Shiny.shinyapp.isConnected()"))
  expect_null(driver$get_js("document.querySelector('.popover')"))
  box <- driver$get_js(
    "(() => {
      const box = document.querySelector('.nav-text').getBoundingClientRect();
      return {x: box.x + box.width / 2, y: box.y + box.height / 2};
    })()"
  )
  driver$get_chromote_session()$Input$dispatchMouseEvent(
    type = "mouseMoved",
    x = box$x,
    y = box$y
  )
  driver$wait_for_js("document.querySelector('.popover') !== null")
  expect_match(driver$get_text(".popover"), "0123456")
  expect_match(driver$get_text(".popover"), "R process started")
  expect_match(driver$get_text(".popover"), "App started")
  expect_match(driver$get_text(".popover"), "Session started")
})

test_that("each page load has its own session time, but the same app time", {
  skip_if_not_installed("bslib")
  local_envvars(GITHUB_SHA = "abc")
  driver <- local_app_driver(show_deployment_app)
  load_time <- function(label) {
    page <- paste(readLines(driver$get_url(), warn = FALSE), collapse = "")
    pattern <- paste0(label, "</dt>\\s*<dd>([^<]+)</dd>")
    regmatches(page, regexec(pattern, page))[[1]][[2]]
  }
  first <- load_time("Session started")
  app <- load_time("App started")
  Sys.sleep(1.1)
  expect_false(load_time("Session started") == first)
  expect_equal(load_time("App started"), app)
})
