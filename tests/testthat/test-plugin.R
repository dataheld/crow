test_that("agent plugin version matches package version", {
  plugin <- jsonlite::read_json(system.file("plugin.json", package = "crow"))
  expect_identical(plugin$version, utils::packageDescription("crow")$Version)
})
