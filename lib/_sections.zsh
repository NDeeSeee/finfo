# Section icons and glyphs for finfo.zsh

_sec_icon() {
  local key="$1"
  if _has_nerd; then
    case "$key" in
      type)       print -rn -- "󰈙" ;;
      dir)        print -rn -- "󰉋" ;;
      perms)      print -rn -- "󰌾" ;;
      dates)      print -rn -- ""  ;;
      paths)      print -rn -- "󰌷" ;;
      gitdocker)  print -rn -- "󰊢 " ;;
      actions)    print -rn -- ""  ;;
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

_cmd_icon() {
  local cmd="$1"
  if _has_nerd; then
    case "$cmd" in
      bat|less|glow|open) echo "";;
      jq|yq)              echo "";;
      ruff|eslint|yamllint|markdownlint|shellcheck|hadolint|vale|cspell|typos) echo "";;
      black|prettier|shfmt) echo "";;
      unzip|tar|gunzip|bunzip2|unxz|7z) echo "";;
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
