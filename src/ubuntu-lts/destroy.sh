{ name="${ORCA_VM_INSTANCE_ID:-$(sed -n 's/.*"instanceId":"\([^"]*\)".*/\1/p')}"; limactl delete --force "${name:?No instance id in ORCA_VM_INSTANCE_ID or the stdin payload}" >&2; }
