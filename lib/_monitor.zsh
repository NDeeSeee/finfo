# Monitor helpers

# Emits a one-line rate kv based on size diff over dt seconds
_print_rate_over_window() {
  local path_arg="$1" dt="$2" unit_scheme="$3"
  local s1 s2
  local sb
  s1=0; s2=0
  if [[ $OSTYPE == darwin* ]]; then sb="/usr/bin/stat"; [[ -x $sb ]] || sb="stat"; s1=$($sb -f '%z' "$path_arg" 2>/dev/null) ; else s1=$(stat -c '%s' -- "$path_arg" 2>/dev/null) ; fi
  sleep "$dt"
  if [[ $OSTYPE == darwin* ]]; then sb="/usr/bin/stat"; [[ -x $sb ]] || sb="stat"; s2=$($sb -f '%z' "$path_arg" 2>/dev/null) ; else s2=$(stat -c '%s' -- "$path_arg" 2>/dev/null) ; fi
  [[ -z "$s1" ]] && s1=0; [[ -z "$s2" ]] && s2=$s1
  local dr=$(( s2 - s1 ))
  local sign="~"; local color="$WHITE"
  if (( dr > 0 )); then sign="+"; color="$GREEN"; elif (( dr < 0 )); then sign="-"; color="$YELLOW"; fi
  local rate_abs=$(( dr>=0 ? dr : -dr ))
  local per_sec=$(( dt>0 ? rate_abs/dt : rate_abs ))
  local rate_disp; rate_disp=$(_hr_size_fmt $per_sec "$unit_scheme")
  _kv "Rate" "${color}${sign}${rate_disp}/s${RESET} ${DIM}(${dt}s window)${RESET}"
}
