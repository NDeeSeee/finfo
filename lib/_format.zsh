# Formatting helpers for finfo.zsh

_term_cols() { local c=${COLUMNS:-}; [[ -z $c ]] && c=$(tput cols 2>/dev/null || echo 120); echo $c; }
_ellipsize_middle() {
  local s="$1" max="$2"; (( ${#s} <= max )) && { print -r -- "$s"; return; }
  local head=$(( (max-1)/2 )) tail=$(( max - head - 1 ));
  print -r -- "${s[1,head]}…${s[-tail,-1]}"
}

_section() {
  local title="$1"; local key="$2"; local cols=$(_term_cols)
  if _has_nerd; then
    local tag_l="" tag_r=""; local bg=$(_bg256 ${THEME_HDR_BG_IDX:-24}) fg=$(_color256 15)
    local ic; ic=$(_sec_icon "$key")
    printf "  %s%s%s %s %s %s%s" "$bg" "$fg" "$tag_l" "$ic" "$title" "$tag_r" "$RESET"
    local pad=$(( cols - ${#title} - 8 )); (( pad < 1 )) && pad=1
    printf "%${pad}s\n" ""
  else
    local ic; ic=$(_sec_icon "$key")
    printf "  %s[%s] %s%s\n" "$BOLD$BLUE" "$title" "$ic" "$RESET"
  fi
  if (( ${OPT_BOXED:-0} )); then
    local rule=""; local i=0; local width=$(( cols - 2 ));
    while (( i < width )); do rule+="─"; (( i++ )); done
    printf "  %s%s%s\n" "$DIM" "$rule" "$RESET"
  fi
}

_kv() { local label="$1"; shift; local value="$*"; local W=12; printf "  %s%-*s %s\n" "$LABEL" $W "$label:" "$value"; }
_kvx() { local _unused_key="$1"; shift; local label="$1"; shift; local value="$*"; _kv "$label" "$value"; }
_kv_path() {
  local label="$1"; shift; local p="$*"; local cols=$(_term_cols)
  local prefix_len=$(( 2 + 1 + 1 + 10 + 1 ))
  local max=$(( cols - prefix_len )); (( max < 20 )) && max=20
  local disp=$(_ellipsize_middle "$p" $max)
  _kv "$label" "$disp"
}
