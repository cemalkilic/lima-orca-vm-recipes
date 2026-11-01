# Contributing

Thanks for helping out. Issues and pull requests are welcome.

## Before you open a pull request

1. Edit the scripts in `src/<recipe>/`, never `recipes/*.json` by hand.
2. Run `scripts/build.sh` and commit the regenerated JSON with your change.
3. Run `scripts/test-recipe.sh recipes/<recipe>.json` on macOS or Linux with Lima 2.x and say in
   the pull request that it passed. CI checks lint, build freshness and Orca's plugin validator; it doesn't boot VMs.

## Recipe rules

Orca runs each lifecycle command with `/bin/sh` from the repo root, so:

- Write POSIX `sh`, not bash.
- Keep stdout for the single JSON result. Send everything else to stderr (`>&2`).
- `create` must delete its VM when it fails, and `resume` must print the connection again.
- `destroy` must be safe to run twice.
- Never put credentials in the VM, a recipe, or its output.
- Don't add host mounts. They would give agents in the VM access to the host's files.

## Adding a recipe

1. Create `src/<recipe>/{create,suspend,resume,destroy}.sh`. Copy `src/ubuntu-lts/` as a start.
2. Add an `emit` line for it in `scripts/build.sh`.
3. Add its `recipes/<recipe>.json` to `contributes.vmRecipes` in `orca-plugin.json`.
4. Add it to the recipe table in the README and to `CHANGELOG.md`.

## Releasing

1. Bump `version` in `orca-plugin.json` and add a `CHANGELOG.md` entry.
2. Open a pull request. After it merges and CI passes, tag the merge commit on `main` and push: `git tag -a vX.Y.Z -m vX.Y.Z && git push origin vX.Y.Z`.

Orca asks users to review the plugin again whenever a recipe changes.
