test_that("drives an app from a factory", {
  driver <- local_app_driver(counter_button_app)
  driver$click(selector = "#test_object-button")
  expect_equal(driver$get_value(export = "res"), 1L)
})
test_that("stops the driver when the calling frame exits", {
  driver <- local({
    local_app_driver(counter_button_app)
  })
  expect_error(driver$get_value(export = "res"))
})
test_that("runs app factories only in the app's process", {
  withr::local_envvar(CROW_TEST_FACTORY = NA)
  local_app_driver(shinytest2_app_fn({
    Sys.setenv(CROW_TEST_FACTORY = "ran")
    counter_button_app()
  }))
  expect_equal(Sys.getenv("CROW_TEST_FACTORY"), "")
})

describe("screenshots of testbed modules", {
  module_app <- function(ui, server = NULL, ...) {
    local_app_driver(
      shinytest2_app_fn(
        module2app_bare(!!rlang::enexpr(ui), !!rlang::enexpr(server))
      ),
      ...,
      .local_envir = parent.frame()
    )
  }
  it("include positioned descendants, also below the page", {
    driver <- module_app(function(id) {
      shiny::div(
        style = "position: relative; height: 20px",
        shiny::div(style = "position: absolute; height: 2000px; width: 50px")
      )
    })
    expect_equal(screenshot_size(driver)[["height"]], 2000)
  })
  it("leave out what is hidden outside the page", {
    driver <- module_app(function(id) {
      shiny::fileInput(shiny::NS(id, "file"), NULL)
    })
    expect_true(all(screenshot_size(driver) < 1000))
  })
  it("measure after the delay", {
    driver <- module_app(function(id) {
      shiny::div(id = id, style = "height: 50px")
    })
    driver$run_js(paste(
      "const module = document.getElementById('test_object');",
      "setTimeout(() => module.style.height = '200px', 500);"
    ))
    expect_equal(screenshot_size(driver, delay = 1)[["height"]], 200)
  })
  it("leave out what scroll containers hide", {
    driver <- module_app(function(id) {
      shiny::div(
        style = "overflow: auto; height: 50px",
        shiny::div(style = "height: 500px")
      )
    })
    expect_equal(screenshot_size(driver)[["height"]], 50)
  })
  it("include notifications only if asked to", {
    module <- rlang::expr(function(id) shiny::div(style = "height: 50px"))
    notifying <- rlang::expr(function(id) {
      shiny::moduleServer(id, function(input, output, session) {
        shiny::showNotification("Done", duration = NULL)
      })
    })
    without <- module_app(!!module, !!notifying)
    expect_equal(screenshot_size(without)[["height"]], 50)
    with <- module_app(!!module, !!notifying, notifications = TRUE)
    # Shiny shows notifications at the bottom of the window
    stage_top <- with$get_js(sprintf(
      "document.getElementById('%s').getBoundingClientRect().top",
      inner_module_id
    ))
    expect_equal(
      screenshot_size(with)[["height"]],
      with$get_window_size()$height - stage_top
    )
  })
})

test_that("shows the end state of transitions", {
  driver <- local_app_driver(shinytest2_app_fn(module2app_bare(
    function(id) {
      shiny::div(
        id = id,
        style = "width: 10px; height: 10px; transition: width 0.3s"
      )
    }
  )))
  width <- "document.getElementById('test_object').offsetWidth"
  expect_equal(
    driver$get_js(paste(
      "document.getElementById('test_object').style.width = '300px';",
      width
    )),
    300
  )
})
