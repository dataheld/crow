# crow

## Overview

crow is a loose collection of helpers for your shiny development.
It is *not* a full-blown framework like [golem](https://thinkr-open.github.io/golem/),
but a lightweight time- and line-saver.

It can help with:

- 📦 modules
- 🧪 testing
- 📖 documentation
- ... and more


## Installation

```r
# install.packages("pak")
pak::pak("dataheld/crow")
```

Notice that crow is a *development*-time dependency;
your shiny app should not need it to work,
and it thus *might not need it in your `DESCRIPTION`*.

If you use it for tests, you can include it as a `Suggests`.

If you don't need it for tests,
but want to otherwise record that you used it for development,
consider an [extra dependency](https://pak.r-lib.org/reference/package-dependency-types.html#extra-dependencies):

```DESCRIPTION
Config/Needs/website: dataheld/crow
```

## Development with Nix

The project starts from nullkomma's default flake template and uses its R
package support and the shared dataheld brand for pkgdown.
Run `nix develop` (or `direnv allow`) to enter the development environment.
Inside that shell:

```sh
tasks                          # List project tasks
format                         # Format and lint
r-document                     # Generate manuals and NAMESPACE
check                          # Run working-tree checks
check r-testthat --installed    # Exercise the installed package and browser tests
r-pkgdown                      # Build docs/
secret-history                 # Scan Git history for secrets
```

Run `nix flake check --print-build-logs` for the sandboxed CI checks and
`nix build .#site` for the branded website.
Browser tests need Chrome on macOS; nullkomma provides Chromium on Linux.
On macOS, run `check r-testthat --installed` separately: Chrome cannot run
as the Nix build user. CI enforces this native test run as a publication gate.
Update its pinned Chrome version together with reviewed macOS screenshot baselines.

After changing `DESCRIPTION`, run `nix run .#r-lock` and commit `pkg.lock`.
Keep `Remotes: dataheld/elf`: the lock records its GitHub commit, not a CRAN
substitute. Run `nix flake update` to update nullkomma and the brand, then
`nix develop -c write-files` and `nix develop -c generate-files`.
Review generated-file conflicts rather than overwriting project edits.

CI runs nullkomma's checks, scans Git history, and saves the pkgdown website
as an artifact. The reusable workflow publishes the flake to FlakeHub as
**unlisted** after successful default-branch or tag checks.
Successful main-branch pushes publish to the existing
Cloudflare Pages project using the existing repository credentials.
Migration workarounds and upstream findings are recorded in [UPSTREAM.md](UPSTREAM.md).

<!-- nullkomma:r-development:start -->
## R development without Nix {.callout-tip}

You do not need Nix or direnv to run or develop this package.

> [! NOTE]
> Developing without nix provides only limited reproducibility of the environment.
> The PPM date *approximates* the Nix package set:
> R package versions can differ,
> and neither your R installation nor system libraries are pinned by this setup.

Install R or use the version you already have.
The recommended version recorded in `.Renviron`.
Then open this directory in R, and start a fresh R session.
The committed `.Rprofile` reads `.Renviron`, selects the project's dated Posit
Package Manager (PPM) repository, and creates a writable library in
`.R/library/<R-version>/<platform>/`.

Other user and site libraries on your machine are neither affected,
nor used when the `.Rprofile` is used
(default behavior, unless you use `R --vanilla`).

### Install dependencies

Run this in the R console, from the directory containing `DESCRIPTION`:

```r
source(".R/install.R")
```

This helper installs pak and the DESCRIPTION dependencies explicitly into the project
library, even if pak is already installed elsewhere.
Re-run it to update dependencies.
It refuses to run without the project profile or inside Nix.

The PPM resolver selects a platform-specific repository when supported; a custom
repository URL is left unchanged.
pak chooses binaries when available, otherwise source packages.
The local library is Git-ignored; do not commit it.

The helper delegates resolution, downloads, caching and installation to
[`pak::local_install_deps()`](https://pak.r-lib.org/reference/local_install_deps.html),
with a single `lib` path.

### Add or remove dependencies

- To add or update a package, list it in `DESCRIPTION`, restart R and re-run
  `.R/install.R`.
- To remove a package, delete it from `DESCRIPTION`, re-run `.R/install.R`, and
  optionally remove it from the project library with
  `pak::pkg_remove("packageName", lib = getOption("nullkomma.r.library"))`.
- Commit `DESCRIPTION`. `pkg.lock` pins the packages for Nix; a Nix collaborator
  refreshes it with `r-lock`.
<!-- nullkomma:r-development:end -->
