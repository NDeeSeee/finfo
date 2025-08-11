# finfo – rich file/dir inspector for zsh (macOS-friendly)
# Lightweight, fast, colorful; minimal external calls.

# Optional Nerd Font icon map
if [[ -z ${i_oct_file_directory:-} ]] && [[ -f ~/.local/share/nerd-fonts/i_all.sh ]]; then
  source ~/.local/share/nerd-fonts/i_all.sh
fi
: ${i_oct_file_directory:=}
: ${i_oct_link:=}
: ${i_fa_file_o:=}

# Icons resolver
typeset -gA _NF_KEY=(
  dir     oct_file_directory
  link    oct_link
  file    fa_file_o
)
_icon() { local var="i_${_NF_KEY[$1]:-fa_file_o}"; print -rn -- "${(P)var}"; }

# Colors (tput if available, otherwise ANSI)
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

# Terminal helpers and formatting utilities
_has_nerd() { [[ -n ${i_oct_file_directory:-} ]] || command -v lsd >/dev/null 2>&1; }
_term_cols() { local c=${COLUMNS:-}; [[ -z $c ]] && c=$(tput cols 2>/dev/null || echo 120); echo $c; }
_ellipsize_middle() {
  local s="$1" max="$2"; (( ${#s} <= max )) && { print -r -- "$s"; return; }
  local head=$(( (max-1)/2 )) tail=$(( max - head - 1 ));
  print -r -- "${s[1,head]}…${s[-tail,-1]}"
}
_color256() {
  local code="$1"; if command -v tput >/dev/null 2>&1; then tput setaf "$code" 2>/dev/null; fi
}
_bg256() {
  local code="$1"; if command -v tput >/dev/null 2>&1; then tput setab "$code" 2>/dev/null; fi
}

# Format seconds as human-readable age (largest 2 units) + " ago"
_fmt_ago() {
  local secs=${1:-0}
  (( secs < 0 )) && secs=0
  local y=$(( secs/31557600 ))
  local rem=$(( secs%31557600 ))
  local mo=$(( rem/2629800 ))
  rem=$(( rem%2629800 ))
  local d=$(( rem/86400 ))
  rem=$(( rem%86400 ))
  local h=$(( rem/3600 ))
  rem=$(( rem%3600 ))
  local m=$(( rem/60 ))
  typeset -a parts; parts=()
  if (( y>0 )); then parts+=("${y}y"); fi
  if (( mo>0 && ${#parts[@]}<2 )); then parts+=("${mo}mo"); fi
  if (( d>0 && ${#parts[@]}<2 )); then parts+=("${d}d"); fi
  if (( h>0 && ${#parts[@]}<2 )); then parts+=("${h}h"); fi
  if (( m>0 && ${#parts[@]}<2 )); then parts+=("${m}m"); fi
  if (( ${#parts[@]} == 0 )); then parts+=("0m"); fi
  local joined="${(j: :)parts}"
  print -r -- "${joined} ago"
}

# Format seconds as duration (largest 2 units), no suffix
_fmt_dur() {
  local secs=${1:-0}
  (( secs < 0 )) && secs=0
  local y=$(( secs/31557600 ))
  local rem=$(( secs%31557600 ))
  local mo=$(( rem/2629800 ))
  rem=$(( rem%2629800 ))
  local d=$(( rem/86400 ))
  rem=$(( rem%86400 ))
  local h=$(( rem/3600 ))
  rem=$(( rem%3600 ))
  local m=$(( rem/60 ))
  typeset -a parts; parts=()
  if (( y>0 )); then parts+=("${y}y"); fi
  if (( mo>0 && ${#parts[@]}<2 )); then parts+=("${mo}mo"); fi
  if (( d>0 && ${#parts[@]}<2 )); then parts+=("${d}d"); fi
  if (( h>0 && ${#parts[@]}<2 )); then parts+=("${h}h"); fi
  if (( m>0 && ${#parts[@]}<2 )); then parts+=("${m}m"); fi
  if (( ${#parts[@]} == 0 )); then parts+=("0m"); fi
  local joined="${(j: :)parts}"
  print -r -- "$joined"
}

# Section icon resolver (with ASCII fallbacks)
_sec_icon() {
  local key="$1"
  if _has_nerd; then
    case "$key" in
      type)       print -rn -- "󰈙" ;;      # document
      dir)        print -rn -- "󰉋" ;;      # folder
      perms)      print -rn -- "󰌾" ;;      # lock/key
      dates)      print -rn -- ""  ;;      # clock
      paths)      print -rn -- "󰌷" ;;      # location
      gitdocker)  print -rn -- "󰊢 " ;;    # git + docker
      actions)    print -rn -- ""  ;;      # bulb
      *)          print -rn -- ""  ;;
    esac
  else
    case "$key" in
      type)       print -rn -- "[T]" ;;
      dir)        print -rn -- "[D]" ;;
      perms)      print -rn -- "[P]" ;;
      dates)      print -rn -- "[C]" ;;
      paths)      print -rn -- "[L]" ;;
      gitdocker)  print -rn -- "[G]" ;;
      actions)    print -rn -- "[!]" ;;
      *)          print -rn -- "[*]" ;;
    esac
  fi
}

# Theme application
_apply_theme() {
  local theme="${1:-default}"
  # Defaults
  THEME_LABEL="$MAGENTA"; THEME_VALUE="$WHITE"; THEME_PATH="$CYAN"; THEME_NUM="$YELLOW"; THEME_HDR_BG_IDX=24
  if command -v tput >/dev/null 2>&1; then
    case "$theme" in
      nord|Nord)
        THEME_LABEL=$(_color256 75) # light blue
        THEME_VALUE=$(_color256 255)
        THEME_PATH=$(_color256 81)
        THEME_NUM=$(_color256 186)
        THEME_HDR_BG_IDX=24
        ;;
      dracula|Dracula)
        THEME_LABEL=$(_color256 201)
        THEME_VALUE=$(_color256 255)
        THEME_PATH=$(_color256 45)
        THEME_NUM=$(_color256 221)
        THEME_HDR_BG_IDX=53
        ;;
      solarized|Solarized)
        THEME_LABEL=$(_color256 136)
        THEME_VALUE=$(_color256 250)
        THEME_PATH=$(_color256 33)
        THEME_NUM=$(_color256 166)
        THEME_HDR_BG_IDX=37
        ;;
      *) : ;;
    esac
  fi
}

# Section header (btop-like tag)
_section() {
  local title="$1"; local key="$2"; local cols=$(_term_cols)
  local left="├─"; local right=""
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

# Small header logo
_logo() {
  local cols=$(_term_cols)
  if _has_nerd; then
    local fg=$(_color256 81)
    printf " %s finfo%s\n" "$fg" "$RESET"
  else
    printf " %s[finfo]%s\n" "$BOLD$BLUE" "$RESET"
  fi
}

# Key/Value line with aligned label
_kv() {
  local label="$1"; shift; local value="$*"; local LABEL="$MAGENTA"
  local W=12; printf "  %s%-*s %s\n" "$LABEL" $W "$label:" "$value"
}

# Key/Value specialized for wide paths with middle-ellipsis
_kv_path() {
  local label="$1"; shift; local p="$*"; local cols=$(_term_cols)
  local prefix_len=$(( 2 + 1 + 1 + 10 + 1 ))  # approx spaces + branch + label width
  local max=$(( cols - prefix_len )); (( max < 20 )) && max=20
  local disp=$(_ellipsize_middle "$p" $max)
  _kv "$label" "$disp"
}

# Glyph for KV labels
_glyph() {
  local key="$1"
  if _has_nerd; then
    case "$key" in
      type) echo "󰈙";; size) echo "󰍛";; link) echo "";; entries) echo "󰚌";; disk) echo "󰋊";;
      perms) echo "󰌾";; created) echo "󰃭";; modified) echo "";; rel) echo "󰉖";; abs) echo "󰉌";;
      git) echo "󰊢";; docker) echo "";; info) echo "󰋽";; lint) echo "󰙂";; try) echo "";; tip) echo "";;
      extract) echo "󰁫";; archive) echo "󰇙";;
      *) echo "";;
    esac
  else
    case "$key" in
      type) echo "[T]";; size) echo "[S]";; link) echo "[L]";; entries) echo "[E]";; disk) echo "[D]";;
      perms) echo "[P]";; created) echo "[C]";; modified) echo "[M]";; rel) echo "[r]";; abs) echo "[a]";;
      git) echo "[G]";; docker) echo "[K]";; info) echo "[i]";; lint) echo "[lint]";; try) echo "[try]";; tip) echo "[!]";;
      extract) echo "[x]";; archive) echo "[arc]";;
      *) echo "[*]";;
    esac
  fi
}

