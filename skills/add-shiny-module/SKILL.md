---
name: add-shiny-module
description: Add a shiny module to an R package the crow way, with foo_ui, foo_server and a foo_app testbed from crow::module2app(), testServer() tests covering all server logic, and shinytest2 screenshots of the interaction inserted into the docs. Use when creating or restructuring a shiny module in an R package.
compatibility: Requires R, an R package with testthat 3e, and the R packages crow, shiny, shinytest2, pkgload and withr. Screenshots need Chrome.
---

# Adding a shiny module

A module `foo` lives in `R/foo.R`, is tested in `tests/testthat/test-foo.R`,
and exports exactly these functions:

- `foo_ui(id, ...)`: the module UI.
- `foo_server(id, ...)`: the module server.
- `foo_app(...)`: the module in a [`crow::module2app()`](https://crow.maxheld.de/reference/module2app.html) testbed,
  to run and screenshot it alone.

Run all scripts and R from the package root.
`<skill>` is the directory of this file.

## 1. Set up the package once

In `DESCRIPTION`:

- Add `crow`, `shinytest2` and `withr` to `Suggests`.
  crow is a development-time dependency;
  only `foo_app()` calls it,
  so the package works without crow.
  If `crow` is not on CRAN for this project,
  also add `dataheld/crow` to `Remotes`.
- Let roxygen2 use crow's tags:
  `Roxygen: list(markdown = TRUE, packages = "crow")`.
  Keep other `Roxygen` options.

## 2. Write the files

```sh
Rscript <skill>/scripts/new-module.R foo
```

This writes `R/foo.R` and `tests/testthat/test-foo.R`
from [`assets/`](assets/), and does not overwrite files.
The scaffold runs and passes its tests;
replace its placeholder logic with the real module.
Follow crow's own example modules,
[`counter_button`](https://github.com/dataheld/crow/blob/main/R/modules.R)
and its nested parent `x_counter_button`.

### Server

- Wrap the logic in `shiny::moduleServer()`.
- Arguments that the caller changes at runtime are reactives;
  configuration is plain values.
  Give every argument a default,
  so that `foo_app()` runs without arguments,
  e.g. `increment_by = shiny::reactiveVal(1L)`.
- Assert the kind of each argument at the top of `foo_server()`,
  before `shiny::moduleServer()`.
  If the package imports crow,
  use `crow::abort_if_reactive()` and `crow::abort_if_not_reactive()`.
  Otherwise use `stopifnot(shiny::is.reactive(x))`,
  so that crow stays in `Suggests`.
- Return a reactive, or a (nested) list of reactives,
  never a writable `shiny::reactiveVal()`:
  wrap it, e.g. `shiny::reactive(count())`.
  Return `NULL` only if the module has no output for its caller.
- Compose modules by calling the child's `bar_server(id = "bar", ...)`
  in the server and `bar_ui(ns("bar"))` in the UI.

### UI

- Start with `ns <- shiny::NS(id)` and wrap every input and output ID in `ns()`.
- Return a `shiny::tagList()` of plain shiny tags.
  Do not add page functions or themes:
  the caller (or `module2app(ui_wrapper = )`) owns them.
- Only plain, non-reactive arguments.

### App

`foo_app(...)` passes `...` to `crow::module2app()`,
so callers can set `ui_args`, `server_args` and `ui_wrapper`.
The testbed prints the evaluated server arguments and return values,
and exports the return value as the shinytest2 export `res`.

### Docs

One roxygen2 topic per module,
`@name foo`, with one `@describeIn foo ...` per function,
as in the scaffold.
Document every argument; inherit with `@inheritParams` where possible.
Use `shiny::` prefixes; do not `@import shiny`.

## 3. Test all server logic

Test `foo_server()` with `shiny::testServer()`,
without a browser.
Every reactive, observer, output and return value must be exercised.

```r
test_that("foo_server counts by the increment", {
  increment_by <- shiny::reactiveVal(2L)
  shiny::testServer(
    foo_server,
    args = list(set_to = 10L, increment_by = increment_by),
    {
      expect_equal(session$returned(), 10L)
      session$setInputs(button = 1)
      expect_equal(session$returned(), 12L)
      increment_by(5L)
      session$setInputs(button = 2)
      expect_equal(output$out, "17")
    }
  )
})
```

- Change reactive arguments from the test,
  as with `increment_by` above.
- Inputs of child modules are namespaced: `` `bar-button` = 1 ``.
- Test that wrong argument kinds fail:
  `expect_error(foo_server("x", increment_by = 1L))`.
- If `covr` is installed,
  `covr::file_coverage("R/foo.R", "tests/testthat/test-foo.R")`
  must show every line of `foo_server()` as covered.

## 4. Screenshot the interaction

The scaffold's second test drives `foo_app()` in Chrome with shinytest2.
It screenshots only the module UI,
because `crow::get_screenshot_args_attr()` selects it from the testbed.
Extend it with the interactions that show what the module does,
one `driver$expect_screenshot()` after each:

```r
driver$expect_screenshot()
driver$click("test_object-button")
driver$expect_screenshot()
expect_equal(driver$get_value(export = "res"), 1L)
```

- The testbed mounts the module with ID `test_object`,
  so its inputs are `test_object-<input>`.
- Keep the test's `name = "foo"`:
  screenshots are then numbered `foo-001.png`, `foo-002.png`, ...
  in `tests/testthat/_snaps/<variant>/foo/`,
  where `<variant>` is `mac` or `linux`.
- Keep the app a function that calls `library(<package>)`:
  shinytest2 then runs the working tree (via `pkgload::load_all()`),
  not an installed, possibly outdated package.
- Avoid randomness and time in the UI;
  screenshots must be identical between runs.

Run the tests, then look at the screenshots.
To check the UI while you iterate, without tests:

```sh
Rscript <skill>/scripts/screenshot-module.R foo foo.png
```

Delete that file afterwards.
Commit the `_snaps/` screenshots.

## 5. Insert the screenshots into the docs

Once the screenshots are committed,
add one `@crowInsertSnaps` tag per committed variant to the module's topic:

```r
#' @crowInsertSnaps
#' foo
#' foo
#' TRUE
#' linux
```

The lines are the test file without `test-`,
the shinytest2 `name`,
whether screenshots are auto-numbered (`TRUE` for the scaffold),
and the variant.
When documenting, crow merges the numbered screenshots into an animated GIF
in `man/figures/crow_screenshots/`
and inserts it as a "Screenshots from Tests" section
(see [`crowInsertSnaps`](https://crow.maxheld.de/reference/tag_shiny.html)).
Documenting fails if no screenshots match,
so only tag variants that exist.

## 6. Check

Regenerate `NAMESPACE` and `man/` with roxygen2,
then run the project's tests and checks.
Use the project's task runner if it has one (see its `AGENTS.md` or `README.md`).
Commit `R/foo.R`, `tests/testthat/test-foo.R`, the snapshots,
and the generated `NAMESPACE` and `man/` files,
including the GIFs in `man/figures/crow_screenshots/`,
unless the project ignores and regenerates `man/` in its builds.
