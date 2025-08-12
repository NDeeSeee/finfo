# Git helpers for finfo

# Sets: in_repo (0/1), branch, git_flag for a given target
_compute_git_info() {
  local target="$1"
  in_repo=0; branch=""; git_flag=""
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    in_repo=1
    branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    local status_line
    status_line=$(git status --porcelain -- "$target" 2>/dev/null)
    if [[ -z "$status_line" ]]; then git_flag="clean"
    elif print -r -- "$status_line" | grep -q '^??'; then git_flag="untracked"
    elif print -r -- "$status_line" | grep -Eq '^[ MARC]M|^M '; then git_flag="modified"
    elif print -r -- "$status_line" | grep -q '^A '; then git_flag="added"
    elif print -r -- "$status_line" | grep -q '^D '; then git_flag="deleted"
    else git_flag="changed"; fi
  fi
}
