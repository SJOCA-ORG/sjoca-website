#!/usr/bin/env bash
# A fingerprint of every page the live site serves: path, bytes, and a hash of
# the rendered HTML. Run it before and after a revision change to prove the
# site came back exactly as it was.
BASE="${BASE:-http://localhost:3000}"
cd "$(dirname "$0")/.."
bin/rails runner 'puts Page.in_revision(Revision.live).order(:slug).pluck(:slug)' 2>/dev/null |
while read -r slug; do
  [ -z "$slug" ] && continue
  path=$([ "$slug" = "home" ] && echo "/" || echo "/$slug")
  # The CSRF token is random on every request and a fixed length, so without
  # stripping it every page looks changed and none of them is. That cost a
  # confusing ten minutes the first time.
  body=$(curl -s "$BASE$path" | sed -E 's/(name="csrf-token" content=")[^"]*/\1REDACTED/')
  printf "%-44s %7d  %s\n" "$path" "${#body}" "$(printf '%s' "$body" | shasum -a 256 | cut -c1-16)"
done
