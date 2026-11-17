# ui wrapper which arranges the parts of the testbed
if (elf::is_installed2("bslib")) {
  ui_wrapper <- function(heading, inputs, module, returns) {
    bslib::page_fluid(
      heading,
      bslib::layout_sidebar(
        sidebar = bslib::sidebar(inputs),
        bslib::layout_sidebar(
          sidebar = bslib::sidebar(returns, position = "right"),
          module
        )
      )
    )
  }
}
