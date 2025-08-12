# Icon helpers for finfo.zsh

# Optional Nerd Font icon map
if [[ -z ${i_oct_file_directory:-} ]] && [[ -f ~/.local/share/nerd-fonts/i_all.sh ]]; then
  source ~/.local/share/nerd-fonts/i_all.sh
fi
: ${i_oct_file_directory:=}
: ${i_oct_link:=}
: ${i_fa_file_o:=}

typeset -gA _NF_KEY=(
  dir     oct_file_directory
  link    oct_link
  file    fa_file_o
)
_icon() { local var="i_${_NF_KEY[$1]:-fa_file_o}"; print -rn -- "${(P)var}"; }

_has_nerd() { [[ "${FINFONERD:-1}" == "1" && -n ${i_oct_file_directory:-} ]]; }
