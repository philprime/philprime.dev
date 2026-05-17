#!/bin/bash

# Optimize images
#
# Walks raw_assets/ for source images (jpg, png, gif, webp), encodes them
# to webp under assets/ at max width 800px, and tracks every output in a
# JSONL manifest. An entry is skipped on subsequent runs when both the
# source hash and the script hash are unchanged, so re-running this is a
# no-op until something actually changes. Source files that disappear
# from raw_assets/ also have their generated webp pruned.

set -e

# Resolve paths and run from the repo root so manifest paths are repo-relative.
script_dir="$(cd "$(dirname "$0")" && pwd)"
script_path="$script_dir/$(basename "$0")"
cd "$script_dir/.."

manifest="assets/.optimize-manifest.jsonl"
script_sha=$(shasum -a 256 "$script_path" | awk '{print $1}')

tmp_manifest=$(mktemp)
seen_file=$(mktemp)
trap 'rm -f "$tmp_manifest" "$seen_file"' EXIT

while IFS= read -r -d '' input_path; do
  output_path="${input_path/raw_assets\//assets/}"
  output_path="${output_path%.*}.webp"
  echo "$output_path" >> "$seen_file"

  input_sha=$(shasum -a 256 "$input_path" | awk '{print $1}')

  skip=false
  if [[ -f "$manifest" && -f "$output_path" ]]; then
    prev_line=$(jq -c --arg p "$output_path" 'select(.path == $p)' "$manifest" 2>/dev/null | head -1 || true)
    if [[ -n "$prev_line" ]]; then
      prev_in=$(jq -r '.input' <<<"$prev_line")
      prev_sc=$(jq -r '.script' <<<"$prev_line")
      if [[ "$prev_in" == "$input_sha" && "$prev_sc" == "$script_sha" ]]; then
        skip=true
      fi
    fi
  fi

  if [[ "$skip" == "true" ]]; then
    echo "skip   $output_path"
  else
    echo "encode $input_path -> $output_path"
    mkdir -p "$(dirname "$output_path")"
    magick "$input_path" \
      -strip \
      -resize "800x>" \
      -quality 95 \
      -format webp \
      -define webp:method=6 \
      -define webp:lossless=true \
      -define webp:alpha-quality=95 \
      -define webp:thread-level=0 \
      -define webp:low-memory=false \
      "$output_path"
  fi

  jq -cn --arg p "$output_path" --arg i "$input_sha" --arg s "$script_sha" \
    '{path: $p, input: $i, script: $s}' >> "$tmp_manifest"
done < <(find raw_assets -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.gif" -o -name "*.webp" \) -print0)

# Prune outputs whose source files were removed from raw_assets/.
if [[ -f "$manifest" ]]; then
  while IFS= read -r orphan; do
    [[ -z "$orphan" ]] && continue
    if [[ -f "$orphan" ]]; then
      echo "prune  $orphan"
      rm "$orphan"
    fi
  done < <(comm -23 <(jq -r '.path' "$manifest" | sort -u) <(sort -u "$seen_file"))
fi

mkdir -p "$(dirname "$manifest")"
sort "$tmp_manifest" > "$manifest"
