local_ci <- function(..., .local_envir = parent.frame()) {
  unset <- c(
    DEPLOY_INFO = NA,
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

scm <- function(...) deploy_info(...)[c("sha", "ref")]
unknown <- list(sha = NA_character_, ref = NA_character_)

test_that("deploy_info reads GitHub Actions variables", {
  local_ci(GITHUB_SHA = "abc", GITHUB_REF_NAME = "main")
  expect_equal(scm(), list(sha = "abc", ref = "main"))
})

test_that("deploy_info prefers the source branch of pull requests", {
  local_ci(
    GITHUB_SHA = "abc",
    GITHUB_HEAD_REF = "feature",
    GITHUB_REF_NAME = "99/merge"
  )
  expect_equal(deploy_info()$ref, "feature")
})

test_that("deploy_info reads GitLab CI variables", {
  local_ci(CI_COMMIT_SHA = "abc", CI_COMMIT_REF_NAME = "main")
  expect_equal(scm(), list(sha = "abc", ref = "main"))
})

test_that("deploy_info does not mix CI variables with a local git repo", {
  local_git_repo()
  local_ci(GITHUB_SHA = "abc")
  expect_equal(scm(), list(sha = "abc", ref = NA_character_))
})

test_that("deploy_info reads a clean git working tree", {
  local_ci()
  sha <- local_git_repo()
  expect_equal(scm(), list(sha = sha, ref = "feature"))
})

test_that("deploy_info has no ref on a detached git HEAD", {
  local_ci()
  sha <- local_git_repo()
  git_test("checkout", "--detach")
  expect_equal(scm(), list(sha = sha, ref = NA_character_))
})

test_that("deploy_info ignores git working trees that are not clean", {
  local_ci()
  local_git_repo()
  writeLines("b", "file")
  expect_equal(scm(), unknown)
  git_test("checkout", "file")
  writeLines("new", "untracked")
  expect_equal(scm(), unknown)
})

test_that("deploy_info is unknown without CI variables or a git repo", {
  local_ci()
  withr::local_dir(withr::local_tempdir())
  expect_equal(scm(), unknown)
  withr::local_envvar(PATH = "")
  expect_equal(scm(), unknown)
})

test_that("deploy_info looks for the variable before anything else", {
  local_ci(DEPLOY_INFO = "abc:main", GITHUB_SHA = "other")
  expect_equal(scm(), list(sha = "abc", ref = "main"))
})

test_that("deploy_info accepts a value instead of the variable", {
  local_ci(DEPLOY_INFO = "abc:main")
  expect_equal(scm(env = "def:feature"), list(sha = "def", ref = "feature"))
  expect_equal(scm(env = "def"), list(sha = "def", ref = NA_character_))
})

test_that("deploy_info_set_env creates a variable that deploy_info reads", {
  local_ci(GITHUB_SHA = "abc", GITHUB_REF_NAME = "main")
  expect_equal(deploy_info_set_env(), "abc:main")
  expect_equal(Sys.getenv("DEPLOY_INFO"), "abc:main")
  withr::local_envvar(GITHUB_SHA = NA, GITHUB_REF_NAME = NA)
  expect_equal(scm(), list(sha = "abc", ref = "main"))
})

test_that("deploy_info_set_env records unknown values as unknown", {
  local_ci()
  withr::local_dir(withr::local_tempdir())
  deploy_info_set_env()
  expect_equal(scm(), unknown)
})

test_that("deploy_info has both times in a timezone", {
  local_ci()
  before <- Sys.time()
  info <- deploy_info()
  expect_gte(info$session_started, before)
  expect_lte(info$session_started, Sys.time())
  expect_lt(info$app_started, before)
  expect_equal(attr(info$session_started, "tzone"), "Europe/Berlin")
  expect_equal(attr(info$app_started, "tzone"), "Europe/Berlin")
  expect_equal(attr(deploy_info(tz = "UTC")$app_started, "tzone"), "UTC")
  expect_error(deploy_info(tz = "Mars/Olympus"))
})

test_that("deploy_info_server renders and returns the info of the session", {
  local_ci()
  shiny::testServer(
    deploy_info_server,
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

test_that("deploy_info_server renders unknown values as NA", {
  local_ci()
  withr::local_dir(withr::local_tempdir())
  shiny::testServer(deploy_info_server, {
    expect_equal(output$label, "NA")
    expect_equal(output$sha, "NA")
  })
})

test_that("deploy_info_server fails on a wrong timezone", {
  expect_error(deploy_info_server("x", tz = shiny::reactive("UTC")))
})

test_that("deploy_info UIs hold the namespaced outputs", {
  skip_if_not_installed("bslib")
  details <- c("x-sha", "x-ref", "x-app_started", "x-session_started")
  for (output in details) {
    expect_match(as.character(deploy_info_ui("x")), output, fixed = TRUE)
    expect_match(
      as.character(deploy_info_navbar_ui("x")),
      output,
      fixed = TRUE
    )
  }
  expect_match(
    as.character(deploy_info_navbar_ui("x")),
    "x-label",
    fixed = TRUE
  )
})

test_that("the standalone file does not need the rest of crow", {
  path <- test_path("..", "..", "R", "standalone-deploy_info.R")
  skip_if_not(file.exists(path))
  local_ci(GITHUB_SHA = "abc", GITHUB_REF_NAME = "main")
  vendored <- new.env(parent = baseenv())
  sys.source(path, envir = vendored)
  expect_equal(vendored$deploy_info(env = "def:feature")$ref, "feature")
  expect_s3_class(vendored$deploy_info_ui("x"), "shiny.tag")
  expect_equal(vendored$deploy_info_set_env(), "abc:main")
})

test_that("hovering over the ref in the navbar shows the details", {
  skip_if_not_installed("bslib")
  local_ci(DEPLOY_INFO = "0123456789abcdef:main")
  driver <- local_app_driver(deploy_info_app)
  expect_equal(driver$get_value(output = "deploy_info-label"), "main")
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
    "document.querySelector('.popover #deploy_info-sha')?.textContent
      === '0123456'"
  )
  expect_match(driver$get_text(".popover"), "App started")
  expect_match(driver$get_text(".popover"), "Session started")
})
