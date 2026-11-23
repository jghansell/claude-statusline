# Checkout segment: the checkout as one unit; inside a submodule that is its
# outermost superproject. A linked worktree shows its name, a main checkout its
# branch, and a dot marks uncommitted changes anywhere in it (status counts
# changes inside submodules).
#
# A folder that is not a repository but holds several repositories shows its own
# name when every repo under it is a linked worktree, else the branch shared by
# every repo not on master/main, else master/main, else "mixed".
#
# Emits the loc segment, the canon fact (the main checkout's root) and, in a linked
# worktree, the worktree fact (that worktree's root).

location() {  # DIR
  local dir=$1 top super common canon="" label icon=$I_WORKTREE dirty="" r b linked=1
  if top=$(git -C $dir rev-parse --show-toplevel 2>/dev/null); then
    while super=$(git -C $top rev-parse --show-superproject-working-tree 2>/dev/null) && [[ -n $super ]]; do
      top=$super
    done
    common=$(git -C $top rev-parse --path-format=absolute --git-common-dir)
    canon=$common; [[ ${common:t} == .git ]] && canon=${common:h}
    if [[ $top == $canon ]]; then
      icon=$I_BRANCH
      label=$(git -C $top branch --show-current)
      label=${label:-$(git -C $top rev-parse --short HEAD)}
    else
      label=${top:t}
    fi
    [[ -n $(git --no-optional-locks -C $top status --porcelain 2>/dev/null | head -1) ]] && dirty=" $I_DIRTY"
  else
    local -a repos
    local -A trunk other
    repos=($dir/*/.git(N:h))
    (( ${#repos} )) || return 0
    for r in $repos; do
      [[ -f $r/.git ]] || linked=0
      b=$(git -C $r branch --show-current 2>/dev/null)
      case ${b:-detached} in
        master|main) trunk[$b]=1 ;;
        *) other[${b:-detached}]=1 ;;
      esac
      [[ -z $dirty && -n $(git --no-optional-locks -C $r status --porcelain 2>/dev/null | head -1) ]] && dirty=" $I_DIRTY"
    done
    if (( linked )); then
      label=${dir:t}
    else
      icon=$I_BRANCH
      case ${#other} in
        0) label=${(j:/:)${(ko)trunk}} ;;
        1) label=${(k)other} ;;
        *) label=mixed ;;
      esac
    fi
  fi
  emit seg loc ${${dirty:+$C_DIRTY}:-$C_CLEAN} 1 "$icon $label$dirty" "$icon $(ellipsize $label 20)$dirty"
  [[ -z $canon ]] || emit fact canon $canon
  [[ -z $canon || $top == $canon ]] || emit fact worktree $top
}

location $cwd
