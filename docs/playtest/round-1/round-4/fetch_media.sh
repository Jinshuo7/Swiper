#!/usr/bin/env bash
# Fetch the ~20 real photos and one short video used to judge the Home cards.
#
# The images come from picsum.photos (deterministic seeds, so a re-run is the
# same library), and the video is a short Ken Burns clip built from the first
# photo with ffmpeg. Nothing here is committed: the samples live under
# `round-3/samples/`, which is gitignored.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../round-3/samples"
mkdir -p "$OUT"
cd "$OUT"

sizes=("1600 2000" "2000 1500" "1600 1600" "1440 1920" "2048 1536")
index=0
for seed in swipr01 swipr02 swipr03 swipr04 swipr05 swipr06 swipr07 swipr08 swipr09 swipr10 \
            swipr11 swipr12 swipr13 swipr14 swipr15 swipr16 swipr17 swipr18 swipr19 swipr20; do
  set -- ${sizes[$((index % 5))]}
  printf -v name "%02d" $((index + 1))
  curl -L --fail -s -o "${name}.jpg" "https://picsum.photos/seed/${seed}/$1/$2"
  index=$((index + 1))
done

if [ ! -f video-beach.mp4 ]; then
  ffmpeg -y -loglevel error -loop 1 -i 01.jpg \
    -vf "scale=1080:-2,zoompan=z='min(zoom+0.0015,1.3)':d=125:s=1080x1350,format=yuv420p" \
    -t 5 -r 25 -c:v libx264 -pix_fmt yuv420p video-beach.mp4
fi

printf 'fetched %d photos + 1 video into %s\n' "$(ls ./*.jpg | wc -l | tr -d ' ')" "$OUT"
