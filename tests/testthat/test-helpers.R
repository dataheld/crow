test_that("example app for manually numbered, named screenshots", {
  bins <- 20:30
  purrr::walk(
    bins,
    function(bin) testthat::announce_snapshot_file(glue::glue("bins-{bin}.png"))
  )
  skip_example_screenshots()
  driver <- local_app_driver(
    examples_app(),
    variant = shinytest2::platform_variant(r_version = FALSE)
  )
  purrr::walk(
    bins,
    function(bin) {
      driver$set_inputs(bins = bin)
      driver$expect_screenshot(name = glue::glue("bins-{bin}.png"))
    }
  )
})
test_that("example app for automatically numbered, named screenshots", {
  announce_snapshot_file("mpg-001.png")
  announce_snapshot_file("mpg-002.png")
  skip_example_screenshots()
  driver <- local_app_driver(
    examples_app("04_mpg"),
    name = "mpg",
    variant = shinytest2::platform_variant(r_version = FALSE)
  )
  driver$expect_screenshot()
  driver$expect_screenshot()
})
test_that("example app for automatically numbered, unnamed screenshots", {
  announce_snapshot_file("001.png")
  announce_snapshot_file("002.png")
  skip_example_screenshots()
  driver <- local_app_driver(
    examples_app("05_sliders"),
    variant = shinytest2::platform_variant(r_version = FALSE)
  )
  driver$expect_screenshot()
  driver$expect_screenshot()
})
test_that("example app for non-numbered, named screenshots", {
  announce_snapshot_file("foo.png")
  announce_snapshot_file("bar.png")
  skip_example_screenshots()
  driver <- local_app_driver(
    # 06_tabsets example was bad to use,
    # because it uses rnorm and thus keeps changing
    examples_app("07_widgets"),
    variant = shinytest2::platform_variant(r_version = FALSE)
  )
  driver$expect_screenshot(name = "foo")
  driver$expect_screenshot(name = "bar")
})
