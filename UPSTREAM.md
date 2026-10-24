# Nullkomma migration findings

## Remote packages with nullkomma startup files

Building the GitHub dependency `dataheld/elf` failed during
`R CMD INSTALL` with `there is no package called 'checkmate'`, despite
checkmate being present in both its pak dependency lock and Nix build
inputs.

Elf itself uses nullkomma's native-R `.Rprofile`. During the Nix build of
this remote source, that profile runs without `NULLKOMMA_R_NIX` and calls
`.libPaths(library, include.site = FALSE)`, hiding Nix's dependency library.
The flag is set by nullkomma's R wrapper, but remote packages are built
using nixpkgs' underlying R, before that wrapper exists.

Crow temporarily supplies an elf build-input setup hook setting
`NULLKOMMA_R_NIX=true`. Upstream should set this environment variable on
all off-nixpkgs R package derivations, and test a GitHub dependency that
itself uses `r-non-nix`. The existing remote-source tests do not prevent
this startup interaction.

## CRAN packages missing from nixpkgs

Dependency resolution selected `rdtools` 0.1.0 from the 2026-10-07 PPM
snapshot, but it is absent from the selected nixpkgs R package set.
Nullkomma correctly refused to build it without a source hash. Crow
supplies the hash obtained with:

```sh
nix store prefetch-file \
  https://packagemanager.posit.co/cran/2026-10-07/src/contrib/rdtools_0.1.0.tar.gz
```

This is supported behavior, not a nullkomma defect. It would be useful
for `r-lock` to offer a hash-generation step for packages absent from
nixpkgs, so a successful lock operation also leaves a buildable project.

## Cloudflare Pages continuity

Crow retains its existing Pages project, URL, deployment credentials and
GitHub deployment reporting. The website is now built by nullkomma's
`packages.site`, using the shared brand flake.

Nullkomma's Cloudflare module provisions Workers with OpenTofu and an
R2 state backend. Switching an existing Pages site to that module would
require an infrastructure migration and additional credentials, not just
an R development-tooling migration. Crow therefore calls nullkomma's
reusable CI from a project-owned workflow and publishes its built site
through the existing Pages integration. A Pages publishing option
upstream would make this use case simpler.

## Preserved safeguards

The replacement uses nullkomma's note-fatal R CMD check,
warning-fatal installed-package testthat run, roxygen NAMESPACE
consistency check, pkgdown build, R formatting/linting, workflow and
other text-file linting, duplication detection, and working-tree secret
scanning. A separate CI job retains full-history secret scanning.
Website publishing depends on successful checks and remains main-only;
the website is also retained as a downloadable artifact.

All existing testthat tests and platform snapshots are retained.
The existing Shiny timeouts and package-check thresholds are carried
over. Docker images, container health checks and Makefile orchestration
are removed as permitted.

`DESCRIPTION` still specifies `Remotes: dataheld/elf`. Pak resolves it to
a GitHub commit in `pkg.lock`; it is not replaced by a CRAN package.
The test-only `bsicons` dependency is now explicitly declared rather
than relying on its accidental presence in a development library.
Development tools are declared in `Config/Needs/development`, so both
the Nix environment and native-R installer include them.

## macOS browser tests must run as the login user

The macOS Nix builder could not launch the installed Chrome browser:
Chrome tried to create its headless profile in the build user's
unwritable application-support directory. Supplying a temporary
`--user-data-dir` changed the error to a fatal `DIR_USER_DATA` lookup
failure, rather than making the browser usable.

The same installed-package tests pass under `nix develop` as the login
user. CI therefore runs them in a separate macOS job with Chrome,
outside the Nix builder. Only the exported macOS sandboxed
`r-testthat` derivation is omitted; the native `check r-testthat --installed` task and the Linux sandboxed derivations remain enabled.
CI pins Chrome to the version used to review the macOS screenshots.
Both website and unlisted FlakeHub publication require the native test
job to succeed.

Upstream could offer this as a supported CI execution mode for
browser-dependent packages. It should also make failed browser
initialization fatal in CI: shinytest2 otherwise reports it as skipped
tests. Crow adds a browser preflight, and runs test files serially
because parallel browser starts timed out on the Linux builder.

## Linux browser fonts

Chromium starts successfully in the Linux Nix sandbox without usable
fonts, but renders the counter screenshot almost empty: its height
shrinks from 56 to 20 pixels and its text disappears. Browser startup
alone therefore does not prove screenshots are usable.

Crow supplies Chromium with a Fontconfig configuration containing
Liberation and DejaVu fonts. The resulting screenshot has the original
dimensions and visible controls; only the reviewed rendering baseline
changes. Nullkomma's Linux browser wrapper should provide fonts by
default, with a browser integration test that checks rendered text.

## Documentation and branding warnings

Fresh-source roxygen runs emit unresolved-link warnings for links to
crow's own not-yet-generated manuals. The previous Makefile ran
roxygen twice for this reason. The package check still completes
without errors, warnings or notes, and the website builds. A configurable
documentation pass count upstream would preserve this workaround
without duplicating its R workflow commands in each consumer.

The branded pkgdown site also emits an incomplete-final-line warning
for the generated template's `_pkgdown.yml`. Nullkomma writes JSON
without a trailing newline into this YAML file; adding that newline
would avoid the warning.

## Snapshot compatibility

All existing assertions remain enabled. Snapshot headings were migrated
from testthat's old `describe: it` naming to `describe / it`; Shiny now
wraps action-button labels in an `action-label` span. Reviewed image
baselines are refreshed for the new browser and ImageMagick stack
without relaxing comparison tolerances. The four example-screenshot
setup tests were already deliberately skipped; they are not newly
disabled by this migration.

## Validation and remaining external checks

`nix flake check --all-systems --print-build-logs --keep-going` passes
for aarch64-darwin, aarch64-linux and x86_64-linux. Both Linux installed
test runs pass all 46 assertions with no test failures or warnings.
The separate native macOS installed-package run also passes all 46.
Only the four pre-existing fixture-setup skips remain. Formatting,
namespace consistency, duplication checks, R CMD check and branded
pkgdown builds pass, as does the full-history secret scan.

Linux R wrapper startup still emits shell locale warnings about
`en_US.UTF-8`, even though the package checks and tests pass. Upstream
should exercise its UTF-8 locale setup inside a Linux build sandbox.

GitHub Actions, unlisted FlakeHub publication and Cloudflare deployment
have not been executed from this checkout; they require pushing the
migration. A fresh dependency installation through the generated
non-Nix installer has not been repeated.
