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
      if command -v fd >/dev/null 2>&1; then
        # fd respects .gitignore and is faster
        for f in $(fd --type f --hidden --follow --color never . "$p" 2>/dev/null | head -n $max); do
          out+=( "$f" )
        done
      else
        for f in $(command find "$p" -type f 2>/dev/null); do
          out+=( "$f" )
          (( ${#out[@]} >= max )) && break
        done
      fi
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


# Minimal interactive TUI (pure zsh; no deps).
# Keys: j/k or arrows to move; Tab cycles panes; Enter to view; a actions; o open; e edit; m chmod; r clear quarantine (macOS);
# C copy path; E reveal (macOS); q quit.
finfo_tui() {
  emulate -L zsh
  setopt pipefail
  if ! [[ -t 1 ]]; then
    echo "Not a TTY; falling back to table" 1>&2
    finfo_table "$@"; return
  fi
  local -a files; files=( $(_tui_collect_paths "$@") )
  local n=${#files[@]}
  (( n == 0 )) && { echo "No files"; return; }
  local idx=1 key pane=files  # panes: files|actions
  local cols; cols=$(tput cols 2>/dev/null || echo 120)
  _draw_list() {
    command clear
    printf " %s finfo (minimal) — %d items  %sPane:%s %s\n" "$BOLD$BLUE" $n "$DIM" "$RESET" "$pane"
    local i start=1 stop=n maxitems=20
    # Window around idx
    if (( n > maxitems )); then
      start=$(( idx - maxitems/2 )); (( start < 1 )) && start=1
      stop=$(( start + maxitems - 1 )); (( stop > n )) && { stop=$n; start=$(( n - maxitems + 1 )); }
    fi
    for i in {$start..$stop}; do
      local mark="  "; (( i == idx )) && mark="> "
      printf "%s%s%s%s\n" "$mark" "$VALUE" "${files[i]}" "$RESET"
    done
    printf "\n  %sUp/Down, j/k%s  Tab: switch pane  Enter: view  a: actions  o: open  e: edit  m: chmod  r: clear quarantine  C: copy  E: reveal  q: quit\n" "$DIM" "$RESET"
  }
  while :; do
    _draw_list
    read -sk 1 key || break
    case "$key" in
      $'\t') pane=$([[ "$pane" == files ]] && echo actions || echo files);;
      $'A'|k) (( idx>1 )) && ((idx--));;               # up (arrow A when using read -sk can vary; keep k/j primary)
      $'B'|j) (( idx<n )) && ((idx++));;               # down
      '') # Enter
        finfo_interactive_one "${files[idx]}" ;;
      a)
        command clear
        printf "Actions for: %s\n\n" "${files[idx]}"
        printf "  o open default  |  e edit (
$EDITOR)  |  m chmod  |  r clear quarantine (macOS)  |  C copy abs  |  E reveal (macOS)\n"
        printf "\nPress key to execute (any other to cancel)...\n"
        read -sk 1 key || key=""
        ;;
      o)
        if command -v open >/dev/null 2>&1; then open -- "${files[idx]}" >/dev/null 2>&1 || true
        elif command -v xdg-open >/dev/null 2>&1; then xdg-open "${files[idx]}" >/dev/null 2>&1 || true
        fi;;
      e)
        if [[ -n ${EDITOR:-} ]]; then "$EDITOR" "${files[idx]}" >/dev/null 2>&1 & disown || true
        elif command -v open >/dev/null 2>&1; then open -- "${files[idx]}" >/dev/null 2>&1 || true
        fi;;
      m)
        command clear
        printf "chmod OCTAL for %s: " "${files[idx]}"; read -r oct || oct=""; [[ -n "$oct" ]] && chmod -- "$oct" "${files[idx]:A}" 2>/dev/null || true ;;
      r)
        command -v xattr >/dev/null 2>&1 && xattr -d com.apple.quarantine -- "${files[idx]:A}" >/dev/null 2>&1 || true ;;
      C) print -rn -- "${files[idx]:A}" | { command -v pbcopy >/dev/null 2>&1 && pbcopy || command -v wl-copy >/dev/null 2>&1 && wl-copy || command -v xclip >/dev/null 2>&1 && xclip -selection clipboard || cat; } ;;
      E) command -v open >/dev/null 2>&1 && open -R -- "${files[idx]}" >/dev/null 2>&1 || true ;;
      q) break;;
      *) : ;;
    esac
  done
}


