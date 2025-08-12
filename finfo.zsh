# finfo – rich file/dir inspector for zsh (macOS-friendly)
# Lightweight, fast, colorful; minimal external calls.

source ./lib/_icons.zsh
source ./lib/_colors.zsh
source ./lib/_format.zsh
source ./lib/_sections.zsh
source ./lib/_actions.zsh
source ./lib/_security.zsh
source ./lib/_filetype.zsh
source ./lib/_summary.zsh
source ./lib/_checksum.zsh
source ./lib/_monitor.zsh
source ./lib/_html.zsh
source ./lib/cmd_duplicates.zsh

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

source ./lib/_size.zsh

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

# KV with glyph
_kvx() {
  local _unused_key="$1"; shift; local label="$1"; shift; local value="$*"
  _kv "$label" "$value"
}

# Command category glyph and color helpers moved to lib/_sections.zsh

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
## Moved hint and action helpers to lib/_actions.zsh

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
  # Ensure tracing is disabled locally regardless of caller state
  setopt localoptions noxtrace
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
      --html)        html_output=1;;
      --help)        show_help=1;;
      *)             argv_new+=("$1");;
    esac
    shift
  done
  set -- "${argv_new[@]}"

  # Subcommand: diff A B → side-by-side metadata diff (porcelain-based)
  if [[ "$1" == diff ]]; then shift; finfo_cmd_diff "$1" "$2"; _cleanup; return $?; fi

  # Subcommand: watch PATH → live sample of size/mtime/xattrs (Ctrl-C to stop)
  if [[ "$1" == watch ]]; then shift; finfo_cmd_watch "$1" "$2"; _cleanup; return $?; fi

  # Subcommand: chmod PATH → interactive chmod helper (arrow-based)
  if [[ "$1" == chmod ]]; then shift; finfo_cmd_chmod "$1"; _cleanup; return $?; fi

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
  local opt_html=${html_output:-0}

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
  typeset -a _size_entries; _size_entries=()

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
  # quick stats holders
  local ft_pages ft_headings ft_columns ft_delim ft_image_dims; ft_pages=""; ft_headings=""; ft_columns=""; ft_delim=""; ft_image_dims=""
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

  # Decide whether to emit pretty sections (skip when json/porcelain/compact|html)
    local emit_pretty=$(( (opt_json || opt_porcelain || opt_compact || opt_html) ? 0 : 1 ))

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
      # Top subdir by immediate entries (best-effort)
      if (( ${#subdirs[@]} > 0 )); then
        local _top_name="" _top_count=0
        local sd
        for sd in "${subdirs[@]}"; do
          local -a inside=( "$sd"/*(N) )
          local cnt=${#inside}
          if (( cnt > _top_count )); then _top_count=$cnt; _top_name=${sd:t}; fi
        done
        if (( _top_count > 0 )); then
          _kv "Top dir" "${_top_name} ${DIM}(${_top_count} entries)${RESET}"
        fi
      fi
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
    # Open handles (best-effort; verbose only)
    if (( opt_verbose )) && command -v lsof >/dev/null 2>&1; then
      local _lsof; _lsof=$(lsof -n -- "$path_arg" 2>/dev/null | awk 'NR>1{print $1"("$2")"}' | head -3 | paste -sd ', ' -)
      [[ -n "$_lsof" ]] && _kv "Open" "${_lsof}"
    fi
    # Filetype quick stats & About
    if [[ -f "$path_arg" ]]; then
      _compute_filetype_stats "$path_arg" "$name" "$file_desc"
      [[ -n "$about_str" ]] && _kv "About" "$about_str"
      [[ -n "$ft_pages" ]] && _kv "Pages" "$ft_pages"
      [[ -n "$ft_image_dims" ]] && _kv "Image" "$ft_image_dims"
      [[ -n "$ft_headings" ]] && _kv "Headings" "$ft_headings"
      if [[ -n "$ft_columns" ]]; then
        local dname="$ft_delim"; _kv "Columns" "${ft_columns} ${DIM}(delimiter: ${dname})${RESET}"
      fi
      [[ -n "$ft_duration" ]] && _kv "Duration" "$ft_duration"
    fi
    # Monitor growth/shrink rate (files only; optional)
    if (( opt_monitor )) && [[ -f "$path_arg" ]]; then
      _print_rate_over_window "$path_arg" "${opt_monitor_secs:-1}" "$unit_scheme"
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
    local checksum="" algo_disp="${hash_algo}"; _compute_checksum "$path_arg" "$hash_algo"; checksum="$checksum_out"
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
    # Compute security info when pretty+wanted OR for json/porcelain
    local do_sec_compute=$(( (emit_pretty && want_secprov) || opt_porcelain || opt_json ))
    local gk_assess cs_signed cs_status cs_team cs_auth nota_stapled quarantine_present froms qstr verdict
    if (( do_sec_compute )); then
      _compute_security "$path_arg" "$file_desc" "$target"
    fi
    if (( emit_pretty && want_secprov )); then
      _section "SECURITY & PROVENANCE" perms
      if [[ "$verdict" != "unknown" || "$gk_assess" != "unknown" || $cs_signed -eq 1 || "$nota_stapled" != "unknown" ]]; then
        local vr_col="$WHITE"
        case "$verdict" in
          safe) vr_col="$GREEN";; caution) vr_col="$YELLOW";; unsafe) vr_col="$RED";;
        esac
        _kv "Verdict" "${vr_col}${verdict}${RESET} ${DIM}(gatekeeper:${gk_assess} codesign:${cs_status}${cs_team:+ team:${cs_team}}${nota_stapled:+ notarization:${nota_stapled}})${RESET}"
      fi
      if [[ $OSTYPE == darwin* ]]; then
        local -a xas; xas=()
        if command -v xattr >/dev/null 2>&1; then
          xas=( $(xattr -l "$path_arg" 2>/dev/null | sed -n 's/^\([^:]*\):.*/\1/p') )
        fi
        local acl_present=0
        if command -v ls >/dev/null 2>&1; then
          ls -le "$path_arg" 2>/dev/null | grep -q '^\s*[0-9]\+:' && acl_present=1
        fi
        if [[ -n "$qstr" ]]; then _kv "Quarantine" "${YELLOW}yes${RESET} ${DIM}(${qstr%%;*})${RESET}"; fi
        if [[ -n "$froms" ]]; then _kv "WhereFroms" "${froms}"; fi
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
      # Ensure xtrace is off in this block to avoid leaking debug lines
      local __was_xtrace=0
      if [[ -o xtrace ]]; then __was_xtrace=1; set +x; fi
      for line in "${act_lines[@]}"; do
        [[ -z "$line" ]] && continue
        if [[ -z ${seen_map[$line]:-} ]]; then
          seen_map[$line]=1
          local basecmd=${line%% *}
          local _icon_out; _icon_out=$(_cmd_icon "$basecmd")
          local _color_out; _color_out=$(_cmd_color "$basecmd")
          printf "  %s%s %s%s\n" "$_color_out" "$_icon_out" "$line" "$RESET"
        fi
      done
      if (( __was_xtrace )); then set -x; fi
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
    [[ -n "$link_count" && "$link_count" == <-> && $link_count -gt 1 ]] && print -r -- "hardlinks${tab}${link_count}"
    [[ -n "$branch" ]] && print -r -- "git_branch${tab}${branch}"
    [[ -n "$git_flag" ]] && print -r -- "git_status${tab}${git_flag}"
    [[ -n "$qstr" ]] && print -r -- "quarantine${tab}yes"
    [[ -n "$froms" ]] && print -r -- "where_froms${tab}${froms}"
    [[ -n "$hash_algo" && -n "$checksum" ]] && print -r -- "${hash_algo}${tab}${checksum}"
    [[ -n "$ft_pages" ]] && print -r -- "pages${tab}${ft_pages}"
    [[ -n "$ft_headings" ]] && print -r -- "headings${tab}${ft_headings}"
    [[ -n "$ft_columns" ]] && print -r -- "columns${tab}${ft_columns}"
    [[ -n "$ft_delim" ]] && print -r -- "delimiter${tab}${ft_delim}"
    [[ -n "$ft_image_dims" ]] && print -r -- "image_dims${tab}${ft_image_dims}"
    [[ -n "$about_str" ]] && print -r -- "about${tab}${about_str}"
    # Security fields
    print -r -- "gatekeeper${tab}${gk_assess}"
    print -r -- "codesign_status${tab}${cs_status}"
    [[ -n "$cs_team" ]] && print -r -- "codesign_team${tab}${cs_team}"
    print -r -- "notarization${tab}${nota_stapled}"
    print -r -- "verdict${tab}${verdict}"
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
    local j_img; j_img=$(_json_escape "$ft_image_dims")
    local j_delim; j_delim=$(_json_escape "$ft_delim")
    local j_pages=$(_json_escape "$ft_pages")
    local j_headings=$(_json_escape "$ft_headings")
    local j_columns=$(_json_escape "$ft_columns")
    local j_about; j_about=$(_json_escape "$about_str")
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
    printf '{"name":"%s","path":{"abs":"%s","rel":"%s"},"is_dir":%s,"type":{"description":"%s","is_text":"%s","charset":"%s"},"size":{"bytes":%s,"human":"%s"},"lines":%s,"perms":{"symbolic":"%s","octal":"%s","explain":"%s"},"dates":{"created":"%s","modified":"%s"},"git":{"present":%s,"branch":"%s","status":"%s"},"security":{"gatekeeper":"%s","codesign":{"signed":%s,"status":"%s","team":"%s"},"notarization":"%s","quarantine":"%s","where_froms":"%s","verdict":"%s"},"links":{"hardlinks":%s},"symlink":{"is_symlink":%s,"target":"%s","target_exists":%s},"dir":{"num_dirs":%s,"num_files":%s,"size_human":"%s"},"filetype":{"pages":%s,"headings":%s,"columns":%s,"delimiter":"%s","image_dims":"%s"},"about":"%s","quality":%s,"actions":%s}\n' \
      "$j_name" "$j_abs" "$j_rel" \
      $([[ -d "$target" ]] && echo true || echo false) \
      "$j_type" "$is_text" "$j_charset" \
      "${size_bytes:-0}" "$size_human" \
      $([[ -n "$lc" ]] && echo "$lc" || echo null) \
      "$j_perms" "${perms_oct:-}" "$j_permexp" \
      "$j_created" "$j_modified" \
      $([[ -n "$branch" ]] && echo true || echo false) "$j_branch" "$j_gitflag" \
      "$gk_assess" $(( cs_signed ? 1 : 0 )) "$cs_status" "$cs_team" "$nota_stapled" "$([[ -n "$qstr" ]] && echo yes || echo no)" "$(_json_escape "$froms")" "$verdict" \
      $([[ -n "$link_count" && "$link_count" == <-> ]] && echo "$link_count" || echo null) \
      $(( is_symlink ? 1 : 0 )) "$j_link" $(( link_exists ? 1 : 0 )) \
      $([[ -d "$target" ]] && echo ${#subdirs} || echo 0) $([[ -d "$target" ]] && echo ${#files} || echo 0) "$([[ -d "$target" ]] && echo "$dsz" || echo "")" \
      $([[ -n "$ft_pages" ]] && echo "$j_pages" || echo null) $([[ -n "$ft_headings" ]] && echo "$j_headings" || echo null) $([[ -n "$ft_columns" ]] && echo "$j_columns" || echo null) "$j_delim" "$j_img" \
      "$j_about" \
      "$qa_json" "$ac_json"
      return 0
    fi

  # HTML mode: emit a minimal single-file report (self-contained plaintext/HTML)
  if (( opt_html )); then
    # Very simple HTML wrapping of key sections
    local title="finfo: ${name}"
    echo "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><title>${title}</title><style>body{font-family:ui-monospace,Menlo,Consolas,monospace;background:#111;color:#ddd;padding:16px} h1,h2{color:#9cf} .dim{color:#888} .sec{margin-top:1em} code{color:#cdf}</style></head><body>"
    printf "<h1>%s</h1>\n" "$name"
    echo "<div class=\"sec\"><h2>Essentials</h2>"
    printf "<div>Type: <code>%s</code></div>\n" "$file_desc"
    printf "<div>Size: <code>%s</code> <span class=\"dim\">(%s B)</span></div>\n" "$(_hr_size_fmt ${size_bytes:-0} "$unit_scheme")" "${size_bytes:-0}"
    [[ -n "$lc" ]] && printf "<div>Lines: <code>%s</code></div>\n" "$lc"
    printf "<div>Owner: <code>%s</code> Perms: <code>%s</code> (<span class=\"dim\">%s</span>)</div>\n" "$owner_group" "$perms_sym" "$perms_oct"
    [[ -n "$about_str" ]] && printf "<div>About: <code>%s</code></div>\n" "$about_str"
    echo "</div>"
    echo "<div class=\"sec\"><h2>Timeline</h2>"
    printf "<div>Created: <code>%s</code></div>\n" "$created_at"
    printf "<div>Modified: <code>%s</code></div>\n" "$modified_at"
    echo "</div>"
    echo "<div class=\"sec\"><h2>Paths</h2>"
    printf "<div>Rel: <code>%s</code></div>\n" "$rel_path"
    printf "<div>Abs: <code>%s</code></div>\n" "$abs_path"
    echo "</div>"
    echo "<div class=\"sec\"><h2>Security</h2>"
    printf "<div>Gatekeeper: <code>%s</code> Codesign: <code>%s</code> Team: <code>%s</code> Notarization: <code>%s</code> Verdict: <code>%s</code></div>\n" "$gk_assess" "$cs_status" "$cs_team" "$nota_stapled" "$verdict"
    [[ -n "$qstr" ]] && printf "<div>Quarantine: <code>yes</code> (<span class=\"dim\">%s</span>)</div>\n" "${qstr%%;*}"
    [[ -n "$froms" ]] && printf "<div>WhereFroms: <code>%s</code></div>\n" "$froms"
    echo "</div>"
    echo "</body></html>"
    _cleanup; return 0
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
      if [[ ${size_bytes:-0} == <-> ]]; then _total_bytes=$((_total_bytes + size_bytes)); _size_entries+="$size_bytes\t$rel_path"; fi
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
      _summary_print
    fi
  fi

  # Duplicate finder (pretty-only, on demand)
  if (( opt_duplicates )) && (( ! opt_json && ! opt_porcelain && ! opt_compact )); then
    finfo_cmd_duplicates "${targets[@]}"
  fi

  # Final cleanup once
  multi_mode=0
  _cleanup; return 0
}
