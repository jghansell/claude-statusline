# Agent guide

A Claude Code statusline, published for anyone to install. `README.md` describes it
for users; this file holds the rules for changing it.

## Layout

- `statusline.zsh`: the core. It parses Claude Code's stdin JSON with jq, gates and
  runs the modules, builds the always-available segments (project, session, context,
  model), and renders and trims the line.
- `lib/common.zsh`: glyphs, colours, small helpers and `emit`, the module output
  protocol. Sourced by the core; modules inherit it.
- `segments/*.zsh`: one module per optional feature: `git` (checkout), `usage`
  (5h/7d), `hive` (role icon and launch autonomy), `workflow-issue` (bound issue and
  its mode).
- `install.sh`: POSIX sh installer. It links the script and `docs/claude-usage.md`
  into the config dir and prints the settings; it never edits them.
- `docs/claude-usage.md`: loaded into every Claude session of users who import it,
  so keep it short.

## Invariants

### Fault isolation
- Code for an optional feature lives only in its module. A user without that
  feature's dependency never runs the module's code, so a bug in it cannot touch
  their statusline.
- Every gate lives in the core and is trivial: an environment variable, a
  `$+commands[...]` lookup or a glob, with no fork. A check that needs a fork (e.g.
  `git --version`) goes in a `deep_gate_<module>` function, which runs inside the
  module's subshell.
- Modules run through `run_module`: in a subshell, with stderr discarded and a time
  limit (`MODULE_TIMEOUT`). A module that fails to parse, errors, ends with a non-zero
  status or runs out of time loses only its own segments, and the rest of the line
  renders. A module that has nothing to show must still end with status 0.
- Modules talk to the core only through `emit` records (`seg`, `fact`). The core
  ignores malformed records and strips control characters. A module may only emit
  the segments `MODULE_KEYS` assigns it. Its facts are stored as `<module>.<name>`.
- Running in a subshell keeps a module away from the core's variables and functions.
  It could still reach the core process from outside, for example by signalling `$$`
  or changing files the core reads. Modules must never do that.
- Slow work, such as git status over many repos, runs in the background behind a
  cache. The cache is replaced only by a refresh that finished with status 0, so a
  failing refresh keeps the last good output.

### Portability
- Hard requirements are zsh and jq; nothing else. Without jq the script prints one
  line saying so.
- Use zsh builtins and modules (`zsh/datetime`, `zsh/stat`, `zsh/system`) or POSIX
  tools. Never use GNU- or BSD-only flags (`date -d`, `stat -f`, `sed -i`, ...).
- The script runs with `zsh -f` and `emulate -R zsh`: never depend on the user's zsh
  configuration.
- `install.sh` is POSIX sh.

### No environment-specific content
- No absolute paths, user names, host names or references to one person's setup in
  code, comments or docs.
- Hive and the development-workflow plugin are optional integrations. Describe them
  as such, and never assume they exist.

### State
- All state lives under `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/statusline`: the
  optional `style` file and `cache/`. Nothing is ever written next to the script or
  anywhere in the repository. The script is usually a symlink into this repository.
- Code is found through `${0:A:h}`, which resolves that symlink. State is never
  found through it.

### Speed
- Claude Code reruns the script every couple of seconds in every session. A typical
  render takes about 60 ms, most of it process start-up and jq. Keep work per render
  small, and move anything slow behind a cache.

## Comments

- Clean, idiomatic code needs no comment. Comment only a deviation from the idiomatic
  pattern, to say why, and only when the reason isn't obvious from the context.
- Comments describe what the code does, never its history (why it changed, what it
  used to do).

## Testing

There is no test suite; run the script by hand. Use a throwaway config dir so your
own cache is not touched:

```sh
export CLAUDE_CONFIG_DIR=$(mktemp -d)
now=$(date +%s)
json='{"cwd":"'$PWD'","workspace":{"current_dir":"'$PWD'","project_dir":"'$PWD'"},
  "session_id":"abc12345","session_name":"demo","model":{"display_name":"Opus"},
  "effort":{"level":"high"},"context_window":{"used_percentage":42},
  "rate_limits":{"five_hour":{"used_percentage":63,"resets_at":'$((now+7000))'},
                 "seven_day":{"used_percentage":21,"resets_at":'$((now+300000))'}}}'
print -r -- $json | ./statusline.zsh
```

Before committing, cover at least:

- Input variations:
  - with and without `rate_limits`;
  - inside a repository, outside any repository, and in a folder holding several
    repositories;
  - git removed from `PATH`;
  - `HIVE_ROLE`/`HIVE_AUTONOMY` unset and set;
  - a bound-issue marker present (`.swarmbox/markers/workflow-bound-<session_id>.marker`
    holding an issue path).
- Every style (`minimal`, `powerline`, `pills`) and layout (`one`, `two`, `auto`) at
  `CLAUDE_STATUSLINE_WIDTH=60` and `200`.
- Deliberately broken modules, in a copy of the repository: a syntax error,
  `exit 1`, a fatal error such as `${unset:?}`, garbage output (bad records, control
  characters, another module's segment), and a hang (`sleep 5`). The rest of the line
  must still render, and a hang must cost no more than `MODULE_TIMEOUT`.
- The first run of a freshly copied script on macOS can take a few hundred ms longer
  while the system checks the new file. Time the second run.
- `install.sh` against a throwaway `CLAUDE_CONFIG_DIR`:
  - twice, which must be idempotent;
  - over a regular file, without `--force` (refuses) and with it (backs the file up
    to `.bak`).
- `grep -ri` the repository for paths or names from your own machine.
