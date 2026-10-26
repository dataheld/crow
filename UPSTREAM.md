# Remaining nullkomma integration gaps

These findings apply to nullkomma 0.1.536.

## Remote R package startup

The current `dataheld/elf` source includes a native-R `.Rprofile` that
hides Nix's dependency libraries unless `NULLKOMMA_R_NIX` is set.
Nullkomma sets this flag in its development wrapper, but not in the
off-nixpkgs package derivations in `modules/lang/r/package.nix`.
Crow retains an elf build-input setup hook to set it during installation.
Upstream should supply the flag when building remote R packages.
This hook does not enable non-Nix R support in crow.

## Linux screenshot fonts

Nullkomma's default browser is plain `pkgs.chromium`, without a
Fontconfig configuration.
In crow's Linux sandbox tests, missing fonts produced an almost empty
counter screenshot, 20 pixels high instead of 56.
Crow supplies Liberation and DejaVu fonts through a browser wrapper.
Upstream should provide fonts for reproducible browser screenshots.

## Unlisted FlakeHub publication

The current reusable CI workflow no longer accepts `visibility`.
It selects public or private publication from repository visibility,
so using it would lose the explicitly requested unlisted publication.
Crow uses a project workflow with an explicit unlisted publication step
and Linux-only CI matrix.
Upstream should restore an explicit publication-visibility input and
support selecting CI systems independently of local flake checks.

## macOS CI follow-up

macOS runners are temporarily excluded at the user's request.
Local browser tests remain enabled through
`nix develop --command check r-testthat --installed`.
Restore CI coverage in [crow#52](https://github.com/dataheld/crow/issues/52).
The browser startup and runner-version findings are recorded in
[dataheld/nullkomma#255](https://github.com/dataheld/nullkomma/issues/255).
