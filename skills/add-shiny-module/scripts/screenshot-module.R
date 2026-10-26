#!/usr/bin/env Rscript
# Usage: Rscript screenshot-module.R <name> [file], from the root of an R package.
# Screenshots the module UI of <name>_app(), as the working tree defines it.

args <- commandArgs(trailingOnly = TRUE)
name <- args[1]
file <- if (is.na(args[2])) paste0(name, ".png") else args[2]
if (is.na(name)) {
  stop("Give the module name, e.g. `screenshot-module.R foo`.")
}
package <- read.dcf("DESCRIPTION", fields = "Package")[[1]]
pkgload::load_all(quiet = TRUE)
app <- as.name(paste0(name, "_app"))
crow::get_screenshot_from_app(
  # shinytest2 load_all()s the working tree when the app calls library()
  eval(bquote(function() {
    library(.(package))
    .(app)()
  })),
  screenshot_args = crow::get_screenshot_args_attr(eval(app)()),
  file = file,
  strict = TRUE
)
message("Wrote ", file)
