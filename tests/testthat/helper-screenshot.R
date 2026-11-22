screenshot_size <- function(driver, ...) {
  path <- withr::local_tempfile(fileext = ".png")
  driver$get_screenshot(file = path, ...)
  unlist(magick::image_info(magick::image_read(path))[c("width", "height")])
}
