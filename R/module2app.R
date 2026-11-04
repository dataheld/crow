# testbed core ====

new_testbed <- function(testbed_ui, testbed_server) {
  force(testbed_ui)
  force(testbed_server)
  function(
    module_ui = NULL,
    module_server = NULL,
    ui_args = list(),
    server_args = list(),
    ui_wrapper = shiny::basicPage,
    options = list(test.mode = TRUE),
    ...
  ) {
    res <- shiny::shinyApp(
      ui = testbed_ui(module_ui, ui_args, ui_wrapper = ui_wrapper),
      server = testbed_server(module_server, server_args),
      options = options,
      ...
    )
    attributes(res) <- c(
      attributes(res),
      list(
        crow_screenshot_args = list(
          # need to select down to child
          # because only that actually has a height
          # the parent div may not, and will then fail the screenshot
          selector = paste0("#", inner_module_id, " > *")
        )
      )
    )
    res
  }
}

mount_server <- function(
  module_server,
  server_args,
  display = function(server_args, effective_args, returns) NULL
) {
  checkmate::assert_function(module_server, args = c("id"), null.ok = TRUE)
  checkmate::assert_list(server_args)
  # created outside the server function, so all sessions share them
  overrides <- purrr::imap(
    reactive_args(server_args),
    \(x, name) shiny::reactiveVal(label = paste0("crow_override_", name))
  )
  effective_args <- server_args
  effective_args[names(overrides)] <- purrr::pmap(
    list(server_args[names(overrides)], overrides, names(overrides)),
    overridable
  )
  if (is.null(module_server)) {
    module_server <- no_fun_provided_server
  } else {
    # partialising above boilerplate with server args makes no sense
    module_server <- purrr::partial(module_server, !!!effective_args)
  }
  function(input, output, session) {
    shiny::observeEvent(
      input$crow_server_args,
      set_overrides(overrides, input$crow_server_args),
      label = "crow_server_args"
    )
    res <- module_server(id = "test_object")
    shiny::exportTestValues(
      res = fix_test_returns(res),
      server_args = tree_text(server_args, effective_args),
      returns = tree_text(res),
      reactlog = session_reactlog(shiny::reactlog(), session$token)
    )
    display(server_args, effective_args, res)
    res
  }
}

reactive_args <- function(server_args) {
  purrr::keep(server_args[rlang::names2(server_args) != ""], shiny::is.reactive)
}

overridable <- function(original, override, name) {
  shiny::reactive(
    if (is.null(override())) original() else override(),
    label = paste0("crow_server_arg_", name)
  )
}

#' Errors would end the session,
#' so they only go to stderr and a notification.
#' @noRd
set_overrides <- function(overrides, values) {
  tryCatch(
    {
      check_overridable(values, names(overrides))
      purrr::iwalk(values, \(value, name) overrides[[name]](value))
    },
    error = function(cnd) {
      message(rlang::cnd_message(cnd, prefix = TRUE))
      shiny::showNotification(conditionMessage(cnd), type = "error")
    }
  )
}

check_overridable <- function(values, overridable) {
  if (!is.list(values) || !rlang::is_named(values)) {
    rlang::abort(
      "`crow_server_args` must be a JSON object keyed by server argument name.",
      call = NULL
    )
  }
  rejected <- setdiff(names(values), overridable)
  if (length(rejected) > 0) {
    rlang::abort(
      c(
        paste(
          ngettext(
            length(rejected),
            "Cannot change server argument",
            "Cannot change server arguments"
          ),
          backticks(rejected)
        ),
        i = paste(
          "Only reactive arguments passed in `server_args` can change:",
          if (length(overridable) > 0) backticks(overridable) else "none."
        )
      ),
      call = NULL
    )
  }
}

backticks <- function(x) paste0("`", x, "`", collapse = ", ")

# module2app helper ====

