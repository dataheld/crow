test_that("agent plugin version matches package version", {
  plugin <- jsonlite::read_json(system.file("plugin.json", package = "crow"))
  expect_identical(plugin$version, utils::packageDescription("crow")$Version)
})

test_that("agent plugin starts the MCP server of the installed crow", {
  mcp <- jsonlite::read_json(system.file("mcp.json", package = "crow"))
  expect_identical(mcp$mcpServers$crow$args[[2]], "crow::crow_mcp_server()")
})
