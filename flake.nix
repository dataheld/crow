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
          removeAttrs config.allSystems.aarch64-darwin.checks [ "r-test" ]
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
        nullkomma.r.hashes.rdtools = "sha256-8BQ/3Vdl1vndn4BNdoHfjo4TP4ioBWv3Y1bZu22ej70=";

        perSystem =
          { config, ... }:
          let
            testEnvironment = {
              SHINYTEST2_LOAD_TIMEOUT = "16000";
              SHINYTEST2_TIMEOUT = "8000";
              _R_CHECK_PKG_SIZES_THRESHOLD_ = "10";
              _R_CHECK_EXCESSIVE_IMPORTS_ = "40";
              TESTTHAT_CPUS = "1";
            };
          in
          {
            # Serves the working tree's MCP tools to agents in this repository.
            nullkomma.agents.mcpServers.crow = {
              type = "stdio";
              command = lib.getExe' config.nullkomma.r.package "Rscript";
              args = [
                "--vanilla"
                "-e"
                "pkgload::load_all(quiet = TRUE); crow_mcp_server()"
              ];
            };
            nullkomma.devShell.env = testEnvironment;
            process-compose.dev.settings.processes = {
              r-check.environment = testEnvironment;
              r-test.environment = testEnvironment;
            };
          };
      }
    );
}
