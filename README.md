# crow

## Overview

crow is a loose collection of helpers for your shiny development.

It can help with:

- 📦 modules
- 🧪 testing
- 📖 documentation
- ... and more

For example, `module2app()` shows a module in a full app,
with the module's input arguments, UI and return values:

![The module2app() testbed for a counter module, clicked three times](man/figures/crow_screenshots/module2app/double-counter.gif)

crow is:

- **Opinionated on quality**:
  shiny apps and modules should be exported functions in an R package.
  crow adds helpers that you call, not generated code to maintain.
  The agent skill's starter module is the one exception.
- **Flexible in implementation**:
  crow is not a framework.
  Use only the helpers that you need.
- **Lightweight**:
  crow is for development.
  Your app needs shiny, not crow.

If you want a framework or a generated app structure,
use [rhino](https://appsilon.github.io/rhino/),
[golem](https://thinkr-open.github.io/golem/)
or [leprechaun](https://leprechaun.opifex.org/).

## Installation

```r
# install.packages("pak")
pak::pak("dataheld/crow")
```

Do not add crow to `Imports:` in your `DESCRIPTION`.
If your tests or testbed apps call crow,
add it to `Suggests:`.

If they don't,
but you want to record that you used crow for development,
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
