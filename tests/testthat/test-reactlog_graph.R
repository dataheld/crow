local_reactlog <- function(.local_envir = parent.frame()) {
  withr::local_options(shiny.reactlog = TRUE, .local_envir = .local_envir)
  shiny::reactlogReset()
  withr::defer(shiny::reactlogReset(), envir = .local_envir)
}

describe("reactlog_graph", {
  it("gives the nodes and edges of a module", {
    local_reactlog()
    shiny::testServer(
      counter_button_server,
      args = list(id = "counter"),
      expr = {
        session$setInputs(button = 1)
        graph <- reactlog_graph(session = session$token)
        expect_equal(
          graph$nodes$label,
          c(
            "reactiveVal",
            "count",
            "observeEvent(input$button)",
            "output (unnamed in testServer)",
            "reactive({ count() })",
            "input$counter-button"
          )
        )
        expect_equal(
          format(graph),
          c(
            "count -> output (unnamed in testServer)",
            "input$counter-button -> observeEvent(input$button)",
            "reactiveVal",
            "reactive({ count() })"
          )
        )
      }
    )
  })
  it("gives the edges between nested modules", {
    local_reactlog()
    shiny::testServer(
      x_counter_button_server,
      args = list(id = "x", deep = TRUE),
      expr = {
        session$setInputs(`set_increment-button` = 1)
        session$setInputs(`set_count-button` = 1)
        tree_text(session$returned)
        expect_snapshot(print(reactlog_graph(session = session$token)))
      }
    )
  })
  it("drops the testbed's own nodes", {
    local_reactlog()
    increment_by <- shiny::reactiveVal(1L, label = "increment_by")
    shiny::testServer(
      module2app_bare_server(
        counter_button_server,
        server_args = list(increment_by = increment_by)
      ),
      expr = {
        session$setInputs(crow_server_args = list(increment_by = 5))
        session$setInputs(`test_object-button` = 1)
        expect_equal(
          format(reactlog_graph(session = session$token)),
          c(
            "count -> output (unnamed in testServer)",
            "input$test_object-button -> observeEvent(input$button)",
            "increment_by",
            "reactive({ count() })"
          )
        )
      }
    )
  })
  it("filters to one session", {
    log <- list(
      list(action = "define", reactId = "r1", label = "a", type = "t", session = "s1"),
      list(action = "define", reactId = "r2", label = "b", type = "t", session = "s2"),
      list(action = "define", reactId = "r3", label = "c", type = "t", session = NULL)
    )
    expect_equal(reactlog_graph(log, session = "s1")$nodes$label, c("a", "c"))
    expect_equal(reactlog_graph(log)$nodes$label, c("a", "b", "c"))
  })
  it("is empty without logging", {
    graph <- reactlog_graph(list())
    expect_equal(nrow(graph$nodes), 0)
    expect_equal(format(graph), character(0))
  })
  it("reads the log exported from a running app", {
    driver <- local_app_driver(
      counter_button_app,
      options = list(shiny.reactlog = TRUE)
    )
    driver$click(selector = "#test_object-button")
    expect_snapshot(print(reactlog_graph(driver$get_value(export = "reactlog"))))
  })
  it("exports no events from apps without logging", {
    driver <- local_app_driver(counter_button_app)
    expect_equal(driver$get_value(export = "reactlog"), list())
  })
})

describe("one_line_label", {
  it("shortens code to one line", {
    expect_equal(one_line_label("reactive({\n    count()\n})"), "reactive({ count() })")
    expect_equal(nchar(one_line_label(strrep("x", 100))), 60)
  })
  it("drops the random suffix of anonymous reactive values", {
    expect_equal(one_line_label("reactiveVal3339463e"), "reactiveVal")
    expect_equal(one_line_label("reactiveValues3339463e$x"), "reactiveValues$x")
  })
})

describe("contract_edges", {
  it("connects the dependencies of dropped nodes to their dependents", {
    edges <- data.frame(from = c("a", "b", "b", "c"), to = c("b", "c", "d", "d"))
    expect_equal(
      contract_edges(edges, c("b", "c")),
      data.frame(from = "a", to = "d"),
      ignore_attr = "row.names"
    )
  })
})

describe("format.reactlog_graph", {
  it("numbers duplicated labels", {
    graph <- new_reactlog_graph(
      nodes = data.frame(id = c("r1", "r2", "r3"), label = c("a", "b", "a"), type = "t"),
      edges = data.frame(from = c("r1", "r3"), to = "r2")
    )
    expect_equal(format(graph), c("a [1] -> b", "a [2] -> b"))
  })
})
