#!/usr/bin/env bash
# Regenerates the Cydia/Sileo (APT) repository metadata:
#   Packages          — index of every .deb in debs/ with Size/MD5/SHA1/SHA256
#   Packages.{gz,bz2,xz} — compressed copies of the index
#   Release           — repo info + checksums of all index files
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

# Fingerprint of the generated files, used to avoid touching Release (and thus
# making a pointless commit) when nothing in the package set actually changed.
snapshot_indexes() {
    sha256sum Packages Packages.gz Packages.bz2 Packages.xz 2>/dev/null || true
}
indexes_before="$(snapshot_indexes)"

# ---------------------------------------------------------------------------
# 1. Build the Packages index from every .deb in debs/
# ---------------------------------------------------------------------------
tmp_control="$(mktemp)"
tmp_packages="$(mktemp)"
trap 'rm -f "$tmp_control" "$tmp_packages"' EXIT

: > "$tmp_packages"

shopt -s nullglob
debs=(debs/*.deb)
shopt -u nullglob

for deb in "${debs[@]}"; do
    [[ -f "$deb" ]] || continue

    # Control fields (Package, Version, Architecture, Name, ...) come from the
    # .deb itself, so there is no metadata to keep in sync by hand.
    dpkg-deb -f "$deb" > "$tmp_control"

    size=$(stat -c %s "$deb")
    md5=$(md5sum "$deb" | cut -d' ' -f1)
    sha1=$(sha1sum "$deb" | cut -d' ' -f1)
    sha256=$(sha256sum "$deb" | cut -d' ' -f1)
    sha512=$(sha512sum "$deb" | cut -d' ' -f1)

    cat "$tmp_control" >> "$tmp_packages"
    {
        printf 'Filename: %s\n' "$deb"
        printf 'Size: %s\n' "$size"
        printf 'MD5sum: %s\n' "$md5"
        printf 'SHA1: %s\n' "$sha1"
        printf 'SHA256: %s\n' "$sha256"
        printf 'SHA512: %s\n' "$sha512"
        printf '\n'
    } >> "$tmp_packages"
done

mv "$tmp_packages" Packages

# ---------------------------------------------------------------------------
# 2. Compressed indexes (-n keeps gzip byte-for-byte reproducible)
# ---------------------------------------------------------------------------
gzip -9 -n -c Packages > Packages.gz
bzip2 -9 -c Packages > Packages.bz2
xz -9 -c Packages > Packages.xz

indexes_after="$(snapshot_indexes)"
if [[ "$indexes_before" == "$indexes_after" ]] \
    && grep -q '^MD5Sum:' Release 2>/dev/null \
    && grep -q '^SHA256:' Release 2>/dev/null \
    && grep -q '^SHA512:' Release 2>/dev/null; then
    echo "Package indexes unchanged; Release left as is."
    exit 0
fi

# ---------------------------------------------------------------------------
# 3. Release: keep existing header fields, refresh Date + checksum sections
# ---------------------------------------------------------------------------
tmp_release="$(mktemp)"
trap 'rm -f "$tmp_control" "$tmp_packages" "$tmp_release"' EXIT

if [[ -f Release ]]; then
    # Drop previously generated sections so they are rebuilt from scratch.
    awk '
        /^(MD5Sum|SHA1|SHA256|SHA512|Date|Acquire-By-Hash):/ { exit }
        { print }
    ' Release > "$tmp_release"
else
    : > "$tmp_release"
fi

{
    printf 'Date: %s\n' "$(date -Ru)"
    # saurik's Cydia guide uses exactly one space between hash, size and name.
    # Keep that canonical form: some Cydia builds split by a single space.
    for algo in MD5Sum SHA1 SHA256 SHA512; do
        printf '%s:\n' "$algo"
        for file in Packages Packages.gz Packages.bz2 Packages.xz; do
            case "$algo" in
                MD5Sum) hash=$(md5sum "$file" | cut -d' ' -f1) ;;
                SHA1)   hash=$(sha1sum "$file" | cut -d' ' -f1) ;;
                SHA256) hash=$(sha256sum "$file" | cut -d' ' -f1) ;;
                SHA512) hash=$(sha512sum "$file" | cut -d' ' -f1) ;;
            esac
            size=$(stat -c %s "$file")
            printf ' %s %s %s\n' "$hash" "$size" "$file"
        done
    done
} >> "$tmp_release"

mv "$tmp_release" Release

echo "Repository metadata updated (${#debs[@]} package(s))."
