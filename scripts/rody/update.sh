#!/usr/bin/env bash
# Pull the latest upstream CrossUsage into the `rody` branch, rebuild the .deb.
#   scripts/rody/update.sh            merge upstream, test, build
#   scripts/rody/update.sh --no-build merge only
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
UPSTREAM_BRANCH="feat/linux-windows-native-support"

[[ "$(git branch --show-current)" == "rody" ]] || git checkout rody
[[ -z "$(git status --porcelain)" ]] || { echo "update.sh: working tree not clean" >&2; exit 1; }

echo "==> fetching upstream"
git fetch -q upstream
before="$(git rev-parse HEAD)"
if ! git merge --no-edit "upstream/$UPSTREAM_BRANCH"; then
  echo "update.sh: merge conflict. Resolve, 'git commit', then run scripts/rody/build.sh" >&2
  exit 1
fi
if [[ "$(git rev-parse HEAD)" == "$before" ]]; then
  echo "==> already up to date with upstream/$UPSTREAM_BRANCH"
else
  echo "==> merged upstream:"; git log --oneline "$before..HEAD" --no-merges | head -20
fi

# Which of our patches has upstream already taken?
for b in fix/preserve-tray-lines-on-startup feat/base-provider-label fix/codex-account-no-base-fallback fix/no-settings-wipe-without-plugins; do
  git rev-parse -q --verify "$b" >/dev/null || continue
  if git merge-base --is-ancestor "$b" "upstream/$UPSTREAM_BRANCH"; then
    echo "    upstream already has $b"
  fi
done

git push -q origin rody
[[ "${1:-}" == "--no-build" ]] || exec "$ROOT/scripts/rody/build.sh"
