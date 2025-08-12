# Summary helpers for multi-target output

_summary_print() {
  # Uses dynamic scoped variables from caller:
  # _total_files _total_dirs _ext_count _largest_name _largest_size _total_bytes _oldest_name _oldest_epoch _quar_count _hl_multi_count _size_entries
  # LABEL, DIM, RESET, unit_scheme
  _section "SUMMARY" type
  _kv "Items" "$(( _total_files + _total_dirs )) total — ${_total_files} files, ${_total_dirs} dirs"
  if (( ${#_ext_count[@]} )); then
    local sorted_types; sorted_types=$(for k in ${(k)_ext_count}; do printf "%s:%s\n" "$k" "${_ext_count[$k]}"; done | sort -t ':' -k2,2nr | paste -sd ', ' -)
    printf "  %s%-*s %s\n" "$LABEL" 12 "By type:" "$sorted_types"
  fi
  [[ -n "$_largest_name" ]] && _kv "Largest" "${_largest_name} ${DIM}($(_hr_size $_largest_size), ${_largest_size} B)${RESET}"
  if (( _total_bytes > 0 )); then
    local _tot_disp; _tot_disp=$(_hr_size_fmt $_total_bytes "$unit_scheme")
    _kv "Total" "${_tot_disp} ${DIM}(${_total_bytes} B)${RESET}"
  fi
  if (( _oldest_epoch > 0 )); then
    local _oldest_rel; _oldest_rel=$(_fmt_ago $(( $(date +%s) - _oldest_epoch )))
    _kv "Oldest" "${_oldest_name} ${DIM}(${_oldest_rel})${RESET}"
  fi
  if (( _quar_count > 0 )); then
    _kv "Quarantine" "${YELLOW}${_quar_count}${RESET} flagged"
  fi
  if (( _hl_multi_count > 0 )); then
    _kv "Hardlinks" "${_hl_multi_count} files with >1 link"
  fi
  if (( ${#_size_entries[@]} > 0 )); then
    local N=${FINFO_TOPN:-5}
    local tops; tops=$(printf "%s\n" "${_size_entries[@]}" | sort -nr -k1,1 | head -n $N)
    local idx=1
    local line
    while IFS=$'\t' read -r sz path; do
      [[ -z "$sz" ]] && continue
      _kv "Top $idx" "${path} ${DIM}($(_hr_size $sz), ${sz} B)${RESET}"
      (( idx++ ))
    done <<< "$tops"
  fi
}
