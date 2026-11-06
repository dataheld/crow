#!/usr/bin/env Rscript
# Usage: Rscript new-module.R <name>, from the root of an R package.
# Writes R/<name>.R and tests/testthat/test-<name>.R from this skill's assets.

name <- commandArgs(trailingOnly = TRUE)[1]
if (is.na(name) || !grepl("^[a-z][a-z0-9_]*$", name)) {
  stop("Give the module name in snake_case, e.g. `new-module.R foo_bar`.")
}
if (!file.exists("DESCRIPTION")) {
  stop("Run this from the root of an R package.")
}
package <- read.dcf("DESCRIPTION", fields = "Package")[[1]]
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))
assets <- file.path(dirname(script), "..", "assets")
targets <- c(
  module.R = file.path("R", paste0(name, ".R")),
  `test-module.R` = file.path("tests", "testthat", paste0("test-", name, ".R"))
)
existing <- targets[file.exists(targets)]
if (length(existing) > 0) {
  stop("Not overwriting existing files: ", toString(existing))
}
for (asset in names(targets)) {
  template <- readLines(file.path(assets, asset))
  template <- gsub("MODULE", name, template, fixed = TRUE)
  template <- gsub("PACKAGE", package, template, fixed = TRUE)
  dir.create(dirname(targets[[asset]]), recursive = TRUE, showWarnings = FALSE)
  writeLines(template, targets[[asset]])
  message("Wrote ", targets[[asset]])
}
