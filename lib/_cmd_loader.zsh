# Command loader for finfo subcommands

_load_cmds() {
  local root="$1"
  local d="$root/lib/cmd"
  if [[ -d "$d" ]]; then
    local f
    for f in "$d"/*.zsh; do
      [[ -f "$f" ]] && source "$f"
    done
  else
    # Legacy fallback (pre-reorg)
    source "$root/lib/cmd_diff.zsh" 2>/dev/null || true
    source "$root/lib/cmd_watch.zsh" 2>/dev/null || true
    source "$root/lib/cmd_chmod.zsh" 2>/dev/null || true
    source "$root/lib/cmd_duplicates.zsh" 2>/dev/null || true
  fi
}
