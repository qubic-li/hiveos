#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <path-to-qli-Client>" >&2
    exit 1
fi

QLI_CLIENT=$1
if [[ ! -f $QLI_CLIENT ]]; then
    echo "qli-Client not found: $QLI_CLIENT" >&2
    exit 1
fi

ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"

VERSION=$(grep -Po '(?<=^CUSTOM_VERSION=).*' h-manifest.conf)
if [[ -z $VERSION ]]; then
    echo "Could not read CUSTOM_VERSION from h-manifest.conf" >&2
    exit 1
fi

OUT_DIR="$ROOT/build/$VERSION"
TARBALL="$OUT_DIR/qubminer-latest.tar.gz"
HASH_FILE="$OUT_DIR/qubminer-latest.hash"

mkdir -p "$OUT_DIR"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

PKG="$STAGE/qubminer"
mkdir -p "$PKG"

cp appsettings_global.json h-config.sh h-manifest.conf h-run.sh h-stats.sh "$PKG/"
cp "$QLI_CLIENT" "$PKG/qli-Client"
chmod 0777 "$PKG"/*

tar -czf "$TARBALL" -C "$STAGE" qubminer
sha256sum "$TARBALL" | awk '{print $1}' > "$HASH_FILE"

echo "Built version $VERSION"
echo "  $TARBALL"
echo "  $HASH_FILE ($(cat "$HASH_FILE"))"
