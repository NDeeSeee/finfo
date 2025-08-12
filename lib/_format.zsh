# Formatting helpers for finfo.zsh

_term_cols() { local c=${COLUMNS:-}; [[ -z $c ]] && c=$(tput cols 2>/dev/null || echo 120); echo $c; }
_clamp_width() { local w=$1; local max=${FINFO_SECTION_WIDTH:-100}; (( w>max )) && echo $max || echo $w; }
_ellipsize_middle() {
  local s="$1" max="$2"; (( ${#s} <= max )) && { print -r -- "$s"; return; }
  local head=$(( (max-1)/2 )) tail=$(( max - head - 1 ));
  print -r -- "${s[1,head]}…${s[-tail,-1]}"
}

_section() {
  local title="$1"; local key="$2"; local cols=$(_term_cols)
  local want_rule=${FINFO_RULE:-1}
  # Always add one blank line before each section header for breathing room
  printf "\n"
  if _has_nerd; then
    local tag_l="" tag_r=""; local hdr_idx=$(_hdr_bg_idx_for "$key"); local bg=$(_bg256 ${hdr_idx:-${THEME_HDR_BG_IDX:-24}}) fg=$(_color256 15)
    local ic; ic=$(_sec_icon "$key")
    local style="${FINFO_HEADER_STYLE:-left}"; local mode="${FINFO_HEADER_MODE:-line}"
    if [[ "$mode" == chip ]]; then
      if [[ "$style" == center ]]; then
        # Center within clamp width (default 100)
        local width=$(_clamp_width $cols)
        local text=" $ic ${BOLD}$title${RESET}"
        local left=$(( (width - ${#text} - 2) / 2 )); (( left < 0 )) && left=0
        local right=$(( width - ${#text} - left - 2 )); (( right < 0 )) && right=0
        printf " %*s" $left ""
        printf "%s%s%s%s%s%s" "$bg" "$fg$BOLD" "$tag_l" "$text" "$tag_r" "$RESET"
        printf "%*s\n" $right ""
      else
        # Left-aligned header chip
        printf "  %s%s%s %s %s %s%s\n" "$bg" "$fg$BOLD" "$tag_l" "$ic" "$title" "$tag_r" "$RESET"
      fi
    else
      # Line mode: simple colored label and optional rule
      printf "  %s%s %s%s%s\n" "$THEME_LABEL" "$ic" "$BOLD" "$title" "$RESET"
    fi
  else
    local ic; ic=$(_sec_icon "$key")
    printf "  %s[%s] %s%s\n" "$BOLD$BLUE" "$title" "$ic" "$RESET"
  fi
  if (( want_rule )); then
    local width=$(_clamp_width $cols)
    local rule=""; local i=0; local inner=$(( width - 2 )); (( inner < 10 )) && inner=10
    while (( i < inner )); do rule+="─"; (( i++ )); done
    printf "  %s%s%s\n" "$DIM" "$rule" "$RESET"
  fi
}

_kv() {
  local label="$1"; shift; local value="$*"; local W=12
  # Semantic tinting inside values
  case "$label" in
    Size|Lines|Pages) value="${NUM}${value}${RESET}" ;;
    Rel|Abs|Symlink) value="${PATHC}${value}${RESET}" ;;
    Owner|Perms|Access) value="${VALUE}${value}${RESET}" ;;
  esac
  printf "  %s%-*s %s\n" "$LABEL" $W "$label:" "$value"
}
_kvx() { local _unused_key="$1"; shift; local label="$1"; shift; local value="$*"; _kv "$label" "$value"; }
_kv_path() {
  local label="$1"; shift; local p="$*"; local cols=$(_term_cols)
  local prefix_len=$(( 2 + 1 + 1 + 10 + 1 ))
  local max=$(( cols - prefix_len )); (( max < 20 )) && max=20
  local disp=$(_ellipsize_middle "$p" $max)
  _kv "$label" "$disp"
}
