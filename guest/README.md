# x86_64 guest image

This directory builds the single guest supported by Try Omarchy: our own
unprovisioned x86_64 Arch Linux factory image containing pinned upstream Omarchy
source. It is not a prebuilt image published by Basecamp.

From the repository root:

```sh
make guest
```

The privileged AMD64 Docker build writes verified artifacts to `dist/guest/`.
Its persistent package/source cache lives in a project-scoped Docker volume, so
repeat builds do not start from zero.

Useful lower-level commands:

```sh
guest/build-container.sh --dry-run
guest/build-container.sh --output dist/guest
guest/build-container.sh --refresh-package-lock /tmp/packages.lock.json
guest/test
```

`spec.json` is the authoritative image and runtime contract. `packages.txt` is
the requested transaction and `packages.lock.json` pins the full resolved x86_64
package set. Source repositories, commits, downloads, versions, and hashes are
reviewed inputs rather than floating build dependencies.

The output includes the kernel, initramfs, raw and compressed ext4 image,
provenance, package inventory, licenses, manifest, and SHA-256 sums. Generated
output belongs under the repository's ignored `dist/` directory and must not be
committed.
