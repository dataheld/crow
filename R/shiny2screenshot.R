#' Tags for documenting shiny apps with screenshots
#'
#' Provides new roxygen2 tags to add screenshots to shiny app documentation.
#'
#' @details
#' Because starting a shiny app does not return,
#' it cannot be included as an `#' @examples`,
#' or must wrapped in `\dontrun`.
#' But for quick reference, a screenshot or gif of a shiny app
#' are still helpful for the reader of your documentation.
#'
#' @section Usage in Packages:
#' If you want to use these tags in your own packages,
#' you need let roxygen2 know about *crow*.
#'
#' To do that, append this line to your `DESCRIPTION`:
#'
#' ```
#' Roxygen: list(packages =  "crow")
#' ```
#'
#' If you already have other arguments specified for Roxygen,
#' just add `packages` list element.
#'
#' @family screenshot
#'
#' @name tag_shiny
NULL

# crowExamplesShiny tag ====

#' @rdname tag_shiny
#' @details
#' - `@crowExamplesShiny$ {1:# example code}`
#'    R code which returns a shiny app.
#'    A screenshot of the shiny app is added to the documentation,
#'    along with the code required to create the screenshot and
#'    launch the app interactively.
#'    Wraps @examples.
#' @usage
#' # @crowExamplesShiny ${1:# example code}
#' @name crowExamplesShiny
NULL

#' @exportS3Method roxygen2::roxy_tag_parse
roxy_tag_parse.roxy_tag_crowExamplesShiny <- function(x) {
  check_installed_roxygen2()
  roxygen2::tag_examples(x)
}

#' @exportS3Method roxygen2::roxy_tag_rd
roxy_tag_rd.roxy_tag_crowExamplesShiny <- function(x, base_path, env) {
  call <- x[["val"]]
  x[["val"]] <- paste(
    "\\dontshow{",
    "# automatically inserted screenshot",
    "get_screenshot_from_app(",
    call,
    ")",
    "}",
    "\\dontrun{",
    "# launch the app",
    call,
    "}",
    sep = "\n"
  )
  roxygen2::rd_section("examples", x$val)
}

check_installed_roxygen2 <- function() {
  rlang::check_installed(
    "roxygen2",
    reason = "roxygen2 is needed for extended documentation of shiny apps."
  )
}

check_installed_shinytest2 <- function() {
  rlang::check_installed(
    "shinytest2",
    reason = "shinytest2 is needed to create screenshots of shiny apps."
  )
}

#' Get screenshot from shiny app
#'
#' Wrapper around [shinytest2::AppDriver()].
#' Shows only the shiny app at launch.
#' To show interactions with an app, use a different function.
#'
#' @inheritParams shiny::runApp
#' @param screenshot_args
#' Passed to [`shinytest2::AppDriver`]'s `$new()` method.
#' @param name
#' If the shiny app is developed inside a package (recommended),
#' the name of that package.
#' The screenshot is created using the (last)
#' *installed* (not `pkgload::load_all()`d) version of that package.
#' When the name is provided,
#' the function can test whether it is using
#' the installed version of that package,
#' to avoid confusion (recommended).
#' @param strict
#' Should the function error out,
#' when the various conditions for creating screenshots are not met?
#' To reduce friction during development,
#' the function will default to just issuing a warning.
#' Instead of the screenshot,
#' it then returns the reason for the failure as a string.
#' @param file
#' Path to save the screenshot to; only used for testing.
#' Leave to `NULL`.
#' @examples
#' \dontrun{
#' get_screenshot_from_app(examples_app())
#' }
#' @family screenshot
#' @export
get_screenshot_from_app <- function(
  appDir,
  screenshot_args = get_screenshot_args_attr(appDir),
  name = character(1L),
  file = NULL,
  strict = FALSE
) {
  checkmate::assert_flag(strict)
  f_screenshot <- purrr::partial(
    get_screenshot_from_app_strictly,
    appDir,
    screenshot_args = screenshot_args,
    name = name,
    file = file
  )
  if (!strict) {
    f_screenshot <- purrr::possibly(
      f_screenshot,
      otherwise = {
        glue::glue(
          "The screenshot could not be generated.",
          "Please check the logs for errors.",
          .sep = " "
        )
      },
      quiet = TRUE
    )
  }
  f_screenshot()
}

get_screenshot_from_app_strictly <- function(
  appDir,
  screenshot_args,
  name,
  file
) {
  check_installed_shinytest2()
  if (name != character(1L)) {
    elf::assert_pkg_installed_but_not_via_loadall(x = name)
  }
  driver <- shinytest2::AppDriver$new(
    app_dir = appDir,
    screenshot_args = screenshot_args
  )
  withr::defer(driver$stop())
  driver$get_screenshot(file = file)
}

