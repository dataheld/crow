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
test_that("get_screenshot_from_app can record a screenshot", {
  # these should use boring counter_button_app, not examples_app,
  # because they're in this package and don't change
  # upstream change from shiny examples could break screenshots
  path <- withr::local_tempfile(fileext = ".png")
  get_screenshot_from_app(counter_button_app, file = path)
  expect_snapshot_file(path, name = "counter.png", variant = variant)
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
      )
    )
    expect_snapshot(snaps, variant = variant)
  })
  it("finds automatically numbered, named screenshots", {
    snaps <- dir_ls_snaps(
      test_file = "helpers",
      regexp = glue_regexp_snaps(
        name = "mpg",
        auto_numbered = FALSE
      )
    )
    expect_snapshot(snaps, variant = variant)
  })
  it("finds automatically numbered, unnamed screenshots", {
    snaps <- dir_ls_snaps(
      test_file = "helpers",
      regexp = glue_regexp_snaps()
    )
    expect_snapshot(snaps, variant = variant)
  })
  it("finds non-numbered, named screenshots", {
    snaps <- dir_ls_snaps(
      test_file = "helpers",
      regexp = glue_regexp_snaps(
        name = "foo",
        auto_numbered = FALSE
      )
    )
    expect_snapshot(snaps, variant = variant)
  })
})

describe("image_animate_snaps", {
  it("fails if file is missing", {
    expect_error(image_animate_snaps("i-do-not-exist"), "could not be found")
    expect_error(
      image_animate_snaps(c("i-do-not-exist", "me-neither")),
      "could not be found"
    )
  })
  it("reads in single screenshot", {
    snaps <- dir_ls_snaps(
      test_file = "helpers",
      regexp = glue_regexp_snaps(
        name = "foo",
        auto_numbered = FALSE
      )
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
      )
    )
    path <- withr::local_tempfile()
    testthat::expect_snapshot_file(
      path = image_animate_snaps(snaps) |> image_write_snaps(path = path),
      name = "multiple.gif",
      variant = variant
    )
  })
  it("shows every frame whole and alone, whatever its size", {
    snaps <- withr::local_tempfile(fileext = c(".png", ".png"))
    magick::image_write(magick::image_blank(100, 50, "red"), snaps[[1]])
    magick::image_write(magick::image_blank(80, 70, "blue"), snaps[[2]])
    gif <- image_animate_snaps(snaps) |>
      image_write_snaps(path = withr::local_tempfile(fileext = ".gif"))
    # as a browser shows it, after each frame's disposal
    shown <- magick::image_coalesce(magick::image_read(gif))
    expect_equal(magick::image_info(shown)$width, c(100, 100))
    expect_equal(magick::image_info(shown)$height, c(70, 70))
    color <- function(frame, x, y) {
      pixel <- magick::image_data(shown[frame], "rgba")[, x, y]
      if (pixel[[4]] == 0) "none" else paste(pixel[1:3], collapse = "")
    }
    expect_equal(color(1, 100, 50), "ff0000")
    expect_equal(color(1, 100, 51), "none")
    expect_equal(color(2, 80, 70), "0000ff")
    expect_equal(color(2, 81, 1), "none")
  })
})

describe("snaps2fig and friends work", {
  output_path <- "man/figures/crow_screenshots/helpers/bins.gif"
  withr::defer(fs::file_delete(output_path))
  it("writes out snapshots to man folder", {
    res <- snaps2fig(
      test_file = "helpers",
      name = "bins",
      auto_numbered = FALSE
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
      auto_numbered = FALSE
    )
    expect_snapshot(res)
  })
  it("replaces a figure of the other format", {
    figure <- fs::path("man/figures/crow_screenshots/helpers/foo")
    withr::defer(unlink(fs::path_ext_set(figure, c("png", "gif"))))
    fs::dir_create(fs::path_dir(figure))
    fs::file_touch(fs::path_ext_set(figure, "gif"))
    res <- snaps2fig(test_file = "helpers", name = "foo", auto_numbered = FALSE)
    expect_equal(res, fs::path("crow_screenshots", "helpers", "foo.png"))
    expect_equal(
      fs::path_file(fs::dir_ls(fs::path_dir(figure), regexp = "/foo\\.")),
      "foo.png"
    )
  })
})
