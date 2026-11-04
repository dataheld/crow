test_that("works without any inputs", {
  shiny::testServer(module2app_server(), expect_equal(res, NULL))
  expect_snapshot(module2app_ui())
  driver <- shinytest2::AppDriver$new(app_factory({
    library(crow)
    elf::source_pef("crow", "module2app", "simple", "no-funs")
  }))
  withr::defer(driver$stop())
  expect_equal(driver$get_value(export = "res"), NULL)
})
test_that("works with only UI input", {
  expect_snapshot(module2app_ui(module_ui = counter_button_ui))
  driver <- shinytest2::AppDriver$new(app_factory({
    library(crow)
    elf::source_pef("crow", "module2app", "simple", "only-ui")
  }))
  withr::defer(driver$stop())
  driver$expect_text("#test_object-button")
})
test_that("works with only server input", {
  shiny::testServer(
    module2app_server(module_server = counter_button_server),
    expect_equal(res(), 0)
  )
  driver <- shinytest2::AppDriver$new(app_factory({
    library(crow)
    elf::source_pef("crow", "module2app", "simple", "only-server")
  }))
  withr::defer(driver$stop())
  expect_equal(driver$get_value(export = "res"), 0)
})
test_that("works with both inputs", {
  driver <- shinytest2::AppDriver$new(app_factory({
    library(crow)
    elf::source_pef("crow", "module2app", "simple", "both-funs")
  }))
  withr::defer(driver$stop())
  expect_equal(
    driver$get_value(output = "returns-eval"),
    capture.output(print(0))
  )
  driver$click(selector = "#test_object-button")
  expect_equal(
    driver$get_value(output = "returns-eval"),
    capture.output(print(1))
  )
})
test_that("works with arguments to ui and server", {
  increment_by <- shiny::reactiveVal(4L)
  shiny::testServer(
    app = module2app_server(
      module_server = counter_button_server,
      server_args = list(set_to = 10, increment_by = increment_by)
    ),
    expr = {
      expect_equal(res(), 10)
      session$setInputs(`test_object-button` = 1)
      expect_equal(res(), 14)
      # changing reactive input here
      increment_by(1L)
      session$setInputs(`test_object-button` = 2)
      expect_equal(res(), 15)
    }
  )
  driver <- shinytest2::AppDriver$new(app_factory({
    library(crow)
    elf::source_pef("crow", "module2app", "simple", "args")
  }))
  withr::defer(driver$stop())
  expect_equal(
    driver$get_value(output = "returns-eval"),
    capture.output(print(100))
  )
  driver$click(selector = "#test_object-button")
  expect_equal(
    driver$get_value(output = "returns-eval"),
    capture.output(print(102))
  )
})
test_that("works with only server args", {
  driver <- shinytest2::AppDriver$new(app_factory({
    library(crow)
    module2app(server_args = list(c(1, 2)))
  }))
  withr::defer(driver$stop())
  expect_equal(
    driver$get_value(output = "inputs-eval"),
    "[[1]]\n[1] 1 2"
  )
})
test_that("works with `shiny.tag` returns (workaround)", {
  driver <- shinytest2::AppDriver$new(app_factory({
    library(crow)
    module2app(server_args = list(bar = 1, zap = htmltools::p()))
  }))
  withr::defer(driver$stop())
  expect_snapshot(
    driver$get_value(output = "inputs-eval"),
    transform = purrr::compose(elf::transform_with_generated)
  )
})
test_that("works with S3-classed return", {
  expect_no_condition({
    driver <- shinytest2::AppDriver$new(app_factory({
      library(crow)
      module2app(
        server_args = list(zap = shiny::reactive(bsicons::bs_icon("heart")))
      )
    }))
    withr::defer(driver$stop())
  })
})
test_that("works with nested modules and flat returns", {
  shiny::testServer(
    module2app_server(x_counter_button_server),
    expr = {
      expect_equal(res(), 2)
      session$setInputs(`test_object-set_count-button` = 1)
      expect_equal(res(), 3)
      session$setInputs(`test_object-set_increment-button` = 1)
      session$setInputs(`test_object-set_count-button` = 1)
      expect_equal(res(), 5)
    }
  )
})
test_that("works with nested modules and deep returns", {
  driver <- shinytest2::AppDriver$new(app_factory({
    library(crow)
    elf::source_pef("crow", "module2app", "nested", "deep")
  }))
  withr::defer(driver$stop())
  driver$expect_text("#returns-eval")
  # changing increment does not work in test,
  # probably because of needed sleep or something
})
test_that("works with bs5", {
  expect_snapshot(
    # navbar is not a good example, because it has random tab ids
    module2app_ui(
      module_ui = counter_button_ui,
      ui_wrapper = source_pef("module2app", "ui", "bootstrap")
    )
  )
})
test_that("exported app factories use the package's module code", {
  driver <- shinytest2::AppDriver$new(counter_button_app)
  withr::defer(driver$stop())
  expect_equal(driver$get_text("#test_object-button"), "Counter")
  expect_equal(driver$get_value(export = "res"), 0)
  driver$click(selector = "#test_object-button")
  expect_equal(driver$get_value(export = "res"), 1)
})
correct_attr <- list(selector = paste0("#", inner_module_id, " > *"))
test_that("returns attribute with dom selector", {
  expect_equal(
    attr(module2app(counter_button_ui), "crow_screenshot_args"),
    correct_attr
  )
})
test_that("screenshot args attribute can be retrieved", {
  expect_equal(
    get_screenshot_args_attr(module2app(counter_button_ui)),
    correct_attr
  )
})
test_that("app without crow args returns missing arg", {
  expect_equal(get_screenshot_args_attr(examples_app()), rlang::missing_arg())
})
test_that("absence and presence of crow attrs can be found", {
  expect_true(has_crow_attrs(counter_button_app()))
  expect_false(has_crow_attrs(examples_app()))
})
