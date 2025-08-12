#!/usr/bin/env zsh
set -eu
# Normalize JSON by sorting keys and removing volatile fields
# Requires jq if available; otherwise, passthrough

if ! command -v jq >/dev/null 2>&1; then
  cat
  exit 0
fi

jq 'del(.dates, .git, .security, .links, .symlink, .dir, .quality, .actions) 
    | .type.description? //= ""
    | .type.is_text? //= ""
    | .size.bytes? //= 0
    | .size.human? //= ""
    | .filetype |= {pages, headings, columns, delimiter, image_dims}
    | .path |= {abs, rel}
    | .perms |= {symbolic, octal, explain}
    | {name, path, is_dir, type, size, lines, perms, about, filetype}'