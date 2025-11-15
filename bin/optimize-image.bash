#!/bin/bash

# Optimize images
#
#
# Usage:
# ./optimize-image.bash <image_path>
#
# Example:
# ./optimize-image.bash assets/images/example.jpg

set -e

# Store current working directory
pushd $(pwd) >/dev/null
# Change to script directory
cd "${0%/*}"

# -- Begin Script --

FILES=$(find ../raw_assets -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.gif" -o -name "*.webp" \))

for file in $FILES; do
  expanded_path=$(realpath "$file")
  echo "Input path: $expanded_path"
  outfile="${expanded_path/raw_assets\//assets/}"
  renamed_outfile="${outfile%.*}.webp"
  echo "Output path: $renamed_outfile"

  # Create the output directory if it doesn't exist
  output_dir=$(dirname "$outfile")
  echo "Creating output directory: $output_dir"
  mkdir -p "$output_dir"

  # -verbose: Print verbose output
  # -strip: Remove metadata like EXIF, comments, and color profiles
  # -resize: Resize image to max width of 740px while maintaining aspect ratio
  # -quality: Set JPEG quality to 85% for good balance of size/quality
  # -format: Set output format to webp
  # -define: Set webp compression options
  # -define webp:method=6: Set webp compression method to 6 (default is 4)
  # -define webp:lossless=true: Set webp compression to lossless
  # -define webp:alpha-quality=85: Set webp alpha quality to 85
  # -define webp:thread-level=0: Set webp thread level to 0
  # -define webp:low-memory=false: Set webp low memory to false
  magick -verbose \
    "$expanded_path" \
    -strip \
    -resize "800x>" \
    -quality 95 \
    -format webp \
    -define webp:method=6 \
    -define webp:lossless=true \
    -define webp:alpha-quality=95 \
    -define webp:thread-level=0 \
    -define webp:low-memory=false \
    "$renamed_outfile"
done

# -- End Script --

# Return to original working directory
popd >/dev/null
