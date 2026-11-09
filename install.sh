#!/usr/bin/env bash
# install.sh — put statusline.sh in ~/.claude and wire it into settings.json.
#
#   ./install.sh            copy statusline.sh to ~/.claude/statusline.sh
#   ./install.sh --link     symlink instead of copy (keep editing it under git)
#   ./install.sh --force    also replace a statusLine entry that points elsewhere
#
# Safe by default: an existing script is backed up, and a statusLine entry
# that already points somewhere else (e.g. a wrapper that calls this script)
# is left alone unless you pass --force.
set -euo pipefail

LINK=no; FORCE=no
for a in "$@"; do
  case "$a" in
    --link)  LINK=yes ;;
    --force) FORCE=yes ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "unknown option: $a" >&2; exit 1 ;;
  esac
done

command -v jq >/dev/null || { echo "jq is required (apt install jq / brew install jq)" >&2; exit 1; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/statusline.sh"
CLAUDE_DIR="$HOME/.claude"
DEST="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
WANT_CMD="~/.claude/statusline.sh"

mkdir -p "$CLAUDE_DIR"

# ── script ──────────────────────────────────────────────────────────────────
if [ -e "$DEST" ] && [ ! -L "$DEST" ] && ! cmp -s "$DEST" "$SRC"; then
  bak="$DEST.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$DEST" "$bak"
  echo "backed up existing script to $bak"
fi
rm -f "$DEST"
if [ "$LINK" = yes ]; then
  ln -s "$SRC" "$DEST"
  echo "linked $DEST -> $SRC"
else
  cp "$SRC" "$DEST" && chmod +x "$DEST"
  echo "installed $DEST"
fi

# ── settings.json ───────────────────────────────────────────────────────────
[ -s "$SETTINGS" ] || echo '{}' > "$SETTINGS"
current=$(jq -r '.statusLine.command // empty' "$SETTINGS")
if [ -n "$current" ] && [ "$current" != "$WANT_CMD" ] && [ "$FORCE" = no ]; then
  echo "settings.json already has statusLine.command = $current"
  echo "left it alone (pass --force to replace it)"
else
  tmp=$(mktemp)
  jq --arg cmd "$WANT_CMD" \
     '.statusLine = {type: "command", command: $cmd, padding: 0}' \
     "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "set statusLine.command = $WANT_CMD in $SETTINGS"
fi

echo "done — restart Claude Code to see it."
