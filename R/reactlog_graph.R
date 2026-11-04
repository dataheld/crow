#' Get the reactive graph of a shiny app as text
#'
#' Replays the raw events of [shiny::reactlog()] into the current reactive
#' graph:
#' its nodes, such as inputs, reactives, observers and outputs,
#' and its edges, from each dependency to its dependent.
#' Unlike the reactlog package, which draws the graph for people,
#' this gives the graph as text, for tests and coding agents.
#'
#' @details
#' Shiny logs the events only with `options(shiny.reactlog = TRUE)`,
#' also inside [shiny::testServer()].
#' [module2app()] and [module2app_bare()] export the events of each session
#' as `reactlog`:
#' ```r
#' driver <- local_app_driver(
#'   counter_button_app,
#'   options = list(shiny.reactlog = TRUE)
#' )
#' reactlog_graph(driver$get_value(export = "reactlog"))
#' ```
#'
#' The graph drops the testbed's own nodes:
#' the reactives which change server arguments while the app runs
#' (see [module2app_bare()]),
#' the displays of [module2app()] (outputs `inputs-*` and `returns-*`),
#' and shiny's internal `Theme Counter`.
#' Their dependencies become dependencies of their dependents,
#' so the graph of [module2app_bare()] is that of an app which only uses the
#' module.
#'
#' Reads inside [shiny::isolate()],
#' such as in the handler of [shiny::observeEvent()],
#' are no dependencies, and so no edges.
#' Reactives which nothing has read yet have no dependencies either.
#'
#' Labels are shortened to one line.
#' Shiny labels reactives and observers by their code,
#' unless they are assigned to a name or given a `label`.
#' Anonymous [shiny::reactiveVal()]s are labelled `reactiveVal`.
#' Inside [shiny::testServer()],
#' outputs are labelled `output (unnamed in testServer)`,
#' because shiny does not log their names there.
#'
#' A snapshot of the printed graph ([testthat::expect_snapshot()])
#' is a regression test of a module's reactive structure.
#'
#' @param log
#' Events from [shiny::reactlog()].
#' @param session
#' The token of a shiny session, such as `session$token`,
#' to keep only the events of that session.
#' Events without a session,
#' such as from reactives created outside of a server function,
#' are always kept.
#' `NULL` keeps the events of all sessions.
#' @return
#' A list of class `reactlog_graph`, with the data frames
#' - `nodes`, with columns `id`, `label` and `type`, and
#' - `edges`, with columns `from` and `to`, giving node `id`s.
#'
#' Its `format()` and `print()` methods give one line per edge,
#' such as `input$test_object-button -> observeEvent(input$button)`,
#' and then one line per node without edges.
#' Duplicated labels are numbered in the order of definition,
#' such as `count [1]` and `count [2]`.
#' @example inst/examples/reactlog_graph.R
#' @family modules
#' @export
reactlog_graph <- function(log = shiny::reactlog(), session = NULL) {
  if (!is.null(session)) {
    log <- session_reactlog(log, session)
  }
  nodes <- replay_nodes(log)
  edges <- replay_edges(log)
  kept <- nodes[!is_ignored_label(nodes$label), ]
  edges <- contract_edges(
    edges,
    setdiff(c(nodes$id, edges$from, edges$to), kept$id)
  )
  new_reactlog_graph(nodes = kept, edges = edges)
}

new_reactlog_graph <- function(nodes, edges) {
  edges <- edges[
    order(match(edges$from, nodes$id), match(edges$to, nodes$id)),
  ]
  rownames(nodes) <- NULL
  rownames(edges) <- NULL
  structure(list(nodes = nodes, edges = edges), class = "reactlog_graph")
}

#' @export
format.reactlog_graph <- function(x, ...) {
  labels <- rlang::set_names(number_duplicates(x$nodes$label), x$nodes$id)
  connected <- x$nodes$id %in% c(x$edges$from, x$edges$to)
  c(
    sprintf("%s -> %s", labels[x$edges$from], labels[x$edges$to]),
    unname(labels[!connected])
  )
}

#' @export
print.reactlog_graph <- function(x, ...) {
  cat(format(x), sep = "\n")
  invisible(x)
}

session_reactlog <- function(log, session) {
  purrr::keep(log, \(event) {
    is.null(event$session) || identical(event$session, session)
  })
}

replay_nodes <- function(log) {
  defines <- events_of(log, "define")
  data.frame(
    id = purrr::map_chr(defines, "reactId"),
    label = one_line_label(
      purrr::map_chr(defines, \(event) as.character(event$label))
    ),
    type = purrr::map_chr(defines, "type")
  )
}

#' The last event of each dependency decides whether it still exists.
#' @noRd
replay_edges <- function(log) {
  events <- events_of(log, c("dependsOn", "dependsOnRemove"))
  edges <- data.frame(
    action = purrr::map_chr(events, "action"),
    from = purrr::map_chr(events, "depOnReactId"),
    to = purrr::map_chr(events, "reactId")
  )
  last <- edges[!duplicated(edges[c("from", "to")], fromLast = TRUE), ]
  last[last$action == "dependsOn", c("from", "to")]
}

events_of <- function(log, actions) {
  purrr::keep(log, \(event) event$action %in% actions)
}

#' Connect the dependencies of dropped nodes to their dependents.
#' @noRd
contract_edges <- function(edges, dropped) {
  for (id in dropped) {
    bridges <- merge(
      data.frame(from = edges$from[edges$to == id]),
      data.frame(to = edges$to[edges$from == id]),
      by = NULL
    )
    edges <- unique(rbind(edges[edges$from != id & edges$to != id, ], bridges))
  }
  edges
}

one_line_label <- function(label, width = 60L) {
  label <- gsub("\\s+", " ", trimws(label))
  label <- sub("^(reactiveVal(ues)?)[0-9a-f]{8}\\b", "\\1", label)
  label[grepl("private$withCurrentOutput(name,", label, fixed = TRUE)] <-
    "output (unnamed in testServer)"
  ifelse(
    nchar(label) > width,
    paste0(substr(label, 1L, width - 3L), "..."),
    label
  )
}

is_ignored_label <- function(label) {
  grepl(
    "^crow_|^input\\$crow_server_args$|^output\\$(inputs|returns)-|^Theme Counter$",
    label
  )
}

number_duplicates <- function(labels) {
  rank <- purrr::imap_int(labels, \(label, i) sum(labels[seq_len(i)] == label))
  duplicated <- labels %in% labels[duplicated(labels)]
  ifelse(duplicated, paste0(labels, " [", rank, "]"), labels)
}
