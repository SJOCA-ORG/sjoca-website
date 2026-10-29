#!/usr/bin/env bash
# Put a Markdown file on paper.
#
#   script/print_md.sh docs/organizations.md
#   script/print_md.sh notes/domain-candidates.md --columns
#   script/print_md.sh deck/walkthrough.md --landscape --out /tmp
#
# VS Code renders Markdown beautifully with Cmd+Shift+V and then offers no way
# to print it, which is the thing that sends everybody looking for an
# extension. This needs no extension: pandoc turns the Markdown into HTML, and
# Chrome -- already required by the visual checks -- prints the HTML to PDF.
#
#   --columns     two columns. Good for a list to tick through, bad for prose.
#   --landscape   for wide tables, or reading on a laptop screen.
#   --out DIR     where the .pdf and .html go. Default: beside the source.
#   --no-open     do not open the result when it is done.
set -euo pipefail

SOURCE=""
COLUMNS=no
ORIENT=portrait
OUT=""
OPEN=yes

while [ $# -gt 0 ]; do
  case "$1" in
    --columns)   COLUMNS=yes ;;
    --landscape) ORIENT=landscape ;;
    --out)       OUT="${2:-}"; shift ;;
    --no-open)   OPEN=no ;;
    -h|--help)   sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*)          echo "unknown option: $1" >&2; exit 1 ;;
    *)           SOURCE="$1" ;;
  esac
  shift
done

[ -n "$SOURCE" ] || { echo "usage: $(basename "$0") FILE.md [--columns] [--landscape] [--out DIR] [--no-open]" >&2; exit 1; }
[ -f "$SOURCE" ] || { echo "no such file: $SOURCE" >&2; exit 1; }

command -v pandoc >/dev/null || {
  echo "pandoc is not installed. brew install pandoc" >&2; exit 1; }

# The same list the visual checks use, and the same CHROME override. This Mac's
# Chrome.app contains a binary called "Google Chrome Beta", which is not a name
# anything looks for by default.
CHROME="${CHROME:-}"
if [ -z "$CHROME" ]; then
  for candidate in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome Beta" \
    "/Applications/Google Chrome Beta.app/Contents/MacOS/Google Chrome Beta" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    /usr/bin/google-chrome /usr/bin/chromium /usr/bin/chromium-browser
  do
    [ -x "$candidate" ] && CHROME="$candidate" && break
  done
fi
[ -n "$CHROME" ] || { echo "no Chrome found; set CHROME=/path/to/chrome" >&2; exit 1; }

BASE="$(basename "${SOURCE%.*}")"
DIR="${OUT:-$(dirname "$SOURCE")}"
mkdir -p "$DIR"
HTML="$DIR/$BASE.html"
PDF="$DIR/$BASE.pdf"
TITLE="$(grep -m1 '^# ' "$SOURCE" | sed 's/^# *//' || true)"
TITLE="${TITLE:-$BASE}"

# A stylesheet meant for paper rather than for a screen: no dark background to
# waste toner, headings that do not strand themselves at the foot of a page,
# tables that keep their rules, and task-list boxes you can tick with a pen.
CSS_FILE="$(mktemp -t printmd).css"
trap 'rm -f "$CSS_FILE"' EXIT
cat > "$CSS_FILE" <<CSS
@page { size: letter $ORIENT; margin: 14mm; }
body { font: 11pt/1.5 -apple-system, "Segoe UI", system-ui, sans-serif;
       color: #222; max-width: none; margin: 0; }
h1 { font-size: 18pt; margin: 0 0 .4em; }
h2 { font-size: 13pt; margin: 1.2em 0 .35em; border-bottom: 1px solid #ccc;
     padding-bottom: .15em; }
h3 { font-size: 11.5pt; margin: 1em 0 .3em; }
/* A heading alone at the bottom of a page is a heading in the wrong place. */
h1, h2, h3, h4 { break-after: avoid; }
p, li, td { orphans: 2; widows: 2; }
li, tr, pre, blockquote { break-inside: avoid; }
a { color: #222; text-decoration: none; border-bottom: 1px solid #bbb; }
code { font: 10pt/1.4 ui-monospace, SFMono-Regular, Menlo, monospace;
       background: #F4F4F4; padding: .05em .3em; border-radius: 3px; }
pre { background: #F4F4F4; padding: .7em .9em; border-radius: 4px;
      overflow-wrap: break-word; white-space: pre-wrap; }
pre code { background: none; padding: 0; }
blockquote { margin: .8em 0; padding-left: .9em; border-left: 3px solid #ccc;
             color: #444; }
table { border-collapse: collapse; width: 100%; margin: .6em 0; font-size: 10pt; }
th, td { border: 1px solid #ccc; padding: .3em .5em; text-align: left;
         vertical-align: top; }
th { background: #F4F4F4; }
img { max-width: 100%; }
/* pandoc writes a real <input type=checkbox> for "- [ ]". Chrome does not
   reliably PAINT a form control inside a multi-column flow -- with --columns,
   every box in the first column simply did not appear, while the HTML had all
   thirty-six of them. So the box is drawn as ordinary inline content, which
   paints anywhere, and the input is hidden. */
ul.task-list { list-style: none; padding-left: 0; }
ul.task-list li { padding: .18em 0; }
ul.task-list input[type=checkbox] { display: none; }
ul.task-list li::before { content: ""; display: inline-block;
  width: .78em; height: .78em; border: 1px solid #555; border-radius: 2px;
  margin-right: .5em; vertical-align: -1px; }
ul.task-list li:has(input:checked)::before { content: "x"; font-weight: 700;
  line-height: .72em; text-align: center; font-size: .9em; }

/* pandoc's --standalone emits the metadata title as a visible <h1> as well as
   putting it in <title>, so a document that begins with its own "# Heading"
   prints that heading twice. The tab and the PDF still get the title. */
header#title-block-header { display: none; }
CSS

if [ "$COLUMNS" = yes ]; then
  cat >> "$CSS_FILE" <<'CSS'
body > h1, body > p:first-of-type { column-span: all; }
body { column-count: 2; column-gap: 10mm; }
CSS
fi

pandoc "$SOURCE" --standalone --embed-resources \
       --metadata title="$TITLE" --css "$CSS_FILE" \
       --from gfm --to html5 --output "$HTML"

"$CHROME" --headless --disable-gpu --no-pdf-header-footer \
          --print-to-pdf="$PDF" "file://$(cd "$(dirname "$PDF")" && pwd)/$(basename "$HTML")" \
          >/dev/null 2>&1

printf '%s  (%s)\n%s  (%s)\n' \
  "$PDF"  "$(du -h "$PDF"  | cut -f1 | tr -d ' ')" \
  "$HTML" "$(du -h "$HTML" | cut -f1 | tr -d ' ')"

[ "$OPEN" = yes ] && command -v open >/dev/null && open "$PDF"
exit 0
