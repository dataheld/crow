local_ci <- function(..., .local_envir = parent.frame()) {
  unset <- c(
    DEPLOYMENT_SOURCE = NA,
    CI_MERGE_REQUEST_SOURCE_BRANCH_NAME = NA,
    GITHUB_SHA = NA,
    GITHUB_HEAD_REF = NA,
    GITHUB_REF_NAME = NA,
    CI_COMMIT_SHA = NA,
    CI_COMMIT_REF_NAME = NA
  )
  set <- c(...)
  unset[names(set)] <- set
  withr::local_envvar(unset, .local_envir = .local_envir)
}

git_test <- function(...) {
  system2(
    "git",
    c("-c", "user.name=crow", "-c", "user.email=crow@example.com", ...),
    stdout = TRUE,
    stderr = TRUE
  )
}

local_git_repo <- function(.local_envir = parent.frame()) {
  skip_if(Sys.which("git") == "")
  withr::local_dir(
    withr::local_tempdir(.local_envir = .local_envir),
    .local_envir = .local_envir
  )
  git_test("init", "--initial-branch=feature")
  writeLines("a", "file")
  git_test("add", "file")
  git_test("commit", "--no-gpg-sign", "--message=init")
  git_test("rev-parse", "HEAD")
}

scm <- function(...) get_deployment(...)[c("sha", "ref")]
unknown <- list(sha = NA_character_, ref = NA_character_)

test_that("get_deployment reads GitHub Actions variables", {
  local_ci(GITHUB_SHA = "abc", GITHUB_REF_NAME = "main")
  expect_equal(scm(), list(sha = "abc", ref = "main"))
})

test_that("get_deployment prefers the source branch of pull requests", {
  local_ci(
    GITHUB_SHA = "abc",
    GITHUB_HEAD_REF = "feature",
    GITHUB_REF_NAME = "99/merge"
  )
  expect_equal(get_deployment()$ref, "feature")
})

test_that("get_deployment reads GitLab CI variables", {
  local_ci(CI_COMMIT_SHA = "abc", CI_COMMIT_REF_NAME = "main")
  expect_equal(scm(), list(sha = "abc", ref = "main"))
})

test_that("get_deployment prefers the source branch of GitLab merge requests", {
  local_ci(
    CI_COMMIT_SHA = "abc",
    CI_MERGE_REQUEST_SOURCE_BRANCH_NAME = "feature",
    CI_COMMIT_REF_NAME = "other"
  )
  expect_equal(get_deployment()$ref, "feature")
})

test_that("get_deployment does not mix CI variables with a local git repo", {
  local_git_repo()
  local_ci(GITHUB_SHA = "abc")
  expect_equal(scm(), list(sha = "abc", ref = NA_character_))
})

test_that("get_deployment reads a clean git working tree", {
  local_ci()
  sha <- local_git_repo()
  expect_equal(scm(), list(sha = sha, ref = "feature"))
})

test_that("get_deployment has no ref on a detached git HEAD", {
  local_ci()
  sha <- local_git_repo()
  git_test("checkout", "--detach")
  expect_equal(scm(), list(sha = sha, ref = NA_character_))
})

test_that("get_deployment ignores git working trees that are not clean", {
  local_ci()
  local_git_repo()
  writeLines("b", "file")
  expect_equal(scm(), unknown)
  git_test("checkout", "file")
  writeLines("new", "untracked")
  expect_equal(scm(), unknown)
})

test_that("get_deployment is unknown without CI variables or a git repo", {
  local_ci()
  withr::local_dir(withr::local_tempdir())
  expect_equal(scm(), unknown)
  withr::local_envvar(PATH = "")
  expect_equal(scm(), unknown)
})

test_that("get_deployment looks for the variable before anything else", {
  local_ci(DEPLOYMENT_SOURCE = "abc:main", GITHUB_SHA = "other")
  expect_equal(scm(), list(sha = "abc", ref = "main"))
})

test_that("get_deployment accepts a value instead of the variable", {
  local_ci(DEPLOYMENT_SOURCE = "abc:main")
  expect_equal(scm(env = "def:feature"), list(sha = "def", ref = "feature"))
  expect_equal(scm(env = "def"), list(sha = "def", ref = NA_character_))
})

test_that("set_deployment_envvar creates a variable that get_deployment reads", {
  local_ci(GITHUB_SHA = "abc", GITHUB_REF_NAME = "main")
  expect_equal(set_deployment_envvar(), "abc:main")
  expect_equal(Sys.getenv("DEPLOYMENT_SOURCE"), "abc:main")
  withr::local_envvar(GITHUB_SHA = NA, GITHUB_REF_NAME = NA)
  expect_equal(scm(), list(sha = "abc", ref = "main"))
})

test_that("set_deployment_envvar records unknown values as unknown", {
  local_ci()
  withr::local_dir(withr::local_tempdir())
  set_deployment_envvar()
  expect_equal(scm(), unknown)
})

test_that("get_deployment has both times in a timezone", {
  local_ci()
  before <- Sys.time()
  info <- get_deployment()
  expect_gte(info$session_started, before)
  expect_lte(info$session_started, Sys.time())
  expect_lt(info$app_started, before)
  expect_equal(attr(info$session_started, "tzone"), "Europe/Berlin")
  expect_equal(attr(info$app_started, "tzone"), "Europe/Berlin")
  expect_equal(attr(get_deployment(tz = "UTC")$app_started, "tzone"), "UTC")
  expect_error(get_deployment(tz = "Mars/Olympus"))
})

test_that("show_deployment_server renders and returns the info of the session", {
  local_ci()
  shiny::testServer(
    show_deployment_server,
    args = list(env = "0123456789abcdef:main", tz = "UTC"),
    {
      expect_equal(output$label, "main")
      expect_equal(output$ref, "main")
      expect_equal(output$sha, "0123456")
      expect_match(output$app_started, " UTC$")
      expect_match(output$session_started, " UTC$")
      expect_equal(session$returned()$sha, "0123456789abcdef")
    }
  )
})

test_that("show_deployment_server renders unknown values as NA", {
  local_ci()
  withr::local_dir(withr::local_tempdir())
  shiny::testServer(show_deployment_server, {
    expect_equal(output$label, "NA")
    expect_equal(output$sha, "NA")
  })
})

test_that("show_deployment_server fails on a wrong timezone", {
  expect_error(show_deployment_server("x", tz = shiny::reactive("UTC")))
})

test_that("the standalone file does not need the rest of crow", {
  path <- test_path("..", "..", "R", "standalone-show_deployment.R")
  skip_if_not(file.exists(path))
  local_ci(GITHUB_SHA = "abc", GITHUB_REF_NAME = "main")
  vendored <- new.env(parent = baseenv())
  sys.source(path, envir = vendored)
  expect_equal(vendored$get_deployment(env = "def:feature")$ref, "feature")
  expect_s3_class(vendored$show_deployment_ui("x"), "shiny.tag")
  expect_equal(vendored$set_deployment_envvar(), "abc:main")
})

test_that("hovering over the ref in the navbar shows the details", {
  skip_if_not_installed("bslib")
  local_ci(DEPLOYMENT_SOURCE = "0123456789abcdef:main")
  driver <- local_app_driver(show_deployment_app)
  expect_equal(driver$get_value(output = "show_deployment-label"), "main")
  expect_equal(driver$get_js("document.querySelector('.popover')"), NULL)
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
  driver$wait_for_js(
    "document.querySelector('.popover #show_deployment-sha')?.textContent
      === '0123456'"
  )
  expect_match(driver$get_text(".popover"), "App started")
  expect_match(driver$get_text(".popover"), "Session started")
})
