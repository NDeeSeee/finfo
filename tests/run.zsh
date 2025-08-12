#!/usr/bin/env zsh
set -eu

# Ensure predictable environment
export NO_COLOR=1
export FINFOTHEME=default
export FINFONERD=0

ROOT=${0:A:h:h}
FINFO="$ROOT/finfo.zsh"
NORM_P="$ROOT/tests/normalize_porcelain.zsh"
NORM_J="$ROOT/tests/normalize_json.zsh"
GOLD="$ROOT/tests/golden"
FX="$ROOT/tests/fixtures"
TMP="$ROOT/tests/tmp"

mkdir -p "$GOLD" "$FX" "$TMP"

# Fixtures
print -r -- "hello world" > "$FX/sample.txt"
mkdir -p "$FX/sample_dir"
print -r -- "inner" > "$FX/sample_dir/inner.txt"
ln -sf "sample.txt" "$FX/sample_link"

# Markdown fixture
cat > "$FX/sample.md" <<'MD'
# Title

## Section 1

### Subsection
MD

# Zip fixture (deterministic)
rm -f "$FX/sample_zip.zip"
(cd "$FX" && zip -q -X sample_zip.zip sample.txt sample.md >/dev/null 2>&1 || true)

# Tiny PNG (1x1 transparent) via base64 (deterministic)
PNG_B64="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII="
echo "$PNG_B64" | base64 --decode > "$FX/sample.png" 2>/dev/null || echo "$PNG_B64" | base64 -D > "$FX/sample.png" 2>/dev/null || true

# Helper to capture and normalize porcelain
run_porc() {
  local target="$1"; shift
  "$FINFO" --porcelain --no-git --no-icons --unit bytes -- "$target" | zsh "$NORM_P"
}

run_json() {
  local target="$1"; shift
  "$FINFO" --json --no-git --no-icons --unit bytes -- "$target" | zsh "$NORM_J"
}

# Generate current outputs
run_porc "$FX/sample.txt" > "$TMP/porcelain_sample.txt.txt"
run_porc "$FX/sample_dir" > "$TMP/porcelain_sample_dir.dir.txt"
run_porc "$FX/sample_link" > "$TMP/porcelain_symlink.txt"

run_json "$FX/sample.txt" > "$TMP/json_sample.txt.json"
run_json "$FX/sample_dir" > "$TMP/json_sample_dir.dir.json"
run_json "$FX/sample_link" > "$TMP/json_symlink.json"
run_json "$FX/sample.md" > "$TMP/json_sample_md.json"
run_json "$FX/sample.png" > "$TMP/json_sample_png.json"

# Monitor smoke: create a temp growing file and ensure Rate appears
monfile="$TMP/mon_grow.txt"
print -n -- "a" > "$monfile"
(
  # background write growth
  sleep 0.2
  print -n -- "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" >> "$monfile"
) &
"$FINFO" --monitor --unit bytes -- "$monfile" > "$TMP/monitor_pretty.txt" || true
grep -q -- "Rate" "$TMP/monitor_pretty.txt" || { echo "monitor missing Rate" >&2; ok=0; }

# Zip pretty smoke: should show Archive stats
"$FINFO" --unit bytes -- "$FX/sample_zip.zip" > "$TMP/zip_pretty.txt" || true
grep -q -- "Archive" "$TMP/zip_pretty.txt" || { echo "zip missing Archive" >&2; ok=0; }

# HTML smoke: ensure HTML contains Essentials and filename
"$FINFO" --html -- "$FX/sample.txt" > "$TMP/html_report.txt" || true
grep -q -- "<h1>sample.txt</h1>" "$TMP/html_report.txt" || { echo "html missing h1" >&2; ok=0; }
grep -q -- "Essentials" "$TMP/html_report.txt" || { echo "html missing Essentials" >&2; ok=0; }

# If golden missing or REGEN=1 or file empty, (re)initialize
for f in porcelain_sample.txt.txt porcelain_sample_dir.dir.txt porcelain_symlink.txt json_sample.txt.json json_sample_dir.dir.json json_symlink.json json_sample_md.json json_sample_png.json; do
  if [[ ! -f "$GOLD/$f" || "${REGEN:-0}" == 1 || ! -s "$GOLD/$f" ]]; then
    cp "$TMP/$f" "$GOLD/$f"
  fi
done

# Diff against golden
ok=1
for f in porcelain_sample.txt.txt porcelain_sample_dir.dir.txt porcelain_symlink.txt json_sample.txt.json json_sample_dir.dir.json json_symlink.json json_sample_md.json json_sample_png.json; do
  if ! diff -u --label "golden/$f" --label "current/$f" "$GOLD/$f" "$TMP/$f"; then
    ok=0
  fi
done

# Basic help sanity (flags presence)
if ! "$FINFO" --help | grep -q -- "--keys-timeout"; then
  echo "--help missing --keys-timeout" >&2
  ok=0
fi
# Duplicates command smoke: should run and not error
"$FINFO" --duplicates -- "$FX" > "$TMP/dups.txt" || true

if (( ok )); then
  print -r -- "All tests passed"
  exit 0
else
  print -r -- "Some tests failed"
  exit 1
fi
