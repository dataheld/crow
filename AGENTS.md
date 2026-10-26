<!-- nullkomma:agents:start -->
## nullkomma

This project's development environment comes from [nullkomma](https://github.com/dataheld/nullkomma).
Run commands inside its dev shell:
`direnv exec . <command>`, or `nix develop --command <command>` without direnv.
`tasks` lists the project's workflows.

Check your work locally, from fastest to strictest:

1. While you work, run the narrowest task that covers the change,
   e.g. `check <name>` or a single language task.
1. Before you report a change as done, run `tasks all`, then `nix flake check`,
   and fix what fails.
   `tasks all` formats, regenerates files and runs the checks in the working tree.
   `nix flake check` runs the checks sandboxed, as CI does,
   and sees only files that Git tracks: `git add` new files first.

Skills for nullkomma itself are in `.agents/skills/nullkomma-*`;
if they are missing, run `nk-generate-files`.
<!-- nullkomma:agents:end -->
