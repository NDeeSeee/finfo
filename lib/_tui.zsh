# TUI and table helpers

# Collect files from inputs (files kept as-is; dirs expanded up to cap)
_tui_collect_paths() {
  emulate -L zsh
  local max=${FINFO_TUI_MAX:-3000}
  local -a inputs; inputs=( "$@" )
  (( ${#inputs[@]} == 0 )) && inputs=( . )
  local -a out; out=()
  local p f
  for p in "${inputs[@]}"; do
    if [[ -f "$p" ]]; then
      out+=( "$p" )
    elif [[ -d "$p" ]]; then
      local IFS=$'\n'
      for f in $(command find "$p" -type f 2>/dev/null); do
        out+=( "$f" )
        (( ${#out[@]} >= max )) && break
      done
    fi
    (( ${#out[@]} >= max )) && break
  done
  print -r -- ${(F)out}
}

# Non-interactive compact table (pure zsh, column-aligned)
finfo_table() {
  emulate -L zsh
  setopt pipefail
  local -a files; files=( $(_tui_collect_paths "$@") )
  local tmp
  tmp=$(mktemp 2>/dev/null || mktemp -t finfo)
  {
    printf "Name\tBytes\tSize\tType\tVerdict\tPath\n"
    local p j name bytes size type verdict rel
    for p in "${files[@]}"; do
      j=$("$FINFOROOT/finfo.zsh" --json -- "$p" 2>/dev/null) || continue
      name=$(printf %s "$j" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p' | head -1)
      bytes=$(printf %s "$j" | sed -n 's/.*"bytes":\([0-9][0-9]*\).*/\1/p' | head -1)
      size=$(printf %s "$j" | sed -n 's/.*"human":"\([^"]*\)".*/\1/p' | head -1)
      type=$(printf %s "$j" | sed -n 's/.*"description":"\([^"]*\)".*/\1/p' | head -1)
      verdict=$(printf %s "$j" | sed -n 's/.*"verdict":"\([^"]*\)".*/\1/p' | head -1)
      rel=$(printf %s "$j" | sed -n 's/.*"rel":"\([^"]*\)".*/\1/p' | head -1)
      printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$name" "$bytes" "$size" "$type" "$verdict" "$rel"
    done
  } >| "$tmp"
  command column -t -s $'\t' "$tmp"
  rm -f "$tmp"
}

# Interactive browser (fzf + jq). Falls back to finfo_table if deps missing.
finfo_browse() {
  emulate -L zsh
  if ! command -v fzf >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    printf "Dependencies missing (fzf and jq). Showing plain table.\n" 1>&2
    finfo_table "$@"
    return
  fi
  local -a files; files=( $(_tui_collect_paths "$@") )
  local tmp
  tmp=$(mktemp 2>/dev/null || mktemp -t finfo)
  local p
  for p in "${files[@]}"; do
    "$FINFOROOT/finfo.zsh" --json -- "$p" 2>/dev/null || true
  done | jq -r '[.name,.size.bytes,.size.human,.type.description,.security.verdict,.path.rel] | @tsv' >| "$tmp"

  FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:-} --ansi --bind=alt-s:toggle-sort --height 90% --layout=reverse --info=inline" \
  fzf --header=$'Name\tBytes\tSize\tType\tVerdict\tPath' --with-nth=1,3,4,5,6 \
      --delimiter=$'\t' --multi --preview-window=right:70% \
      --preview '"$FINFOROOT/finfo.zsh" --long -- {6}' < "$tmp"
  rm -f "$tmp"
}


