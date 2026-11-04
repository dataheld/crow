# reactlog_graph / gives the edges between nested modules

    Code
      print(reactlog_graph(session = session$token))
    Output
      count [1] -> output (unnamed in testServer) [1]
      count [1] -> reactive({ count() }) [1]
      reactive({ count() }) [1] -> reactive({ increment_by() }) [1]
      reactive({ count() }) [1] -> reactive({ increment_by() }) [2]
      count [2] -> output (unnamed in testServer) [2]
      count [2] -> reactive({ count() }) [2]
      reactive({ count() }) [2] -> reactive({ count_by() })
      input$x-set_increment-button -> observeEvent(input$button) [1]
      input$x-set_count-button -> observeEvent(input$button) [2]
      reactiveVal
      reactive({ list(increment_by = shiny::reactive(increment_...

# reactlog_graph / reads the log exported from a running app

    Code
      print(reactlog_graph(driver$get_value(export = "reactlog")))
    Output
      count -> output$test_object-out
      count -> reactive({ count() })
      input$test_object-button -> observeEvent(input$button)
      reactiveVal

