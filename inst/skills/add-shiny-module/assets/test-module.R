test_that("MODULE_server returns its value", {
  shiny::testServer(MODULE_server, {
    expect_null(session$returned())
    expect_equal(output$out, "NULL")
  })
})

test_that("MODULE_app works in a browser", {
  skip_on_cran()
  driver <- crow::local_app_driver(
    MODULE_app,
    name = "MODULE",
    variant = shinytest2::platform_variant(r_version = FALSE)
  )
  driver$expect_screenshot()
  expect_null(driver$get_value(export = "res"))
})
