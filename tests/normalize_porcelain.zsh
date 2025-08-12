#!/usr/bin/env zsh
set -eu
# Normalize porcelain by removing volatile or environment-specific keys
# Usage: normalize_porcelain.zsh < input

awk -F"\t" 'BEGIN{OFS="\t"}
{
  key=$1
  if (key ~ /^(owner_group|perms_sym|perms_oct|created|modified|accessed|rel|abs|git_branch|git_status|quarantine|where_froms|gatekeeper|codesign_status|codesign_team|notarization|verdict|sha256|blake3)$/) {
    next
  }
  print $0
}' | LC_ALL=C sort
