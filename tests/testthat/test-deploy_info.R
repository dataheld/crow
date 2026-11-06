local_ci <- function(..., .local_envir = parent.frame()) {
  unset <- c(
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

test_that("deploy_info reads GitHub Actions variables", {
  local_ci(GITHUB_SHA = "abc", GITHUB_REF_NAME = "main")
  expect_equal(deploy_info()[c("sha", "ref")], list(sha = "abc", ref = "main"))
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
  expect_equal(deploy_info()[c("sha", "ref")], list(sha = "abc", ref = "main"))
})

test_that("deploy_info does not mix CI variables with a local git repo", {
  local_git_repo()
  local_ci(GITHUB_SHA = "abc")
  expect_equal(
    deploy_info()[c("sha", "ref")],
    list(sha = "abc", ref = NA_character_)
  )
})

test_that("deploy_info reads a clean git working tree", {
  local_ci()
  sha <- local_git_repo()
  expect_equal(deploy_info()[c("sha", "ref")], list(sha = sha, ref = "feature"))
})

test_that("deploy_info has no ref on a detached git HEAD", {
  local_ci()
  sha <- local_git_repo()
  git_test("checkout", "--detach")
  expect_equal(
    deploy_info()[c("sha", "ref")],
    list(sha = sha, ref = NA_character_)
  )
})

test_that("deploy_info ignores git working trees that are not clean", {
  local_ci()
  unknown <- list(sha = NA_character_, ref = NA_character_)
  local_git_repo()
  writeLines("b", "file")
  expect_equal(deploy_info()[c("sha", "ref")], unknown)
  git_test("checkout", "file")
  writeLines("new", "untracked")
  expect_equal(deploy_info()[c("sha", "ref")], unknown)
})

test_that("deploy_info is unknown without CI variables or a git repo", {
  local_ci()
  unknown <- list(sha = NA_character_, ref = NA_character_)
  withr::local_dir(withr::local_tempdir())
  expect_equal(deploy_info()[c("sha", "ref")], unknown)
  withr::local_envvar(PATH = "")
  expect_equal(deploy_info()[c("sha", "ref")], unknown)
})

test_that("deploy_info records the time in a timezone", {
  local_ci()
  before <- Sys.time()
  info <- deploy_info()
  expect_gte(info$launched, before)
  expect_lte(info$launched, Sys.time())
  expect_equal(attr(info$launched, "tzone"), "Europe/Berlin")
  expect_equal(attr(deploy_info(tz = "UTC")$launched, "tzone"), "UTC")
  expect_error(deploy_info(tz = "Mars/Olympus"))
})

test_that("deploy_info_server renders and returns the info of the session", {
  local_ci(GITHUB_SHA = "0123456789abcdef", GITHUB_REF_NAME = "main")
  shiny::testServer(deploy_info_server, args = list(tz = "UTC"), {
    expect_equal(output$sha, "0123456")
    expect_equal(output$ref, "main")
    expect_match(output$launched, " UTC$")
    expect_equal(session$returned()$sha, "0123456789abcdef")
  })
})

test_that("deploy_info_server renders unknown values as NA", {
  local_ci()
  withr::local_dir(withr::local_tempdir())
  shiny::testServer(deploy_info_server, {
    expect_equal(output$sha, "NA")
    expect_equal(output$ref, "NA")
  })
})

test_that("deploy_info_server fails on a wrong timezone", {
  expect_error(deploy_info_server("x", tz = shiny::reactive("UTC")))
})

test_that("deploy_info UIs hold the namespaced outputs", {
  skip_if_not_installed("bslib")
  for (ui in list(deploy_info_ui("x"), deploy_info_card_ui("x"))) {
    for (output in c("x-sha", "x-ref", "x-launched")) {
      expect_match(as.character(ui), output, fixed = TRUE)
    }
  }
})

test_that("deploy_info_app shows the info in a browser", {
  skip_if_not_installed("bslib")
  local_ci(GITHUB_SHA = "0123456789abcdef", GITHUB_REF_NAME = "main")
  driver <- local_app_driver(deploy_info_app)
  expect_equal(driver$get_value(output = "test_object-sha"), "0123456")
  expect_equal(driver$get_value(output = "test_object-ref"), "main")
})
