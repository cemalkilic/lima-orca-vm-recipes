# Lima has no pause; stopping keeps the disk and frees CPU and memory.
limactl stop "${ORCA_VM_INSTANCE_ID:?ORCA_VM_INSTANCE_ID is not set}" >&2
