#!/usr/bin/env bash
# End-to-end test of one recipe against a real Lima VM, the way Orca drives it:
# create -> SSH check -> suspend -> resume -> SSH check -> destroy (id from stdin).
# Usage: scripts/test-recipe.sh recipes/ubuntu-lts.json
set -euo pipefail

if [ $# != 1 ] || [ ! -f "$1" ]; then echo "usage: $0 recipes/<recipe>.json" >&2; exit 2; fi
recipe="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
cmd() { jq -er --arg k "$1" '.[$k]' "$recipe"; }

work="$(mktemp -d "${TMPDIR:-/tmp}/orca-lima-test.XXXXXX")"
# A space in the name exercises quoting through limactl shell and the JSON escaping.
repo="$work/demo repo"
id="orca-$(uuidgen | tr '[:upper:]' '[:lower:]')"
cleanup() { limactl delete --force "$id" >/dev/null 2>&1 || true; rm -rf "$work"; }
trap cleanup EXIT

step() { printf '\n== %s\n' "$*" >&2; }
fail() { printf 'FAIL: %b\n' "$*" >&2; exit 1; }

git init -q -b main "$repo"
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "recipe test"
# Orca matches the VM checkout to the project by remote URL, so these must survive into the VM.
git -C "$repo" remote add origin https://github.com/example/demo-repo.git
git -C "$repo" remote add upstream git@github.com:upstream/demo-repo.git
# Credentials in a remote URL must be stripped before it reaches the VM.
git -C "$repo" remote add fork https://user:s3cret-token@github.com/fork/demo-repo.git
remotes="$(git -C "$repo" remote -v | sed 's#user:s3cret-token@##')"
head="$(git -C "$repo" rev-parse HEAD)"

check_result() { # file
  [ "$(wc -l < "$1" | tr -d ' ')" = 1 ] || fail "stdout must be exactly one line:\n$(cat "$1")"
  jq -e '
    .schemaVersion == 1 and .connection.type == "ssh"
    and (.connection.projectRoot | type == "string" and startswith("/"))
    and (.connection.target | (.label|type=="string") and (.host|type=="string")
         and (.port|type=="number" and . > 0) and (.username|type=="string")
         and (.identityFile|type=="string") and .identitiesOnly == true)
    and (keys - ["schemaVersion","connection"] == [])' "$1" >/dev/null \
    || fail "result does not match the SSH recipe contract: $(cat "$1")"
  local t root
  t="$(jq -c .connection.target "$1")"; root="$(jq -r .connection.projectRoot "$1")"
  [ "$(basename "$root")" = "demo repo" ] || fail "projectRoot $root should end in 'demo repo'"
  # Dial exactly what the recipe emitted.
  got="$(ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
    -o IdentitiesOnly="$(jq -r 'if .identitiesOnly then "yes" else "no" end' <<<"$t")" \
    -i "$(jq -r .identityFile <<<"$t")" -p "$(jq -r .port <<<"$t")" \
    "$(jq -r .username <<<"$t")@$(jq -r .host <<<"$t")" \
    "git -C '$root' rev-parse HEAD && test ! -e \"\$HOME/repo.bundle\"")" \
    || fail "SSH check failed for $t"
  [ "$got" = "$head" ] || fail "VM checkout is at $got, expected $head"
  got_remotes="$(limactl shell --workdir / "$id" -- git -C "$root" remote -v)"
  [ "$got_remotes" = "$remotes" ] || fail "VM remotes differ from host:\n$got_remotes\nexpected:\n$remotes"
  [ "$(limactl list "$id" --format '{{len .Config.Mounts}}')" = 0 ] || fail "VM has host mounts"
  echo "ok: $(cat "$1")" >&2
}

step "create $id"
(cd "$repo" && ORCA_VM_INSTANCE_ID="$id" sh -c "$(cmd create)") > "$work/create.json"
check_result "$work/create.json"

step suspend
(cd "$repo" && ORCA_VM_INSTANCE_ID="$id" sh -c "$(cmd suspend)") > "$work/suspend.out"
[ ! -s "$work/suspend.out" ] || fail "suspend wrote to stdout"
[ "$(limactl list "$id" --format '{{.Status}}')" = Stopped ] || fail "VM not stopped after suspend"

step resume
(cd "$repo" && ORCA_VM_INSTANCE_ID="$id" sh -c "$(cmd resume)") > "$work/resume.json"
check_result "$work/resume.json"

step "destroy (instance id from stdin only)"
printf '{"instanceId":"%s"}' "$id" | (cd "$repo" && env -u ORCA_VM_INSTANCE_ID sh -c "$(cmd destroy)")
! limactl list -q 2>/dev/null | grep -qx "$id" || fail "VM still exists after destroy"

step "create failure cleans up"
bad="orca-$(uuidgen | tr '[:upper:]' '[:lower:]')"
# Not a git repo: create must fail at the bundle step and delete the VM it started.
mkdir "$work/not-a-repo"
if (cd "$work/not-a-repo" && ORCA_VM_INSTANCE_ID="$bad" sh -c "$(cmd create)") >/dev/null 2>"$work/bad.err"; then
  limactl delete --force "$bad" >/dev/null 2>&1; fail "create succeeded outside a git repo"
fi
! limactl list -q 2>/dev/null | grep -qx "$bad" || { limactl delete --force "$bad"; fail "failed create left $bad behind"; }

printf '\nPASS %s\n' "$(basename "$recipe")" >&2
