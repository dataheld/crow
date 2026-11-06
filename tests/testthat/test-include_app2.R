test_that("embeds the app in an iframe", {
  expect_snapshot(include_app2("https://example.com"))
})
test_that("ships its stylesheet", {
  dep <- htmltools::findDependencies(include_app2("https://example.com"))[[1]]
  expect_true(
    fs::file_exists(
      system.file(dep$src$file, dep$stylesheet, package = dep$package)
    )
  )
})
test_that("needs a url", {
  expect_error(include_app2(NULL))
})
