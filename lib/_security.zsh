# Security and provenance helpers for finfo

# Computes security globals for a given path
# Sets: gk_assess cs_signed cs_status cs_team cs_auth nota_stapled quarantine_present froms qstr verdict
_compute_security() {
  local path_arg="$1" file_desc="$2" target="$3"
  gk_assess="unknown"; cs_signed=0; cs_status="unknown"; cs_team=""; cs_auth=""; nota_stapled="unknown";
  quarantine_present="no"; froms=""; qstr=""; verdict="unknown"
  if [[ $OSTYPE == darwin* && ! -d "$target" ]]; then
    if print -r -- "$file_desc" | grep -Eq 'Mach-O|executable|dylib|shared library'; then
      if command -v spctl >/dev/null 2>&1; then
        local _spout
        _spout=$(spctl --assess -vv --type execute -- "$path_arg" 2>&1)
        if [[ $? -eq 0 ]]; then gk_assess="pass"; else gk_assess="fail"; fi
      fi
      if command -v codesign >/dev/null 2>&1; then
        local _csinfo _csverr
        _csinfo=$(codesign -dv --verbose=2 -- "$path_arg" 2>&1)
        if [[ $? -eq 0 ]]; then cs_signed=1; fi
        _csverr=$(codesign --verify --deep --strict -- "$path_arg" 2>&1)
        if [[ $? -eq 0 ]]; then cs_status="valid"; else cs_status="invalid"; fi
        cs_team=$(print -r -- "$_csinfo" | sed -nE 's/^TeamIdentifier=(.*)$/\1/p' | head -n1)
        cs_auth=$(print -r -- "$_csinfo" | sed -nE 's/^Authority=(.*)$/\1/p' | head -n1)
      fi
      if command -v xcrun >/dev/null 2>&1; then
        local _stout
        _stout=$(xcrun stapler validate -- "$path_arg" 2>&1)
        if [[ $? -eq 0 ]]; then nota_stapled="ok"; else nota_stapled="missing"; fi
      fi
    fi
  fi
  if [[ $OSTYPE == darwin* ]]; then
    qstr=$(xattr -p com.apple.quarantine "$path_arg" 2>/dev/null)
    [[ -n "$qstr" ]] && quarantine_present="yes"
    froms=$(mdls -name kMDItemWhereFroms -raw "$path_arg" 2>/dev/null)
    [[ "$froms" == "(null)" ]] && froms=""
  fi
  if [[ "$gk_assess" == pass && "$cs_status" == valid && "$quarantine_present" == no ]]; then
    verdict="safe"
  elif [[ "$gk_assess" == fail || "$cs_status" == invalid ]]; then
    verdict="unsafe"
  elif [[ "$quarantine_present" == yes ]]; then
    verdict="caution"
  fi
}
