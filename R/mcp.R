# MCP tools ====

#' Tools for coding agents to run shiny modules
#'
#' Lets coding agents run a shiny module of an R package,
#' set its inputs, read its arguments, return values and outputs,
#' and screenshot it,
#' through the [Model Context Protocol](https://modelcontextprotocol.io).
#' The module runs in [module2app_bare()],
#' the testbed without displays for humans.
#'
#' @details
#' The tools offer two tiers of cost:
#' - `module_test_server` runs [shiny::testServer()]
#'   on [module2app_bare_server()] in a new R process,
#'   without a browser.
#'   It takes a few seconds and keeps no state.
#' - `module_app_start` runs [module2app_bare()] in a new R process
#'   and drives it with [`shinytest2::AppDriver`] in Chrome.
#'   It takes about ten seconds to start,
#'   and runs until `module_app_stop`.
#'   `module_app_set`, `module_app_get` and `module_app_screenshot`
#'   use the running app.
#'
#' All tools report the server arguments and return values
#' as unevaluated and evaluated trees (see [mixed_react_tree()]),
#' the raw events of [shiny::reactlog()] on request,
#' and the logs of their R and shiny processes,
#' errors first.
#'
#' Every tool starts its R processes in `path`,
#' the package root with the `DESCRIPTION`,
#' and loads the package from there with [pkgload::load_all()],
#' so it runs the working tree, not an installed version.
#' Running apps load the package when they start;
#' restart them after changing the package.
#' Each app runs in its own processes,
#' which end when the app or the MCP server stops.
#'
#' @section Security:
#' The tools evaluate the R code that the agent passes,
#' such as `server_args`,
#' with the rights of the user running the MCP server.
#' Only a sandbox around the agent and the MCP server
#' isolates your system from that code.
#' Changes to running apps (`module_app_set`) accept only JSON,
#' because the apps listen on local websockets
#' that any web page in the same browser could reach.
#'
#' @return
#' - `crow_tools()`: A named list of [ellmer::tool()]s.
#' - `crow_mcp_server()`: Does not return;
#'   serves the tools until the MCP client disconnects.
#' @examples
#' \dontrun{
#' # combine with btw's tools for documentation and package development
#' mcptools::mcp_server(
#'   c(btw::btw_tools(c("docs", "pkg")), crow::crow_tools()),
#'   session_tools = FALSE
#' )
#' }
#' @family agentic coding
#' @export
crow_tools <- function() {
  path <- ellmer::type_string(paste(
    "Absolute path to the R package root, which contains `DESCRIPTION`.",
    "Its working tree is loaded."
  ))
  r_code <- function(description) {
    ellmer::type_string(description, required = FALSE)
  }
  server <- r_code(
    "R code giving the module server function, e.g. `counter_button_server`."
  )
  server_args <- r_code(paste(
    "R code giving a named list of arguments to the module server,",
    "e.g. `list(increment_by = shiny::reactiveVal(1L))`.",
    "Only reactives passed here can be changed later."
  ))
  reactlog <- ellmer::type_boolean(
    paste(
      "Whether to report the raw events of shiny::reactlog() for the",
      "module's session, one JSON object per line, to inspect which reactives",
      "depend on which. The testbed's own reactives are labelled `crow_*`.",
      "Long; request it only when needed."
    ),
    required = FALSE
  )
  id <- ellmer::type_string("ID of the running app, from module_app_start.")
  tools <- list(
    ellmer::tool(
      reporting(module_test_server),
      name = "module_test_server",
      description = paste(
        "Run shiny::testServer() on a module server, in a new R process,",
        "without a browser (a few seconds).",
        "Use this first: it answers questions about server logic,",
        "reactive inputs and return values.",
        "It cannot show rendered HTML, JavaScript or layout;",
        "use module_app_start for those.",
        "Reports the value of `expr`, the server arguments and return value",
        "as unevaluated and evaluated trees, and the logs.",
        "Runs the package's working tree, reloaded on every call."
      ),
      arguments = list(
        path = path,
        server = server,
        server_args = server_args,
        expr = r_code(paste(
          "R code run inside shiny::testServer(), with `session`, `input`",
          "and `output`. The module has ID `test_object`, so set its inputs",
          "with session$setInputs(`test_object-button` = 1),",
          "read outputs as output$`test_object-out`, and change reactive",
          "server arguments with",
          "session$setInputs(crow_server_args = list(increment_by = 5))."
        )),
        reactlog = reactlog
      )
    ),
    ellmer::tool(
      reporting(module_app_start),
      name = "module_app_start",
      description = paste(
        "Start a module in a bare test app, driven by shinytest2 in Chrome",
        "(about ten seconds). Use it only for questions about the rendered",
        "module: HTML, JavaScript, layout, screenshots; otherwise use",
        "module_test_server.",
        "Returns the app ID, its URL (a human opening it gets a separate",
        "session), the trees of server arguments and return value, and logs.",
        "The app keeps the package code from its start:",
        "after changing the package, stop and start it again.",
        "Stop it with module_app_stop when done."
      ),
      arguments = list(
        path = path,
        ui = r_code(
          "R code giving the module UI function, e.g. `counter_button_ui`."
        ),
        server = server,
        ui_args = r_code(
          "R code giving a named list of arguments to the module UI."
        ),
        server_args = server_args,
        ui_wrapper = r_code(paste(
          "R code giving a function to wrap the module UI in a page,",
          "e.g. `bslib::page_fluid`. Defaults to `shiny::basicPage`."
        ))
      )
    ),
    ellmer::tool(
      reporting(module_app_set),
      name = "module_app_set",
      description = paste(
        "Change a running module app, then wait until it is idle.",
        "Reports the trees and the new logs."
      ),
      arguments = list(
        id = id,
        inputs = ellmer::type_string(
          paste(
            "JSON object of module input values by input ID without the",
            "module namespace, e.g. {\"button\": \"click\", \"n\": 3}.",
            "Use \"click\" for action buttons."
          ),
          required = FALSE
        ),
        server_args = ellmer::type_string(
          paste(
            "JSON object of new values for reactive server arguments,",
            "e.g. {\"increment_by\": 5}; null restores the start value."
          ),
          required = FALSE
        )
      )
    ),
    ellmer::tool(
      reporting(module_app_get),
      name = "module_app_get",
      description = paste(
        "Report a running module app: trees of server arguments and",
        "return value, the module's outputs, and the new logs."
      ),
      arguments = list(id = id, reactlog = reactlog)
    ),
    ellmer::tool(
      reporting(module_app_screenshot),
      name = "module_app_screenshot",
      description = paste(
        "Screenshot the module UI of a running app, without anything",
        "around it. Returns the path of the PNG file; open it to look at it."
      ),
      arguments = list(id = id)
    ),
    ellmer::tool(
      reporting(module_app_stop),
      name = "module_app_stop",
      description = "Stop a running module app and report its last logs.",
      arguments = list(id = id)
    )
  )
  rlang::set_names(tools, purrr::map_chr(tools, \(x) x@name))
}

