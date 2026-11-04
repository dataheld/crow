old <- options(shiny.reactlog = TRUE)
shiny::testServer(counter_button_server, {
  session$setInputs(button = 1)
  print(reactlog_graph(session = session$token))
})
options(old)
