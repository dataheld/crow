{
  description = "crow: Shiny development helpers";

  inputs = {
    nullkomma.url = "https://flakehub.com/f/dataheld/nullkomma/0.1.*";
    nixpkgs.follows = "nullkomma/nixpkgs";
    maxheld = {
      url = "https://flakehub.com/f/dataheld/maxheld/*";
      inputs.nullkomma.follows = "nullkomma";
    };
  };

  outputs =
    inputs:
    inputs.nullkomma.lib.mkFlake { inherit inputs; } (
      { config, lib, ... }:
      {
        # macOS Chrome needs the login user; run its browser tests in nix develop.
        flake.checks.aarch64-darwin = lib.mkForce (
          removeAttrs config.allSystems.aarch64-darwin.checks [ "r-testthat" ]
        );
        nullkomma.brand = inputs.maxheld;
        nullkomma.cloudflare = {
          enable = true;
          domain = "maxheld.de";
          worker = "crow";
        };
        # CI and deployment use project-owned workflows.
        nullkomma.github.enable = false;
        nullkomma.r.enable = true;
        nullkomma.r.shiny = {
          enable = true;
          function = "counter_button_app";
        };
        nullkomma.r.pkgdown.brand.enable = true;
        nullkomma.r.check.args = [
          "--no-manual"
          "--ignore-vignettes"
          "--no-tests"
        ];
        nullkomma.r.hashes.rdtools = "sha256-8BQ/3Vdl1vndn4BNdoHfjo4TP4ioBWv3Y1bZu22ej70=";

        perSystem =
          { config, ... }:
          let
            testEnvironment = ''
              export SHINYTEST2_LOAD_TIMEOUT=16000 SHINYTEST2_TIMEOUT=8000
              export _R_CHECK_PKG_SIZES_THRESHOLD_=10 _R_CHECK_EXCESSIVE_IMPORTS_=40
              export TESTTHAT_CPUS=1
            '';
          in
          {
            nullkomma.devShell.shellHook = testEnvironment;
            nullkomma.checks = {
              r-cmd-check.command = lib.mkBefore testEnvironment;
              r-testthat.packages = [ config.nullkomma.r.package ];
              r-testthat.command = lib.mkBefore (
                testEnvironment
                + ''
                  # shinytest2 otherwise silently skips browser tests when Chrome cannot start.
                  # shellcheck disable=SC2016
                  Rscript --vanilla -e 'browser <- chromote::ChromoteSession$new(); browser$close()'
                ''
              );
            };
          };
      }
    );
}
