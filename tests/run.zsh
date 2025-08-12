#!/usr/bin/env zsh
set -eu

# Ensure predictable environment
export NO_COLOR=1
export FINFOTHEME=default
export FINFONERD=0

ROOT=${0:A:h:h}
FINFO="$ROOT/finfo.zsh"
NORM="$ROOT/tests/normalize_porcelain.zsh"
GOLD="$ROOT/tests/golden"
FX="$ROOT/tests/fixtures"
TMP="$ROOT/tests/tmp"

mkdir -p "$GOLD" "$FX" "$TMP"

# Fixtures
print -r -- "hello world" > "$FX/sample.txt"
mkdir -p "$FX/sample_dir"
print -r -- "inner" > "$FX/sample_dir/inner.txt"
ln -sf "sample.txt" "$FX/sample_link"

# Helper to capture and normalize porcelain
run_porc() {
  local target="$1"; shift
  "$FINFO" --porcelain --no-git --no-icons --unit bytes -- "$target" | zsh "$NORM"
}

# Generate current outputs
run_porc "$FX/sample.txt" > "$TMP/porcelain_sample.txt.txt"
run_porc "$FX/sample_dir" > "$TMP/porcelain_sample_dir.dir.txt"
run_porc "$FX/sample_link" > "$TMP/porcelain_symlink.txt"

# If golden missing, initialize
for f in porcelain_sample.txt.txt porcelain_sample_dir.dir.txt porcelain_symlink.txt; do
  if [[ ! -f "$GOLD/$f" ]]; then
    cp "$TMP/$f" "$GOLD/$f"
  fi
done

# Diff against golden
ok=1
for f in porcelain_sample.txt.txt porcelain_sample_dir.dir.txt porcelain_symlink.txt; do
  if ! diff -u --label "golden/$f" --label "current/$f" "$GOLD/$f" "$TMP/$f"; then
    ok=0
  fi
done

if (( ok )); then
  print -r -- "All tests passed"
  exit 0
else
  print -r -- "Some tests failed"
  exit 1
fi
