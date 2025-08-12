# finfo subcommand: watch PATH [interval]

finfo_cmd_watch() {
  local W="$1" interval="${2:-1}"
  [[ -z "$W" ]] && { echo "Usage: finfo watch PATH [interval_s]"; return 2; }
  [[ "$interval" != <-> || $interval -lt 1 ]] && interval=1
  [[ ! -e "$W" ]] && { echo "${RED}✗${RESET} not found: $W"; return 1; }
  _finfo_colors; _apply_theme "${FINFOTHEME:-default}"; local LABEL="$THEME_LABEL" VALUE="$THEME_VALUE"
  echo "Watching $W every ${interval}s — Ctrl-C to stop"
  local last_sz last_mtime last_q
  while :; do
    local sz mt q=""
    if [[ $OSTYPE == darwin* ]]; then
      local sb="/usr/bin/stat"; [[ -x $sb ]] || sb="stat"
      sz=$($sb -f '%z' -- "$W" 2>/dev/null)
      mt=$($sb -f '%Sm' -t '%b %d %Y %H:%M:%S' -- "$W" 2>/dev/null)
    else
      sz=$(stat -c '%s' -- "$W" 2>/dev/null)
      mt=$(stat -c '%y' -- "$W" 2>/dev/null)
    fi
    if command -v xattr >/dev/null 2>&1; then q=$(xattr -p com.apple.quarantine "$W" 2>/dev/null | sed 's/.*/yes/'); fi
    if [[ "$sz" != "$last_sz" || "$mt" != "$last_mtime" || "$q" != "$last_q" ]]; then
      printf "  %s%-*s %s  %s%-*s %s  %s%-*s %s\n" \
        "$LABEL" 12 "size:" "$VALUE$sz$RESET" \
        "$LABEL" 12 "modified:" "$VALUE${mt:-–}$RESET" \
        "$LABEL" 12 "quarantine:" "$VALUE${q:-no}$RESET"
      last_sz="$sz"; last_mtime="$mt"; last_q="$q"
    fi
    sleep "$interval" || break
  done
  return 0
}
