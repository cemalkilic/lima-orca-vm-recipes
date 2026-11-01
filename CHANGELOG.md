# Changelog

## 1.0.0

- First release: the **Lima Ubuntu LTS** recipe (2 CPUs, 4 GiB RAM, 20 GiB disk) with create,
  suspend, resume and destroy.
- VMs have no host mounts. The repo is copied in as a git bundle, and the host's remotes are
  copied to the VM's clone with any embedded credentials removed.
