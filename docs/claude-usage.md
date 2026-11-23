# Claude usage limits

The user's current Claude usage-limit figures are in
`"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/statusline/cache/usage"`: four numbers,
`<5h %> <5h reset epoch> <7d %> <7d reset epoch>`. Their statusline refreshes it from
the newest API response any Claude Code session has seen. Compare the reset epochs with
`date +%s`; a window whose reset has passed starts again at 0%. A missing file means
there is no subscription rate-limit data yet.

Check it before usage-heavy work (large builds, several parallel agents, long test
runs) instead of asking the user.
