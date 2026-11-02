# HiveOS `qubminer` release — procedure

This is the exact sequence used to cut a HiveOS release of the `qubminer` custom miner
package. It is written so it can be folded into the standard publish script. A companion
script, [`publish-hiveos.sh`](publish-hiveos.sh), implements every step below; this file
is the reference for *why* each step is there and what can break.

---

## What a release actually is

The HiveOS package is a thin wrapper around the upstream **qli-Client** binary. A release
is a `tar.gz` containing five wrapper files plus the Linux-x64 `qli-Client` binary,
published as two assets on a **single, rolling GitHub release tagged `latest`**:

```
qubminer-latest.tar.gz    the package
qubminer-latest.hash      its sha256 (one line, lowercase hex, no filename)
```

Rigs install/update from the fixed URL:

```
https://github.com/qubic-li/hiveos/releases/download/latest/qubminer-latest.tar.gz
```

### Two facts that drive the whole procedure

1. **AutoUpdate on the rigs is SHA256-based, not version-string based.** The rig compares
   the live `qubminer-latest.hash` against what it has installed and re-pulls on any
   difference (`h-config.sh`). Consequence: the `CUSTOM_VERSION` string is cosmetic for
   update propagation — any change to *any* packaged file (wrapper or binary) ships to
   every rig, and a release is "live" the moment the new tarball+hash are up. The version
   bump is for humans.

2. **Two different version numbers.** Upstream qli-Client versions are 4-part since
   v3.10.3.0 (e.g. `3.13.0.0`); the HiveOS package version is 3-part (e.g. `3.13.0`). The
   package version is the client version with the trailing `.0` dropped — concretely, the
   **first three dot-components**. The client self-reports the 4-part number at runtime;
   that's expected and not a mismatch.

---

## Inputs

- **Source of truth for the binary:** the upstream release on `qubic-li/client`, *not* a
  locally dropped binary. Always fetch from the release marked **Latest** (or an explicit
  tag the user names).
- **Target repo:** `qubic-li/hiveos`, release tag `latest`.
- **Repo working copy:** `/home/claude/qli/hiveos` (the wrapper files live here).

---

## Step-by-step

### 1. Resolve the upstream version

```bash
gh release list --repo qubic-li/client --limit 5
```

Take the row marked **Latest** (e.g. `v3.13.0.0`), unless a specific tag was requested.
Derive the package version by stripping the leading `v` and keeping the first three
components:

```
v3.13.0.0  ->  CLIENT_VER=3.13.0.0 , PKG_VER=3.13.0
```

### 2. Download the Linux-x64 artifact into an isolated directory

Downloaded archives are untrusted — put them in their own empty dir, never the repo:

```bash
gh release download v<CLIENT_VER> --repo qubic-li/client \
  --pattern 'qli-Client-<CLIENT_VER>-Linux-x64.tar.gz*' --dir "$TMP"
```

That `*` grabs both the tarball and its `.sha256` sidecar.

### 3. Verify the published hash — **of the extracted binary, not the tarball**

This is the easiest step to get wrong. The `.sha256` sidecar is the hash of the
**extracted `qli-Client` binary**, not of the downloaded tarball:

```
$ cat qli-Client-3.13.0.0-Linux-x64.tar.gz.sha256
968b8ca9...  qli-Client          <-- note the filename: it's the BINARY
```

So extract, then compare the binary:

```bash
tar -xzf qli-Client-<CLIENT_VER>-Linux-x64.tar.gz -C "$TMP/extracted"
sha256sum "$TMP/extracted/qli-Client"        # must equal the sidecar's hash
```

Comparing the sidecar against the *tarball* hash produces a false MISMATCH. Abort the
release if the binary hash does not match.

(Optional cross-check: the upstream release body carries a SHA256 table; the Linux-x64
row should equal the sidecar hash. `gh release view v<CLIENT_VER> --repo qubic-li/client
--json body`.)

### 4. Stage the binary and bump the manifest

```bash
cp "$TMP/extracted/qli-Client" /home/claude/qli/hiveos/build/qli-Client
```

In [`h-manifest.conf`](h-manifest.conf), set both lines to the 3-part package version:

```
MINER_LATEST_VER=3.13.0
CUSTOM_VERSION=3.13.0
```

`build.sh` reads `CUSTOM_VERSION` to name the output directory, so this must be set
before building.

### 5. Build

```bash
cd /home/claude/qli/hiveos
bash build.sh build/qli-Client
```

`build.sh` packages the five wrapper files (`appsettings_global.json`, `h-config.sh`,
`h-manifest.conf`, `h-run.sh`, `h-stats.sh`) plus the binary into:

