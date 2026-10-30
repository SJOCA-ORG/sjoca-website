#!/usr/bin/env bash
# The pictures the sample sites ship with.
#
#   script/placeholder_photographs.sh db/seeds/starters
#
# DRAWN, not photographed, and that is the whole point. A photograph committed
# to a public repository is in its history for ever, so a stock image with a
# licence nobody re-read, or a face nobody asked, is a decision that cannot be
# taken back. These are gradients and shapes made by ImageMagick: ours
# outright, nothing to attribute, nothing to clean up if this becomes a
# business, and unmistakably a placeholder to anybody who opens the site.
#
# They are also deliberately handsome. A starter whose pictures are grey boxes
# teaches people that the system makes grey boxes.
#
# The journal starter has none on purpose. Its argument is words first, and it
# was opening with a 400-pixel photograph like everything else -- which made it
# a narrower version of the other five rather than a different thing.
set -euo pipefail
OUT="${1:?usage: placeholder_photographs.sh OUT_DIR}"

# name|width|height|top colour|bottom colour|ink|variant
#
# The variant changes where the forms sit and which way the bands run. Without
# it every picture is the same picture in a different colour, which is fine
# until three of them sit side by side in the studio starter's grid.
LOOKS='
gathering/photos/home-hero-v1.jpg|1600|900|#7C2D2D|#D9A066|#FFFFFF|1
trade/photos/home-hero-v1.jpg|1600|900|#5A2D0C|#C98B43|#FFF4E6|2
noticeboard/photos/home-hero-v1.jpg|1600|900|#14281F|#4F7A5E|#DCEFE2|3
studio/photos/home-hero-v1.jpg|1600|1000|#0E0E0E|#3A3A3A|#F2F2F2|4
studio/photos/work-one-v1.jpg|1200|900|#2B2F36|#737C85|#F6F6F6|1
studio/photos/work-two-v1.jpg|1200|900|#3A2E2A|#8C7566|#F6F1EC|3
studio/photos/work-three-v1.jpg|1200|900|#1F2E2E|#6E8C8C|#EDF5F5|2
'

printf '%s\n' "$LOOKS" | grep . | while IFS='|' read -r path w h top bottom ink variant; do
  file="$OUT/$path"
  mkdir -p "$(dirname "$file")"

  # Built oversize, rotated, then cropped back -- otherwise the rotation leaves
  # empty corners and the picture looks broken rather than deliberate.
  #
  # The +repage after -rotate is load-bearing. Rotation leaves a page offset,
  # -crop with a gravity honours it, and the crop window ends up outside the
  # image -- which pulled a grey wedge into the corner of three of these eight.
  # It was invisible in a contact sheet and obvious in the corner pixels, which
  # is the only reason it was found.
  #
  # Angular translucent bands over a two-colour field, one crisp arc, a light
  # vignette. Abstract on purpose: a placeholder should be good enough that the
  # starter looks designed, and plainly not a photograph of anything.
  big_w=$(( w * 3 / 2 )); big_h=$(( h * 3 / 2 ))

  # Where the arc sits, and how steeply the bands run, by variant.
  case "$variant" in
    1) cx=72; cy=30; tilt=-7;  slope=30 ;;
    2) cx=22; cy=68; tilt=6;   slope=18 ;;
    3) cx=84; cy=74; tilt=-13; slope=42 ;;
    *) cx=38; cy=22; tilt=4;   slope=10 ;;
  esac

  magick -size "${big_w}x${big_h}" gradient:"${top}-${bottom}" \
    \( -size "${big_w}x${big_h}" xc:none \
       -fill "${ink}20" -draw "polygon 0,$((big_h*55/100)) ${big_w},$((big_h*(55-slope)/100)) ${big_w},$((big_h*(75-slope)/100)) 0,$((big_h*75/100))" \
       -fill "${ink}16" -draw "polygon 0,$((big_h*82/100)) ${big_w},$((big_h*(82-slope)/100)) ${big_w},$((big_h*(94-slope)/100)) 0,$((big_h*94/100))" \
       -fill "${ink}10" -draw "polygon 0,0 ${big_w},0 ${big_w},$((big_h*18/100)) 0,$((big_h*(18+slope/2)/100))" \
       -blur 0x3 \) -compose over -composite \
    \( -size "${big_w}x${big_h}" xc:none \
       -stroke "${ink}30" -strokewidth $(( big_h / 90 )) -fill none \
       -draw "circle $((big_w*cx/100)),$((big_h*cy/100)) $((big_w*cx/100)),$((big_h*(cy-22)/100))" \
       -blur 0x1 \) -compose over -composite \
    -background none -rotate "$tilt" +repage \
    -gravity center -crop "${w}x${h}+0+0" +repage \
    \( -size "${w}x${h}" radial-gradient:"#00000000-#00000040" \) -compose multiply -composite \
    -quality 82 -strip "$file"

  printf '%-44s %s\n' "$path" "$(du -h "$file" | cut -f1 | tr -d ' ')"
done
