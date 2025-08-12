# finfo search — fast content/path search with graceful fallbacks

finfo_cmd_search() {
  emulate -L zsh
  setopt pipefail

  local pattern="$1"; shift || true
  local root="${1:-.}"; [[ -n "${1:-}" ]] && shift || true

  if [[ -z "$pattern" ]]; then
    print -r -- "Usage: finfo search PATTERN [DIR]" 1>&2
    return 1
  fi

  local use_rg=0 use_fd=0 use_bat=0 use_fzf=0
  command -v rg >/dev/null 2>&1 && use_rg=1
  command -v fd >/dev/null 2>&1 && use_fd=1
  command -v bat >/dev/null 2>&1 && use_bat=1
  if [[ -t 1 ]] && command -v fzf >/dev/null 2>&1; then use_fzf=1; fi

  # Path candidate list
  local -a files
  if (( use_fd )); then
    files=( ${(f)$(fd --type f --hidden --follow --color never . -- "$root" 2>/dev/null)} )
  else
    files=( ${(f)$(command find "$root" -type f 2>/dev/null)} )
  fi
  (( ${#files[@]} == 0 )) && return 0

  if (( use_fzf )); then
    # Interactive pipeline: ripgrep (or grep) → fzf with preview
    if (( use_rg )); then
      RG_PREFIX=(rg --hidden --smart-case --line-number --no-heading --color=always -- "$pattern")
      :
    else
      RG_PREFIX=(grep -RIn -- "$pattern")
    fi

    local preview_cmd
    if (( use_bat )); then
      preview_cmd='bat --style=numbers --color=always --line-range :500 {1} --highlight-line {2}'
    else
      preview_cmd='sed -n "1,200p" {1} | nl -ba | sed -e "{2}s/.*/\x1b[7m&\x1b[0m/"'
    fi

    # shellcheck disable=SC2016
    eval "${RG_PREFIX[@]}" | \
      fzf --ansi --delimiter ':' --with-nth=1,2,3.. --preview-window=right:70% \
          --preview "$preview_cmd" \
          --bind 'enter:execute-silent(echo {1}:{2} | awk -F: '{print $1"+"$2}')' \
          --header="Search: $pattern  in $root" \
          --height=95% --layout=reverse --info=inline
    return 0
  else
    # Non-interactive: print matches
    if (( use_rg )); then
      rg --hidden --smart-case --line-number --no-heading -- "$pattern" "$root"
    else
      grep -RIn -- "$pattern" "$root"
    fi
  fi
}


