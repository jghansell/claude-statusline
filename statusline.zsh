#!/usr/bin/env -S zsh -f
# Claude Code statusline.
#
# Reads Claude Code's statusline JSON on stdin and prints one (or two) lines:
#   project │ session │ checkout │ 5h usage │ 7d usage │ context │ model │ bound issue
#
# Segments that need something beyond zsh and jq live in segments/*.zsh. Each one
# runs only when its gate below passes, in a subshell with a time limit, and reports
# through the protocol in lib/common.zsh, so a failing module loses only its own
# segments and the rest of the line still renders.
#
# Every segment has a list of variants, longest first. When the line is wider than
# the pane, TRIM_LADDER steps segments down to shorter variants (an empty variant
# drops the segment) until it fits.
#
# State lives in ${CLAUDE_CONFIG_DIR:-~/.claude}/statusline, never next to this script:
#   style        "STYLE [LAYOUT]", or $CLAUDE_STATUSLINE_STYLE. STYLE is minimal,
#                powerline or pills; LAYOUT is one, two or auto (default), where auto
#                uses one line when everything fits untrimmed and two lines otherwise.
#   cache/usage  newest usage figures seen by any session, or $CLAUDE_STATUSLINE_USAGE_FILE.
#   cache/loc-*  checkout summaries from the git module.
# Width: $CLAUDE_STATUSLINE_WIDTH, else the tmux pane width, else $COLUMNS.

emulate -R zsh
setopt extended_glob null_glob
zmodload zsh/datetime zsh/stat zsh/system