#' @describeIn module2app UI
#' @param ui_wrapper
#' A function to wrap the resulting [shiny::tagList()] in.
#' Must yield a full shiny UI,
#' such as [shiny::basicPage()] or [shiny::bootstrapPage()].
#' For maximum reusability of a module,
#' avoid depending on the wrapper and only return "vanilla" UI.
#' @example inst/examples/module2app/ui/navbar.R
#' @example inst/examples/module2app/ui/bootstrap.R
#' @export
module2app_ui <- function(
  module_ui = NULL,
  ui_args = list(),
  ui_wrapper = shiny::basicPage
) {
  ui_wrapper(
    shiny::h1(shiny::code("module2app"), "Testbed"),
    shiny::h2("Server Input Arguments"),
    mixed_react_tree_ui("inputs"),
    shiny::h2("Module UI"),
    module_div(module_ui, ui_args),
    shiny::h2("Server Return Values"),
    mixed_react_tree_ui("returns")
  )
}

module_div <- function(module_ui = NULL, ui_args = list()) {
  checkmate::assert_function(module_ui, args = c("id"), null.ok = TRUE)
  if (is.null(module_ui)) {
    module_ui <- no_fun_provided_ui
  }
  checkmate::assert_list(ui_args)
  module_ui <- purrr::partial(module_ui, !!!ui_args)
  shiny::div(
    module_ui(id = "test_object"),
    id = inner_module_id
  )
}

inner_module_id <- "crow-module2app-module-ui"

#' @describeIn module2app Server
#' @export
module2app_server <- function(module_server = NULL, server_args = list()) {
  mount_server(module_server, server_args, display = display_trees)
}

display_trees <- function(server_args, effective_args, returns) {
  tree_server(id = "inputs", tree = server_args, evaluated = effective_args)
  mixed_react_tree_server(id = "returns", tree = returns)
}

#' Show a module in a full app
#'
#' During development of shiny modules,
#' it can be helpful to see and test a module in the context of a shiny app.
#' This function wraps the module UI and server functions in full shiny
#' app for those purposes.
#' You can also pass reactive values to the server function,
#' to observe how your module reacts to them.
#'
#' @details
#' If you only want to test the server logic of a module,
#' you don't need this function.
#' You can just pass the module server function to [shiny::testServer()].
#' Hadley Wickhams Mastering Shiny as a section on
#' [testing modules](https://mastering-shiny.org/scaling-testing.html#modules).
#'
#' See [mixed_react_tree()] for details on the shown input and return values.
#' See [module2app_bare()] for the values exported for tests,
#' for changing reactive `server_args` while the app runs,
#' and for a testbed without these displays.
#'
#' If you are testing screenshots,
#' you are recommended to use [get_screenshot_args_attr()]
#' to screenshot only your actual module UI,
#' without the surrounding *crow* boilerplate.
#'
#' @param module_ui,module_server
#' Module functions.
#' @param ui_args,server_args
#' Additional arguments passed to `module_server`and `module_ui`.
#' `server_args` can be [shiny::reactive()]s,
#' if corresponding argument in `module_server` accepts it.
#' Named reactive `server_args` can change while the app runs
#' (see [module2app_bare()]).
#' @inheritParams shiny::shinyApp
#' @inheritDotParams shiny::shinyApp
#' @family modules
#' @export
module2app <- new_testbed(module2app_ui, module2app_server)

# module2app_bare helper ====

#' @describeIn module2app_bare UI
#' @export
module2app_bare_ui <- function(
  module_ui = NULL,
  ui_args = list(),
  ui_wrapper = shiny::basicPage
) {
  ui_wrapper(module_div(module_ui, ui_args))
}

#' @describeIn module2app_bare Server
#' @export
module2app_bare_server <- function(
  module_server = NULL,
  server_args = list()
) {
  mount_server(module_server, server_args)
}

