# Lima VM Recipes for Orca

An [Orca](https://www.onorca.dev) plugin that runs each workspace in its own disposable
[Lima](https://lima-vm.io) virtual machine on your own computer. Your agents get a clean
Linux box per workspace, with no access to your host's files and no cloud account involved.

> [!IMPORTANT]
> **VM recipes are an experimental Orca feature.** The **Run on** picker in the new-workspace
> screen stays hidden until you turn it on: **Settings → Experimental → Cloud VM**. The setting
> covers local VMs like these too. Because the feature is experimental, its behavior may change
> between Orca releases.

## Recipes

| Recipe                                  | Base                  | Size                           | Lifecycle                           |
| --------------------------------------- | --------------------- | ------------------------------ | ----------------------------------- |
| **Lima Ubuntu LTS** (`lima-ubuntu-lts`) | `template:ubuntu-lts` | 2 CPUs, 4 GiB RAM, 20 GiB disk | create · suspend · resume · destroy |

## Requirements

- Orca **1.4.245** or later, with **Cloud VM** turned on (see above)
- [Lima](https://lima-vm.io/docs/installation/) **2.x** (`brew install lima`), on macOS or Linux
- `git` on the host
- A project that is a **local Git repository with at least one remote** (see
  [Troubleshooting](#troubleshooting))
- Enough free resources for the VM size above

## Install

- **From the plugin directory:** in Orca, open Settings → Plugins, search for
  _Lima VM Recipes_ and choose **Install**.
- **From a checkout:** clone this repository, then in Orca open Settings → Plugins →
  **Development folders…**, add the folder, then review and enable it.

Orca shows you every recipe command before it enables the plugin.

## Usage

1. Turn on **Settings → Experimental → Cloud VM**.
2. Create a new workspace in a local Git project and choose **Run on → Lima Ubuntu LTS**.
3. Orca creates the VM. The first run downloads the Ubuntu image, which takes a few minutes;
   after that a VM takes about a minute.
4. Sleeping the workspace stops the VM, waking it starts the VM again, and deleting the
   workspace deletes the VM.

## How it works

| Step        | What happens                                                                                                                                                                                                                                                                                                                                                                                           |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **create**  | `limactl start` boots `orca-<uuid>` with **no host mounts** and containerd turned off. A `git bundle` of your branches is copied in and cloned to `~/<repo>`, and your host's remotes are copied to the clone so Orca can match it to your project. Create then prints an SSH target (`127.0.0.1`, Lima's forwarded port, Lima's key at `~/.lima/_config/user`). If any step fails, it deletes the VM. |
| **suspend** | `limactl stop`. Lima has no pause, so the VM shuts down cleanly and keeps its disk.                                                                                                                                                                                                                                                                                                                    |
| **resume**  | `limactl start`, then prints the SSH target again, because Lima often picks a new port.                                                                                                                                                                                                                                                                                                                |
| **destroy** | `limactl delete --force`. Safe to retry.                                                                                                                                                                                                                                                                                                                                                               |

### Security model

- **No host mounts.** Lima normally mounts your home directory into its VMs; these recipes turn
  that off, so agents in the VM can't read your files.
- **No credentials go in.** The repo is copied as a bundle, so private repos work without any
  token in the VM. Usernames and passwords embedded in `http(s)` remote URLs are removed before
  the remotes are copied in. Pushing from the VM needs credentials you set up inside it.
- **SSH stays on localhost.** Orca connects to `127.0.0.1` with Lima's own per-user key.
- **Ports.** Lima forwards ports the VM listens on to `127.0.0.1` on your host. That's handy for
  dev servers, and only your own machine can reach them.

### What gets copied into the VM

Only **committed branches** go in. Uncommitted changes, stashes, untracked files, submodule
contents and Git LFS files stay on the host. Commit (or push) first if the workspace needs them.

## Troubleshooting

**No "Run on" option.** Turn on **Settings → Experimental → Cloud VM**. The picker shows only for
local Git projects, not projects opened over SSH, and not when you're creating a workspace for a
project group.

**"Imported folder does not match the selected project identity."** The project has no Git
remote. Orca links the VM's checkout to your project by its remotes, so a repo with none can't
be matched. Add a remote (`git remote add origin <url>`), then remove and re-add the project in
Orca.

**Create fails or hangs.** Run the recipe outside Orca to see Lima's output:
`scripts/test-recipe.sh recipes/ubuntu-lts.json`. Common causes are low disk space, an
interrupted image download (run `limactl start template:ubuntu-lts` once by hand), and Lima 1.x.

**Leftover VMs.** `limactl list` shows every VM; Orca's VMs are named `orca-<uuid>`. Remove one
with `limactl delete --force <name>`.

## Roadmap

- **VM size you can change**: CPUs, memory and disk, instead of the fixed 2 CPUs, 4 GiB and 20 GiB.
- **Choose a Lima template**: Debian, Fedora, other Ubuntu releases, or your own template file.
- **More recipes**, such as a Docker-ready VM using Lima's `docker` template.
- **Faster creates** by starting from a prepared base VM instead of a fresh image.

Orca recipes don't take settings yet (plugin settings are a planned Orca feature), so for now each
option would ship as its own recipe. Ideas and pull requests are welcome; see
[CONTRIBUTING.md](CONTRIBUTING.md).

## Development

The recipe JSON Orca reads (`recipes/*.json`) is generated from the shell scripts in
`src/<recipe>/`. Edit those, then run:

```sh
scripts/build.sh                                 # regenerate recipes/*.json
scripts/build.sh --check                         # fail if recipes/*.json is stale
scripts/test-recipe.sh recipes/ubuntu-lts.json   # end-to-end test against a real Lima VM
```

`test-recipe.sh` drives a recipe the same way Orca does:

1. create a VM, connect over SSH to the target it prints, and check the commit and the copied
   remotes (credentials removed), and that the VM has no host mounts;
2. suspend, resume, and run the same checks again;
3. destroy, with the instance id given only on stdin;
4. check that a failed create leaves no VM behind.

It uses a repo whose name contains a space, to exercise quoting.

On Orca builds that include the plugin CLI, also run `orca plugin validate .`.

## License

[MIT](LICENSE)
