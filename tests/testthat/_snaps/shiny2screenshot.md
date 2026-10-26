# roxy_tag_crowExamplesShiny / can be parsed

    Code
      roxygen2::parse_text(example)[[1]]$tags
    Output
      [[1]]
      [<text>:  1] @title 'An example documentation for a shiny app' {parsed}
      
      [[2]]
      [<text>:  2] @crowExamplesShiny '...' {parsed}
      
      [[3]]
      [<text>:  4] @usage '<generated>' {parsed}
      
      [[4]]
      [<text>:  4] @.formals '<generated>' {unparsed}
      
      [[5]]
      [<text>:  4] @backref '<generated>' {parsed}
      

# roxy_tag_crowExamplesShiny / can be formatted

    Code
      topic$get_section("examples")
    Output
      \examples{
      \dontshow{
      # automatically inserted screenshot
      get_screenshot_from_app(
      hello_app()
      )
      }
      \dontrun{
      # launch the app
      hello_app()
      }
      } 

# roxy_tag_crowInsertSnaps / can be parsed

    Code
      roxygen2::parse_text(single)[[1]]$tags
    Output
      [[1]]
      [<text>:  1] @title 'An example documentation with inserted snaps fr...' {parsed}
      
      [[2]]
      [<text>:  2] @crowInsertSnaps '...' {parsed}
      
      [[3]]
      [<text>:  7] @usage '<generated>' {parsed}
      
      [[4]]
      [<text>:  7] @.formals '<generated>' {unparsed}
      
      [[5]]
      [<text>:  7] @backref '<generated>' {parsed}
      

# roxy_tag_crowInsertSnaps / can be formatted with single tag

    Code
      topic$get_section("crowInsertSnaps")
    Output
      \section{Screenshots from Tests}{
        \if{html}{
          name: \code{bins}, variant: \code{linux}
      \figure{crow_screenshots/helpers/bins.gif}{options: width='100\%' alt=Screenshot from App}
        }
        \if{latex}{
          Screenshots cannot be shown in this output format.
        }
      } 

# roxy_tag_crowInsertSnaps / can be formatted with multiple tags joined

    Code
      topic$get_section("crowInsertSnaps")
    Output
      \section{Screenshots from Tests}{
        \if{html}{
          name: \code{bins}, variant: \code{linux}
      \figure{crow_screenshots/helpers/bins.gif}{options: width='100\%' alt=Screenshot from App}
      name: \code{bins}, variant: \code{mac}
      \figure{crow_screenshots/helpers/bins.gif}{options: width='100\%' alt=Screenshot from App}
        }
        \if{latex}{
          Screenshots cannot be shown in this output format.
        }
      } 

# snaps2fig and friends work / writes out markdown syntax

    Code
      res
    Output
      ![Screenshot from App](crow_screenshots/helpers/bins.gif)

