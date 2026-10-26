#!/bin/bash
# Not "is it installed" but "does it do the job".
set -u
fail=0
ok()   { printf "  OK    %-26s %s\n" "$1" "$2"; }
bad()  { printf "  FAIL  %-26s %s\n" "$1" "$2"; fail=1; }

v=$(magick -version 2>/dev/null | head -1 | grep -oE 'ImageMagick [0-9.]+')
[ -n "$v" ] && ok "magick" "$v" || bad "magick" "not found"

# A real conversion, the same shape the app does: shrink and strip.
magick -size 4000x3000 gradient:navy-white jpg:- 2>/dev/null > /tmp/big.jpg
if [ -s /tmp/big.jpg ]; then
  magick /tmp/big.jpg -strip -resize '2000x2000>' jpg:- 2>/dev/null > /tmp/small.jpg
  d=$(magick identify -format '%wx%h' /tmp/small.jpg 2>/dev/null)
  [ "$d" = "2000x1500" ] && ok "magick resize" "4000x3000 -> $d" || bad "magick resize" "got '$d'"
else
  bad "magick create" "could not make a test image"
fi

# The hardened policy must be in force, or the AI can make ImageMagick fetch URLs.
if MAGICK_CONFIGURE_PATH=/rails/config/imagemagick magick -list policy 2>/dev/null | grep -qi "rights: none"; then
  ok "magick policy" "the hardened policy loads"
else
  bad "magick policy" "policy.xml is NOT being applied"
fi

for b in ffmpeg ffprobe node rsvg-convert potrace; do
  p=$(command -v $b)
  [ -n "$p" ] && ok "$b" "$($b --version 2>&1 | head -1 | cut -c1-44)" || bad "$b" "not found"
done

# Chromium must actually render, not merely exist.
if [ -x "$CHROME" ]; then
  echo '<html><body style="font:40px serif">Parish</body></html>' > /tmp/t.html
  "$CHROME" --headless --no-sandbox --disable-gpu --hide-scrollbars \
            --virtual-time-budget=4000 --screenshot=/tmp/shot.png \
            --window-size=400,200 file:///tmp/t.html >/dev/null 2>&1
  if [ -s /tmp/shot.png ]; then
    ok "chromium screenshot" "$(magick identify -format '%wx%h %b' /tmp/shot.png 2>/dev/null)"
    # Blank means no fonts. A page of empty boxes is the classic container bug.
    colours=$(magick identify -format '%k' /tmp/shot.png 2>/dev/null)
    [ "${colours:-1}" -gt 1 ] && ok "fonts" "text rendered ($colours colours)" || bad "fonts" "screenshot is blank"
  else
    bad "chromium screenshot" "produced nothing"
  fi
  ok "chromium" "$("$CHROME" --version 2>/dev/null | head -1)"
else
  bad "chromium" "CHROME=$CHROME is not executable"
fi

# A real video, turned into a real still.
ffmpeg -y -f lavfi -i testsrc=duration=1:size=320x240:rate=10 -pix_fmt yuv420p /tmp/v.mp4 >/dev/null 2>&1
ffmpeg -y -i /tmp/v.mp4 -vf "thumbnail=n=10" -frames:v 1 /tmp/frame.jpg >/dev/null 2>&1
[ -s /tmp/frame.jpg ] && ok "video -> still" "$(magick identify -format '%wx%h' /tmp/frame.jpg 2>/dev/null)" || bad "video -> still" "no frame produced"

echo
[ $fail -eq 0 ] && echo "EVERYTHING THE EDITOR NEEDS IS PRESENT AND WORKING." || echo "SOMETHING IS MISSING — see FAIL above."
exit $fail
