local({
  if (!nzchar(Sys.getenv("NULLKOMMA_R_NIX"))) {
    required <- c("NULLKOMMA_R_VERSION", "NULLKOMMA_PPM_URL", "NULLKOMMA_R_DEPENDENCIES")
    if (any(!nzchar(Sys.getenv(required)))) {
      stop("Missing project R settings; restore .Renviron and restart R.", call. = FALSE)
    }
    fields <- strsplit(Sys.getenv("NULLKOMMA_R_DEPENDENCIES"), ",", fixed = TRUE)[[1]]
    if (Sys.getenv("NULLKOMMA_R_ALL_CONFIG_NEEDS") == "true") {
      fields <- unique(c(fields, grep("^Config/Needs/", colnames(read.dcf("DESCRIPTION")), value = TRUE)))
    }
    options(
      repos = c(CRAN = Sys.getenv("NULLKOMMA_PPM_URL")),
      nullkomma.r.dependencies = fields
    )
    version <- paste(R.version$major, strsplit(R.version$minor, ".", fixed = TRUE)[[1]][1], sep = ".")
    library <- file.path(".R", "library", version, R.version$platform)
    dir.create(library, recursive = TRUE, showWarnings = FALSE)
    if (!dir.exists(library) || file.access(library, 2) != 0) {
      stop("The project R library is not writable: ", library, call. = FALSE)
    }
    library <- normalizePath(library, winslash = "/", mustWork = TRUE)
    Sys.setenv(R_LIBS_USER = library)
    .libPaths(library, include.site = FALSE)
    options(nullkomma.r.library = library)
    if (as.character(getRversion()) != Sys.getenv("NULLKOMMA_R_VERSION")) {
      message("Project recommends R ", Sys.getenv("NULLKOMMA_R_VERSION"),
              "; this session uses R ", getRversion(), ".")
    }
  }
})
