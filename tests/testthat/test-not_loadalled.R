describe("skip_if_any_pkgs_via_loadall", {
  it(
    "skips expressions with non-existent packages",
    expect_error(
      skip_if_any_pkgs_via_loadall(

        globals::packagesOf(
          globals::globalsOf(
            # str(rlang::parse_expr("base::abs(purrr::walk())"))
            base::abs(purrr::walk(1, print))
          )
        )
      )
    )
  )
})
