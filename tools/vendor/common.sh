# Shared by tools/vendor/{fetch,record,verify}. Sourced, not run.
#
# Layout:
#   tools/vendor/manifest.tsv      one row per upstream source:
#     source repo tag commit version_string archive archive_sha256 license defines patches
#       archive         comma-separated upstream_path:vendor_path pairs
#       archive_sha256  comma-separated SHA-256 of each upstream file, same order
#       defines         unused (xsum is configured in its own source)
#       patches         comma-separated file names under tools/patches/<source>/,
#                       applied in order with `patch -p1` inside the vendor dir
#   tools/vendor/checksums.sha256  SHA-256 of every file in the vendor tree, as
#                                  installed (after patches)
set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
MANIFEST="$ROOT/tools/vendor/manifest.tsv"
CHECKSUMS="$ROOT/tools/vendor/checksums.sha256"
VENDOR="$ROOT/src/vendor"
PATCHES="$ROOT/tools/patches"

sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | cut -d' ' -f1
    else
        shasum -a 256 "$1" | cut -d' ' -f1
    fi
}

manifest_rows() {
    tail -n +2 "$MANIFEST" | grep -v '^[[:space:]]*$'
}

field() {
    printf '%s\n' "$1" | cut -f"$2"
}

split_list() {
    printf '%s\n' "$1" | tr ',' '\n' | grep -v '^$' || true
}

# Download upstream files for one manifest row into directory $2, checking
# each against its recorded SHA-256, then apply the row's patches there.
fetch_row() {
    row=$1
    dest=$2
    src=$(field "$row" 1)
    repo=$(field "$row" 2)
    commit=$(field "$row" 4)
    archive=$(field "$row" 6)
    hashes=$(field "$row" 7)
    patches=$(field "$row" 10)
    mkdir -p "$dest"
    i=1
    for pair in $(split_list "$archive"); do
        up=${pair%%:*}
        to=${pair#*:}
        want=$(split_list "$hashes" | sed -n "${i}p")
        mkdir -p "$dest/$(dirname "$to")"
        curl -fsSL "https://raw.githubusercontent.com/$repo/$commit/$up" -o "$dest/$to"
        got=$(sha256 "$dest/$to")
        if [ "$got" != "$want" ]; then
            printf 'FAIL upstream %s/%s at %s hashes to %s, manifest says %s\n' \
                "$repo" "$up" "$commit" "$got" "$want" >&2
            return 1
        fi
        i=$((i + 1))
    done
    for p in $(split_list "$patches"); do
        (cd "$dest" && patch -s -p1 --no-backup-if-mismatch < "$PATCHES/$src/$p")
    done
}

record_checksums() {
    (cd "$ROOT" && find src/vendor -type f | LC_ALL=C sort | while read -r f; do
        printf '%s  %s\n' "$(sha256 "$f")" "$f"
    done) > "$CHECKSUMS"
}
