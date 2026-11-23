# Usage-limit segments: 5-hour and 7-day usage with a countdown to each reset.
#
# Claude Code only learns usage from its own API responses, so an idle session's
# figures go stale. Sessions share the newest they have seen through USAGE_FILE:
# "<5h %> <5h reset epoch> <7d %> <7d reset epoch>", "-" where unknown. Usage only
# grows within a window, so for the same reset time the higher figure is newer,
# and a later reset time is a newer window.

SAME_WINDOW=600  # reset times this close together belong to the same window

# countdown EPOCH — " ↻2.2h" until a reset; whole days (" ↻3d") when more than a day
# away, whole minutes (" ↻42m") when less than an hour.
countdown() {
  local left=$(( $1 - EPOCHSECONDS ))
  (( left < 0 )) && left=0
  if (( left > 86400 )); then
    printf ' %s%dd' $I_RESET $(( (left + 43200) / 86400 ))
  elif (( left < 3570 )); then  # rounds to under 60m
    printf ' %s%dm' $I_RESET $(( (left + 30) / 60 ))
  else
    printf ' %s%.1fh' $I_RESET $(( left / 3600.0 ))
  fi
}

newer() {  # PCT RESET PCT RESET — prints the newer "PCT RESET" pair ("-" = unknown)
  if [[ $2 == - ]] || { [[ $4 != - ]] && (( $4 > $2 + SAME_WINDOW ||
       ($4 + SAME_WINDOW >= $2 && ${3%%.*} > ${1%%.*}) )) }; then
    print -r -- "$3 $4"
  else
    print -r -- "$1 $2"
  fi
}

own=(${h5:--} ${h5r:--} ${d7:--} ${d7r:--})
[[ $own[1] == - || $own[2] == - ]] && own[1,2]=(- -)
[[ $own[3] == - || $own[4] == - ]] && own[3,4]=(- -)
shared=()
[[ -r $USAGE_FILE ]] && shared=(${=$(<$USAGE_FILE)})
(( ${#shared} == 4 )) || shared=(- - - -)
merged=(${=$(newer $own[1,2] $shared[1,2])} ${=$(newer $own[3,4] $shared[3,4])})
if [[ "$merged" != "$shared" ]]; then
  mkdir -p ${USAGE_FILE:h}
  print -r -- "$merged" >$USAGE_FILE.$$ && mv $USAGE_FILE.$$ $USAGE_FILE
fi

usage_seg() {  # KEY ICON PCT RESET
  [[ $3 == - ]] && return
  # Once a window has reset its old figure is meaningless; the new one starts at 0.
  if (( $4 <= EPOCHSECONDS )); then
    emit seg $1 $(pct_color 0) 2 "$2 0%"
  else
    emit seg $1 $(pct_color $3) 2 "$2 ${3%%.*}%$(countdown $4)" "$2 ${3%%.*}%"
  fi
}
usage_seg h5 $I_5H $merged[1,2]
usage_seg d7 $I_7D $merged[3,4]
return 0
