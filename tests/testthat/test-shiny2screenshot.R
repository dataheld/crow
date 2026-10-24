variant <- shinytest2::platform_variant(r_version = FALSE)

describe("roxy_tag_crowExamplesShiny", {
  example <- brio::read_file(
    fs::path_package(
      package = "crow",
      "examples",
      "shiny2screenshot",
      "example",
      ext = "R"
    )
  )
  it(
    "can be parsed",
    expect_snapshot(roxygen2::parse_text(example)[[1]]$tags)
  )
  it("can be formatted", {
    topic <- roxygen2::roc_proc_text(roxygen2::rd_roclet(), example)[[1]]
    expect_snapshot(topic$get_section("examples"))
  })
})
# unnecessary wrapper, but otherwise skip has global scope,
# see #32
test_that("get_screenshot_works", {
  # these should use boring counter_button_app, not examples_app,
  # because they're in this package and don't change
  # upstream change from shiny examples could break screenshots
  describe("get_screenshot_from_app", {
    name <- "counter.png"
    announce_snapshot_file(name = name)
    skip_if_load_all2()
    path <- withr::local_tempfile(fileext = ".png")
    it("can record a screenshot", {
      get_screenshot_from_app(counter_button_app(), file = path)
      expect_snapshot_file(
        path = path,
        name = name,
        variant = variant
      )
    })
  })
})

test_that("screenshots fail according to `strict` setting", {
  expect_equal(
    # messages must be suppressed,
    # otherwise snapshot gets polluted with timestamps
    suppressMessages(
      get_screenshot_from_app(counter_button_app(), name = "does_not_exist")
    ),
    # oddly, a snapshot doesn't work here,
    # but keeps getting deleted/re-added
    glue::glue(
      "The screenshot could not be generated.",
      "Please check the logs for errors.",
      .sep = " "
    )
  )
  expect_error(
    get_screenshot_from_app(
      counter_button_app(),
      name = "does_not_exist",
      strict = TRUE
    )
  )
})

describe("roxy_tag_crowInsertSnaps", {
  single <- brio::read_file(
    fs::path_package(
      package = "crow",
      "examples",
      "snaps2fig",
      "single",
      ext = "R"
    )
  )
  it(
    "can be parsed",
    expect_snapshot(roxygen2::parse_text(single)[[1]]$tags)
  )
  it("can be formatted with single tag", {
    topic <- roxygen2::roc_proc_text(roxygen2::rd_roclet(), single)[[1]]
    expect_snapshot(topic$get_section("crowInsertSnaps"))
  })
  multiple <- brio::read_file(
    fs::path_package(
      package = "crow",
      "examples",
      "snaps2fig",
      "multiple",
      ext = "R"
    )
  )
  it("can be formatted with multiple tags joined", {
    topic <- roxygen2::roc_proc_text(roxygen2::rd_roclet(), multiple)[[1]]
    expect_snapshot(topic$get_section("crowInsertSnaps"))
  })
})

describe("dir_ls_snaps", {
  it("finds manually numbered, named screenshots", {
    snaps <- dir_ls_snaps(
      test_file = "helpers",
      regexp = glue_regexp_snaps(
        name = "bins",
        auto_numbered = FALSE
      ),
      variant = variant
    )
    expect_snapshot(snaps, variant = variant)
  })
  it("finds automatically numbered, named screenshots", {
    snaps <- dir_ls_snaps(
      test_file = "helpers",
      regexp = glue_regexp_snaps(
        name = "mpg",
        auto_numbered = FALSE
      ),
      variant = variant
    )
    expect_snapshot(snaps, variant = variant)
  })
  it("finds automatically numbered, unnamed screenshots", {
    snaps <- dir_ls_snaps(
      test_file = "helpers",
      regexp = glue_regexp_snaps(),
      variant = variant
    )
    expect_snapshot(snaps, variant = variant)
  })
  it("finds non-numbered, named screenshots", {
    snaps <- dir_ls_snaps(
      test_file = "helpers",
      regexp = glue_regexp_snaps(
        name = "foo",
        auto_numbered = FALSE
      ),
      variant = variant
    )
    expect_snapshot(snaps, variant = variant)
  })
})

describe("map_snaps_animate", {
  it("fails if file is missing", {
    expect_error(map_snaps_animate("i-do-not-exist"))
    expect_error(map_snaps_animate(c("i-do-not-exist", "me-neither")))
  })
  it("reads in single screenshot", {
    snaps <- dir_ls_snaps(
      test_file = "helpers",
      regexp = glue_regexp_snaps(
        name = "foo",
        auto_numbered = FALSE
      ),
      variant = variant
    )
    path <- withr::local_tempfile()
    testthat::expect_snapshot_file(
      path = image_animate_snaps(snaps) |> image_write_snaps(path = path),
      name = "single.png",
      variant = variant
    )
  })
  it("reads in multiple screenshots", {
    snaps <- dir_ls_snaps(
      test_file = "helpers",
      regexp = glue_regexp_snaps(
        name = "bins",
        auto_numbered = FALSE
      ),
      variant = variant
    )
    path <- withr::local_tempfile()
    testthat::expect_snapshot_file(
      path = image_animate_snaps(snaps) |> image_write_snaps(path = path),
      name = "multiple.gif",
      variant = variant
    )
  })
})

describe("snaps2fig and friends work", {
  output_path <- "man/figures/crow_screenshots/helpers/bins.gif"
  withr::defer(fs::file_delete(output_path))
  it("writes out snapshots to man folder", {
    res <- snaps2fig(
      test_file = "helpers",
      name = "bins",
      auto_numbered = FALSE,
      variant = variant
    )
    checkmate::expect_file_exists(
      "man/figures/crow_screenshots/helpers/bins.gif"
    )
    expect_equal(
      res,
      fs::path("crow_screenshots", "helpers", "bins", ext = "gif")
    )
  })
  it("writes out markdown syntax", {
    res <- snaps2md(
      test_file = "helpers",
      name = "bins",
      auto_numbered = FALSE,
      variant = variant
    )
    expect_snapshot(res)
  })
})