#' @rdname crow_tools
#' @export
crow_mcp_server <- function() {
  reg.finalizer(the, \(e) purrr::walk(names(e$apps), app_close), onexit = TRUE)
  mcptools::mcp_server(tools = crow_tools(), session_tools = FALSE)
}

#' Returns errors as reports,
#' because mcptools turns them into protocol errors,
#' which clients may not show to the agent.
#' @noRd
reporting <- function(fun) {
  call <- rlang::call2(fun, !!!rlang::fn_fmls_syms(fun))
  rlang::new_function(
    rlang::fn_fmls(fun),
    rlang::expr(tryCatch(!!call, error = report_error))
  )
}

report_error <- function(cnd) {
  agent_report(list(Error = conditionMessage(cnd)))
}

the <- new.env(parent = emptyenv())
the$apps <- list()

# tier I: testServer ====

module_test_server <- function(
  path,
  server = "NULL",
  server_args = "list()",
  expr = "NULL",
  reactlog = FALSE
) {
  log <- tempfile(fileext = ".log")
  on.exit(unlink(log))
  sections <- tryCatch(
    callr::r(
      child_call,
      args = list(
        "test_server_sections",
        list(server, server_args, expr, reactlog),
        path
      ),
      wd = path,
      stdout = log,
      stderr = "2>&1",
      timeout = 120
    ),
    error = \(cnd) list(Error = conditionMessage(cnd))
  )
  agent_report(sections, log = readLines(log))
}

