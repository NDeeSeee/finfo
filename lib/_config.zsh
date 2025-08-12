# Config loader for finfo

# Loads environment-based defaults and optional config file in $HOME/.config/finfo/config.zsh
_load_config() {
  : ${FINFO_TOPN:=5}
  : ${FINFO_UNIT:=iec}
  : ${FINFOCODE:=1}
  # Optional config file
  local cfg="$HOME/.config/finfo/config.zsh"
  if [[ -f "$cfg" ]]; then
    source "$cfg"
  fi
}