#' Show only a module in a bare app
#'
#' Mounts a module like [module2app()], but without its headings and displays.
#' The app shows only the module UI,
#' so screenshots of the whole page show only the module.
#' Use it for automated checks, such as by coding agents or in tests;
#' use [module2app()] to look at a module yourself.
#'
#' @details
#' Both testbeds mount the module with the ID `test_object`
#' and export these values for [`shinytest2::AppDriver`]'s `$get_value()`:
#' - `res`: the return value of the module server,
#'   called if it is a reactive.
#' - `server_args`, `returns`:
#'   the server arguments and the return values,
#'   each a list of the `unevaluated` and `evaluated` tree,
#'   as text identical to the display of [module2app()]
#'   (see [mixed_react_tree()]).
#' - `reactlog`: the events of [shiny::reactlog()] for this session,
#'   for [reactlog_graph()].
#'   Empty, unless the app runs with `options(shiny.reactlog = TRUE)`,
#'   such as from `local_app_driver(options = list(shiny.reactlog = TRUE))`.
#'
#' Unlike [module2app()],
#' the bare testbed adds no outputs which depend on the module's reactives.
#' It evaluates the trees only when they are requested.
#' Its reactive graph is thus the same as that of an app
#' which only uses the module.
#'
#' @section Changing server arguments while the app runs:
#' Both testbeds read the hidden input `crow_server_args`,
#' a JSON object keyed by server argument name.
#' Its values replace the values of these arguments,
#' for all sessions of the app.
#' A `null` restores the value passed at start.
#' The module receives each named reactive in `server_args`
#' wrapped in a [shiny::reactive()],
#' so it cannot set the original [shiny::reactiveVal()].
#' Other server arguments are fixed at start.
#' The displayed and exported `server_args` show the reactives as passed,
#' but evaluate to the current values.
#'
#' From R, through [`shinytest2::AppDriver`] (see [local_app_driver()]):
#' ```r
#' driver$set_inputs(
#'   crow_server_args = list(increment_by = 5),
#'   allow_no_input_binding_ = TRUE
#' )
#' ```
#' From the browser console:
#' ```js
#' Shiny.setInputValue("crow_server_args", {increment_by: 5})
#' ```
#' JSON numbers arrive as doubles.
#' The input accepts only JSON, never R code,
#' because the app does not check the origin of websocket connections:
#' any web page open in the same browser can send this input.
#'
#' Changing an unknown or a non-reactive argument changes nothing.
#' The error goes to the app's standard error and a notification,
#' because an error would end the session.
#'
#' @inheritParams module2app
#' @inheritParams module2app_ui
#' @inheritDotParams shiny::shinyApp
#' @family modules
#' @export
module2app_bare <- new_testbed(
  module2app_bare_ui,
  module2app_bare_server
)

#' Need to protect against non-reactive values
#' @noRd
fix_test_returns <- function(x) {
  if (shiny::is.reactive(x)) {
    x()
  } else {
    x
  }
}

no_fun_provided_ui <- function(id, x = "ui") {
  shiny::NS(id) # unused
  shiny::tagList(
    shiny::div(
      shiny::tags$em(no_fun_provided_glue(x)),
      class = "bg-info"
    )
  )
}

no_fun_provided_server <- function(id, x = "server") {
  shiny::moduleServer(
    id = id,
    module = function(input, output, session) {
      shiny::showNotification(
        no_fun_provided_glue(x),
        duration = NULL,
        id = id
      )
      # above, confusingly, returns the ID as a string instead of NULL
      NULL
    }
  )
}

no_fun_provided_glue <- function(x) glue::glue("No {x} function provided.")

# mixed reactive tree ====

#' Show Tree of Mixed Reactive Values
#'
#' To evaluate the (reactive) values,
#' the function walks down the tree of return values
#' and `rlang::exec()`s all the `shiny::is.reactive()`s it can find,
#' going until it hits a non-list (`is.list()`) that is also *not* a reactive.
#'
#' @section Changes to the Reactive Graph:
#' Note that because this module prints *all* returned reactives from the
#' tree to the UI,
#' the reactive graph will be deeply affected.
#' For example,
#' these reactives might be invalidated at a different time in your use
#' of your modules outside of this testbed.
#' [reactlog_graph()] drops the testbed's own nodes, including this display,
#' but keeps the dependencies the display causes:
#' returned reactives which the display reads depend on their sources,
#' even if nothing else reads them.
#' [module2app_bare()] does not have this display.
#'
#' @section Bugs:
#' The display currently includes workarounds for these (likely upstream) bugs:
#' - The content of reactive gets [unclass()]ed
#'   before display ([#40](https://github.com/dataheld/crow/issues/40)).
#' - Some classes from the htmltools package get [format()]ted, not [print()]ed
#'   ([#39](https://github.com/dataheld/crow/issues/38)).
#'
#' @details
#' In the simplest case,
#' modules accept or return a single reactive- or non-reactive value.
#' Non-reactive returns are uncommon, but allowed.
#' In a more complex case, modules can accept or return deeply nested
#' lists of reactives and non-reactives,
#' including non-reactives which contain reactives.
#' For example, consider a module to input the contact details of an arbitrary
#' number of people, say, a travel group.
#'
#' To quickly grasp what *your* module accepts and returns,
#' this module prints both the "raw", unevaluated tree
#' and a version of the tree with all leaves evaluated.
#' [module2app()] and [module2app_bare()] also export both trees as this text,
#' for tests and coding agents.
#' @family modules
#' @name mixed_react_tree
NULL

