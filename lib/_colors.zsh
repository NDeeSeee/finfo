# Colors and theming helpers for finfo.zsh

_finfo_colors() {
  if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
    local colors; colors=$(tput colors 2>/dev/null) || colors=0
    if (( colors >= 8 )); then
      BOLD=$(tput bold); DIM=$(tput dim); RESET=$(tput sgr0)
      RED=$(tput setaf 1); GREEN=$(tput setaf 2); YELLOW=$(tput setaf 3)
      BLUE=$(tput setaf 4); MAGENTA=$(tput setaf 5); CYAN=$(tput setaf 6); WHITE=$(tput setaf 7)
      return
    fi
  fi
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
  BLUE=$'\033[34m'; MAGENTA=$'\033[35m'; CYAN=$'\033[36m'; WHITE=$'\033[37m'
}

_color256() { local code="$1"; if command -v tput >/dev/null 2>&1; then tput setaf "$code" 2>/dev/null; fi }
_bg256() { local code="$1"; if command -v tput >/dev/null 2>&1; then tput setab "$code" 2>/dev/null; fi }

_apply_theme() {
  local theme="${1:-default}"
  THEME_LABEL="$MAGENTA"; THEME_VALUE="$WHITE"; THEME_PATH="$CYAN"; THEME_NUM="$YELLOW"; THEME_HDR_BG_IDX=24
  THEME_NAME="$theme"
  if command -v tput >/dev/null 2>&1; then
    case "$theme" in
      nord|Nord)
        THEME_LABEL=$(_color256 75); THEME_VALUE=$(_color256 255); THEME_PATH=$(_color256 81); THEME_NUM=$(_color256 186); THEME_HDR_BG_IDX=24 ;;
      dracula|Dracula)
        THEME_LABEL=$(_color256 201); THEME_VALUE=$(_color256 255); THEME_PATH=$(_color256 45); THEME_NUM=$(_color256 221); THEME_HDR_BG_IDX=53 ;;
      solarized|Solarized)
        THEME_LABEL=$(_color256 136); THEME_VALUE=$(_color256 250); THEME_PATH=$(_color256 33); THEME_NUM=$(_color256 166); THEME_HDR_BG_IDX=37 ;;
      synesthesia|Synesthesia)
        # Vibrant, high-contrast theme tuned for readability
        # Label: violet, Value: soft white, Path: aqua, Number: amber
        THEME_LABEL=$(_color256 141)
        THEME_VALUE=$(_color256 254)
        THEME_PATH=$(_color256 45)
        THEME_NUM=$(_color256 214)
        THEME_HDR_BG_IDX=60 ;;
      *) : ;;
    esac
  fi
}

# Section header background color per section key, theme-aware
_hdr_bg_idx_for() {
  local key="$1"
  local idx=${THEME_HDR_BG_IDX:-24}
  case "${THEME_NAME:-default}" in
    synesthesia|Synesthesia)
      case "$key" in
        type) idx=60;;       # violet
        perms) idx=125;;     # magenta
        dates) idx=32;;      # teal
        paths) idx=39;;      # cyan
        actions) idx=208;;   # orange
        *) : ;;
      esac ;;
    dracula|Dracula)
      case "$key" in
        type) idx=55;; perms) idx=90;; dates) idx=61;; paths) idx=45;; actions) idx=129;; *) : ;;
      esac ;;
    nord|Nord)
      case "$key" in
        type) idx=24;; perms) idx=25;; dates) idx=23;; paths) idx=31;; actions) idx=67;; *) : ;;
      esac ;;
    solarized|Solarized)
      case "$key" in
        type) idx=37;; perms) idx=94;; dates) idx=65;; paths) idx=33;; actions) idx=166;; *) : ;;
      esac ;;
    *) : ;;
  esac
  print -r -- "$idx"
}
