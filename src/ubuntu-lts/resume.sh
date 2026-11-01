set -eu
name="${ORCA_VM_INSTANCE_ID:?ORCA_VM_INSTANCE_ID is not set}"
key="${LIMA_HOME:-$HOME/.lima}/_config/user"
limactl start --tty=false "$name" >&2
home="$(limactl list "$name" --format '{{.Config.User.Home}}')"
root="$home/${PWD##*/}"
user="$(limactl list "$name" --format '{{.Config.User.Name}}')"
# Lima can pick a different SSH port on restart, so resume re-emits the connection.
port="$(limactl list "$name" --format '{{.SSHLocalPort}}')"
case "$port" in ""|0) echo "Lima reported no SSH port for $name" >&2; exit 1 ;; esac
esc() { printf '%s' "$1" | sed 's/[\\"]/\\&/g'; }
printf '{"schemaVersion":1,"connection":{"type":"ssh","projectRoot":"%s","target":{"label":"%s","host":"127.0.0.1","port":%s,"username":"%s","identityFile":"%s","identitiesOnly":true}}}\n' "$(esc "$root")" "$name" "$port" "$(esc "$user")" "$(esc "$key")"
