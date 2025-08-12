# finfo ls — directory listing sugar (eza/exa if available, else ls)

finfo_cmd_ls() {
  emulate -L zsh
  local dir="${1:-.}"
  local nerd=${FINFONERD:-0}

  if command -v eza >/dev/null 2>&1; then
    if (( nerd )); then
      eza -la --icons --group-directories-first --git -- "$dir"
    else
      eza -la --group-directories-first --git -- "$dir"
    fi
    return $?
  fi
  if command -v exa >/dev/null 2>&1; then
    if (( nerd )); then
      exa -la --icons --group-directories-first --git -- "$dir"
    else
      exa -la --group-directories-first --git -- "$dir"
    fi
    return $?
  fi

  # Fallback
  ls -la "$dir"
}


