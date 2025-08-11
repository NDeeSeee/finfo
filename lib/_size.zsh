# Size and time helpers for finfo.zsh

_hr_size() {
  local bytes="$1"; [[ -z "$bytes" || "$bytes" != <-> ]] && bytes=0
  if (( bytes >= 1073741824 )); then print -r -- "$((bytes/1073741824))G"; return
  elif (( bytes >= 1048576 )); then print -r -- "$((bytes/1048576))M"; return
  elif (( bytes >= 1024 )); then print -r -- "$((bytes/1024))K"; return
  else print -r -- "${bytes}B"; fi
}

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