# crowInsertSnaps tag ====

#' @rdname tag_shiny
#' @details
#' - `@crowInsertSnaps
#'    ${1:test_file}
#'    ${2:name}
#'    ${3:auto_numbered}
#'    ${4:variant}
#'    ${5:fps}`
#'    Instead of re-creating screenshots,
#'    insert reused screenshots created by
#'    [shinytest2](https://rstudio.github.io/shinytest2/) snapshot testing.
#'    For arguments and defaults, see [snaps2fig()].
#'    You can also use [snaps2md()] directly, without a custom tag.
#' @usage
#' # @crowInsertSnaps
#' # ${1:test_file}
#' # ${2:name}
#' # ${3:auto_numbered}
#' # ${4:variant}
#' # ${5:fps}
#' @crowInsertSnaps
#' helpers
#' bins
#' FALSE
#' linux
#' @name crowInsertSnaps
NULL

#' @exportS3Method roxygen2::roxy_tag_parse
roxy_tag_parse.roxy_tag_crowInsertSnaps <- function(x) {
  check_installed_roxygen2()
  roxygen2::tag_words(x, min = 1, max = 5)
}

#' @exportS3Method roxygen2::roxy_tag_rd
roxy_tag_rd.roxy_tag_crowInsertSnaps <- function(x, base_path, env) {
  args <- as.list(x[["val"]])
  if (length(args) >= 2) {
    args[[3]] <- as.logical(args[[3]])
  }
  possible_names <- c("test_file", "name", "auto_numbered", "variant", "fps")
  # this is fine because the order of arguments for tags is always the same
  names(args) <- possible_names[seq_along(args)]
  roxygen2::rd_section(
    type = "crowInsertSnaps",
    value = rlang::exec(snaps2rd, !!!args)
  )
}

glue_latex <- function(..., .envir = parent.frame()) {
  glue::glue(..., .envir = .envir, .open = "[", .close = "]")
}

#' @export
format.rd_section_crowInsertSnaps <- function(x, ...) {
  inner <- glue::glue_collapse(x$value, sep = "\n")
  # appease check
  inner
  glue_latex(
    "\\section{Screenshots from Tests}{
      \\if{html}{
        [inner]
      }
      \\if{latex}{
        Screenshots cannot be shown in this output format.
      }
    }"
  )
}

#' Get screenshots from snapshots
#'
#' Retrieves screenshots from
#' [testthat](https://testthat.r-lib.org)'s `_snaps/` directory.
#' If several files match `dir_ls_snaps()`,
#' they are merged into an animated gif.
#' @family screenshot
#' @name get_screenshot_from_snaps
NULL

#' @describeIn get_screenshot_from_snaps
#' Save screenshots to `man/figures` and return *relative* path from there.
#' @inheritParams glue_regexp_snaps
#' @export
snaps2fig <- function(
  test_file = character(),
  name = NULL,
  auto_numbered = TRUE,
  variant = shinytest2::platform_variant(),
  fps = 5,
  ...
) {
  snaps_paths <- dir_ls_snaps(
    test_file = test_file,
    regexp = glue_regexp_snaps(
      name = name,
      auto_numbered = auto_numbered
    ),
    variant = variant
  )
  if (length(snaps_paths) == 0) {
    rlang::abort(
      "No images were found."
    )
  }
  snaps_img <- image_animate_snaps(snaps = snaps_paths, fps = fps, ...)
  path_for_results <- fs::path(
    "man",
    "figures",
    "crow_screenshots",
    test_file,
    if (!is.null(name)) name,
    ext = unique(magick::image_info(snaps_img)$format)
  )
  fs::dir_create(path = fs::path_dir(path_for_results))
  # side effect happens here
  res <- image_write_snaps(snaps_img, path = path_for_results)
  # roxygen2/man markdown expects relative paths from here
  fs::path_rel(res, start = "man/figures")
}

snap_alt_text <- function() "Screenshot from App"

#' @describeIn get_screenshot_from_snaps
#' Save screenshots to `man/figures` and return markdown image markup,
#' to be inserted in roxygen2 documentation.
#' @param ... Arguments passed on to other functions.
#' @export
snaps2md <- function(...) {
  path <- snaps2fig(...)
  glue::glue("![{snap_alt_text()}]({path})")
}