#' Runs in the R process at the package root.
#' @noRd
test_server_sections <- function(server, server_args, expr, reactlog) {
  env <- new.env(parent = asNamespace(pkgload::pkg_name()))
  server <- eval(rlang::parse_expr(server), env)
  server_args <- eval(rlang::parse_expr(server_args), env)
  expr <- rlang::parse_expr(paste0("{\n", expr, "\n}"))
  options(shiny.reactlog = reactlog)
  sections <- list()
  conditions <- character()
  record <- function(value, env) {
    session <- get("session", envir = env)
    sections[["Value of `expr`"]] <<- print_text(value)
    sections <<- c(sections, testbed_sections(session$userData))
    if (reactlog) {
      sections[["Reactlog events"]] <<- reactlog_lines(
        session_reactlog(shiny::reactlog(), session$token)
      )
    }
  }
  tryCatch(
    withCallingHandlers(
      rlang::inject(shiny::testServer(
        module2app_bare_server(server, server_args),
        record(!!expr, environment())
      )),
      message = \(cnd) {
        conditions[[length(conditions) + 1]] <<- conditionMessage(cnd)
        invokeRestart("muffleMessage")
      },
      warning = \(cnd) {
        conditions[[length(conditions) + 1]] <<- conditionMessage(cnd)
        invokeRestart("muffleWarning")
      }
    ),
    error = \(cnd) {
      sections[["Error"]] <<- conditionMessage(cnd)
    }
  )
  c(sections, list(`Messages and warnings` = conditions))
}

testbed_sections <- function(user_data) {
  testbed <- user_data$crow_testbed
  tree_sections(
    server_args = tree_text(testbed$server_args, testbed$effective_args),
    returns = tree_text(testbed$res)
  )
}

tree_sections <- function(server_args, returns) {
  list(
    `Server arguments (unevaluated)` = server_args$unevaluated,
    `Server arguments (evaluated)` = server_args$evaluated,
    `Return value (unevaluated)` = returns$unevaluated,
    `Return value (evaluated)` = returns$evaluated
  )
}

# tier II: running apps ====

module_app_start <- function(
  path,
  ui = "NULL",
  server = "NULL",
  ui_args = "list()",
  server_args = "list()",
  ui_wrapper = "shiny::basicPage"
) {
  app <- rlang::call2(
    rlang::expr(crow::module2app_bare),
    module_ui = rlang::parse_expr(ui),
    module_server = rlang::parse_expr(server),
    ui_args = rlang::parse_expr(ui_args),
    server_args = rlang::parse_expr(server_args),
    ui_wrapper = rlang::parse_expr(ui_wrapper)
  )
  the$n <- (the$n %||% 0L) + 1L
  id <- paste0("app", the$n)
  log <- tempfile(fileext = ".log")
  on.exit(unlink(log))
  the$apps[[id]] <- callr::r_session$new(
    callr::r_session_options(supervise = TRUE, stdout = log, stderr = log)
  )
  sections <- tryCatch(
    app_run(id, "app_start_child", list(app), path = path),
    error = \(cnd) list(Error = conditionMessage(cnd))
  )
  log <- read_log(log)
  if (!is.null(sections$Error)) {
    app_close(id)
  }
  sections <- c(list(App = paste("ID:", id)), sections)
  agent_report(sections, log = log)
}

read_log <- function(path) {
  if (file.exists(path)) readLines(path, warn = FALSE) else character()
}

module_app_set <- function(id, inputs = "{}", server_args = "{}") {
  agent_report(app_run(
    id,
    "app_set_child",
    list(jsonlite::fromJSON(inputs), jsonlite::fromJSON(server_args))
  ))
}

module_app_get <- function(id, reactlog = FALSE) {
  agent_report(app_run(id, "app_sections", list(TRUE, reactlog)))
}

module_app_screenshot <- function(id) {
  file <- file.path(
    tempdir(),
    paste0("crow-", id, "-", Sys.time() |> as.numeric(), ".png")
  )
  agent_report(app_run(id, "app_screenshot_child", list(file)))
}

module_app_stop <- function(id) {
  sections <- app_run(id, "app_stop_child")
  app_close(id)
  agent_report(c(list(App = paste("Stopped", id)), sections))
}

app_run <- function(id, fun, args = list(), path = NULL, timeout = 120) {
  session <- the$apps[[id]]
  if (is.null(session)) {
    rlang::abort(paste0(
      "No running app with ID `",
      id,
      "`. Start one with module_app_start."
    ))
  }
  session$call(child_call, list(fun, args, path))
  if (session$poll_process(timeout * 1000) == "timeout") {
    app_close(id)
    rlang::abort(paste0(
      "App `",
      id,
      "` did not answer within ",
      timeout,
      "s and was stopped."
    ))
  }
  res <- session$read()
  if (!is.null(res$error)) {
    rlang::abort(conditionMessage(res$error$parent %||% res$error))
  }
  res$result
}

app_close <- function(id) {
  session <- the$apps[[id]]
  if (!is.null(session)) {
    session$close()
  }
  the$apps[[id]] <- NULL
}

#' Calls a crow function in a child R process.
#' Looks it up only after loading the package at `path`,
#' so that developing crow itself runs its working tree.
#' @noRd
child_call <- function(fun, args, path = NULL) {
  if (!is.null(path)) {
    setwd(path)
    pkgload::load_all(quiet = TRUE)
  }
  do.call(utils::getFromNamespace(fun, "crow"), args, quote = TRUE)
}

