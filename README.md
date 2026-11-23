# Claude Code statusline

A statusline for [Claude Code](https://code.claude.com) that shows:

```
project │ session │ git branch/worktree ● │ 5h usage ↻reset │ 7d usage ↻reset │ context % │ model effort │ bound issue
```

- Usage and context percentages turn yellow at 50% and red at 80%.
- The project is the folder Claude Code was started in. Inside a linked worktree it
  is the matching folder of the main checkout, so a worktree's root shows the
  project's name.
- A dot after the branch means uncommitted changes. A linked worktree shows its name
  instead of the branch.
- Claude Code only reports your 5-hour and 7-day usage in a session after that
  session's own API calls. Every session therefore shares the newest figures it has
  seen, so an idle session still shows current numbers.
- When the terminal is too narrow, segments shrink or drop out, and the line splits
  in two.

## Requirements

- zsh (the default shell on macOS; on Linux install the `zsh` package)
- jq (`brew install jq`, `apt install jq`, ...)

Optional; each segment is skipped when its dependency is missing:

- git, for the branch/worktree segment
- tmux, whose pane width is used when you run Claude Code inside it
- A [Nerd Font](https://www.nerdfonts.com) as your terminal font, for the icons
- Hive and its development-workflow plugin: a role icon and autonomy bolt on the
  session segment, and the bound-issue segment

The 5h/7d usage segments need a Claude subscription (Pro, Max, ...); Claude Code
does not report rate limits for API-key usage.

## Install

```sh
git clone <this repository> ~/Source/claude-statusline
~/Source/claude-statusline/install.sh
```

`install.sh` checks for zsh and jq, creates `~/.claude/statusline/` (or
`$CLAUDE_CONFIG_DIR/statusline/` when you set `CLAUDE_CONFIG_DIR`), and symlinks the
script and the usage doc into it. It never edits your settings: it prints the
`statusLine` entry to add to `settings.json` and the optional `CLAUDE.md` line. Then
restart Claude Code.

If something other than a symlink is already at `~/.claude/statusline/statusline.zsh`,
for example an older copy, the installer stops. Rerun it with `--force` to move that
file to `statusline.zsh.bak` and link the repository's script in its place.

### Manual install

```sh
conf="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/statusline"
mkdir -p "$conf/cache"
ln -s ~/Source/claude-statusline/statusline.zsh "$conf/statusline.zsh"
ln -s ~/Source/claude-statusline/docs/claude-usage.md "$conf/claude-usage.md"
```

Add to `settings.json` in the same config dir. If you set `CLAUDE_CONFIG_DIR`, use
that directory in place of `~/.claude` in `command`:

```json
"statusLine": {
  "type": "command",
  "command": "~/.claude/statusline/statusline.zsh",
  "padding": 0,
  "refreshInterval": 2
}
```

### Update

```sh
git -C ~/Source/claude-statusline pull
```

Every statusline picks up the change on its next refresh.

## Customising

Your settings and cache live in `~/.claude/statusline/`, never in the repository.

**Style.** Create `~/.claude/statusline/style` holding `STYLE [LAYOUT]`, for example
`powerline two`:

- STYLE: `minimal` (default), `powerline` or `pills`
- LAYOUT: `auto` (default; one line if it fits, else two), `one` or `two`

Or set the `CLAUDE_STATUSLINE_STYLE` environment variable instead.

**Width.** Set `CLAUDE_STATUSLINE_WIDTH` to fix the width. Otherwise the statusline
uses the tmux pane width, then `$COLUMNS`, then 200.

**Usage file.** The shared usage figures are in `~/.claude/statusline/cache/usage`.
Set `CLAUDE_STATUSLINE_USAGE_FILE` to use a different file.

## Telling Claude about your usage

The usage file holds four numbers, `<5h %> <5h reset epoch> <7d %> <7d reset epoch>`.
Claude can read it to check your remaining budget before heavy work instead of asking
you. To tell every session about it, add this line to `~/.claude/CLAUDE.md`:

```
@statusline/claude-usage.md
```

The import is resolved relative to that `CLAUDE.md`, so it loads
[docs/claude-usage.md](docs/claude-usage.md) through the installed symlink, and
updates with the repository.

## Testing

Pipe sample JSON into the script:

```sh
echo '{"cwd":"'$PWD'","session_id":"abc12345","model":{"display_name":"Opus"},"context_window":{"used_percentage":42}}' \
  | "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/statusline/statusline.zsh"
```

## Uninstall

Remove the `statusLine` entry from `settings.json` and the `@statusline/claude-usage.md`
line from `CLAUDE.md`, then:

```sh
rm -r "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/statusline"
```
