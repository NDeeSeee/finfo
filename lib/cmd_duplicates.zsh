# finfo subcommand/helper: duplicates across provided targets

finfo_cmd_duplicates() {
  # Args: list of targets (files/dirs)
  local -a targets; targets=( "$@" )
  # Collect files under provided targets (recursive)
  typeset -a to_scan; to_scan=()
  local t
  for t in "${targets[@]}"; do
    if [[ -f "$t" ]]; then
      to_scan+=("$t")
    elif [[ -d "$t" ]]; then
      local -a found=( "$t"/**/*(.N) )
      (( ${#found[@]} )) && to_scan+=("${found[@]}")
    fi
  done
  local MAX_SCAN=${FINFO_MAX_DUP_SCAN:-2000}
  local truncated=0
  if (( ${#to_scan[@]} > MAX_SCAN )); then
    to_scan=( "${(@)to_scan[1,MAX_SCAN]}" )
    truncated=1
  fi
  # checksum helper
  _cksum() {
    local p="$1"; local c=""
    if command -v shasum >/dev/null 2>&1; then c=$(shasum -a 256 -- "$p" 2>/dev/null | awk '{print $1}')
    elif command -v openssl >/dev/null 2>&1; then c=$(openssl dgst -sha256 "$p" 2>/dev/null | awk '{print $2}')
    else c=""; fi
    print -r -- "$c"
  }
  typeset -A sum_to_paths; sum_to_paths=()
  local f; for f in "${to_scan[@]}"; do
    local s; s=$(_cksum "$f")
    [[ -z "$s" ]] && continue
    if [[ -z ${sum_to_paths[$s]:-} ]]; then sum_to_paths[$s]="$f"; else sum_to_paths[$s]="${sum_to_paths[$s]}\n$f"; fi
  done
  # Render only sums with >1 files
  local has_dups=0
  for s in ${(k)sum_to_paths}; do
    local cnt; cnt=$(printf "%s\n" "${sum_to_paths[$s]}" | wc -l | tr -d ' ')
    if (( cnt > 1 )); then has_dups=1; break; fi
  done
  if (( has_dups )); then
    _section "DUPLICATES" type
    local s; for s in ${(k)sum_to_paths}; do
      local cnt; cnt=$(printf "%s\n" "${sum_to_paths[$s]}" | wc -l | tr -d ' ')
      (( cnt > 1 )) || continue
      _kv "sha256" "${DIM}${s}${RESET} — ${cnt} files"
      local i=1
      while read -r pth; do
        _kv_path " " "$pth"
        (( i++ )); (( i>5 )) && break
      done <<< "${sum_to_paths[$s]}"
    done
    (( truncated )) && _kv "Note" "scanned first ${MAX_SCAN} files only"
  fi
}
