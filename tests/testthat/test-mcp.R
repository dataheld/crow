tool <- function(name) crow_tools()[[name]]


local_module_pkg <- function(label = "Count", .local_envir = parent.frame()) {
  if (!"crow" %in% rownames(utils::installed.packages())) {
    testthat::skip("Needs crow installed, as packages using crow do.")
  }
  path <- withr::local_tempdir(.local_envir = .local_envir)
  writeLines(
    c("Package: modpkg", "Version: 0.0.1", "Imports: crow, shiny"),
    file.path(path, "DESCRIPTION")
  )
  dir.create(file.path(path, "R"))
  write_module(path, label)
  path
}

write_module <- function(path, label) {
  writeLines(
    c(
      "mod_server <- function(id) {",
      "  shiny::moduleServer(id, function(input, output, session) {",
      sprintf("    shiny::reactive('%s')", label),
      "  })",
      "}"
    ),
    file.path(path, "R", "mod.R")
  )
}

test_that("crow_tools() offers a tool for each task", {
  expect_setequal(
    names(crow_tools()),
    c(
      "module_test_server",
      "module_app_start",
      "module_app_set",
      "module_app_get",
      "module_app_screenshot",
      "module_app_stop"
    )
  )
})

test_that("module_test_server() reports trees, value and messages", {
  res <- tool("module_test_server")(
    path = pkg_root(),
    server = "counter_button_server",
    server_args = "list(increment_by = shiny::reactiveVal(2L))",
    expr = paste(
      "session$setInputs(`test_object-button` = 1)",
      "message('hello from expr')",
      "output$`test_object-out`",
      sep = "\n"
    )
  )
  expect_match(res, "## Value of `expr`\n[1] \"2\"", fixed = TRUE)
  expect_match(res, "## Return value (evaluated)\n[1] 2", fixed = TRUE)
  expect_match(res, "## Server arguments (evaluated)", fixed = TRUE)
  expect_match(res, "hello from expr", fixed = TRUE)
})

test_that("module_test_server() changes reactive server arguments", {
  res <- tool("module_test_server")(
    path = pkg_root(),
    server = "counter_button_server",
    server_args = "list(increment_by = shiny::reactiveVal(1L))",
    expr = paste(
      "session$setInputs(crow_server_args = list(increment_by = 5))",
      "session$setInputs(`test_object-button` = 1)",
      sep = "\n"
    )
  )
  expect_match(res, "## Return value (evaluated)\n[1] 5", fixed = TRUE)
  expect_match(res, "$increment_by\n[1] 5", fixed = TRUE)
})

test_that("module_test_server() reports reactlog events on request", {
  res <- tool("module_test_server")(
    path = pkg_root(),
    server = "counter_button_server",
    expr = "session$setInputs(`test_object-button` = 1)",
    reactlog = TRUE
  )
  expect_match(res, "## Reactlog events\n{\"action\":", fixed = TRUE)
  expect_match(res, "input$test_object-button", fixed = TRUE)
  expect_no_match(
    tool("module_test_server")(pkg_root(), "counter_button_server"),
    "Reactlog",
    fixed = TRUE
  )
})

test_that("module_test_server() reports errors first", {
  res <- tool("module_test_server")(
    path = pkg_root(),
    server = "counter_button_server",
    expr = "stop('boom')"
  )
  expect_match(res, "^## Error\n.*boom")
})

test_that("module_test_server() runs the working tree of the package", {
  path <- local_module_pkg("before")
  run <- function() {
    tool("module_test_server")(path = path, server = "mod_server")
  }
  expect_match(run(), "[1] \"before\"", fixed = TRUE)
  write_module(path, "after")
  expect_match(run(), "[1] \"after\"", fixed = TRUE)
})

