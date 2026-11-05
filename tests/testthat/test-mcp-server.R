describe("the crow MCP server", {
  client <- local_mcp_client()

  it("offers the crow tools", {
    tools <- client$request("tools/list")$result$tools
    expect_setequal(purrr::map_chr(tools, "name"), names(crow_tools()))
  })

  it("runs testServer on nested modules", {
    report <- result_text(client$call(
      "module_test_server",
      path = pkg_root(),
      server = "x_counter_button_server",
      server_args = "list(deep = TRUE)",
      expr = "session$setInputs(`test_object-set_increment-button` = 1)"
    ))
    expect_match(
      report,
      "$deeper_copy_of_increment_by$increment_by\n[1] 2",
      fixed = TRUE
    )
  })

  it("reports wrong calls as tool results, not protocol errors", {
    expect_match(
      result_text(client$call("module_app_get", id = "app0")),
      "^## Error\nNo running app"
    )
    expect_match(
      result_text(client$call("module_app_set", id = "app0", inputs = "{oops")),
      "^## Error\n"
    )
  })

  it("screenshots a running module with its padding and border", {
    start <- result_text(client$call(
      "module_app_start",
      path = pkg_root(),
      ui = paste(
        "function(id) shiny::div(id = id, style =",
        "'width: 100px; height: 50px; padding: 10px; border: 5px solid')"
      )
    ))
    id <- app_id(start)
    shot <- result_text(client$call("module_app_screenshot", id = id))
    png <- regmatches(shot, regexpr("[^\n ]+\\.png", shot))
    expect_equal(
      unlist(magick::image_info(magick::image_read(png))[c("width", "height")]),
      c(width = 100, height = 50)
    )
    expect_match(
      result_text(client$call("module_app_stop", id = id)),
      paste("Stopped", id)
    )
  })

  it("ends all processes when the client disconnects", {
    result_text(client$call(
      "module_app_start",
      path = pkg_root(),
      ui = "counter_button_ui",
      server = "counter_button_server"
    ))
    processes <- ps::ps_children(
      ps::ps_handle(client$server$get_pid()),
      recursive = TRUE
    )
    expect_gt(length(processes), 0)
    close(client$server$get_input_connection())
    client$server$wait(30000)
    expect_equal(client$server$get_exit_status(), 0)
    Sys.sleep(2)
    expect_false(any(purrr::map_lgl(processes, ps::ps_is_running)))
  })
})