# These run in the R process of the app, at the package root.

app_start_child <- function(app) {
  factory <- rlang::new_function(NULL, app, asNamespace(pkgload::pkg_name()))
  lifetime <- new.env()
  driver <- local_app_driver(
    factory,
    options = list(shiny.reactlog = TRUE),
    .local_envir = lifetime
  )
  assign(
    "crow_app",
    list(driver = driver, lifetime = lifetime, logs_seen = character()),
    envir = globalenv()
  )
  c(list(URL = driver$get_url()), app_sections())
}

app_set_child <- function(inputs, server_args) {
  driver <- crow_app()$driver
  if (length(server_args) > 0) {
    driver$set_inputs(
      crow_server_args = server_args,
      allow_no_input_binding_ = TRUE,
      wait_ = FALSE
    )
  }
  if (length(inputs) > 0) {
    names(inputs) <- paste0("test_object-", names(inputs))
    rlang::exec(driver$set_inputs, !!!inputs, wait_ = FALSE)
  }
  driver$wait_for_idle()
  app_sections()
}

app_screenshot_child <- function(file) {
  crow_app()$driver$get_screenshot(file)
  c(list(Screenshot = file), app_sections(trees = FALSE))
}

app_stop_child <- function() {
  withr::deferred_run(crow_app()$lifetime)
  list(Log = new_log_lines())
}

app_sections <- function(
  outputs = FALSE,
  reactlog = FALSE,
  trees = TRUE
) {
  driver <- crow_app()$driver
  sections <- list()
  if (trees) {
    sections <- tree_sections(
      server_args = driver$get_value(export = "server_args"),
      returns = driver$get_value(export = "returns")
    )
  }
  if (outputs) {
    values <- driver$get_values(input = FALSE, output = TRUE, export = FALSE)
    values <- values$output[startsWith(names(values$output), "test_object-")]
    sections[["Module outputs"]] <- paste0(
      "output$`",
      names(values),
      "`: ",
      purrr::map_chr(values, \(x) print_text(x))
    )
  }
  if (reactlog) {
    sections[["Reactlog events"]] <- reactlog_lines(
      driver$get_value(export = "reactlog")
    )
  }
  c(sections, list(Log = new_log_lines()))
}

crow_app <- function() get("crow_app", envir = globalenv())

reactlog_lines <- function(events) {
  purrr::map_chr(
    events,
    \(event) jsonlite::toJSON(event, auto_unbox = TRUE, null = "null")
  )
}

new_log_lines <- function() {
  app <- crow_app()
  logs <- as.data.frame(app$driver$get_logs())
  logs <- logs[logs$level != "websocket", ]
  lines <- paste0("[", logs$location, " ", logs$level, "] ", logs$message)
  # shinytest2 rereads the app's output, so rows are not stable
  keys <- paste(format(logs$timestamp, "%OS6"), lines)
  new <- !keys %in% app$logs_seen
  app$logs_seen <- c(app$logs_seen, keys[new])
  assign("crow_app", app, envir = globalenv())
  lines[new]
}

# report ====

#' Formats sections as markdown for agents,
#' with errors and warnings first.
#' @noRd
agent_report <- function(sections, log = character()) {
  sections[["Log"]] <- c(sections[["Log"]], log)
  sections <- c(
    sections["Error"],
    list(`Errors and warnings in the log` = log_problems(sections[["Log"]])),
    sections[setdiff(names(sections), "Error")]
  )
  sections <- purrr::compact(sections)
  sections <- sections[lengths(sections) > 0]
  if (length(sections) == 0) {
    return("Nothing to report.")
  }
  paste0(
    "## ",
    names(sections),
    "\n",
    purrr::map_chr(sections, \(x) paste(x, collapse = "\n")),
    collapse = "\n\n"
  )
}

#' Lines mentioning errors or warnings,
#' with the lines of their condition messages which follow,
#' such as the `!` and `i` bullets of rlang.
#' @noRd
log_problems <- function(lines) {
  text <- sub("^\\[[^]]*\\] ", "", lines)
  problem <- grepl("error|warning", text, ignore.case = TRUE)
  continues <- grepl(
    "^(!|\u2139|\u2716|\u2022|\\s|Caused by|Backtrace|[0-9]+\\. )",
    text
  )
  for (i in seq_along(lines)[-1]) {
    problem[i] <- problem[i] || (problem[i - 1] && continues[i])
  }
  lines[problem]
}