# KV with glyph
_kvx() {
  local _unused_key="$1"; shift; local label="$1"; shift; local value="$*"
  _kv "$label" "$value"
}

# Command category glyph and color for list bullets
_cmd_icon() {
  local cmd="$1"
  if _has_nerd; then
    case "$cmd" in
      bat|less|glow|open) echo "";;             # view
      jq|yq)              echo "";;             # parse
      ruff|eslint|yamllint|markdownlint|shellcheck|hadolint|vale|cspell|typos) echo "";; # lint
      black|prettier|shfmt) echo "";;           # format
      unzip|tar|gunzip|bunzip2|unxz|7z) echo "";; # archive
      *) echo "";;
    esac
  else
    echo "*"
  fi
}
_cmd_color() {
  local cmd="$1"
  case "$cmd" in
    bat|less|glow|open) echo "$CYAN" ;;
    jq|yq)              echo "$MAGENTA" ;;
    ruff|eslint|yamllint|markdownlint|shellcheck|hadolint|vale|cspell|typos) echo "$YELLOW" ;;
    black|prettier|shfmt) echo "$GREEN" ;;
    unzip|tar|gunzip|bunzip2|unxz|7z) echo "$BLUE" ;;
    *) echo "$LABEL" ;;
  esac
}

# Human-readable size
_hr_size() {
  # Back-compat simple formatter (IEC thresholds, compact units)
  local bytes="$1"; [[ -z "$bytes" || "$bytes" != <-> ]] && bytes=0
  if (( bytes >= 1073741824 )); then print -r -- "$((bytes/1073741824))G"; return
  elif (( bytes >= 1048576 )); then print -r -- "$((bytes/1048576))M"; return
  elif (( bytes >= 1024 )); then print -r -- "$((bytes/1024))K"; return
  else print -r -- "${bytes}B"; fi
}

# Human-readable size with unit scheme
_hr_size_fmt() {
  local bytes="$1"; local scheme="${2:-${FINFO_UNIT:-iec}}"; [[ -z "$bytes" || "$bytes" != <-> ]] && bytes=0
  case "$scheme" in
    bytes|byte)
      print -r -- "${bytes} B"; return ;;
    si)
      if (( bytes >= 1000000000 )); then printf '%.0f GB\n' $((bytes/1000000000));
      elif (( bytes >= 1000000 )); then printf '%.0f MB\n' $((bytes/1000000));
      elif (( bytes >= 1000 )); then printf '%.0f kB\n' $((bytes/1000));
      else print -r -- "${bytes} B"; fi; return ;;
    iec|*)
      if (( bytes >= 1073741824 )); then printf '%.0f GiB\n' $((bytes/1073741824));
      elif (( bytes >= 1048576 )); then printf '%.0f MiB\n' $((bytes/1048576));
      elif (( bytes >= 1024 )); then printf '%.0f KiB\n' $((bytes/1024));
      else print -r -- "${bytes} B"; fi; return ;;
  esac
}

# Infer simple description by extension
_describe_ext() {
  local name_lc="$1"; name_lc="${name_lc:l}"
  case "$name_lc" in
    *.py) echo "Python source" ;;
    *.ipynb) echo "Jupyter notebook" ;;
    *.js) echo "JavaScript source" ;;
    *.ts) echo "TypeScript source" ;;
    *.tsx|*.jsx) echo "React component" ;;
    *.sh|*.bash|*.zsh) echo "Shell script" ;;
    *.md|*.markdown) echo "Markdown document" ;;
    *.json) echo "JSON data" ;;
    *.yaml|*.yml) echo "YAML config" ;;
    *.toml) echo "TOML config" ;;
    *.ini|*.conf) echo "Configuration file" ;;
    *.sql) echo "SQL script" ;;
    Dockerfile|*dockerfile) echo "Docker build recipe" ;;
    Makefile|*.mk) echo "Make build rules" ;;
    *.csv|*.tsv) echo "Delimited text data" ;;
    *.r|*.R) echo "R script" ;;
    *.pdf) echo "PDF document" ;;
    *.zip|*.tar|*.tgz|*.tar.gz|*.gz|*.bz2|*.xz|*.7z) echo "Archive/compressed" ;;
    *) echo "" ;;
  esac
}

