{
  description = "crow: Shiny development helpers";

  inputs = {
    nullkomma.url = "https://flakehub.com/f/dataheld/nullkomma/0.1.*";
    nixpkgs.follows = "nullkomma/nixpkgs";
    brand = {
      url = "https://flakehub.com/f/dataheld/brand/*";
      inputs.nullkomma.follows = "nullkomma";
    };
  };

  outputs =
    inputs:
    inputs.nullkomma.lib.mkFlake { inherit inputs; } (
      { config, lib, ... }:
      {
        # macOS Chrome needs the login user; CI runs this check outside the Nix builder.
        flake.checks.aarch64-darwin = lib.mkForce (
          removeAttrs config.allSystems.aarch64-darwin.checks [ "r-testthat" ]
        );
        nullkomma.brand = inputs.brand;
        # Keep the existing Pages deployment and its credentials.
        nullkomma.github.enable = false;
        nullkomma.r-non-nix.enable = true;
        nullkomma.r.allowOffNixpkgs = true;
        nullkomma.r.check.args = [
          "--no-manual"
          "--ignore-vignettes"
          "--no-tests"
        ];
        nullkomma.r.hashes.rdtools = "sha256-8BQ/3Vdl1vndn4BNdoHfjo4TP4ioBWv3Y1bZu22ej70=";

        perSystem =
          { pkgs, ... }:
          let
            testEnvironment = ''
              export SHINYTEST2_LOAD_TIMEOUT=16000 SHINYTEST2_TIMEOUT=8000
              export _R_CHECK_PKG_SIZES_THRESHOLD_=10 _R_CHECK_EXCESSIVE_IMPORTS_=40
              export TESTTHAT_CPUS=1
            '';
          in
          {
            nullkomma.r.browser = lib.mkIf pkgs.stdenv.isLinux (
              pkgs.writeShellApplication {
                name = "crow-chromium";
                text = ''
                  export FONTCONFIG_FILE=${
                    pkgs.makeFontsConf {
                      fontDirectories = [
                        pkgs.liberation_ttf
                        pkgs.dejavu_fonts
                      ];
                    }
                  }
                  exec ${lib.getExe pkgs.chromium} "$@"
                '';
              }
            );
            # Elf's native-R profile must not hide Nix's build dependencies.
            nullkomma.r.buildInputs.elf = [
              (pkgs.writeTextFile {
                name = "elf-nix-startup";
                destination = "/nix-support/setup-hook";
                text = "export NULLKOMMA_R_NIX=true";
              })
            ];
            nullkomma.devShell.env = {
              SHINYTEST2_LOAD_TIMEOUT = "16000";
              SHINYTEST2_TIMEOUT = "8000";
              _R_CHECK_PKG_SIZES_THRESHOLD_ = "10";
              _R_CHECK_EXCESSIVE_IMPORTS_ = "40";
            };
            nullkomma.files.".Renviron".text = lib.mkAfter ''
              _R_CHECK_PKG_SIZES_THRESHOLD_=10
              _R_CHECK_EXCESSIVE_IMPORTS_=40
              SHINYTEST2_LOAD_TIMEOUT=16000
              SHINYTEST2_TIMEOUT=8000
            '';
            nullkomma.checks = {
              r-cmd-check.command = lib.mkBefore testEnvironment;
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
