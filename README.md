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

For example, `module2app()` shows a module in a full app,
with the module's input arguments, UI and return values:

![The module2app() testbed for a counter module, clicked three times](man/figures/crow_screenshots/module2app/double-counter.gif)

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

Clients such as Copilot CLI copy the plugin when they install it:
reinstall it after you upgrade crow.

The plugin's MCP server lets agents run a module of your package
without crow's displays for humans,
set its inputs, read its arguments, return values, reactlog events and logs,
and screenshot it
(see `?crow_tools`).
It needs Chrome.
The server runs R code that the agent writes, with your rights;
only a sandbox around the agent isolates your system from that code.
To serve crow's tools together with [btw](https://posit-dev.github.io/btw/)'s,
configure this server in your project instead:

```sh
Rscript -e 'mcptools::mcp_server(c(btw::btw_tools(c("docs", "pkg")), crow::crow_tools()), session_tools = FALSE)'
```
