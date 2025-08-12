# Command loader for finfo subcommands

_load_cmds() {
  local root="$1"
  local d="$root/lib/cmd"
  if [[ -d "$d" ]]; then
    local f
    for f in "$d"/*.zsh; do
      [[ -f "$f" ]] && source "$f"
    done
  fi
}