# Lint/format/spell suggestions
_suggest_quality() {
  local name_lc="$1"; name_lc="${name_lc:l}"
  local suggestions=()
  case "$name_lc" in
    *.py)
      command -v ruff >/dev/null 2>&1 && suggestions+=("ruff .")
      command -v black >/dev/null 2>&1 && suggestions+=("black '$2'")
      ;;
    *.js|*.jsx|*.ts|*.tsx)
      command -v eslint >/dev/null 2>&1 && suggestions+=("eslint '$2'")
      command -v prettier >/dev/null 2>&1 && suggestions+=("prettier --write '$2'")
      command -v cspell >/dev/null 2>&1 && suggestions+=("cspell '$2'")
      ;;
    *.json)
      command -v jq >/dev/null 2>&1 && suggestions+=("jq . '$2' > /dev/null")
      command -v prettier >/dev/null 2>&1 && suggestions+=("prettier --write '$2'")
      ;;
    *.yaml|*.yml)
      command -v yamllint >/dev/null 2>&1 && suggestions+=("yamllint '$2'")
      command -v yq >/dev/null 2>&1 && suggestions+=("yq e . '$2' > /dev/null")
      ;;
    *.md|*.markdown)
      command -v markdownlint >/dev/null 2>&1 && suggestions+=("markdownlint '$2'")
      command -v typos >/dev/null 2>&1 && suggestions+=("typos '$2'")
      command -v vale >/dev/null 2>&1 && suggestions+=("vale '$2'")
      ;;
    *.sh|*.bash|*.zsh)
      command -v shellcheck >/dev/null 2>&1 && suggestions+=("shellcheck '$2'")
      command -v shfmt >/dev/null 2>&1 && suggestions+=("shfmt -w '$2'")
      ;;
    Dockerfile|*dockerfile)
      command -v hadolint >/dev/null 2>&1 && suggestions+=("hadolint '$2'")
      ;;
    *) : ;;
  esac
  if (( ${#suggestions} )); then
    printf "%s\n" "${suggestions[@]}"
  fi
}

# Per-type action hints (view/open)
_action_hints() {
  local name_lc="$1"; name_lc="${name_lc:l}"; local p="$2"
  local hints=()
  if [[ -f "$p" ]]; then
    if command -v bat >/dev/null 2>&1; then
      hints+=("bat '$p'")
    else
      hints+=("less -S '$p'")
    fi
  fi
  case "$name_lc" in
    *.md|*.markdown)
      command -v glow >/dev/null 2>&1 && hints+=("glow '$p'")
      ;;
    *.json)
      command -v jq >/dev/null 2>&1 && hints+=("jq . '$p'")
      ;;
    *.yaml|*.yml)
      command -v yq >/dev/null 2>&1 && hints+=("yq e . '$p'")
      ;;
    *.py)
      command -v python3 >/dev/null 2>&1 && hints+=("python3 '$p'")
      ;;
    *.sh|*.bash)
      command -v bash >/dev/null 2>&1 && hints+=("bash '$p'")
      ;;
    *.zsh)
      hints+=("zsh '$p'")
      ;;
    *.r|*.R)
      command -v Rscript >/dev/null 2>&1 && hints+=("Rscript '$p'")
      ;;
    *.ipynb)
      command -v jupyter >/dev/null 2>&1 && hints+=("jupyter lab '$p'")
      ;;
  esac
  [[ "$OSTYPE" == darwin* ]] && hints+=("open '$p'")
  if (( ${#hints} )); then
    printf "%s\n" "${hints[@]}"
  fi
}

# Archive verification and extraction suggestion
_archive_hint() {
  local p="$1"; local name_lc="${2:l}"
  local ext_suggest=""
  case "$name_lc" in
    *.zip) ext_suggest="unzip '$p'" ;;
    *.tar.gz|*.tgz) ext_suggest="tar -xzf '$p'" ;;
    *.tar.bz2|*.tbz|*.tbz2) ext_suggest="tar -xjf '$p'" ;;
    *.tar.xz|*.txz) ext_suggest="tar -xJf '$p'" ;;
    *.tar) ext_suggest="tar -xf '$p'" ;;
    *.gz) ext_suggest="gunzip '$p'" ;;
    *.bz2) ext_suggest="bunzip2 '$p'" ;;
    *.xz) ext_suggest="unxz '$p'" ;;
    *.7z) ext_suggest="7z x '$p'" ;;
  esac
  if [[ -n "$ext_suggest" ]]; then
    local mime_desc; mime_desc=$(file -b -- "$p" 2>/dev/null)
    if print -r -- "$mime_desc" | grep -Eiq '(zip|tar|gzip|bzip2|xz|7-?zip|archive|compressed)'; then
      print -r -- "$ext_suggest"
    else
      print -r -- "WARN: name suggests archive but content is not an archive"
    fi
  fi
}

# Archive quick stats (best-effort, fast)
_archive_stats() {
  local p="$1"; local name_lc="${2:l}"
  local out=""
  case "$name_lc" in
    *.zip)
      if command -v zipinfo >/dev/null 2>&1; then
        out=$(zipinfo -t -- "$p" 2>/dev/null | sed -nE 's/^.* ([0-9]+) files.*$/files: \1/p')
      fi
      ;;
    *.tar|*.tar.gz|*.tgz|*.tar.bz2|*.tbz|*.tbz2|*.tar.xz|*.txz)
      if command -v tar >/dev/null 2>&1; then
        local cnt; cnt=$(tar -tf -- "$p" 2>/dev/null | wc -l | tr -d ' ')
        [[ -n "$cnt" ]] && out="files: $cnt"
      fi
      ;;
  esac
  [[ -n "$out" ]] && print -r -- "$out"
}

