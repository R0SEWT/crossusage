#!/usr/bin/env bash
# Build the Rody .deb from the `rody` branch: upstream + our fixes + theme-rody.css,
# updater disabled, version <upstream>-rody.<YYYYMMDDHHMM>. Output goes to ~/Downloads.
#   scripts/rody/build.sh [--skip-tests]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"

[[ "$(git branch --show-current)" == "rody" ]] || { echo "build.sh: switch to the rody branch first" >&2; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "build.sh: working tree not clean; commit or stash first" >&2; exit 1; }

base_version="$(python3 -c 'import json;print(json.load(open("package.json"))["version"])')"
version="${base_version}-rody.$(date +%Y%m%d%H%M)"
echo "==> CrossUsage ${version} ($(git rev-parse --short HEAD))"

# bundle:plugins rewrites tracked plugin files; restore them however the build ends.
trap 'git checkout -- . 2>/dev/null || true' EXIT

echo "==> bun install (frozen lockfile)"
bun install --frozen-lockfile >/dev/null

if [[ "${1:-}" != "--skip-tests" ]]; then
  echo "==> tests"
  bunx vitest run --reporter=dot
  bunx tsc --noEmit
fi

echo "==> tauri build (deb)"
log="$(mktemp)"
# The updater signing step fails without upstream's private key; the .deb is already written by then.
VITE_DISABLE_UPDATER=true bunx tauri build --bundles deb --config "{\"version\":\"${version}\"}" >"$log" 2>&1 || true
deb="$(ls -t target/release/bundle/deb/crossusage_"${version}"_*.deb 2>/dev/null | head -1 || true)"
if [[ -z "$deb" ]]; then
  tail -40 "$log" >&2
  echo "build.sh: no .deb produced (full log: $log)" >&2
  exit 1
fi
rm -f "$log"

mkdir -p "$HOME/Downloads"
out="$HOME/Downloads/$(basename "$deb")"
cp "$deb" "$out"
echo "==> built $out"
echo "    install: bash scripts/rody/install.sh \"$out\""
