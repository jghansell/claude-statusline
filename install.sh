#!/bin/sh
# Links this statusline into the Claude Code config dir and prints the settings to add.
# Usage: ./install.sh [--force]
#   --force  replace a regular file at a link path, backing it up to <name>.bak first.
set -eu

force=0
for arg in "$@"; do
  case $arg in
    --force) force=1 ;;
    -h|--help) sed -n '2,4s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) echo "install.sh: unknown option: $arg" >&2; exit 2 ;;
  esac
done

repo=$(cd "$(dirname "$0")" && pwd -P)
config=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
conf=$config/statusline

missing=0
if ! command -v zsh >/dev/null 2>&1; then
  echo "zsh not found: install the zsh package (e.g. brew install zsh, apt install zsh)." >&2
  missing=1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found: install the jq package (e.g. brew install jq, apt install jq)." >&2
  missing=1
fi
[ "$missing" -eq 0 ] || exit 1

# link TARGET PATH — points PATH at TARGET; refuses to replace anything but a symlink
# unless --force was given.
link() {
  if [ -L "$2" ]; then
    if [ "$(readlink "$2")" = "$1" ]; then
      echo "ok       $2"
      return
    fi
    rm "$2"
  elif [ -e "$2" ]; then
    if [ "$force" -eq 0 ]; then
      echo "install.sh: $2 exists and is not a symlink; rerun with --force to back it up to $2.bak and replace it." >&2
      exit 1
    fi
    mv "$2" "$2.bak"
    echo "backup   $2.bak"
  fi
  ln -s "$1" "$2"
  echo "linked   $2 -> $1"
}

mkdir -p "$conf/cache"
chmod +x "$repo/statusline.zsh"
link "$repo/statusline.zsh" "$conf/statusline.zsh"
link "$repo/docs/claude-usage.md" "$conf/claude-usage.md"

printf '%s\n' \
  '' \
  'Done. Two manual steps remain; this script edits neither file.' \
  '' \
  "1. Add the statusLine entry to $config/settings.json:" \
  '' \
  '   "statusLine": {' \
  '     "type": "command",' \
  "     \"command\": \"$conf/statusline.zsh\"," \
  '     "padding": 0,' \
  '     "refreshInterval": 2' \
  '   }' \
  '' \
  "2. Optionally, add this line to $config/CLAUDE.md so every session knows where" \
  '   to find your current usage-limit figures:' \
  '' \
  '   @statusline/claude-usage.md' \
  '' \
  '   The import is resolved relative to that CLAUDE.md, so it reaches' \
  "   $conf/claude-usage.md." \
  '' \
  'Restart Claude Code to pick up the statusline. Update later with git pull.'
