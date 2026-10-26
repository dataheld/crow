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