test_that("module apps start, change, report, screenshot and stop", {
  start <- tool("module_app_start")(
    path = pkg_root(),
    ui = "counter_button_ui",
    server = "counter_button_server",
    server_args = "list(increment_by = shiny::reactiveVal(1L))"
  )
  id <- app_id(start)
  withr::defer(try(tool("module_app_stop")(id), silent = TRUE))
  expect_match(start, "http://127.0.0.1:[0-9]+")
  expect_match(start, "## Return value (evaluated)\n[1] 0", fixed = TRUE)

  set <- tool("module_app_set")(
    id,
    server_args = '{"increment_by": 5}',
    inputs = '{"button": "click"}'
  )
  expect_match(set, "## Return value (evaluated)\n[1] 5", fixed = TRUE)

  wrong <- tool("module_app_set")(id, server_args = '{"nope": 1}')
  expect_match(
    wrong,
    "## Errors and warnings in the log\n[^#]*Cannot change server argument `nope`"
  )
  expect_no_match(wrong, "Listening on", fixed = TRUE)

  get <- tool("module_app_get")(id, reactlog = TRUE)
  expect_match(get, "output$`test_object-out`", fixed = TRUE)
  expect_match(get, "input$test_object-button", fixed = TRUE)
  expect_match(get, "## Reactlog events", fixed = TRUE)

  shot <- tool("module_app_screenshot")(id)
  png <- regmatches(shot, regexpr("[^\n ]+\\.png", shot))
  expect_true(file.exists(png))

  stop <- tool("module_app_stop")(id)
  expect_match(stop, "Stopped app", fixed = TRUE)
  expect_false(id %in% names(the$apps))
  expect_match(tool("module_app_get")(id), "^## Error\nNo running app")
})

test_that("module_app_screenshot() reports why a screenshot failed", {
  id <- app_id(tool("module_app_start")(
    path = pkg_root(),
    ui = "function(id) NULL"
  ))
  withr::defer(try(tool("module_app_stop")(id), silent = TRUE))
  expect_match(
    tool("module_app_screenshot")(id),
    "^## Error\n[^#]*screenshot with 0 height"
  )
})

test_that("module app tools report wrong calls as errors", {
  expect_match(
    tool("module_app_set")("app0", inputs = "{not json"),
    "^## Error\n"
  )
  expect_match(tool("module_app_stop")("app0"), "^## Error\nNo running app")
  expect_match(
    tool("module_app_start")(path = withr::local_tempdir()),
    "^## Error\n"
  )
})

test_that("module apps run apart", {
  start <- function() {
    app_id(tool("module_app_start")(
      path = pkg_root(),
      ui = "counter_button_ui",
      server = "counter_button_server"
    ))
  }
  one <- start()
  withr::defer(try(tool("module_app_stop")(one), silent = TRUE))
  two <- start()
  withr::defer(try(tool("module_app_stop")(two), silent = TRUE))
  tool("module_app_set")(one, inputs = '{"button": "click"}')
  expect_match(
    tool("module_app_get")(two),
    "## Return value (evaluated)\n[1] 0",
    fixed = TRUE
  )
})

test_that("stopping an app ends its processes", {
  id <- app_id(tool("module_app_start")(
    path = pkg_root(),
    ui = "counter_button_ui",
    server = "counter_button_server"
  ))
  session <- the$apps[[id]]
  tool("module_app_stop")(id)
  expect_false(session$is_alive())
})

test_that("module apps do not take their start limit from the environment", {
  withr::local_envvar(SHINYTEST2_LOAD_TIMEOUT = "1")
  start <- tool("module_app_start")(
    path = pkg_root(),
    ui = "counter_button_ui",
    server = "counter_button_server"
  )
  withr::defer(try(tool("module_app_stop")(app_id(start)), silent = TRUE))
  expect_no_match(start, "## Error", fixed = TRUE)
})

test_that("log_problems() keeps whole condition messages", {
  lines <- c(
    "[shiny stderr] Listening on http://127.0.0.1:1234",
    "[shiny stderr] Error:",
    "[shiny stderr] ! Cannot change server argument `nope`",
    "[shiny stderr] \u2139 Only reactive arguments can change.",
    "[shiny stderr] Listening on http://127.0.0.1:1234"
  )
  expect_identical(log_problems(lines), lines[2:4])
})
