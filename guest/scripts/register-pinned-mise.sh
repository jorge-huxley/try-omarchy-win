#!/bin/bash

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: register-pinned-mise.sh --root ROOT --work WORK --spec SPEC --pacman-config CONFIG

Downloads the spec-pinned official mise x86_64 archive, verifies the archive and
extracted binary digests, and installs its runtime files as a local Arch
package staged in the guest's immutable local repository.
USAGE
}

fail() {
  echo "register-pinned-mise: $*" >&2
  exit 1
}

root=""
work=""
spec=""
pacman_config=""

while (($#)); do
  case "$1" in
    --root)
      root=${2:-}
      shift 2
      ;;
    --work)
      work=${2:-}
      shift 2
      ;;
    --spec)
      spec=${2:-}
      shift 2
      ;;
    --pacman-config)
      pacman_config=${2:-}
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

[[ $root == /* && -d $root ]] || fail "--root must be an absolute staged root"
case "$root" in
  /|/bin|/boot|/etc|/home|/opt|/root|/usr|/var)
    fail "refusing unsafe root: $root"
    ;;
esac
[[ $work == /* && -d $work ]] || fail "--work must be an absolute directory"
[[ -f $spec ]] || fail "spec not found: $spec"
[[ -f $pacman_config ]] || fail "pacman config not found: $pacman_config"
for command in arch-chroot curl install pacman python3 sha256sum tar zstd; do
  command -v "$command" >/dev/null || fail "$command is required"
done

mapfile -t metadata < <(python3 - "$spec" <<'PY'
import json
import pathlib
import sys

spec = json.loads(pathlib.Path(sys.argv[1]).read_text())
component = spec.get("supplyChain", {}).get("mise")
if component is None:
    print("disabled")
    raise SystemExit
print("enabled")
for key in ("version", "url", "sha256", "binarySha256", "reportedVersion", "license"):
    print(component[key])
print(spec["image"]["architecture"])
print(spec["image"]["sourceDateEpoch"])
PY
) || fail "could not read pinned mise metadata"
[[ ${metadata[0]:-} == disabled ]] && exit 0
[[ ${metadata[0]:-} == enabled ]] || fail "invalid pinned mise state"
(( ${#metadata[@]} == 9 )) || fail "pinned mise metadata is incomplete"
version=${metadata[1]}
url=${metadata[2]}
sha256=${metadata[3]}
binary_sha256=${metadata[4]}
reported_version=${metadata[5]}
license=${metadata[6]}
architecture=${metadata[7]}
source_date_epoch=${metadata[8]}

[[ $architecture == x86_64 ]] || fail "pinned mise component supports only x86_64"
[[ $version =~ ^[0-9]{4}\.[0-9]+\.[0-9]+$ ]] || fail "invalid mise version: $version"
[[ $sha256 =~ ^[0-9a-f]{64}$ ]] || fail "invalid mise archive digest"
[[ $binary_sha256 =~ ^[0-9a-f]{64}$ ]] || fail "invalid mise binary digest"
[[ $reported_version == "$version linux-x64 ("*')' ]] || fail "invalid mise reported version"
[[ $license == MIT ]] || fail "unexpected mise license: $license"
[[ $source_date_epoch =~ ^[0-9]+$ ]] || fail "invalid source date epoch"
expected_url="https://github.com/jdx/mise/releases/download/v$version/mise-v$version-linux-x64.tar.xz"
[[ $url == "$expected_url" ]] || fail "mise URL does not match the pinned official release"

cache_dir="$work/download-cache"
install -d -m 0755 "$cache_dir"
asset_cache="$cache_dir/mise-v$version-linux-x64.tar.xz"

verify_file() {
  local expected=$1
  local path=$2
  printf '%s  %s\n' "$expected" "$path" | sha256sum -c - >/dev/null
}

download_verified() {
  local source_url=$1
  local expected=$2
  local destination=$3
  local temporary=""

  [[ ! -L $destination ]] || fail "refusing symlinked download cache entry: $destination"
  if [[ -f $destination ]] && verify_file "$expected" "$destination"; then
    return 0
  fi
  rm -f "$destination"
  temporary=$(mktemp "$cache_dir/.download.XXXXXX")
  if ! curl --fail --location --proto '=https' --tlsv1.2 --silent --show-error \
    "$source_url" --output "$temporary"; then
    rm -f "$temporary"
    fail "download failed: $source_url"
  fi
  if ! verify_file "$expected" "$temporary"; then
    rm -f "$temporary"
    fail "download digest mismatch: $source_url"
  fi
  chmod 0644 "$temporary"
  mv "$temporary" "$destination"
}

download_verified "$url" "$sha256" "$asset_cache"

package_name=try-omarchy-mise
package_version="$version-1"
stage=$(mktemp -d "$work/mise-package.XXXXXX")
cleanup() {
  rm -rf "$stage"
}
trap cleanup EXIT

expected_members=$'mise/\nmise/README.md\nmise/bin/\nmise/bin/mise\nmise/bin/mise.d\nmise/LICENSE\nmise/share/\nmise/share/fish/\nmise/share/fish/vendor_conf.d/\nmise/share/fish/vendor_conf.d/mise-activate.fish\nmise/man/\nmise/man/man1/\nmise/man/man1/mise.1'
actual_members=$(tar -tf "$asset_cache")
[[ $actual_members == "$expected_members" ]] || fail "mise archive has an unexpected member set"
install -d -m 0755 "$stage/extracted"
tar -xJf "$asset_cache" --no-same-owner -C "$stage/extracted"
verify_file "$binary_sha256" "$stage/extracted/mise/bin/mise" || fail "extracted mise binary digest mismatch"

install -d -m 0755 "$stage/usr/bin"
install -d -m 0755 "$stage/usr/share/licenses/$package_name"
install -d -m 0755 "$stage/usr/share/man/man1"
install -d -m 0755 "$stage/usr/share/fish/vendor_conf.d"
install -m 0755 "$stage/extracted/mise/bin/mise" "$stage/usr/bin/mise"
install -m 0644 "$stage/extracted/mise/LICENSE" "$stage/usr/share/licenses/$package_name/LICENSE"
install -m 0644 "$stage/extracted/mise/man/man1/mise.1" "$stage/usr/share/man/man1/mise.1"
install -m 0644 "$stage/extracted/mise/share/fish/vendor_conf.d/mise-activate.fish" \
  "$stage/usr/share/fish/vendor_conf.d/mise-activate.fish"

installed_size=$(du -sb "$stage/usr" | awk '{print $1}')
cat >"$stage/.PKGINFO" <<EOF
pkgname = $package_name
pkgbase = $package_name
pkgver = $package_version
pkgdesc = Pinned official mise $version binary for the Omarchy x86_64 guest
url = https://github.com/jdx/mise
builddate = $source_date_epoch
packager = Try Omarchy reproducible guest builder
size = $installed_size
arch = x86_64
license = MIT
provides = mise=$version
conflict = mise
depend = glibc
depend = gcc-libs
EOF

package_archive="$stage/$package_name-$package_version-x86_64.pkg.tar.zst"
tar \
  --sort=name \
  --mtime="@$source_date_epoch" \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  --format=gnu \
  -C "$stage" \
  -cf - .PKGINFO usr |
  zstd --force --quiet -12 --threads=1 -o "$package_archive"

pacman \
  --noconfirm \
  --config "$pacman_config" \
  --root "$root" \
  --dbpath "$root/var/lib/pacman" \
  --logfile "$root/var/log/pacman.log" \
  -U "$package_archive"

query=$(pacman --config "$pacman_config" --root "$root" --dbpath "$root/var/lib/pacman" -Q "$package_name")
[[ $query == "$package_name $package_version" ]] || fail "provider query returned: $query"
pacman --config "$pacman_config" --root "$root" --dbpath "$root/var/lib/pacman" -Qkk "$package_name" >/dev/null ||
  fail "installed mise package failed its ownership check"
pacman --config "$pacman_config" --root "$root" --dbpath "$root/var/lib/pacman" -T mise >/dev/null ||
  fail "installed mise package does not satisfy the mise dependency"
verify_file "$binary_sha256" "$root/usr/bin/mise" || fail "installed mise binary digest mismatch"
reported=$(arch-chroot "$root" /usr/bin/mise --version)
[[ $reported == "$reported_version" ]] || fail "mise reported an unexpected identity: $reported"

repo_dir="$root/usr/share/try-omarchy/repo"
install -d -m 0755 "$repo_dir"
install -m 0644 "$package_archive" "$repo_dir/$(basename "$package_archive")"
echo "Registered $query from verified official asset $sha256"
