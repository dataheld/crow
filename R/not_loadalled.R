#' Skip if any of the packages come from `pkgload::load_all()`
#'
#' Loops over all packages in an object,
#' and skips if any of them are currently `pkgload::load_all()`d.
#' @inheritParams globals::globalsOf
#' @inheritDotParams globals::globalsOf
#' @keywords dependencies helper
#' @export
skip_if_any_pkgs_via_loadall <- function(expr, ...) {
  pkgs_used <- globals::packagesOf(globals::globalsOf(expr = expr, ...))
  purrr::walk(pkgs_used, elf::skip_if_pkg_installed_but_not_via_loadall)
}