#' @describeIn mixed_react_tree Test app
#' @inheritDotParams module2app
#' @export
mixed_react_tree_app <- function(...) {
  module2app(mixed_react_tree_ui, mixed_react_tree_server, ...)
}

#' @describeIn mixed_react_tree Module UI
#' @inheritParams shiny::NS
#' @inheritParams shiny::actionButton
#' @export
mixed_react_tree_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::h3("Unevaluated"),
    shiny::verbatimTextOutput(ns("unev")),
    shiny::h3("Evaluated"),
    shiny::verbatimTextOutput(ns("eval"))
  )
}

#' @describeIn mixed_react_tree Module Server
#' @param tree
#' A reactive- or non-reactive value,
#' typically a deeply nested list of reactives and non-reactive values,
#' as passed around between modules.
#' @export
mixed_react_tree_server <- function(id, tree = shiny::reactive(NULL)) {
  tree_server(id, tree)
}

#' Shows `evaluated`, such as overridden server arguments, in place of `tree`
#' @noRd
tree_server <- function(id, tree, evaluated = tree) {
  shiny::moduleServer(
    id = id,
    function(input, output, session) {
      output$unev <- shiny::renderPrint(tree_unevaluated(tree))
      output$eval <- shiny::renderPrint(tree_evaluated(evaluated))
    }
  )
}

tree_unevaluated <- function(tree) {
  filter_tree_shinytag(tree)
}

tree_evaluated <- function(tree) {
  tree |>
    exec_tree_of_reacs() |>
    filter_tree_shinytag()
}

#' Print both trees to text, as [mixed_react_tree_server()] displays them
#' @noRd
tree_text <- function(tree, evaluated = tree) {
  shiny::isolate(list(
    unevaluated = print_text(tree_unevaluated(tree)),
    evaluated = print_text(tree_evaluated(evaluated))
  ))
}

print_text <- function(x) {
  # like shiny::renderPrint(), which drops the final newline
  sub("\n$", "", paste(utils::capture.output(x), collapse = "\n"))
}

# TODO remove this as per https://github.com/dataheld/crow/issues/38
#' There appears to be a bug (in positron?)
#' by which `shiny.tag` (and similarly classed) objects
#' *always* get opened in the Viewer,
#' which breaks and/or overrides the shiny app preview.
#'
#' This just skips all shinytag returns.
#' @noRd
is_shinytag <- function(x) {
  inherits(x, c("shiny.tag", "shiny.tag.list", "html"))
}

filter_tree_shinytag <- function(x) {
  purrr::modify_tree(
    x,
    leaf = function(x) {
      # this is the equivalent to no print output to the console
      if (is_shinytag(x)) {
        x <- character(0)
      }
      x
    }
  )
}

exec_tree_of_reacs <- function(x) {
  purrr::modify_tree(
    x,
    is_node = is_list_or_reactive,
    pre = exec_if_reactive
  )
}

is_list_or_reactive <- function(x) {
  is.list(x) || shiny::is.reactive(x)
}

exec_if_reactive <- function(x) {
  if (shiny::is.reactive(x)) {
    x <- rlang::exec(x)
    # TODO remove this workaround for https://github.com/dataheld/crow/issues/40
    x <- unclass(x)
  }
  x
}

# test modules =====

# taken from shiny docs https://shiny.posit.co/r/articles/improve/modules/

#' Counter Button
#'
#' Example of a simple module.
#' @keywords internal
#' @name counter_button
NULL

#' @describeIn counter_button Test app
#' @inheritDotParams module2app
#' @export
counter_button_app <- function(...) {
  module2app(
    module_ui = counter_button_ui,
    module_server = counter_button_server,
    ...
  )
}

#' @describeIn counter_button Module UI
#' @inheritParams shiny::NS
#' @inheritParams shiny::actionButton
#' @export
counter_button_ui <- function(id, label = "Counter") {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::actionButton(ns("button"), label = label),
    shiny::verbatimTextOutput(ns("out"))
  )
}