```
build/<PKG_VER>/qubminer-latest.tar.gz
build/<PKG_VER>/qubminer-latest.hash
```

> The env-passthrough feature (`qubminer.env`) needs no build change — it is generated at
> runtime by `h-config.sh` from the flight sheet's `env` block and sourced by `h-run.sh`.
> It only needs those two wrapper files to be present in the package, which step 6 checks.

### 6. Verify the packaged contents

Extract the freshly built tarball to a scratch dir and assert:

- binary hash inside the package == upstream published binary hash (step 3);
- `h-manifest.conf` shows the intended `PKG_VER`;
- `h-config.sh` contains the env-passthrough logic (`grep -c 'qubminer.env\|ENV_CONFIG'` ≥ 1);
- `h-run.sh` sources the env file (`grep -c 'qubminer.env'` ≥ 1);
- `h-stats.sh` carries the AMD stats fix (`grep -c 'CUDA|AMD'` == 2).

These guard against a stale wrapper file silently dropping a feature.

### 7. Release notes

Prefer the upstream release body. Upstream often ships only "MANDATORY CLIENT UPDATE" + a
SHA256 table and no changelog; in that case use a short, honest note (what client version
it ships + the standing wrapper features). Do **not** invent a changelog.

### 8. Upload to the `latest` release

```bash
gh release upload latest \
  build/<PKG_VER>/qubminer-latest.tar.gz \
  build/<PKG_VER>/qubminer-latest.hash \
  --repo qubic-li/hiveos --clobber
gh release edit latest --repo qubic-li/hiveos --notes-file <notes>
```

`--clobber` replaces the existing assets on the rolling release.

### 9. Verify end-to-end against what is actually live

The GitHub **CDN can briefly serve a stale `.hash`** right after `--clobber` while the
tarball updates. The **API-fetched asset is authoritative**. Assert all of these equal
the local packaged hash:

```bash
LOCAL=$(cat build/<PKG_VER>/qubminer-latest.hash)

# API-authoritative asset
API_URL=$(gh release view latest --repo qubic-li/hiveos --json assets \
  --jq '.assets[] | select(.name=="qubminer-latest.tar.gz") | .apiUrl')
curl -sL -H "Authorization: token $(gh auth token)" \
     -H "Accept: application/octet-stream" "$API_URL" -o api.tar.gz
API=$(sha256sum api.tar.gz | awk '{print $1}')

# CDN (download URL) tarball + .hash file
CDN=$(curl -sL  https://github.com/qubic-li/hiveos/releases/download/latest/qubminer-latest.tar.gz | sha256sum | awk '{print $1}')
CDNHASH=$(curl -sL https://github.com/qubic-li/hiveos/releases/download/latest/qubminer-latest.hash)
```

`LOCAL == API` is the pass condition. If `CDN`/`CDNHASH` still differ, that's CDN
propagation — re-check after a short wait; it is not a failed release.

### 10. Commit the version bump

Only `h-manifest.conf` changes in the repo per release. The default push credential helper
(`git-credential-manager`) hangs on a prompt in automation; use the `gh` helper and disable
the terminal prompt:

```bash
cd /home/claude/qli/hiveos
git add h-manifest.conf
git commit -m "v.<PKG_VER>"
GIT_TERMINAL_PROMPT=0 git -c credential.helper='!gh auth git-credential' push origin main
```

> **Note on the current repo:** historically this commit has been left to a human and has
> drifted behind the published releases (HEAD was at 3.10.3 while 3.13.0 shipped). Because
> AutoUpdate is hash-based this never affected rigs, but a scripted pipeline should commit
> on every release so `HEAD` tracks what's live. Decide which side owns the commit.

---

## Failure modes seen in practice (each worth a guard in the script)

| Symptom | Cause | Guard |
|---|---|---|
| False hash MISMATCH on download | compared sidecar `.sha256` against the *tarball* instead of the extracted binary | always extract then hash `qli-Client` |
| `git push` hangs forever | `git-credential-manager` interactive prompt | `GIT_TERMINAL_PROMPT=0` + `credential.helper='!gh auth git-credential'` |
| live `.hash` ≠ packaged hash right after upload | CDN propagation lag on the `.hash` asset | treat API asset as authoritative; re-check CDN after a moment |
| `gh release view --json isLatest` errors | field not available on this `gh` version | use the "Latest" marker from `gh release list` |
| feature silently missing from package | stale wrapper file in working copy | step-6 greps for env-passthrough + AMD fix |

## Quick manual run

```bash
./publish-hiveos.sh            # resolves upstream Latest, builds, uploads, verifies
./publish-hiveos.sh v3.13.0.0  # pin a specific upstream tag
./publish-hiveos.sh --no-push  # do everything except the git commit/push
```
