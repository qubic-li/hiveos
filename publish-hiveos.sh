#!/usr/bin/env bash
#
# publish-hiveos.sh — cut a HiveOS `qubminer` release from the latest upstream qli-Client.
# See RELEASE.md for the rationale behind each step.
#
# Usage:
#   ./publish-hiveos.sh              # use the upstream release marked "Latest"
#   ./publish-hiveos.sh v3.13.0.0    # pin a specific upstream client tag
#   ./publish-hiveos.sh --no-push    # build + upload + verify, but don't git commit/push
#   ./publish-hiveos.sh v3.13.0.0 --no-push
#
set -euo pipefail

# --- config -----------------------------------------------------------------
CLIENT_REPO="qubic-li/client"
HIVE_REPO="qubic-li/hiveos"
RELEASE_TAG="latest"
ROOT="$(cd "$(dirname "$0")" && pwd)"
# ----------------------------------------------------------------------------

PIN=""
DO_PUSH=1
for a in "$@"; do
    case "$a" in
        --no-push) DO_PUSH=0 ;;
        v*)        PIN="$a" ;;
        *)         echo "unknown argument: $a" >&2; exit 2 ;;
    esac
done

die() { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1"; }
need gh; need jq; need curl; need tar; need sha256sum

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- 1. resolve upstream version -------------------------------------------
if [[ -n "$PIN" ]]; then
    CLIENT_TAG="$PIN"
else
    CLIENT_TAG=$(gh release list --repo "$CLIENT_REPO" --limit 20 \
        | awk -F'\t' '$2=="Latest"{print $1; exit}')
    [[ -n "$CLIENT_TAG" ]] || die "could not find a release marked Latest on $CLIENT_REPO"
fi
CLIENT_VER="${CLIENT_TAG#v}"                      # 3.13.0.0
PKG_VER="$(echo "$CLIENT_VER" | cut -d. -f1-3)"   # 3.13.0
[[ "$PKG_VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "bad package version derived: '$PKG_VER'"
echo "==> upstream client $CLIENT_TAG  ->  HiveOS package $PKG_VER"

# --- 2. download the Linux-x64 artifact into an isolated dir ---------------
DL="$TMP/dl"; mkdir -p "$DL"
TARBALL_NAME="qli-Client-$CLIENT_VER-Linux-x64.tar.gz"
gh release download "$CLIENT_TAG" --repo "$CLIENT_REPO" \
    --pattern "${TARBALL_NAME}*" --dir "$DL"
[[ -f "$DL/$TARBALL_NAME" ]]        || die "upstream tarball not found: $TARBALL_NAME"
[[ -f "$DL/$TARBALL_NAME.sha256" ]] || die "upstream .sha256 sidecar not found"

# --- 3. verify the published hash OF THE EXTRACTED BINARY -------------------
EX="$TMP/extracted"; mkdir -p "$EX"
tar -xzf "$DL/$TARBALL_NAME" -C "$EX"
[[ -f "$EX/qli-Client" ]] || die "no qli-Client inside upstream tarball"
WANT_BIN="$(awk '{print $1}' "$DL/$TARBALL_NAME.sha256")"
GOT_BIN="$(sha256sum "$EX/qli-Client" | awk '{print $1}')"
[[ "$GOT_BIN" == "$WANT_BIN" ]] || die "binary hash mismatch: got $GOT_BIN want $WANT_BIN"
echo "==> upstream binary hash verified: $GOT_BIN"

# --- 4. stage binary + bump manifest ---------------------------------------
cp "$EX/qli-Client" "$ROOT/build/qli-Client"
sed -i -E "s/^MINER_LATEST_VER=.*/MINER_LATEST_VER=$PKG_VER/; s/^CUSTOM_VERSION=.*/CUSTOM_VERSION=$PKG_VER/" \
    "$ROOT/h-manifest.conf"
grep -q "^CUSTOM_VERSION=$PKG_VER$" "$ROOT/h-manifest.conf" || die "manifest bump failed"

# --- 5. build ---------------------------------------------------------------
bash "$ROOT/build.sh" "$ROOT/build/qli-Client"
OUT="$ROOT/build/$PKG_VER"
PKG_TARBALL="$OUT/qubminer-latest.tar.gz"
PKG_HASH_FILE="$OUT/qubminer-latest.hash"
[[ -f "$PKG_TARBALL" && -f "$PKG_HASH_FILE" ]] || die "build did not produce expected outputs"

# --- 6. verify packaged contents -------------------------------------------
VER="$TMP/verify"; mkdir -p "$VER"
tar -xzf "$PKG_TARBALL" -C "$VER"
P="$VER/qubminer"
[[ "$(sha256sum "$P/qli-Client" | awk '{print $1}')" == "$WANT_BIN" ]] \
    || die "packaged binary hash != upstream"
grep -q "^CUSTOM_VERSION=$PKG_VER$" "$P/h-manifest.conf" \
    || die "packaged manifest version wrong"
[[ "$(grep -c 'qubminer.env\|ENV_CONFIG' "$P/h-config.sh")" -ge 1 ]] \
    || die "env-passthrough missing from packaged h-config.sh"
[[ "$(grep -c 'qubminer.env' "$P/h-run.sh")" -ge 1 ]] \
    || die "packaged h-run.sh does not source env file"
[[ "$(grep -c 'CUDA|AMD' "$P/h-stats.sh")" -eq 2 ]] \
    || die "AMD stats fix missing/changed in packaged h-stats.sh"
echo "==> packaged contents verified"

# --- 7. release notes -------------------------------------------------------
NOTES="$TMP/notes.md"
{
  echo "# 🚀 Version $PKG_VER"
  echo
  echo "Ships qli-Client $CLIENT_VER."
  echo
  echo "- Updated: qli-Client to $CLIENT_VER"
  echo "- Carries: CPU gateway/proxy env passthrough (flight-sheet \`env\`) + AMD share stats"
} > "$NOTES"
# To use upstream's own notes instead:
#   gh release view "$CLIENT_TAG" --repo "$CLIENT_REPO" --json body --jq '.body' > "$NOTES"

# --- 8. upload to the rolling `latest` release ------------------------------
gh release upload "$RELEASE_TAG" "$PKG_TARBALL" "$PKG_HASH_FILE" \
    --repo "$HIVE_REPO" --clobber
gh release edit "$RELEASE_TAG" --repo "$HIVE_REPO" --notes-file "$NOTES"

# --- 9. verify end-to-end against what is live (API is authoritative) -------
LOCAL="$(cat "$PKG_HASH_FILE")"
API_URL="$(gh release view "$RELEASE_TAG" --repo "$HIVE_REPO" --json assets \
    --jq '.assets[] | select(.name=="qubminer-latest.tar.gz") | .apiUrl')"
curl -sL -H "Authorization: token $(gh auth token)" \
     -H "Accept: application/octet-stream" "$API_URL" -o "$TMP/api.tar.gz"
API="$(sha256sum "$TMP/api.tar.gz" | awk '{print $1}')"
DLURL="https://github.com/$HIVE_REPO/releases/download/$RELEASE_TAG/qubminer-latest.tar.gz"
CDN="$(curl -sL "$DLURL" | sha256sum | awk '{print $1}')"
echo "    local=$LOCAL"
echo "    api  =$API"
echo "    cdn  =$CDN"
[[ "$LOCAL" == "$API" ]] || die "live API asset hash != packaged hash"
if [[ "$CDN" == "$LOCAL" ]]; then
    echo "==> ✅ live $PKG_VER verified end-to-end"
else
    echo "==> ✅ live $PKG_VER verified via API (CDN still propagating; re-check later)"
fi

# --- 10. commit the version bump -------------------------------------------
if [[ "$DO_PUSH" -eq 1 ]]; then
    cd "$ROOT"
    git add h-manifest.conf
    git commit -m "v.$PKG_VER"
    GIT_TERMINAL_PROMPT=0 git -c credential.helper='!gh auth git-credential' push origin main
    echo "==> committed and pushed v.$PKG_VER"
else
    echo "==> --no-push: h-manifest.conf bumped to $PKG_VER, left for manual commit"
fi
