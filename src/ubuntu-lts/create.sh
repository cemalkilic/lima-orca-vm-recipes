set -eu
# ORCA_VM_INSTANCE_ID is orca-<uuid>, already a valid Lima instance name.
name="${ORCA_VM_INSTANCE_ID:?ORCA_VM_INSTANCE_ID is not set}"
# Lima's own per-user key; it is authorized in every instance Lima creates.
key="${LIMA_HOME:-$HOME/.lima}/_config/user"
bundle="$(mktemp "${TMPDIR:-/tmp}/orca-lima.XXXXXX")"
trap 'rm -f "$bundle"; [ -n "${ok:-}" ] || limactl delete --force "$name" >/dev/null 2>&1 || true' EXIT
trap 'exit 1' INT TERM
# No host mounts: agents in the VM must not see the host's home directory.
limactl start --tty=false --name "$name" --mount-none --containerd none --cpus 2 --memory 4 --disk 20 template:ubuntu-lts >&2
home="$(limactl list "$name" --format '{{.Config.User.Home}}')"
# A bundle of the local repo works for private repos without credentials in the VM.
git bundle create "$bundle" --branches HEAD >&2
limactl copy "$bundle" "$name:$home/repo.bundle" >&2
root="$home/${PWD##*/}"
limactl shell --workdir / "$name" -- git clone -q "$home/repo.bundle" "$root" >&2
limactl shell --workdir / "$name" -- rm -f "$home/repo.bundle" >&2
# Orca links the VM checkout to the project by its Git remotes, so mirror the host's
# remotes instead of leaving origin pointing at the deleted bundle. Credentials embedded
# in http(s) URLs are stripped so host tokens never reach the VM.
limactl shell --workdir / "$name" -- git -C "$root" remote remove origin >&2
for r in $(git remote); do
  url="$(git remote get-url "$r" | sed -E 's#^(https?://)[^/@]*@#\1#')"
  limactl shell --workdir / "$name" -- git -C "$root" remote add "$r" "$url" </dev/null >&2
done
user="$(limactl list "$name" --format '{{.Config.User.Name}}')"
port="$(limactl list "$name" --format '{{.SSHLocalPort}}')"
case "$port" in ""|0) echo "Lima reported no SSH port for $name" >&2; exit 1 ;; esac
esc() { printf '%s' "$1" | sed 's/[\\"]/\\&/g'; }
printf '{"schemaVersion":1,"connection":{"type":"ssh","projectRoot":"%s","target":{"label":"%s","host":"127.0.0.1","port":%s,"username":"%s","identityFile":"%s","identitiesOnly":true}}}\n' "$(esc "$root")" "$name" "$port" "$(esc "$user")" "$(esc "$key")"
ok=1
