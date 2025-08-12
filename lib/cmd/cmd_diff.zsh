# finfo subcommand: diff A B (porcelain-based)

finfo_cmd_diff() {
  local A="$1" B="$2"
  if [[ -z "$A" || -z "$B" ]]; then
    echo "Usage: finfo diff A B"; return 2
  fi
  _finfo_colors; _apply_theme "${FINFOTHEME:-default}"
  local LABEL="$THEME_LABEL" VALUE="$THEME_VALUE" RESET="$RESET"
  _section "DIFF" type
  local outA outB
  outA=$(finfo --porcelain --no-git -- "$A" 2>/dev/null)
  outB=$(finfo --porcelain --no-git -- "$B" 2>/dev/null)
  if [[ -z "$outA" || -z "$outB" ]]; then
    echo "${RED}✗${RESET} unable to diff (missing data)"; return 1
  fi
  typeset -A mA mB
  local key val
  while IFS=$'\t' read -r key val; do [[ -z "$key" ]] && continue; mA[$key]="$val"; done <<< "$outA"
  while IFS=$'\t' read -r key val; do [[ -z "$key" ]] && continue; mB[$key]="$val"; done <<< "$outB"
  local -a keys=( name type size_bytes size_human lines mime uttype owner_group perms_sym perms_oct created modified accessed rel abs symlink hardlinks git_branch git_status quarantine where_froms sha256 blake3 )
  local printed=0
  for key in "${keys[@]}"; do
    local va="${mA[$key]:-}" vb="${mB[$key]:-}"
    if [[ -n "$va$vb" && "$va" != "$vb" ]]; then
      printf "  %s%-*s %s → %s%s\n" "$LABEL" 12 "${key}:" "$va" "$vb" "$RESET"
      printed=1
    fi
  done
  (( printed == 0 )) && printf "  %s%-*s %s\n" "$LABEL" 12 "result:" "${VALUE}no differences in selected fields${RESET}"
  return 0
}