# Docker hints
_docker_hint() {
  local name="$1"; local p="$2"; local hints=()
  if [[ "${name:l}" == dockerfile || "${name:l}" == *.dockerfile ]]; then
    hints+=("docker build -t myimage:latest $(dirname -- "$p")")
  fi
  if [[ -f "$(dirname -- "$p")/docker-compose.yml" ]] || [[ -f "$(dirname -- "$p")/compose.yml" ]]; then
    hints+=("docker compose up -d")
  fi
  (( ${#hints} )) && print -r -- "${(j:; :)hints}"
}

# Explain permissions at a glance
_perm_explain() {
  local p="$1"
  local desc=()
  if [[ -r "$p" && -w "$p" ]]; then
    desc+=("read-write")
  elif [[ -r "$p" && ! -w "$p" ]]; then
    desc+=("read-only")
  elif [[ ! -r "$p" && -w "$p" ]]; then
    desc+=("write-only")
  else
    desc+=("no-access")
  fi
  if [[ -x "$p" && ! -d "$p" ]]; then desc+=("executable"); fi
  print -r -- "${(j:, :)desc}"
}

# Main entry
finfo() {
  # Silence xtrace within finfo for clean output, restore afterwards
  local _xtrace_was_on=0
  if [[ -o xtrace ]]; then _xtrace_was_on=1; set +x; fi
  # Cleanup helper: restore COLUMNS and xtrace before any return
  local old_COLUMNS=${COLUMNS:-}
  _cleanup() {
    # In multi-target mode, cleanup is performed once at the end
    if (( multi_mode == 0 )); then
      if [[ -n "$opt_width" ]]; then COLUMNS=$old_COLUMNS; fi
      if (( _xtrace_was_on )); then set -x; fi
    fi
  }
  # Options: -n (no color), -J (json), -q (quiet lists), -c (compact), -v (verbose),
  #          -G (nerd bullets), -b (ascii bullets), -H (header bar off)
  # Long option mapping
  local -a argv_new
  local show_help=0
  while (( $# > 0 )); do
    case "$1" in
      --json)        argv_new+=(-J);;
      --brief)       argv_new+=(-B);;
      --long)        argv_new+=(-L);;
      --porcelain)   argv_new+=(-P);;
      --width)       shift; argv_new+=(-W "$1");;
      --hash)        shift; argv_new+=(-Z "$1");;
      --unit)        shift; argv_new+=(-U "$1");;
      --no-git)      argv_new+=(-R);;
      --git)         argv_new+=(-r);;
      --theme)       shift; export FINFOTHEME="$1";;
      --icons)       argv_new+=(-G);;
      --no-icons)    argv_new+=(-b);;
      --monitor)     argv_new+=(-m);;
      --duplicates)  argv_new+=(-d);;
      --help)        show_help=1;;
      *)             argv_new+=("$1");;
    esac
    shift
  done
  set -- "${argv_new[@]}"

  typeset -a _o_n _o_J _o_Y _o_N _o_q _o_c _o_v _o_G _o_b _o_H _o_k _o_s _o_B _o_L _o_P _o_W _o_Z _o_R _o_r _o_m _o_d
  typeset -a _o_U
  zparseopts -D -E n=_o_n J=_o_J Y=_o_Y N=_o_N q=_o_q c=_o_c v=_o_v G=_o_G b=_o_b H=_o_H k=_o_k s=_o_s B=_o_B L=_o_L P=_o_P W:=_o_W Z:=_o_Z U:=_o_U R=_o_R r=_o_r m=_o_m d=_o_d
  local opt_no_color=$(( ${#_o_n} > 0 ))
  local opt_json=$(( ${#_o_J} > 0 ))
  local opt_yaml=$(( ${#_o_Y} > 0 ))
  local opt_ndjson=$(( ${#_o_N} > 0 ))
  local opt_quiet=$(( ${#_o_q} > 0 ))
  local opt_compact=$(( ${#_o_c} > 0 ))
  local opt_verbose=$(( ${#_o_v} > 0 ))
  local opt_nerd_bullets=$(( ${#_o_G} > 0 ))
  local opt_ascii_bullets=$(( ${#_o_b} > 0 ))
  local opt_no_header=$(( ${#_o_H} > 0 ))
  local opt_code_tags
  if (( ${#_o_k} > 0 )); then opt_code_tags=1; else opt_code_tags=${FINFOCODE:-1}; fi
  local opt_sleek=$(( ${#_o_s} > 0 ))
  local opt_brief=$(( ${#_o_B} > 0 ))
  local opt_long=$(( ${#_o_L} > 0 ))
  local opt_porcelain=$(( ${#_o_P} > 0 ))
  local opt_width=""; (( ${#_o_W} > 0 )) && opt_width="${_o_W[2]}"
  local hash_algo=""; (( ${#_o_Z} > 0 )) && hash_algo="${_o_Z[2]}"
  local unit_scheme="${FINFO_UNIT:-iec}"; (( ${#_o_U} > 0 )) && unit_scheme="${_o_U[2]}"; export FINFO_UNIT="$unit_scheme"
  local opt_no_git=$(( ${#_o_R} > 0 ))
  local opt_force_git=$(( ${#_o_r} > 0 ))
  local opt_monitor=$(( ${#_o_m} > 0 ))
  local opt_duplicates=$(( ${#_o_d} > 0 ))

  # Long implies verbose
  if (( opt_long )); then opt_verbose=1; fi

  # Note: zparseopts already removes parsed options from $@, leaving only positional args.
  # Do not shift here, or we will drop the first non-option argument (the target path).

  if (( show_help )); then
    echo "Usage: finfo [--brief|--long|--porcelain|--json] [--width N] [--hash sha256|blake3] [--unit bytes|iec|si] [--icons|--no-icons] [--git|--no-git] [--monitor] [--duplicates] PATH..."
    _cleanup; return 0
  fi

  _finfo_colors
  [[ $opt_no_color -eq 1 ]] && BOLD="" DIM="" RESET="" RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" WHITE=""
  _apply_theme "${FINFOTHEME:-default}"
  # Map theme to local variables for existing code
  local LABEL="$THEME_LABEL" VALUE="$THEME_VALUE" PATHC="$THEME_PATH" NUM="$THEME_NUM"
  # Respect NO_COLOR and porcelain
  if [[ -n "$NO_COLOR" ]] || (( opt_porcelain )); then BOLD="" DIM="" RESET="" RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" WHITE=""; fi
  # Width override
  if [[ -n "$opt_width" ]]; then COLUMNS=$opt_width; fi
  # Multi-target detection
  local -a targets; targets=( "$@" )
  (( ${#targets[@]} == 0 )) && targets=( . )
  local multi_mode=0
  if (( ${#targets[@]} > 1 )); then multi_mode=1; fi

  # Aggregation state for group summary
  typeset -A _ext_count=()
  local _total_files=0 _total_dirs=0 _largest_name="" _largest_size=0 _oldest_name="" _oldest_epoch=0 _quar_count=0 _total_bytes=0 _hl_multi_count=0

  # Helper: process one target
  _finfo_print_one() {
    local target="$1"
    if [[ ! -e "$target" ]]; then
      print -r -- "${RED}✗${RESET} not found: $target"
      return 1
    fi

    # Resolve paths (zsh modifiers)
    local abs_path="${target:A}"
    local rel_path="${abs_path:#$PWD/}"
    [[ "$rel_path" == "$abs_path" ]] && rel_path="$target"

  # Name and icon
    local name=${target:t}
  local glyph=""
  if command -v lsd &>/dev/null; then
    glyph=$(lsd --icon always --color never -1 -- "$target" 2>/dev/null | head -n1 | sed -E 's/^([^[:space:]]+).*/\1/')
  fi
  if [[ -z $glyph ]]; then
    if [[ -d $target ]]; then glyph=$(_icon dir)
    elif [[ -L $target ]]; then glyph=$(_icon link)
    else glyph=$(_icon file); fi
  fi

  # stat block
  local perms_sym perms_oct size_bytes created_at modified_at created_epoch modified_epoch link_count
    local path_arg="$target"; [[ "${path_arg}" == -* ]] && path_arg="./${path_arg}"
  if [[ $OSTYPE == darwin* ]]; then
    local stat_bin="/usr/bin/stat"; [[ -x $stat_bin ]] || stat_bin="stat"
    perms_sym=$($stat_bin -f '%Sp' "$path_arg" 2>/dev/null)
    perms_oct=$($stat_bin -f '%p' "$path_arg" 2>/dev/null)
    size_bytes=$($stat_bin -f '%z' "$path_arg" 2>/dev/null)
    link_count=$($stat_bin -f '%l' "$path_arg" 2>/dev/null)
    created_at=$($stat_bin -f '%SB' -t '%b %d %Y %H:%M' "$path_arg" 2>/dev/null)
    modified_at=$($stat_bin -f '%Sm' -t '%b %d %Y %H:%M' "$path_arg" 2>/dev/null)
    created_epoch=$($stat_bin -f '%B' "$path_arg" 2>/dev/null)
    modified_epoch=$($stat_bin -f '%m' "$path_arg" 2>/dev/null)
  else
    perms_sym=$(stat -c '%A' -- "$path_arg")
    perms_oct=$(stat -c '%a' -- "$path_arg")
    size_bytes=$(stat -c '%s' -- "$path_arg")
    link_count=$(stat -c '%h' -- "$path_arg")
    created_at=$(stat -c '%w' -- "$path_arg"); [[ "$created_at" == '-' ]] && created_at="unknown"
    modified_at=$(stat -c '%y' -- "$path_arg")
    created_epoch=$(stat -c '%W' -- "$path_arg" 2>/dev/null)
    modified_epoch=$(stat -c '%Y' -- "$path_arg" 2>/dev/null)
  fi

    local size_human=$(_hr_size ${size_bytes:-0})

  # File type and text/binary
    local file_desc mime_line is_text="?"
    file_desc=$(file -b "$path_arg" 2>/dev/null)
    mime_line=$(file -b -I "$path_arg" 2>/dev/null)
  local charset="";
  if [[ -d "$target" ]]; then
    is_text="n/a"
  elif print -r -- "$mime_line" | grep -qi 'charset=binary'; then
    is_text="binary"
  else
    is_text="text"
    charset=$(print -r -- "$mime_line" | sed -nE 's/.*charset=([^;]+).*/\1/p')
  fi
  # macOS UTType
    local uttype=""
  if [[ $OSTYPE == darwin* ]]; then
    uttype=$(mdls -name kMDItemContentType -raw "$path_arg" 2>/dev/null)
    [[ "$uttype" == "(null)" ]] && uttype=""
  fi
  # macOS flags
    local posix_flags=""
  if [[ $OSTYPE == darwin* ]]; then
    local stat_bin="/usr/bin/stat"; [[ -x $stat_bin ]] || stat_bin="stat"
    posix_flags=$($stat_bin -f '%Sf' "$path_arg" 2>/dev/null)
    [[ "$posix_flags" == '-' ]] && posix_flags=""
  fi

  # Styling helpers
  # (LABEL/VALUE/PATHC/NUM already themed above)

  # Bullet glyph selection
    local BULLET="•"
  if (( opt_ascii_bullets )); then BULLET="•"; fi
  if (( opt_nerd_bullets )) || [[ -n ${i_oct_file_directory:-} ]]; then
    BULLET=""
  fi

  # Decide whether to emit pretty sections (skip when json/porcelain/compact)
    local emit_pretty=$(( (opt_json || opt_porcelain || opt_compact) ? 0 : 1 ))

    if (( emit_pretty )); then
    # Header bar: one-line headline (name · short type · size · lines)
    if (( ! opt_no_header )); then
      local HB=""; local HFRESET="$RESET"
      if command -v tput >/dev/null 2>&1 && [[ -t 1 ]] && [[ -z "$opt_no_color" ]]; then
        HB="$(tput bold 2>/dev/null)$(tput setaf 4 2>/dev/null)"
      else
        HB="$BOLD$BLUE"
      fi
      _logo
      local short_type="${file_desc%%,*}"
      local head_size="$size_human"; [[ -d "$target" ]] && head_size="—"
      local head_lines=""; if [[ -f "$target" && "$is_text" == text ]]; then local lc_head; lc_head=$(wc -l < "$path_arg" 2>/dev/null | tr -d ' '); [[ -n "$lc_head" ]] && head_lines=" · ${lc_head} lines"; fi
      printf "%s%s%s · %s · %s%s\n" "$HB" "$name" "$RESET" "$short_type" "$head_size" "$head_lines"
    else
      _logo
      printf "%s%s%s\n" "$BOLD$BLUE" "$name" "$RESET"
    fi
    fi

  # Symlink details
    local is_symlink=0 link_target link_exists=0
  if [[ -L "$target" ]]; then
    is_symlink=1
    link_target=$(readlink -- "$target" 2>/dev/null)
    if [[ -n "$link_target" ]]; then
      local base_dir=${target:h}
      [[ -e "$base_dir/$link_target" ]] && link_exists=1
    fi
  fi

  # 1) Header
    if (( emit_pretty )); then
    _section "HEADER" type
    local header_type="$file_desc"; [[ -n "$charset" && "$is_text" == text ]] && header_type+=" ${DIM}(${charset})${RESET}"
    _kvx type "File" "${VALUE}${name}${RESET} ${DIM}–${RESET} ${header_type}"
    fi

  # Owners
  local owner_group
  if [[ $OSTYPE == darwin* ]]; then owner_group=$($stat_bin -f '%Su:%Sg' "$path_arg" 2>/dev/null); else owner_group=$(stat -c '%U:%G' "$path_arg" 2>/dev/null); fi

  # 2) Essentials
    local want_essentials=1
    if (( emit_pretty )); then
    _section "ESSENTIALS" type
    # Size and bytes
    local bytes_disp="${size_bytes:-0}B"; if [[ -n ${size_bytes:-} ]]; then bytes_disp="${size_bytes} B"; fi
    if [[ -d "$target" ]]; then
      _kv "Size" "— ${DIM}(${bytes_disp})${RESET}"
    else
      local size_unit_disp; size_unit_disp=$(_hr_size_fmt ${size_bytes:-0} "$unit_scheme")
      _kv "Size" "${size_unit_disp} ${DIM}(${bytes_disp})${RESET}"
    fi
    # Lines (if text)
    if [[ -f "$target" && "$is_text" == text ]]; then
      local lc; lc=$(wc -l < "$path_arg" 2>/dev/null | tr -d ' ')
      [[ -n "$lc" ]] && _kv "Lines" "${lc}"
    fi
    # MIME / UTType
    local mime_disp="${mime_line}"; [[ -n "$uttype" ]] && mime_disp+=" ${DIM}|${RESET} ${uttype}"
    _kv "Type" "${mime_disp}"
    # Owner / Perm
    local flags_disp=""; [[ -n "$posix_flags" ]] && flags_disp=" ${DIM}| flags:${posix_flags}${RESET}"
    _kv "Owner" "${owner_group} ${DIM}|${RESET} ${perms_sym} ${DIM}(${perms_oct})${RESET}${flags_disp}"
    # Access capability summary
    local perm_hint; perm_hint=$(_perm_explain "$path_arg")
    [[ -n "$perm_hint" ]] && _kv "Access" "${perm_hint}"
    # Directory summary (entries and apparent size)
    if [[ -d "$target" ]]; then
      local -a subdirs files
      subdirs=( "$path_arg"/*(/N) )
      files=( "$path_arg"/*(.N) )
      _kv "Entries" "${#subdirs} dirs, ${#files} files"
      local dsz_bytes dsz
      dsz_bytes=$(du -sk "$path_arg" 2>/dev/null | awk '{print $1*1024}')
      [[ -n "$dsz_bytes" ]] && dsz=$(_hr_size "$dsz_bytes")
      [[ -n "$dsz" ]] && _kv "Disk" "${dsz}"
    fi
    # Archive quick stats
    if [[ -f "$path_arg" ]]; then
      local astats; astats=$(_archive_stats "$path_arg" "$name")
      [[ -n "$astats" ]] && _kv "Archive" "$astats"
    fi
    # Hard links
    if [[ -f "$path_arg" && "$link_count" == <-> && $link_count -gt 1 ]]; then
      _kv "Links" "hardlinks: ${link_count}"
    fi
    # Monitor growth/shrink rate (files only; optional)
    if (( opt_monitor )) && [[ -f "$path_arg" ]]; then
      local s1 s2 dt=${opt_monitor_secs:-1}
      s1=${size_bytes:-0}
      sleep $dt
      if [[ $OSTYPE == darwin* ]]; then
        local _stat_bin="/usr/bin/stat"; [[ -x $_stat_bin ]] || _stat_bin="stat"
        s2=$($_stat_bin -f '%z' "$path_arg" 2>/dev/null)
      else
        s2=$(stat -c '%s' -- "$path_arg")
      fi
      [[ -z "$s2" ]] && s2=$s1
      local dr=$(( s2 - s1 ))
      local sign="~"; local color="$WHITE"
      if (( dr > 0 )); then sign="+"; color="$GREEN"; elif (( dr < 0 )); then sign="-"; color="$YELLOW"; fi
      local rate_abs=$(( dr>=0 ? dr : -dr ))
      local per_sec=$(( dt>0 ? rate_abs/dt : rate_abs ))
      local rate_disp; rate_disp=$(_hr_size_fmt $per_sec "$unit_scheme")
      _kv "Rate" "${color}${sign}${rate_disp}/s${RESET} ${DIM}(${dt}s window)${RESET}"
    fi
    # Git (optional)
    local in_repo=0; if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then in_repo=1; fi
    if (( in_repo )) && (( ! opt_no_git || opt_force_git )); then
      local branch status_line git_flag="clean" mark="$GREEN✓$RESET"
      branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD)
      status_line=$(git status --porcelain -- "$target" 2>/dev/null)
      if [[ -n "$status_line" ]]; then
        if print -r -- "$status_line" | grep -q '^??'; then git_flag="untracked"; mark="$YELLOW●$RESET";
        elif print -r -- "$status_line" | grep -Eq '^[ MARC]M|^M '; then git_flag="modified"; mark="$YELLOW●$RESET";
        elif print -r -- "$status_line" | grep -q '^A '; then git_flag="added"; mark="$YELLOW●$RESET";
        elif print -r -- "$status_line" | grep -q '^D '; then git_flag="deleted"; mark="$YELLOW●$RESET"; fi
      fi
      _kv "Git" "${branch} ${DIM}(${git_flag})${RESET}"
    fi
    fi
  # Checksum
    if [[ -n "$hash_algo" && -f "$path_arg" ]]; then
    local checksum="" algo_disp="${hash_algo}"
    case "$hash_algo" in
      sha256)
        if command -v shasum >/dev/null 2>&1; then checksum=$(shasum -a 256 -- "$path_arg" 2>/dev/null | awk '{print $1}')
        elif command -v openssl >/dev/null 2>&1; then checksum=$(openssl dgst -sha256 "$path_arg" 2>/dev/null | awk '{print $2}')
        fi;;
      blake3|b3)
        if command -v b3sum >/dev/null 2>&1; then checksum=$(b3sum -- "$path_arg" 2>/dev/null | awk '{print $1}')
        fi;;
    esac
    [[ -n "$checksum" ]] && _kv "Checksum" "${algo_disp} ${DIM}${checksum}${RESET}" || _kv "Checksum" "${DIM}${algo_disp} unavailable${RESET}"
    fi

  # 3) Timeline
    local want_timeline=$(( opt_brief ? 0 : 1 ))
    if (( emit_pretty && want_timeline )); then
  _section "TIMELINE" dates
  # Access time (best-effort)
  local accessed_at accessed_epoch
  if [[ $OSTYPE == darwin* ]]; then accessed_at=$($stat_bin -f '%Sa' -t '%b %d %Y %H:%M' "$path_arg" 2>/dev/null); accessed_epoch=$($stat_bin -f '%a' "$path_arg" 2>/dev/null);
  else accessed_at=$(stat -c '%x' "$path_arg" 2>/dev/null); accessed_epoch=$(stat -c '%X' "$path_arg" 2>/dev/null); fi
  # Relatives
  local created_rel="" modified_rel="" accessed_rel=""
  # Only compute relative times when epoch values are purely numeric and positive
  if [[ "$created_epoch" == <-> && "$created_epoch" != "0" ]]; then created_rel=$(_fmt_ago $(( $(date +%s) - created_epoch ))); fi
  if [[ "$modified_epoch" == <-> && "$modified_epoch" != "0" ]]; then modified_rel=$(_fmt_ago $(( $(date +%s) - modified_epoch ))); fi
  if [[ "$accessed_epoch" == <-> && "$accessed_epoch" != "0" ]]; then accessed_rel=$(_fmt_ago $(( $(date +%s) - accessed_epoch ))); fi
  _kv "Created" "${created_at:-–} ${DIM}(${created_rel})${RESET}"
  _kv "Modified" "${modified_at:-–} ${DIM}(${modified_rel})${RESET}"
  [[ -n "$accessed_at" ]] && _kv "Accessed" "${accessed_at} ${DIM}(${accessed_rel})${RESET}"
    fi

  # 4) Paths
    local want_paths=$(( opt_brief ? 0 : 1 ))
    if (( emit_pretty && want_paths )); then
  _section "PATHS" paths
  if (( opt_code_tags )); then
    _kv "Rel" "${PATHC}</>${RESET} ${PATHC}${rel_path}${RESET}"
    local abs_disp=$(_ellipsize_middle "$abs_path" ${COLUMNS:-120})
    _kv "Abs" "${PATHC}</>${RESET} ${PATHC}${abs_disp}${RESET}"
  else
    _kv "Rel" "${PATHC}${rel_path}${RESET}"
    local abs_disp=$(_ellipsize_middle "$abs_path" ${COLUMNS:-120})
    _kv "Abs" "${PATHC}${abs_disp}${RESET}"
    fi
  if (( is_symlink )); then
    if (( link_exists )); then _kv "Symlink" "${PATHC}${link_target}${RESET}"; else _kv "Symlink" "${YELLOW}${link_target} (missing)${RESET}"; fi
  fi
  fi

  # 5) Security & provenance
    local want_secprov=$(( opt_brief ? 0 : 1 ))
    if (( emit_pretty && want_secprov )); then
  _section "SECURITY & PROVENANCE" perms
  # Gatekeeper / Codesign / Notarization (macOS only; best-effort)
  local gk_assess="unknown" cs_signed=0 cs_status="unknown" cs_team="" cs_auth="" nota_stapled="unknown"
  if [[ $OSTYPE == darwin* && ! -d "$target" ]]; then
    # Only attempt for executables or Mach-O files; avoid noisy output for plain docs
    if print -r -- "$file_desc" | grep -Eq 'Mach-O|executable|dylib|shared library'; then
      if command -v spctl >/dev/null 2>&1; then
        local _spout
        _spout=$(spctl --assess -vv --type execute -- "$path_arg" 2>&1)
        if [[ $? -eq 0 ]]; then gk_assess="pass"; else gk_assess="fail"; fi
      fi
      if command -v codesign >/dev/null 2>&1; then
        local _csinfo _csverr
        _csinfo=$(codesign -dv --verbose=2 -- "$path_arg" 2>&1)
        if [[ $? -eq 0 ]]; then cs_signed=1; fi
        _csverr=$(codesign --verify --deep --strict -- "$path_arg" 2>&1)
        if [[ $? -eq 0 ]]; then cs_status="valid"; else cs_status="invalid"; fi
        cs_team=$(print -r -- "$_csinfo" | sed -nE 's/^TeamIdentifier=(.*)$/\1/p' | head -n1)
        cs_auth=$(print -r -- "$_csinfo" | sed -nE 's/^Authority=(.*)$/\1/p' | head -n1)
      fi
      # Notarization staple check
      if command -v xcrun >/dev/null 2>&1; then
        local _stout
        _stout=$(xcrun stapler validate -- "$path_arg" 2>&1)
        if [[ $? -eq 0 ]]; then nota_stapled="ok"; else nota_stapled="missing"; fi
      fi
    fi
    fi
  # Verdict (simple heuristic)
  local quarantine_present="no"
    if [[ $OSTYPE == darwin* ]]; then
    local _qtmp
    _qtmp=$(xattr -p com.apple.quarantine "$path_arg" 2>/dev/null)
    [[ -n "$_qtmp" ]] && quarantine_present="yes"
    fi
  local verdict="unknown"
  if [[ "$gk_assess" == pass && "$cs_status" == valid && "$quarantine_present" == no ]]; then
    verdict="safe"
  elif [[ "$gk_assess" == fail || "$cs_status" == invalid ]]; then
    verdict="unsafe"
  elif [[ "$quarantine_present" == yes ]]; then
    verdict="caution"
  fi
  # Summary line
  if [[ "$verdict" != "unknown" || "$gk_assess" != "unknown" || $cs_signed -eq 1 || "$nota_stapled" != "unknown" ]]; then
    local vr_col="$WHITE"
    case "$verdict" in
      safe) vr_col="$GREEN";; caution) vr_col="$YELLOW";; unsafe) vr_col="$RED";;
    esac
    _kv "Verdict" "${vr_col}${verdict}${RESET} ${DIM}(gatekeeper:${gk_assess} codesign:${cs_status}${cs_team:+ team:${cs_team}}${nota_stapled:+ notarization:${nota_stapled}})${RESET}"
  fi
  # macOS xattrs/ACL (shown when verbose or present)
  if [[ $OSTYPE == darwin* ]]; then
    local -a xas; xas=()
    if command -v xattr >/dev/null 2>&1; then
      xas=( $(xattr -l "$path_arg" 2>/dev/null | sed -n 's/^\([^:]*\):.*/\1/p') )
    fi
    local acl_present=0
    if command -v ls >/dev/null 2>&1; then
      ls -le "$path_arg" 2>/dev/null | grep -q '^\s*[0-9]\+:' && acl_present=1
    fi
    # Quarantine decode
    local qstr=""; qstr=$(xattr -p com.apple.quarantine "$path_arg" 2>/dev/null)
    if [[ -n "$qstr" ]]; then _kv "Quarantine" "${YELLOW}yes${RESET} ${DIM}(${qstr%%;*})${RESET}"; fi
    # WhereFroms
    local froms=""; froms=$(mdls -name kMDItemWhereFroms -raw "$path_arg" 2>/dev/null)
    if [[ -n "$froms" && "$froms" != "(null)" ]]; then _kv "WhereFroms" "${froms}"; fi
    if (( opt_verbose )); then
      if (( ${#xas} > 0 )); then
        printf "  %s%-*s %s\n" "$LABEL" 12 "XAttr:" ""
        local xa; for xa in "${xas[@]}"; do printf "  %s  %s\n" "$LABEL" "$xa"; done
      fi
      (( acl_present )) && _kv "ACL" "present"
    fi
  fi
  fi

  # 5b) Creator metadata (Spotlight) — show in long/verbose only
  if [[ $OSTYPE == darwin* && ( opt_long || opt_verbose ) ]]; then
    local creator_val authors_val
    creator_val=$(mdls -name kMDItemCreator -raw "$path_arg" 2>/dev/null)
    authors_val=$(mdls -name kMDItemAuthors -raw "$path_arg" 2>/dev/null)
    [[ "$creator_val" == "(null)" ]] && creator_val=""
    [[ "$authors_val" == "(null)" ]] && authors_val=""
    if [[ -n "$creator_val" || -n "$authors_val" ]]; then
      _section "CREATOR" type
      [[ -n "$creator_val" ]] && _kv "Creator" "$creator_val"
      [[ -n "$authors_val" ]] && _kv "Authors" "$authors_val"
    fi
  fi
  # 6) Suggested actions (view/parse/format/lint/open), archives & docker
    if (( emit_pretty && ! opt_quiet )); then
    local -a qual_lines action_lines docker_lines archive_lines act_lines
    qual_lines=( "${(@f)$(_suggest_quality "$name" "$abs_path")}" )
    action_lines=( "${(@f)$(_action_hints "$name" "$abs_path")}" )
    docker_lines=( "${(@f)$(_docker_hint "$name" "$abs_path")}" )
    archive_lines=( "${(@f)$(_archive_hint "$abs_path" "$name")}" )
    act_lines=()
    (( ${#qual_lines[@]} )) && act_lines+=( "${qual_lines[@]}" )
    (( ${#action_lines[@]} )) && act_lines+=( "${action_lines[@]}" )
    (( ${#docker_lines[@]} )) && act_lines+=( "${docker_lines[@]}" )
    (( ${#archive_lines[@]} )) && act_lines+=( "${archive_lines[@]}" )
    # Deduplicate while preserving order (approximate)
    if (( ${#act_lines[@]} )); then
      _section "ACTIONS" actions
      local -A seen_map=()
      local line
      for line in "${act_lines[@]}"; do
        [[ -z "$line" ]] && continue
        if [[ -z ${seen_map[$line]:-} ]]; then
          seen_map[$line]=1
          local basecmd=${line%% *}
          local ic; ic=$(_cmd_icon "$basecmd")
          local col; col=$(_cmd_color "$basecmd")
          printf "  %s%s %s%s\n" "$col" "$ic" "$line" "$RESET"
        fi
      done
    fi
    fi
  # 7) Tips (1 line max, contextual)
    if (( emit_pretty && ! opt_quiet )); then
    if [[ -d "$target" ]]; then
      printf "  %s%s %-*s %s\n" "$LABEL" "$(_glyph info)" 12 "Tip:" "${CYAN}use 'll' for detailed listing${RESET}"
    else
      if command -v bat >/dev/null 2>&1; then
        printf "  %s%s %-*s %s\n" "$LABEL" "$(_glyph info)" 12 "Tip:" "${CYAN}prefer 'bat' over 'cat' for syntax highlighting${RESET}"
      fi
    fi
  fi

  # Compact mode output (overrides above): show concise summary
    if (( opt_compact )); then
    # Clear screen part: reprint minimal lines only
    printf "%s%s %s%s\n" "$BOLD$BLUE" "$glyph" "$name" "$RESET"
    printf "  %s•%s %s%s%s  %s%s%s  %s%s%s  %s%s%s\n" \
      "$LABEL" "$RESET" "$VALUE" "${file_desc}" "$RESET" \
      "$NUM" "$size_human" "$RESET" \
      "$VALUE" "$perms_sym" "$RESET" \
      "$VALUE" "${modified_at:-–}" "$RESET"
    fi

  # Porcelain output (stable columns, no colors/icons)
    if (( opt_porcelain )); then
    local tab=$'\t'
    print -r -- "name${tab}${name}"
    print -r -- "type${tab}${file_desc}"
    print -r -- "size_bytes${tab}${size_bytes:-0}"
    print -r -- "size_human${tab}${size_human}"
    [[ -n "$lc" ]] && print -r -- "lines${tab}${lc}"
    print -r -- "mime${tab}${mime_line}"
    [[ -n "$uttype" ]] && print -r -- "uttype${tab}${uttype}"
    print -r -- "owner_group${tab}${owner_group}"
    print -r -- "perms_sym${tab}${perms_sym}"
    print -r -- "perms_oct${tab}${perms_oct}"
    print -r -- "created${tab}${created_at}"
    print -r -- "modified${tab}${modified_at}"
    [[ -n "$accessed_at" ]] && print -r -- "accessed${tab}${accessed_at}"
    print -r -- "rel${tab}${rel_path}"
    print -r -- "abs${tab}${abs_path}"
    [[ -n "$link_target" ]] && print -r -- "symlink${tab}${link_target}"
    [[ -n "$branch" ]] && print -r -- "git_branch${tab}${branch}"
    [[ -n "$git_flag" ]] && print -r -- "git_status${tab}${git_flag}"
    [[ -n "$qstr" ]] && print -r -- "quarantine${tab}yes"
    [[ -n "$froms" ]] && print -r -- "where_froms${tab}${froms}"
    [[ -n "$hash_algo" && -n "$checksum" ]] && print -r -- "${hash_algo}${tab}${checksum}"
      return 0
    fi

  # JSON mode: print machine-readable output and exit
    if (( opt_json )); then
    _json_escape() { local s="$1"; s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\n'/\\n}; print -rn -- "$s"; }
    local j_name; j_name=$(_json_escape "$name")
    local j_abs; j_abs=$(_json_escape "$abs_path")
    local j_rel; j_rel=$(_json_escape "$rel_path")
    local j_type; j_type=$(_json_escape "$file_desc")
    local j_charset; j_charset=$(_json_escape "$charset")
    local j_perms; j_perms=$(_json_escape "$perms_sym")
    local j_permexp; j_permexp=$(_json_escape "$perm_hint")
    local j_created; j_created=$(_json_escape "$created_at")
    local j_modified; j_modified=$(_json_escape "$modified_at")
    local j_branch; j_branch=$(_json_escape "$branch")
    local j_gitflag; j_gitflag=$(_json_escape "$git_flag")
    local j_link; j_link=$(_json_escape "$link_target")
    # Build arrays
    local -a qual_lines act_lines
    local qa_json="["; local first=1; local q
    for q in "${qual_lines[@]}"; do
      local qq; qq=$(_json_escape "$q");
      (( first )) || qa_json+=" ,"; first=0; qa_json+="\"$qq\""
    done; qa_json+="]"
    local ac_json="["; first=1; local a
    for a in "${act_lines[@]}"; do
      local aa; aa=$(_json_escape "$a");
      (( first )) || ac_json+=" ,"; first=0; ac_json+="\"$aa\""
    done; ac_json+="]"
    printf '{"name":"%s","path":{"abs":"%s","rel":"%s"},"is_dir":%s,"type":{"description":"%s","is_text":"%s","charset":"%s"},"size":{"bytes":%s,"human":"%s"},"lines":%s,"perms":{"symbolic":"%s","octal":"%s","explain":"%s"},"dates":{"created":"%s","modified":"%s"},"git":{"present":%s,"branch":"%s","status":"%s"},"symlink":{"is_symlink":%s,"target":"%s","target_exists":%s},"dir":{"num_dirs":%s,"num_files":%s,"size_human":"%s"},"quality":%s,"actions":%s}\n' \
      "$j_name" "$j_abs" "$j_rel" \
      $([[ -d "$target" ]] && echo true || echo false) \
      "$j_type" "$is_text" "$j_charset" \
      "${size_bytes:-0}" "$size_human" \
      $([[ -n "$lc" ]] && echo "$lc" || echo null) \
      "$j_perms" "${perms_oct:-}" "$j_permexp" \
      "$j_created" "$j_modified" \
      $([[ -n "$branch" ]] && echo true || echo false) "$j_branch" "$j_gitflag" \
      $(( is_symlink ? 1 : 0 )) "$j_link" $(( link_exists ? 1 : 0 )) \
      $([[ -d "$target" ]] && echo ${#subdirs} || echo 0) $([[ -d "$target" ]] && echo ${#files} || echo 0) "$([[ -d "$target" ]] && echo "$dsz" || echo "")" \
      "$qa_json" "$ac_json"
      return 0
    fi

    # Aggregation for summary (pretty mode only)
    local _ext=""
    if [[ -d "$target" ]]; then
      (( _total_dirs++ ))
      _ext="dir"
    else
      (( _total_files++ ))
      _ext="${name##*.}"; [[ "$name" == *.* ]] || _ext="(noext)"; _ext="${_ext:l}"
      # Largest
      if [[ ${size_bytes:-0} == <-> ]] && (( size_bytes > _largest_size )); then _largest_size=$size_bytes; _largest_name="$name"; fi
      # Oldest by modified
      if [[ ${modified_epoch:-0} == <-> ]] && { (( _oldest_epoch == 0 )) || (( modified_epoch < _oldest_epoch )); }; then _oldest_epoch=$modified_epoch; _oldest_name="$name"; fi
      # Quarantine
      if [[ $OSTYPE == darwin* ]]; then
        local _qtmp2; _qtmp2=$(xattr -p com.apple.quarantine "$path_arg" 2>/dev/null)
        [[ -n "$_qtmp2" ]] && (( _quar_count++ ))
      fi
      if [[ ${size_bytes:-0} == <-> ]]; then _total_bytes=$((_total_bytes + size_bytes)); fi
      if [[ "$link_count" == <-> && $link_count -gt 1 ]]; then (( _hl_multi_count++ )); fi
    fi
    (( _ext_count[$_ext]++ ))
    return 0
  }

  # Loop over targets
  local _t
  for _t in "${targets[@]}"; do
    _finfo_print_one "$_t" || true
  done

  # Group summary (pretty only, multi-mode)
  if (( multi_mode )); then
    if (( ! opt_json && ! opt_porcelain && ! opt_compact )); then
      _section "SUMMARY" type
      _kv "Items" "$(( _total_files + _total_dirs )) total — ${_total_files} files, ${_total_dirs} dirs"
      # Extensions
      local k; local -a ext_lines=()
      for k in ${(k)_ext_count}; do
        ext_lines+=("${k}:${_ext_count[$k]}")
      done
      if (( ${#ext_lines[@]} )); then
        printf "  %s%-*s %s\n" "$LABEL" 12 "By type:" "${(j:, :)ext_lines}"
      fi
      [[ -n "$_largest_name" ]] && _kv "Largest" "${_largest_name} ${DIM}($(_hr_size $_largest_size), ${_largest_size} B)${RESET}"
      if (( _total_bytes > 0 )); then
        local _tot_disp; _tot_disp=$(_hr_size_fmt $_total_bytes "$unit_scheme")
        _kv "Total" "${_tot_disp} ${DIM}(${_total_bytes} B)${RESET}"
      fi
      if (( _oldest_epoch > 0 )); then
        local _oldest_rel; _oldest_rel=$(_fmt_ago $(( $(date +%s) - _oldest_epoch )))
        _kv "Oldest" "${_oldest_name} ${DIM}(${_oldest_rel})${RESET}"
      fi
      if (( _quar_count > 0 )); then
        _kv "Quarantine" "${YELLOW}${_quar_count}${RESET} flagged"
      fi
      if (( _hl_multi_count > 0 )); then
        _kv "Hardlinks" "${_hl_multi_count} files with >1 link"
      fi
    fi
  fi

  # Duplicate finder (pretty-only, on demand)
  if (( opt_duplicates )) && (( ! opt_json && ! opt_porcelain && ! opt_compact )); then
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
  fi

  # Final cleanup once
  multi_mode=0
  _cleanup; return 0
}
