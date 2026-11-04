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

## Coding agents

crow ships an [Agent Plugin](https://agent-plugins.org) in its installed package directory.
Its `add-shiny-module` skill teaches agents to build, test and document modules with crow.
Install the plugin from there,
for example in Copilot CLI:

```sh
copilot plugin install "$(Rscript -e 'cat(system.file(package = "crow"))')"
```

The plugin must match the installed crow version:
reinstall it after you upgrade crow.
