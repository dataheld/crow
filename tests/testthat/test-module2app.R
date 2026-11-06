test_that("works without any inputs", {
  shiny::testServer(module2app_server(), expect_equal(res, NULL))
  expect_snapshot(module2app_ui())
  driver <- local_app_driver(shinytest2_app_fn(
    source_pef("module2app", "simple", "no-funs")
  ))
  expect_equal(driver$get_value(export = "res"), NULL)
})
test_that("works with only UI input", {
  expect_snapshot(module2app_ui(module_ui = counter_button_ui))
  driver <- local_app_driver(shinytest2_app_fn(
    source_pef("module2app", "simple", "only-ui")
  ))
  driver$expect_text("#test_object-button")
})
test_that("works with only server input", {
  shiny::testServer(
    module2app_server(module_server = counter_button_server),
    expect_equal(res(), 0)
  )
  driver <- local_app_driver(shinytest2_app_fn(
    source_pef("module2app", "simple", "only-server")
  ))
  expect_equal(driver$get_value(export = "res"), 0)
})
test_that("works with both inputs", {
  driver <- local_app_driver(shinytest2_app_fn(
    source_pef("module2app", "simple", "both-funs")
  ))
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
  driver <- local_app_driver(shinytest2_app_fn(
    source_pef("module2app", "simple", "args")
  ))
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
test_that("shows module inputs, UI and returns in screenshots", {
  purrr::walk(
    glue::glue("double-counter-00{1:4}.png"),
    testthat::announce_snapshot_file
  )
  # linux screenshots are the canonical source for the docs
  skip_on_os(c("windows", "mac", "solaris"))
  driver <- local_app_driver(
    shinytest2_app_fn(source_pef("module2app", "simple", "args")),
    screenshot_args = list(selector = ".container-fluid", expand = 15),
    name = "double-counter",
    variant = "linux"
  )
  driver$expect_screenshot()
  purrr::walk(1:3, function(click) {
    driver$click("test_object-button")
    driver$expect_screenshot()
  })
})
test_that("works with only server args", {
  driver <- local_app_driver(shinytest2_app_fn(
    module2app(server_args = list(c(1, 2)))
  ))
  expect_equal(
    driver$get_value(output = "inputs-eval"),
    "[[1]]\n[1] 1 2"
  )
})
test_that("works with `shiny.tag` returns", {
  driver <- local_app_driver(shinytest2_app_fn(
    module2app(server_args = list(bar = 1, zap = htmltools::p()))
  ))
  expect_snapshot(
    driver$get_value(output = "inputs-eval"),
    transform = purrr::compose(elf::transform_with_generated)
  )
})
test_that("works with S3-classed return", {
  expect_no_condition({
    local_app_driver(shinytest2_app_fn(
      module2app(
        server_args = list(zap = shiny::reactive(bsicons::bs_icon("heart")))
      )
    ))
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
  driver <- local_app_driver(shinytest2_app_fn(
    source_pef("module2app", "nested", "deep")
  ))
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
correct_attr <- list(
  selector = paste0("#", inner_module_id, " > *"),
  region = "border"
)
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

describe("module2app_bare", {
  it("shows only the module UI", {
    expect_snapshot(module2app_bare_ui(module_ui = counter_button_ui))
  })
  it("mounts the module server with arguments", {
    shiny::testServer(
      module2app_bare_server(
        module_server = counter_button_server,
        server_args = list(set_to = 10L)
      ),
      expr = {
        expect_equal(res(), 10L)
        session$setInputs(`test_object-button` = 1)
        expect_equal(res(), 11L)
      }
    )
  })
  it("exports the reactlog events of its session", {
    driver <- local_app_driver(
      counter_button_app,
      options = list(shiny.reactlog = TRUE)
    )
    driver$click(selector = "#test_object-button")
    log <- driver$get_value(export = "reactlog")
    labels <- purrr::map_chr(
      purrr::keep(log, \(e) e$action == "define"),
      "label"
    )
    expect_contains(labels, c("input$test_object-button", "crow_server_args"))
    expect_length(unique(unlist(purrr::map(log, "session"))), 1)
  })
  it("exports no reactlog events without logging", {
    driver <- local_app_driver(counter_button_app)
    expect_equal(driver$get_value(export = "reactlog"), list())
  })
  it("exports the trees of server arguments and return values", {
    driver <- local_app_driver(shinytest2_app_fn(
      module2app_bare(
        x_counter_button_ui,
        x_counter_button_server,
        server_args = list(deep = TRUE)
      )
    ))
    expect_equal(
      driver$get_value(export = "server_args"),
      list(unevaluated = "$deep\n[1] TRUE", evaluated = "$deep\n[1] TRUE")
    )
    returns <- driver$get_value(export = "returns")
    expect_snapshot(cat(returns$unevaluated))
    expect_snapshot(cat(returns$evaluated))
  })
  it("screenshots the module with its padding and border", {
    path <- withr::local_tempfile(fileext = ".png")
    driver <- local_app_driver(shinytest2_app_fn(module2app_bare(
      function(id) {
        shiny::div(
          id = id,
          style = "width: 100px; height: 50px; padding: 10px; border: 5px solid"
        )
      }
    )))
    driver$get_screenshot(file = path)
    expect_equal(
      unlist(magick::image_info(magick::image_read(path))[c(
        "width",
        "height"
      )]),
      c(width = 100, height = 50)
    )
  })
  it("screenshots the same module as module2app", {
    screenshot_info <- function(app) {
      path <- withr::local_tempfile(fileext = ".png")
      local_app_driver(app)$get_screenshot(file = path)
      magick::image_info(magick::image_read(path))[c("width", "height")]
    }
    expect_equal(
      screenshot_info(shinytest2_app_fn(
        module2app_bare(counter_button_ui, counter_button_server)
      )),
      screenshot_info(counter_button_app)
    )
  })
})
test_that("module2app exports the trees it displays", {
  driver <- local_app_driver(shinytest2_app_fn(
    source_pef("module2app", "nested", "deep")
  ))
  returns <- driver$get_value(export = "returns")
  expect_equal(returns$evaluated, driver$get_value(output = "returns-eval"))
  expect_equal(returns$unevaluated, driver$get_value(output = "returns-unev"))
  server_args <- driver$get_value(export = "server_args")
  expect_equal(server_args$evaluated, driver$get_value(output = "inputs-eval"))
})

browsable_p <- htmltools::browsable(htmltools::p())

local_failing_viewer <- function(.local_envir = parent.frame()) {
  withr::local_options(
    viewer = \(url, ...) stop("Viewer called."),
    .local_envir = .local_envir
  )
}

describe("tree_text", {
  it("prints flat returns", {
    tree <- shiny::reactive(2L)
    expect_equal(
      tree_text(tree),
      list(
        unevaluated = paste(capture.output(tree), collapse = "\n"),
        evaluated = "[1] 2"
      )
    )
  })
  it("prints deeply nested returns, including reactives of reactives", {
    shiny::testServer(
      module2app_bare_server(
        x_counter_button_server,
        server_args = list(deep = TRUE)
      ),
      expr = {
        session$setInputs(`test_object-set_count-button` = 1)
        expect_snapshot(cat(tree_text(res)$evaluated))
      }
    )
  })
  it("evaluates outside of reactive contexts", {
    expect_equal(
      tree_text(list(shiny::reactiveVal(1L)))$evaluated,
      "[[1]]\n[1] 1"
    )
  })
  it("prints shiny tags", {
    expect_equal(tree_text(htmltools::p())$evaluated, "<p></p>")
  })
  it("prints browsable leaves as text, without the viewer", {
    local_failing_viewer()
    expect_equal(
      tree_text(browsable_p),
      list(unevaluated = "<p></p>", evaluated = "<p></p>")
    )
    expect_equal(
      tree_text(list(a = list(browsable_p))),
      list(
        unevaluated = "$a\n$a[[1]]\n<p></p>\n",
        evaluated = "$a\n$a[[1]]\n<p></p>\n"
      )
    )
    expect_equal(
      tree_text(shiny::reactive(list(a = browsable_p)))$evaluated,
      "$a\n<p></p>"
    )
  })
  it("prints classed lists without walking them", {
    time <- as.POSIXlt("2026-01-01", tz = "UTC")
    expect_equal(print_text(list(time)), "[[1]]\n[1] \"2026-01-01 UTC\"")
  })
})

describe("mixed_react_tree_server", {
  it("prints browsable leaves as text, without the viewer", {
    local_failing_viewer()
    shiny::testServer(
      mixed_react_tree_server,
      args = list(tree = list(a = browsable_p)),
      expr = {
        expect_equal(output$unev, "$a\n<p></p>")
        expect_equal(output$eval, "$a\n<p></p>")
      }
    )
  })
})

describe("crow_server_args", {
  it("overrides reactive server arguments", {
    shiny::testServer(
      module2app_bare_server(
        counter_button_server,
        server_args = list(increment_by = shiny::reactiveVal(1L))
      ),
      expr = {
        session$setInputs(crow_server_args = list(increment_by = 5))
        session$setInputs(`test_object-button` = 1)
        expect_equal(res(), 5)
        session$setInputs(crow_server_args = list(increment_by = NULL))
        session$setInputs(`test_object-button` = 2)
        expect_equal(res(), 6)
      }
    )
  })
  it("rejects unknown and non-reactive arguments", {
    shiny::testServer(
      module2app_bare_server(
        counter_button_server,
        server_args = list(set_to = 0L, increment_by = shiny::reactiveVal(1L))
      ),
      expr = {
        expect_snapshot(
          session$setInputs(
            crow_server_args = list(increment_by = 5, set_to = 3, foo = 1)
          )
        )
        session$setInputs(`test_object-button` = 1)
        expect_equal(res(), 1L)
      }
    )
  })
  it("rejects values other than JSON objects", {
    shiny::testServer(
      module2app_bare_server(counter_button_server),
      expect_snapshot(session$setInputs(crow_server_args = 5))
    )
  })
  it("overrides server arguments in a running app", {
    driver <- local_app_driver(shinytest2_app_fn(
      source_pef("module2app", "simple", "args")
    ))
    driver$set_inputs(
      crow_server_args = list(increment_by = 5),
      allow_no_input_binding_ = TRUE
    )
    driver$click(selector = "#test_object-button")
    expect_equal(driver$get_value(export = "res"), 105)
    expect_equal(
      driver$get_value(output = "inputs-eval"),
      "$set_to\n[1] 100\n\n$increment_by\n[1] 5"
    )
    expect_equal(
      driver$get_value(export = "server_args"),
      list(
        unevaluated = driver$get_value(output = "inputs-unev"),
        evaluated = driver$get_value(output = "inputs-eval")
      )
    )
  })
  it("shows the original reactives in the unevaluated tree", {
    driver <- local_app_driver(shinytest2_app_fn(
      source_pef("module2app", "simple", "args")
    ))
    driver$set_inputs(
      crow_server_args = list(increment_by = 5),
      allow_no_input_binding_ = TRUE
    )
    expect_equal(
      driver$get_value(output = "inputs-unev"),
      tree_text(
        list(set_to = 100L, increment_by = shiny::reactiveVal(2L))
      )$unevaluated
    )
  })
  it("logs rejected arguments and keeps the app running", {
    driver <- local_app_driver(shinytest2_app_fn(
      source_pef("module2app", "simple", "args")
    ))
    driver$set_inputs(
      crow_server_args = list(set_to = 5),
      allow_no_input_binding_ = TRUE
    )
    expect_match(
      paste(driver$get_logs()$message, collapse = "\n"),
      "Cannot change server argument `set_to`",
      fixed = TRUE
    )
    driver$click(selector = "#test_object-button")
    expect_equal(driver$get_value(export = "res"), 102L)
  })
})
