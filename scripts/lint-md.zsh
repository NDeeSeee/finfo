#!/usr/bin/env zsh
# Lint Markdown files and optionally auto-fix common issues
# Usage:
#   scripts/lint-md.zsh          # report problems
#   scripts/lint-md.zsh --fix    # auto-fix (prettier + markdownlint --fix), then re-run lint

set -euo pipefail
cd "${0:A:h:h}"  # repo root

# Globs to include/exclude
INCLUDE=("**/*.md")
EXCLUDE=("node_modules/**" "dist/**" ".git/**")

# Join globs for tools that don't support --ignore-glob
collect_files() {
  local -a files=()
  local f
  for pat in ${INCLUDE[@]}; do
    for f in ${(f)~pat}(N); do
      # skip excluded
      local skip=0; local ex
      for ex in ${EXCLUDE[@]}; do
        [[ $f == ${(~)ex} ]] && skip=1 && break
      done
      (( skip )) || files+=("$f")
    done
  done
  print -r -- ${(F)files}
}

have() { command -v "$1" >/dev/null 2>&1 }
run_or_npx() {
  local bin="$1"; shift
  if have "$bin"; then "$bin" "$@"; else npx -y "$bin" "$@"; fi
}

if [[ ${1:-} == "--fix" ]]; then
  echo "Formatting with prettier (lists → 1.)..."
  local -a files; files=( ${(f)$(collect_files)} )
  if (( ${#files[@]} > 0 )); then
    local -a pargs=("--prose-wrap" "always" "--print-width" "100")
    if have prettier; then
      prettier -w ${pargs[@]} -- ${files[@]}
    else
      npx -y prettier -w ${pargs[@]} -- ${files[@]}
    fi
  fi
  echo "Applying markdownlint --fix where supported..."
  if (( ${#files[@]} > 0 )); then
    if have markdownlint; then
      markdownlint --fix -- ${files[@]} || true
    else
      npx -y markdownlint-cli --fix -- ${files[@]} || true
    fi
  fi
fi

echo "Linting Markdown with markdownlint..."
local -a files2; files2=( ${(f)$(collect_files)} )
if (( ${#files2[@]} == 0 )); then
  echo "No Markdown files found."; exit 0
fi
if have markdownlint; then
  markdownlint -- ${files2[@]}
else
  npx -y markdownlint-cli -- ${files2[@]}
fi
