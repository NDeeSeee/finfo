# Command loader for finfo subcommands

_load_cmds() {
  local d="./lib/cmd"
  if [[ -d "$d" ]]; then
    local f
    for f in "$d"/*.zsh; do
      [[ -f "$f" ]] && source "$f"
    done
  else
    # Legacy fallback (pre-reorg)
    source ./lib/cmd_diff.zsh 2>/dev/null || true
    source ./lib/cmd_watch.zsh 2>/dev/null || true
    source ./lib/cmd_chmod.zsh 2>/dev/null || true
    source ./lib/cmd_duplicates.zsh 2>/dev/null || true
  fi
}
