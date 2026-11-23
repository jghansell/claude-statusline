# Helpers shared by the core script and every segment module.

# Nerd Font glyphs.
I_PROJECT=$''   # folder-open
I_ORCH=$''      # sitemap
I_WORKER=$''    # wrench
I_SESSION=$''   # comment
I_BRANCH=$''    # powerline branch
I_WORKTREE=$''  # code-fork
I_DIRTY=$'●'     # black circle
I_5H=$''        # hourglass-half
I_7D=$''        # calendar
I_AUTO=$''      # bolt
I_CTX=$''       # microchip
I_MODEL=$''     # robot
I_ISSUE=$''     # issue-opened
I_RESET=$'↻'     # clockwise arrow
PL_RIGHT=$''
CAP_L=$''
CAP_R=$''

# 256-colour palette.
C_PROJECT=67 C_SESSION=140 C_CLEAN=108 C_DIRTY=179 C_MODEL=246 C_ISSUE=74
C_OK=108 C_WARN=178 C_HOT=167 C_SEP=240 C_INK=235

pct_color() {
  local p=${1%%.*}
  (( p >= 80 )) && print $C_HOT && return
  (( p >= 50 )) && print $C_WARN && return
  print $C_OK
}

ellipsize() {  # TEXT MAX
  (( ${#1} > $2 )) && print -rn -- "${1[1,$2-1]}…" || print -rn -- $1
}

# Module output protocol, one record per line, fields separated by \x1f:
#   seg KEY COLOR LINE VARIANT...   add a segment (LINE is 1 or 2 in the two-line layout)
#   fact NAME VALUE                 pass a value to the core and to later modules
# The records count only if the module ends with status 0, so end on a command that
# succeeds, `return 0` or `exit 0`.
emit() {
  local IFS=$'\x1f'
  print -r -- "$*"
}
