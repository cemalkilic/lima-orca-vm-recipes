# Changelog

## 1.0.2

- Added a cover image and a "What crosses into the VM" screenshot to the plugin listing.
- Shortened the screenshot's alt text to fit Orca's 160-character limit.

## 1.0.0

- First release: the **Lima Ubuntu LTS** recipe (2 CPUs, 4 GiB RAM, 20 GiB disk) with create,
  suspend, resume and destroy.
- VMs have no host mounts. The repo is copied in as a git bundle, and the host's remotes are
  copied to the VM's clone with any embedded credentials removed.
