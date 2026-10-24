local({
  library <- getOption("nullkomma.r.library")
  if (nzchar(Sys.getenv("NULLKOMMA_R_NIX"))) {
    stop("Run this installer outside Nix; Nix supplies the R dependencies in its development shell.", call. = FALSE)
  }
  if (is.null(library)) {
    stop("Run from the project directory with its .Rprofile enabled.", call. = FALSE)
  }
  if (!identical(library, .libPaths()[1])) {
    stop("The project library must be first in .libPaths(); restart R from the project directory.", call. = FALSE)
  }
  if (file.access(library, 2) != 0) {
    stop("The project R library is not writable: ", library, call. = FALSE)
  }
  if (!requireNamespace("pak", lib.loc = library, quietly = TRUE)) {
    install.packages("pak", lib = library, repos = sprintf(
      "https://r-lib.github.io/p/pak/stable/%s/%s/%s",
      .Platform$pkgType, R.Version()$os, R.Version()$arch
    ))
  }
  if (identical(getOption("repos")[["CRAN"]], paste0(
    "https://packagemanager.posit.co/cran/", Sys.getenv("NULLKOMMA_PPM_SNAPSHOT")
  ))) {
    pak::repo_add(CRAN = paste0("PPM@", Sys.getenv("NULLKOMMA_PPM_SNAPSHOT")))
  }
  pak::local_install_deps(
    lib = library,
    dependencies = getOption("nullkomma.r.dependencies"),
    ask = FALSE
  )
})
