# finfo subcommand: chmod PATH (interactive)

finfo_cmd_chmod() {
  local T="$1"
  [[ -z "$T" ]] && { echo "Usage: finfo chmod PATH"; return 2; }
  [[ ! -e "$T" ]] && { echo "${RED}✗${RESET} not found: $T"; return 1; }
  local psym poct
  if [[ $OSTYPE == darwin* ]]; then psym=$(/usr/bin/stat -f '%Sp' -- "$T" 2>/dev/null); poct=$(/usr/bin/stat -f '%p' -- "$T" 2>/dev/null)
  else psym=$(stat -c '%A' -- "$T" 2>/dev/null); poct=$(stat -c '%a' -- "$T" 2>/dev/null); fi
  local flags="${psym[2,10]}"; local pos=1
  _chmod_flags_to_octal() { local s="$1"; local u=${s[1,3]} g=${s[4,6]} o=${s[7,9]}; _trip(){local t="$1";local n=0;[[ ${t[1]}==r ]]&&((n+=4));[[ ${t[2]}==w ]]&&((n+=2));[[ ${t[3]}==x ]]&&((n+=1));echo -n "$n";}; printf "%s%s%s" "$(_trip "$u")" "$(_trip "$g")" "$(_trip "$o")"; }
  _render(){ local buf="${flags}"; local u=${buf[1,3]} g=${buf[4,6]} o=${buf[7,9]}; local expl; expl=$(_perm_explain "$T"); local oct=""; oct=$(_chmod_flags_to_octal "$buf"); printf "\n  %sInteractive chmod for:%s %s\n" "$BOLD" "$RESET" "$T"; printf "  perms: %s%s%s  %s(u)%s%s  %s(g)%s%s  %s(o)%s%s\n" "$BOLD" "$flags" "$RESET" "$DIM" "$RESET" "$u" "$DIM" "$RESET" "$g" "$DIM" "$RESET" "$o"; printf "  octal: %s%s%s    explain: %s\n" "$BOLD" "$oct" "$RESET" "$expl"; printf "  Use arrows to move, space to toggle; s=save, q=quit without changes\n"; local pad=$(( pos + 8 )); printf "  perms: "; local i=1; while (( i<=9 )); do if (( i==pos )); then printf "%s^%s" "$YELLOW" "$RESET"; else printf " "; fi; (( i++ )); done; printf "\n"; }
  stty -echo -icanon time 0 min 0 2>/dev/null || true
  local ch
  while :; do tput civis 2>/dev/null || true; _render; read -r -k 1 ch; [[ -z "$ch" ]] && { tput el 2>/dev/null || true; sleep 0.05; printf "\r"; continue; }
    case "$ch" in
      q) printf "\n"; stty sane 2>/dev/null || true; tput cnorm 2>/dev/null || true; return 0;;
      s) local oct; oct=$(_chmod_flags_to_octal "$flags"); printf "\nApply chmod %s%s%s to %s? [y/N] " "$BOLD" "$oct" "$RESET" "$T"; local ans; read -r ans; if [[ "$ans" == [yY] ]]; then chmod "$oct" -- "$T" && echo "Applied."; fi; stty sane 2>/dev/null || true; tput cnorm 2>/dev/null || true; return 0;;
      ' ') local arr; arr=( ${(s::)flags} ); local idx=$pos; local cur=${arr[$idx]}; local col=$(( (pos-1)%3 )); case $col in 0) arr[$idx]=$([[ $cur == r ]] && echo '-' || echo 'r');; 1) arr[$idx]=$([[ $cur == w ]] && echo '-' || echo 'w');; 2) arr[$idx]=$([[ $cur == x ]] && echo '-' || echo 'x');; esac; flags="${(j::)arr}";;
      $'\x1b') read -r -k 2 ch; case "$ch" in '[C') (( pos<9 )) && ((pos++)) ;; '[D') (( pos>1 )) && ((pos--)) ;; esac;;
    esac; printf "\r\033[5A" 2>/dev/null || true
  done
}
