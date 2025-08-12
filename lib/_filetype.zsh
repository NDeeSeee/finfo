# Filetype quick stats and About computation

# Sets globals: ft_pages ft_headings ft_columns ft_delim ft_image_dims ft_duration about_str
_compute_filetype_stats() {
  local path_arg="$1" name="$2" file_desc="$3"
  ft_pages=""; ft_headings=""; ft_columns=""; ft_delim=""; ft_image_dims=""; ft_duration=""; about_str=""
  # PDF
  case "${name:l}" in
    *.pdf)
      if [[ $OSTYPE == darwin* ]]; then
        local pages; pages=$(mdls -name kMDItemNumberOfPages -raw "$path_arg" 2>/dev/null)
        [[ "$pages" != "(null)" && "$pages" == <-> ]] && ft_pages="$pages"
      fi
      ;;
    *.png|*.jpg|*.jpeg|*.gif|*.tif|*.tiff|*.bmp|*.heic)
      if [[ $OSTYPE == darwin* ]] && command -v sips >/dev/null 2>&1; then
        local dim; dim=$(sips -g pixelWidth -g pixelHeight "$path_arg" 2>/dev/null | awk '/pixel(Width|Height):/{print $2}' | paste -sd 'x' -)
        [[ -n "$dim" ]] && ft_image_dims="$dim"
      fi
      ;;
    *.mp3|*.m4a|*.aac|*.wav|*.aiff|*.aif|*.flac|*.mp4|*.mov|*.m4v)
      if [[ $OSTYPE == darwin* ]]; then
        local dur=""; dur=$(mdls -name kMDItemDurationSeconds -raw "$path_arg" 2>/dev/null)
        if [[ "$dur" != "(null)" && -n "$dur" ]]; then
          local dur_s; dur_s=${dur%.*}
          ft_duration=$(_fmt_duration ${dur_s:-0})
        fi
      fi
      ;;
    *.md|*.markdown)
      if command -v grep >/dev/null 2>&1; then
        local hcnt; hcnt=$(grep -E '^[#]{1,6} ' -c -- "$path_arg" 2>/dev/null || echo 0)
        [[ "$hcnt" == <-> ]] && ft_headings="$hcnt"
      fi
      ;;
    *.csv|*.tsv|*.txt)
      local first_line; first_line=$(sed -n '/./{p;q;}' "$path_arg" 2>/dev/null)
      if [[ -n "$first_line" ]]; then
        local dl=","; local ccomma csemi ctab cpipe
        ccomma=$(print -r -- "$first_line" | awk -F',' '{print NF-1}')
        csemi=$(print -r -- "$first_line" | awk -F';' '{print NF-1}')
        ctab=$(print -r -- "$first_line" | awk -F'\t' '{print NF-1}')
        cpipe=$(print -r -- "$first_line" | awk -F'\|' '{print NF-1}')
        local max=$ccomma; dl=","; if (( csemi>max )); then max=$csemi; dl=";"; fi; if (( ctab>max )); then max=$ctab; dl=$'\t'; fi; if (( cpipe>max )); then max=$cpipe; dl='|'; fi
        if (( max>0 )); then
          ft_columns=$(( max + 1 ))
          case "$dl" in $'\t') ft_delim="tab";; ';') ft_delim="semicolon";; '|') ft_delim="pipe";; *) ft_delim="comma";; esac
        fi
      fi
      ;;
  esac
  # About line selection
  if [[ -n "$ft_image_dims" ]]; then about_str="Image ${ft_image_dims}"
  elif [[ -n "$ft_pages" ]]; then about_str="PDF ${ft_pages} pages"
  elif [[ -n "$ft_headings" ]]; then about_str="Markdown ${ft_headings} headings"
  elif [[ -n "$ft_columns" ]]; then about_str="Delimited ${ft_columns} columns${ft_delim:+ (${ft_delim})}"
  else
    local extd; extd=$(_describe_ext "$name")
    if [[ -n "$extd" ]]; then about_str="$extd"; else about_str="${file_desc%%,*}"; fi
  fi
}