# Interactive detailed view for a single file using normal finfo output segmented by sections
finfo_interactive_one() {
  emulate -L zsh
  setopt pipefail
  local target="$1"; shift || true
  if ! [[ -t 1 ]]; then "$FINFOROOT/finfo.zsh" -- "$target"; return; fi
  local show_long=0 key idx=1
  local -a sections=(
    "HEADER"
    "ESSENTIALS"
    "TIMELINE"
    "PATHS"
    "SECURITY & PROVENANCE"
    "CREATOR"
    "ACTIONS"
  )
  local tmp; tmp=$(mktemp 2>/dev/null || mktemp -t finfo)
  _render() {
    : >| "$tmp"
    if (( show_long )); then "$FINFOROOT/finfo.zsh" --long -- "$target" >| "$tmp" 2>/dev/null
    else "$FINFOROOT/finfo.zsh" --brief -- "$target" >| "$tmp" 2>/dev/null
    fi
  }
  _render
  _draw() {
    command clear
    local filedisp="${target:A}"
    printf " %s finfo interactive — %s%s\n" "$BOLD$BLUE" "$filedisp" "$RESET"
    # locate section boundaries
    local -a lines; lines=()
    local s
    for s in "${sections[@]}"; do
      local ln; ln=$(grep -n "${s}" "$tmp" | head -1 | cut -d: -f1)
      [[ -n "$ln" ]] && lines+=("$ln") || lines+=(0)
    done
    # find next nonzero start >= current index's line
    local start=${lines[$idx]}
    if (( start == 0 )); then start=1; fi
    local stop
    local j=$(( idx + 1 ))
    while (( j <= ${#sections[@]} )); do
      stop=${lines[$j]}; (( stop > 0 )) && break
      (( j++ ))
    done
    if (( stop == 0 || stop == start )); then stop=$(wc -l < "$tmp"); fi
    # print segment
    sed -n "${start},$(( stop-1 ))p" "$tmp"
    # footer with controls
    printf "\n  %s[1-7] jump  h:brief  l:long  n/p: next/prev section  o:open  e:edit  m:chmod  r:clear quarantine  c:copy  E:reveal  q:quit%s\n" "$DIM" "$RESET"
    # show tabs with current highlighted
    local t=""
    local k=1
    for s in "${sections[@]}"; do
      if (( k == idx )); then t+="$BOLD[$k:$s]$RESET "
      else t+=" $k:$s "
      fi
      (( k++ ))
    done
    printf "  %s\n" "$t"
  }
  while :; do
    _draw
    read -sk 1 key || break
    case "$key" in
      h) show_long=0;;
      l) show_long=1; _render;;
      n) (( idx < ${#sections[@]} )) && ((idx++));;
      p) (( idx > 1 )) && ((idx--));;
      [1-7]) idx=$(( $(printf %d "$key") ));;
      o)
        if command -v open >/dev/null 2>&1; then open -- "$target" >/dev/null 2>&1 || true
        elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$target" >/dev/null 2>&1 || true
        fi;;
      e)
        if [[ -n ${EDITOR:-} ]]; then "$EDITOR" "$target" >/dev/null 2>&1 & disown || true
        elif command -v open >/dev/null 2>&1; then open -- "$target" >/dev/null 2>&1 || true
        fi;;
      m)
        command clear; printf "chmod OCTAL for %s: " "$target"; local oct; read -r oct || oct=""; [[ -n "$oct" ]] && chmod -- "$oct" "$target" 2>/dev/null || true; _render;;
      r)
        command -v xattr >/dev/null 2>&1 && xattr -d com.apple.quarantine -- "$target" >/dev/null 2>&1 || true; _render;;
      c)
        print -rn -- "${target:A}" | { command -v pbcopy >/dev/null 2>&1 && pbcopy || command -v wl-copy >/dev/null 2>&1 && wl-copy || command -v xclip >/dev/null 2>&1 && xclip -selection clipboard || cat; } ;;
      E)
        command -v open >/dev/null 2>&1 && open -R -- "$target" >/dev/null 2>&1 || true ;;
      q) break;;
      *) : ;;
    esac
  done
  rm -f "$tmp"
}


