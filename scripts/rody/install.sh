#!/usr/bin/env bash
# Install a Rody .deb (asks for sudo), skip the "what's new" wizard for our own
# rebuilds, restart CrossUsage and check it came up.
#   scripts/rody/install.sh [path/to/crossusage_*-rody.*.deb]   (default: newest in ~/Downloads)
set -euo pipefail
DATA="$HOME/.local/share/com.barramee27.crossusage"

deb="${1:-$(ls -t "$HOME"/Downloads/crossusage_*-rody.*_amd64.deb 2>/dev/null | head -1 || true)}"
[[ -f "$deb" ]] || { echo "install.sh: no Rody .deb found" >&2; exit 1; }
version="$(dpkg-deb -f "$deb" Version)"
echo "==> installing CrossUsage $version from $deb"

pkill -x crossusage 2>/dev/null || true
sleep 2
sudo apt install -y "$deb"

# The onboarding wizard reappears whenever the version changes. Mark our
# rebuild as seen (app is stopped, so it won't overwrite this).
if [[ -f "$DATA/settings.json" ]]; then
  cp "$DATA/settings.json" "$DATA/settings.json.bak-install"
  python3 - "$DATA/settings.json" "$version" <<'EOF'
import json, sys
path, version = sys.argv[1], sys.argv[2]
s = json.load(open(path))
s["dualUiOnboardingVersion"] = version
json.dump(s, open(path, "w"), indent=2)
EOF
fi

(setsid /usr/bin/crossusage >/dev/null 2>&1 &)
sleep 8
if pgrep -x crossusage >/dev/null; then
  echo "==> CrossUsage $version running"
else
  echo "install.sh: CrossUsage did not start; check $DATA/logs/crossusage.log" >&2
  exit 1
fi
