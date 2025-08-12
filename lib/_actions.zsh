# Action and hint helpers for finfo.zsh

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
  # Editors and viewers
  command -v code >/dev/null 2>&1 && hints+=("code '$p'")
  command -v subl >/dev/null 2>&1 && hints+=("subl '$p'")
  command -v cursor >/dev/null 2>&1 && hints+=("cursor '$p'")
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

_clipboard_copy() {
  local data="$1"
  if [[ -z "$data" ]]; then return 1; fi
  if [[ "${FINFO_CLIPBOARD_MODE:-}" == "stdout" ]]; then
    print -rn -- "$data"
    return 0
  fi
  if command -v pbcopy >/dev/null 2>&1; then
    print -rn -- "$data" | pbcopy
    return 0
  fi
  if command -v xclip >/dev/null 2>&1; then
    print -rn -- "$data" | xclip -selection clipboard
    return 0
  fi
  if command -v wl-copy >/dev/null 2>&1; then
    print -rn -- "$data" | wl-copy
    return 0
  fi
  # Fallback: print to stdout so users can pipe it
  print -rn -- "$data"
  return 0
}

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