#' @describeIn get_screenshot_from_snaps
#' Save screenshots to `man/figures` and return R documentation image markup,
#' to be inserted in R documentation.
#' For a custom roxygen2 tag with equivalent functionality,
#' see [crowInsertSnaps()].
#' @export
snaps2rd <- function(
  test_file = character(),
  name = NULL,
  auto_numbered = TRUE,
  variant = shinytest2::platform_variant(),
  fps = 5
) {
  path <- snaps2fig(
    test_file = test_file,
    name = name,
    auto_numbered = auto_numbered,
    variant = variant,
    fps = fps
  )
  # appease R CMD check
  path
  glue_latex(
    "name: \\code{[name]}, variant: \\code{[variant]}
    \\figure{[path]}{options: width='100\\%' alt=[snap_alt_text()]}"
  )
}

#' @describeIn get_screenshot_from_snaps
#' List all testthat `_snaps/` screenshots
#' Finds all files for a variant, file and name.
#'
#' @section Matching several screenshots:
#' You can deposit several screenshots of a shiny app using
#' [shinytest2::AppDriver] in testing.
#' Use [dir_ls_snaps()] to identify all the resulting images.
#' Typically used for *consecutive* screenshots.
#' @param test_file
#' Name of the test file, in which the snapshots are generated,
#' *without*:
#' - the extension
#' - the `test-` prefix.
#' If you're using testthat convention,
#' this will be the name of the file in `R/`,
#' which you are currently testing.
#' @inheritParams shinytest2::AppDriver
#' @inheritParams testthat::expect_snapshot_file
#' @inheritParams fs::dir_ls
#' @export
dir_ls_snaps <- function(
  test_file = character(),
  regexp = glue_regexp_snaps(),
  variant = shinytest2::platform_variant()
) {
  checkmate::assert_string(test_file)
  test_path <- testthat::test_path("_snaps", variant, test_file)
  fs::dir_ls(
    test_path,
    all = FALSE,
    recurse = FALSE,
    type = "file",
    regexp = regexp
  )
}

#' Build the regular expression to match consecutive screenshots
#'
#' [shinytest2::AppDriver] uses several schemes to
#' name consecutive screenshot files.
#' Use this regex to capture paths of screenshots.
#' @param name
#' The `name` passed to [shinytest2::AppDriver] to be used for screenshots.
#' Can be `NULL`, for no filtering by name.
#' @param auto_numbered
#' If `TRUE`, filter for snapshot files automatically numbered
#' according to the scheme used by [shinytest2::AppDriver].
#' If you pass a `name` only to `shinytest2::AppDriver$new()` (recommended),
#' and then invoke several `shinytest2::AppDriver$expect_snapshot()`,
#' they resulting snapshots will all have the same name,
#' appended by a counter from `000` to `999`.
#' If `FALSE`, any filename `{name}*.png` will be selected.
#' You may need to set `FALSE`
#' if you pass a name to`shinytest2::AppDriver$expect_snapshot()`
#' directly.
#' @family screenshot
#' @export
glue_regexp_snaps <- function(name = NULL, auto_numbered = TRUE) {
  checkmate::assert_string(name, null.ok = TRUE)
  checkmate::assert_flag(auto_numbered)
  glue::glue(
    "^.*[\\\\/]", # path
    if (is.null(name)) "" else "{name}",
    if (!is.null(name) && auto_numbered) "-" else "",
    if (auto_numbered) "\\d{{3}}" else ".*",
    # shinytest2 only defaults to png
    "\\.png$"
  )
}

#' @describeIn get_screenshot_from_snaps
#' Read in screenshot.
#' If several, animate into a gif.
#' @param snaps
#' Vector of file names, as returned by [dir_ls_snaps()]
#' @inheritParams magick::image_animate
#' @inheritDotParams magick::image_animate
#' @return For [image_animate_snaps()] A `magick-image`.
#' @export
image_animate_snaps <- function(snaps = fs::path(), fps = 5, ...) {
  if (!all(fs::file_exists(snaps))) {
    rlang::abort("File could not be found.")
  }
  names(snaps) <- fs::path_file(snaps)
  check_installed_magick()
  # stripping helps to avoid spurious diffs
  res <- magick::image_read(snaps, strip = TRUE)
  if (length(snaps) == 1) {
    res
  } else {
    magick::image_animate(res, fps = fps, ...)
  }
}

#' @describeIn get_screenshot_from_snaps
#' Write out (merged) screenshots to new path.
#' @inheritParams magick::image_write
#' @return For [image_write_snaps()], path to the (merged) screenshots.
#' @export
image_write_snaps <- function(image, path = withr::local_tempfile()) {
  magick::image_write(image = image, path = path)
}

check_installed_magick <- function() {
  rlang::check_installed(
    "magick",
    reason = "magick is needed show `snaps`."
  )
}