#' @describeIn counter_button Module Server
#' @param set_to
#' Giving the value to set the counter to.
#' @param increment_by
#' A reactive, giving the value to increment the counter by.
#' @export
counter_button_server <- function(
  id,
  set_to = 0L,
  increment_by = shiny::reactiveVal(1L)
) {
  abort_if_reactive(set_to)
  abort_if_not_reactive(increment_by)
  shiny::moduleServer(
    id,
    function(input, output, session) {
      count <- shiny::reactiveVal(set_to)
      shiny::observeEvent(input$button, {
        count(count() + increment_by())
      })
      output$out <- shiny::renderText({
        count()
      })
      shiny::reactive(count())
    }
  )
}

#' Counter Button with Arbitrary Increments
#'
#' Example of a nested module.
#' @keywords internal
#' @name x_counter_button
NULL

#' @describeIn x_counter_button Test app
#' @inheritDotParams module2app
#' @export
x_counter_button_app <- function(...) {
  module2app(
    module_ui = x_counter_button_ui,
    module_server = x_counter_button_server,
    ...
  )
}

#' @describeIn x_counter_button Module UI
#' @inheritParams shiny::NS
#' @export
x_counter_button_ui <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::wellPanel(
      shiny::h3("Outer Module", shiny::code("x_counter_button")),
      shiny::wellPanel(
        shiny::h4("Inner Module 1", shiny::code("counter_button")),
        counter_button_ui(
          id = ns("set_increment"),
          label = "Set Count Increment"
        ),
      ),
      shiny::wellPanel(
        shiny::h4("Inner Module 2", shiny::code("counter_button")),
        counter_button_ui(id = ns("set_count"))
      )
    )
  )
}

#' @describeIn x_counter_button Module Server
#' @inheritParams counter_button_server
#' @param deep
#' Whether or not to return the inner module's reactive values.
#' Only useful for testing, does not make much sense in this context.
#' @export
x_counter_button_server <- function(id, set_to = 2L, deep = FALSE) {
  abort_if_reactive(set_to)
  shiny::moduleServer(
    id,
    function(input, output, session) {
      increment_by <- counter_button_server(id = "set_increment", set_to = 1L)
      count_by <- counter_button_server(
        id = "set_count",
        set_to = set_to,
        increment_by = increment_by
      )
      if (deep) {
        list(
          increment_by = shiny::reactive(increment_by()),
          count_by = shiny::reactive(count_by()),
          a_non_reactive_return = "just for testing",
          deeper_copy_of_increment_by = shiny::reactive(
            list(increment_by = shiny::reactive(increment_by()))
          )
        )
      } else {
        shiny::reactive(count_by())
      }
    }
  )
}

# ==== helpers

#' Retrieve `crow_screenshot_args` attribute with screenshot settings
#'
#' An app may require special settings for a good screenshot.
#' For example, you would usually only be interested in the Module UI
#' part of apps created by [module2app()].
#' [module2app()] supports this by setting the correct DOM selector
#' and exposing it via the `crow_screenshot_args`.
#'
#' @details
#' The `crow_screenshot_args` attribute can be set on whatever
#' object you pass to `appDir`.
#' It should be a list passable to the `screenshot_args` argument
#' of [`shinytest2::AppDriver`]'s `$new()` method.
#' You *can* set all sorts of screenshot behavior that way,
#' but same of these settings may break functionality in crow.
#' It is known to work for DOM selection.
#' @return
#' A list for the `screenshot_args` argument
#' of [`shinytest2::AppDriver`]'s `$new()` method.
#' If no attribute is found,
#' returns [rlang::missing_arg()], to keep shinytest2
#' defaults intact.
#' @inheritParams shiny::runApp
#' @export
#' @family modules
#' @family screenshot
get_screenshot_args_attr <- function(appDir) {
  if (has_crow_attrs(appDir)) {
    res <- attr(appDir, which = "crow_screenshot_args")
    checkmate::assert_list(res)
    res
  } else {
    return(rlang::missing_arg())
  }
}

has_crow_attrs <- function(appDir) {
  "crow_screenshot_args" %in% names(attributes(appDir))
}