# The glyphs and width maths need a UTF-8 locale, which a bare environment lacks.
if [[ ${LC_ALL:-${LC_CTYPE:-$LANG}} != *(#i)utf(-|)8* ]]; then
  probe=$'\xc3\xa9'
  for loc in C.UTF-8 en_US.UTF-8; do
    export LC_ALL=$loc
    (( ${#probe} == 1 )) && break
  done
fi

if (( ! $+commands[jq] )); then
  print -r -- "statusline: jq not found"
  exit 0
fi

HERE=${0:A:h}
source $HERE/lib/common.zsh

CONF=${CLAUDE_CONFIG_DIR:-$HOME/.claude}/statusline
CACHE=$CONF/cache
USAGE_FILE=${CLAUDE_STATUSLINE_USAGE_FILE:-$CACHE/usage}
# Cache writes go to <file>.<pid> and are renamed into place; a run killed in between leaves that file behind.
stale=($CACHE/*.<->(N.mm+1) $USAGE_FILE.<->(N.mm+1))
(( $#stale )) && rm -f -- $stale
# In seconds.
MODULE_TIMEOUT=0.3
LOCATION_TTL=10
LOCATION_TIMEOUT=30

STYLE=$CLAUDE_STATUSLINE_STYLE
[[ -z $STYLE && -r $CONF/style ]] && STYLE=$(<$CONF/style)
style_words=(${=STYLE})
STYLE=${style_words[1]:-minimal} LAYOUT=${style_words[2]:-auto}

COLS=$CLAUDE_STATUSLINE_WIDTH
[[ $COLS != <1-> && -n $TMUX_PANE ]] && (( $+commands[tmux] )) &&
  COLS=$(tmux display -p -t $TMUX_PANE '#{pane_width}' 2>/dev/null)
[[ $COLS == <1-> ]] || COLS=$COLUMNS
[[ $COLS == <1-> ]] || COLS=200
AVAIL=$(( COLS - 4 ))  # Claude Code pads the statusline

# Display order. Each segment has a fixed owner: the core or one module.
ORDER=(project session loc h5 d7 ctx model issue)
typeset -A MODULE_KEYS=(git loc usage 'h5 d7' workflow-issue issue)

# Least useful first. Each step is segment:variant.
TRIM_LADDER=(session:2 project:2 model:2 d7:2 h5:2 model:3 issue:2 session:3 loc:2 issue:3 session:4)

IFS=$'\x1f' read -r cwd project_dir sid sname model effort ctx h5 h5r d7 d7r < <(
  jq -r '[.workspace.current_dir // .cwd, .workspace.project_dir, .session_id, .session_name,
          .model.display_name, .effort.level, .context_window.used_percentage,
          .rate_limits.five_hour.used_percentage, .rate_limits.five_hour.resets_at,
          .rate_limits.seven_day.used_percentage, .rate_limits.seven_day.resets_at]
         | map(. // "" | tostring) | join("\u001f")' 2>/dev/null)
cwd=${cwd:-$PWD}
root=${project_dir:-$cwd}

typeset -A V color line lvl FACT
# seg KEY COLOR LINE VARIANT... — LINE is 1 or 2, used by the two-line layout.
seg() {
  local k=$1 n=1 v
  color[$k]=$2 line[$k]=$3 lvl[$k]=1
  shift 3
  for v; do V[$k:$n]=$v; (( n++ )); done
}

# --- modules ---------------------------------------------------------------------

module_end() {  # STATUS — the last record of every module run
  print -r -- $'\x1e'$1
}

# run_module NAME SECONDS — runs segments/NAME.zsh in a subshell and sets reply to
# its records. Fails if the module errors, ends with a non-zero status or outlives
# SECONDS. The exit trap reports the status even when the module calls exit.
run_module() {
  local mod=$HERE/segments/$1.zsh fd pid rec rc=""
  local deadline=$(( EPOCHREALTIME + $2 )) left
  local -a out
  reply=()
  [[ -r $mod ]] || return 1
  exec {fd}< <(
    {
      print -r -- $sysparams[pid]
      trap 'module_end $?' EXIT
      { (( ! $+functions[deep_gate_$1] )) || deep_gate_$1 } && source $mod
    } 2>/dev/null </dev/null
  )
  if read -u $fd -r pid; then
    while left=$(( deadline - EPOCHREALTIME )); (( left > 0 )) && read -u $fd -t $left -r rec; do
      if [[ $rec == $'\x1e'* ]]; then
        rc=${rec#?}
        break
      fi
      out+=$rec
    done
    [[ -z $rc ]] && (( EPOCHREALTIME >= deadline )) && kill $pid 2>/dev/null
  fi
  exec {fd}<&-
  [[ $rc == 0 ]] || return 1
  reply=("${out[@]}")
}

# apply MODULE RECORD — applies one protocol record, ignoring anything malformed or
# outside the module's own segments.
apply() {
  local US=$'\x1f'
  local -a f=("${(@ps:$US:)2}")
  f=("${(@)f//[[:cntrl:]]/}")
  case $f[1] in
    seg)
      (( ${#f} >= 5 && ${${(s: :)MODULE_KEYS[$1]}[(Ie)$f[2]]} )) || return
      [[ $f[3] == <0-255> && $f[4] == [12] ]] || return
      seg "${(@)f[2,-1]}"
      ;;
    fact)
      (( ${#f} == 3 )) && [[ $f[2] == [a-z_]## ]] && FACT[$1.$f[2]]=$f[3]
      ;;
  esac
}

run_and_apply() {  # NAME
  local rec
  run_module $1 $MODULE_TIMEOUT || return
  for rec in "${reply[@]}"; do apply $1 $rec; done
}

# --- checkout (git module) -------------------------------------------------------
# git status over many repos or submodules is slow, so the git module runs in the
# background and the render reads its last records from a cache. Only a cache with
# no records yet makes the render wait for it, up to MODULE_TIMEOUT.

# A missing git, or macOS's /usr/bin/git stub without the developer tools (which
# opens an install dialog), fails this inside the module's subshell.
deep_gate_git() {
  if [[ $OSTYPE == darwin* && $commands[git] == /usr/bin/git ]]; then
    xcode-select -p &>/dev/null || return 1
  fi
  git --version &>/dev/null
}

refresh_location() {  # CACHE_FILE SECONDS
  local tmp=$1.$sysparams[pid] rc=1
  run_module git $2 && print -rl -- "${reply[@]}" >$tmp && mv $tmp $1 && rc=0
  rm -f $tmp
  return $rc
}

if (( $+commands[git] )) && mkdir -p $CACHE 2>/dev/null; then
  key=$(print -rn -- $cwd | cksum); cache_file=$CACHE/loc-${key%% *}
  # A refresh that died, or failed, leaves its lock behind; retry after a minute.
  [[ -d $cache_file.lock ]] && (( EPOCHSECONDS - $(zstat +mtime $cache_file.lock) > 60 )) &&
    rmdir $cache_file.lock 2>/dev/null
  if { [[ ! -e $cache_file ]] || (( EPOCHSECONDS - $(zstat +mtime $cache_file) > LOCATION_TTL )) } &&
      mkdir $cache_file.lock 2>/dev/null; then
    if [[ ! -e $cache_file ]] && refresh_location $cache_file $MODULE_TIMEOUT; then
      rmdir $cache_file.lock
    else
      { refresh_location $cache_file $LOCATION_TIMEOUT && rmdir $cache_file.lock } &>/dev/null &!
    fi
  fi
  if [[ -r $cache_file ]]; then
    for rec in "${(@f)$(<$cache_file)}"; do apply git $rec; done
  fi
fi

# --- usage budget ----------------------------------------------------------------
run_and_apply usage

# --- bound issue -----------------------------------------------------------------
# The development workflow marks a session bound to an issue with a marker file.
if [[ $sid == [A-Za-z0-9_-]## ]]; then
  marker_name=.swarmbox/markers/workflow-bound-$sid.marker
  canon=$FACT[git.canon]
  MARKERS=(${canon:+$canon/$marker_name(N)} $root/{,*/}$marker_name(N) $cwd/$marker_name(N))
  (( ${#MARKERS} )) && run_and_apply workflow-issue
fi

# --- Hive role -------------------------------------------------------------------
[[ -n $HIVE_ROLE || -n $HIVE_AUTONOMY ]] && run_and_apply hive

# --- project, session, context, model --------------------------------------------
# A folder inside a linked worktree is named after the same folder in the main
# checkout, so a worktree's root shows the project's name.
project=$root
worktree=$FACT[git.worktree]
if [[ -n $worktree && -n $FACT[git.canon] ]]; then
  real_root=${root:A}
  [[ $real_root == $worktree(|/*) ]] && project=$FACT[git.canon]${real_root#$worktree}
fi
seg project $C_PROJECT 1 "$I_PROJECT ${project:t}" ""

name=${sname:-${sid[1,8]}}
if [[ -n $name ]]; then
  icon=${FACT[hive.icon]:-$I_SESSION}
  # A bound issue's workflow.mode records later changes to the launch autonomy.
  autonomy=${FACT[workflow-issue.mode]:-$FACT[hive.autonomy]}
  auto=""; [[ $autonomy == autonomous ]] && auto=" $I_AUTO"
  seg session $C_SESSION 1 "$icon $name$auto" "$icon $name" "$icon $(ellipsize $name 18)" "$icon"
fi

[[ -n $ctx ]] && seg ctx $(pct_color $ctx) 2 "$I_CTX ${ctx%%.*}%"
[[ -n $model ]] && seg model $C_MODEL 2 "$I_MODEL $model${effort:+ $effort}" "$I_MODEL $model" ""

# --- render ----------------------------------------------------------------------
E=$'\e['
R="${E}0m"

render_minimal() {
  local -a out
  local k sep="${E}38;5;${C_SEP}m │ $R"
  for k; do out+="${E}38;5;${color[$k]}m${V[$k:$lvl[$k]]}$R"; done
  REPLY=${(pj:$sep:)out}
}

render_powerline() {
  local -a ks=("$@")
  local n c
  REPLY=""
  for (( n = 1; n <= ${#ks}; n++ )); do
    c=$color[$ks[n]]
    REPLY+="${E}48;5;${c};38;5;${C_INK}m ${V[$ks[n]:$lvl[$ks[n]]]} "
    if (( n < ${#ks} )); then
      REPLY+="${E}48;5;${color[$ks[n+1]]};38;5;${c}m$PL_RIGHT"
    else
      REPLY+="${E}0;38;5;${c}m$PL_RIGHT$R"
    fi
  done
}

render_pills() {
  local -a out
  local k c
  for k; do
    c=$color[$k]
    out+="${E}38;5;${c}m$CAP_L${E}48;5;${c};38;5;${C_INK}m${V[$k:$lvl[$k]]}${R}${E}38;5;${c}m$CAP_R$R"
  done
  REPLY=${(j: :)out}
}

# Sets LINES_OUT to the rendered line(s) for the current variant levels.
render() {
  local -a visible line1 line2
  local k
  for k in $ORDER; do [[ -n ${V[$k:$lvl[$k]]} ]] && visible+=$k; done
  local fn=render_$STYLE
  (( ${+functions[$fn]} )) || fn=render_minimal
  LINES_OUT=()
  if [[ $LAYOUT == two ]]; then
    for k in $visible; do
      if [[ $line[$k] == 1 ]]; then line1+=$k; else line2+=$k; fi
    done
    $fn $line1; LINES_OUT+=$REPLY
    $fn $line2; LINES_OUT+=$REPLY
  else
    $fn $visible; LINES_OUT+=$REPLY
  fi
}

WIDTHS_OUT=()
widest() {  # sets REPLY to the widest line's width and WIDTHS_OUT to every line's
  local l plain w=0
  WIDTHS_OUT=()
  for l in $LINES_OUT; do
    plain=${l//$'\e'\[[0-9;]##m/}
    WIDTHS_OUT+=${(m)#plain}
    (( ${(m)#plain} > w )) && w=${(m)#plain}
  done
  REPLY=$w
}

render; widest
if [[ $LAYOUT == auto ]] && (( REPLY > AVAIL )); then
  LAYOUT=two
  render; widest
fi
for step in $TRIM_LADDER; do
  (( REPLY <= AVAIL )) && break
  k=${step%:*}
  (( ${+V[$step]} )) || continue
  # On two lines, only trim the line that overflows.
  [[ $LAYOUT == two ]] && (( WIDTHS_OUT[line[$k]] <= AVAIL )) && continue
  lvl[$k]=${step#*:}
  render; widest
done
print -rl -- $LINES_OUT
