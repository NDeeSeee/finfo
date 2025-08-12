# Checksum helpers

# Sets checksum_out based on algo for a file
_compute_checksum() {
  local path_arg="$1" algo="$2"
  checksum_out=""
  case "$algo" in
    sha256)
      if command -v shasum >/dev/null 2>&1; then checksum_out=$(shasum -a 256 -- "$path_arg" 2>/dev/null | awk '{print $1}')
      elif command -v openssl >/dev/null 2>&1; then checksum_out=$(openssl dgst -sha256 "$path_arg" 2>/dev/null | awk '{print $2}')
      fi;;
    blake3|b3)
      if command -v b3sum >/dev/null 2>&1; then checksum_out=$(b3sum -- "$path_arg" 2>/dev/null | awk '{print $1}')
      fi;;
  esac
}
