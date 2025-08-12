# Git helpers for finfo

# Sets: in_repo (0/1), branch, git_flag for a given target
_compute_git_info() {
  local abs_path="$1"
  in_repo=0; branch=""; git_flag=""
  # Determine repo root from the file's directory
  local dir="${abs_path:h}"
  if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    in_repo=1
    branch=$(git -C "$dir" symbolic-ref --quiet --short HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null)
    local status_line
    status_line=$(git -C "$dir" status --porcelain -- "$abs_path" 2>/dev/null)
    if [[ -z "$status_line" ]]; then git_flag="clean"
    elif print -r -- "$status_line" | grep -q '^??'; then git_flag="untracked"
    elif print -r -- "$status_line" | grep -Eq '^[ MARC]M|^M '; then git_flag="modified"
    elif print -r -- "$status_line" | grep -q '^A '; then git_flag="added"
    elif print -r -- "$status_line" | grep -q '^D '; then git_flag="deleted"
    else git_flag="changed"; fi
  fi
}
