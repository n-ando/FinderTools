#!/bin/sh
# for Mac OS X
# required sips command

cd "$(dirname "$0")"

# 出力する解像度とファイル名の対応
sizes=(
  "1024:icon_512x512@2x.png"
  "512:icon_512x512.png"
  "512:icon_256x256@2x.png"
  "256:icon_256x256.png"
  "256:icon_128x128@2x.png"
  "128:icon_128x128.png"
  "64:icon_32x32@2x.png"
  "32:icon_32x32.png"
  "32:icon_16x16@2x.png"
  "16:icon_16x16.png"
)

# light と dark をループで処理
for theme in light dark; do
  outdir="icon_${theme}.iconset"
  mkdir -p "$outdir"

  base_file="icon_512x512@2x_${theme}.png"
  if [ ! -e "$base_file" ]; then
    echo "Not Found file $base_file..."
    exit 1
  fi

  for entry in "${sizes[@]}"; do
    size="${entry%%:*}"
    filename="${entry##*:}"
    sips -Z "$size" "$base_file" --out "${outdir}/${filename}"
  done

  iconutil -c icns "$outdir"
done

exit 0


