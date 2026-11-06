pkg_root <- function() {
  path <- testthat::test_path("..", "..")
  if (!file.exists(file.path(path, "DESCRIPTION"))) {
    testthat::skip("Needs the package source.")
  }
  normalizePath(path)
}

app_id <- function(report) regmatches(report, regexpr("app[0-9]+", report))

local_mcp_client <- function(.local_envir = parent.frame()) {
  server <- processx::process$new(
    mcp_command()[[1]],
    mcp_command()[-1],
    stdin = "|",
    stdout = "|",
    stderr = withr::local_tempfile(.local_envir = .local_envir),
    supervise = TRUE
  )
  withr::defer(
    {
      server$kill_tree()
    },
    envir = .local_envir
  )
  client <- new.env()
  client$server <- server
  client$next_id <- 0L
  client$request <- function(method, params = NULL) {
    client$next_id <- client$next_id + 1L
    send(
      server,
      list(
        jsonrpc = "2.0",
        id = client$next_id,
        method = method,
        params = params
      )
    )
    receive(server)
  }
  client$call <- function(name, ...) {
    client$request("tools/call", list(name = name, arguments = list(...)))
  }
  client$request(
    "initialize",
    list(
      protocolVersion = "2025-06-18",
      capabilities = structure(list(), names = character()),
      clientInfo = list(name = "crow-tests", version = "0")
    )
  )
  send(server, list(jsonrpc = "2.0", method = "notifications/initialized"))
  client
}

#' The command of the agent plugin when crow is installed,
#' otherwise the working tree.
mcp_command <- function() {
  if (pkgload::is_dev_package("crow")) {
    return(c(
      file.path(R.home("bin"), "Rscript"),
      "-e",
      sprintf(
        "pkgload::load_all('%s', quiet = TRUE); crow_mcp_server()",
        pkg_root()
      )
    ))
  }
  mcp <- jsonlite::read_json(system.file("mcp.json", package = "crow"))
  c(mcp$mcpServers$crow$command, unlist(mcp$mcpServers$crow$args))
}

send <- function(server, message) {
  json <- jsonlite::toJSON(purrr::compact(message), auto_unbox = TRUE)
  server$write_input(paste0(json, "\n"))
}

#' Every line on stdout must be a JSON-RPC message.
receive <- function(server, timeout = 120000) {
  line <- character()
  deadline <- Sys.time() + timeout / 1000
  while (length(line) == 0) {
    if (Sys.time() > deadline || !server$is_alive()) {
      testthat::fail("The MCP server did not answer.")
    }
    server$poll_io(1000)
    line <- server$read_output_lines(n = 1)
  }
  jsonlite::fromJSON(line, simplifyVector = FALSE)
}

result_text <- function(response) {
  testthat::expect_null(response$error)
  paste(purrr::map_chr(response$result$content, "text"), collapse = "\n")
}
