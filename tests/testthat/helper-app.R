app_factory <- function(code) {
  # testthat's environment can bypass shinytest2's global library() hook.
  rlang::new_function(pairlist(), substitute(code), globalenv())
}
