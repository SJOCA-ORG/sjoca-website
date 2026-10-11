# Turns the captured Google Sites site into structured content:
#   db/seeds/content.yml  — pages, sections, blocks
#   db/seeds/assets.yml   — image names and where they came from
#
# Two inputs, and both are needed:
#
#   reference/current-site/dom/*.html   what the content IS   (capture.sh)
#   reference/current-site/geometry.json where it SITS        (measure.mjs)
#
# The DOM alone is not enough. Google Sites places grid cells explicitly, so
# document order does not match visual order — on the home page the DOM reads
# as two rows of two, while the page actually renders as two columns with
# stacked items. Layout therefore comes from measured bounding boxes, and the
# DOM is used only to say what each measured box contains.
#
#   bin/rails runner script/extract_current_site.rb
#
# Touches no database; re-run it and diff the YAML.
require "nokogiri"
require "yaml"
require "json"

ROOT     = Rails.root.join("reference/current-site")
OUT_DIR  = Rails.root.join("db/seeds")
GEOMETRY = JSON.parse(File.read(ROOT.join("geometry.json")))

SECTION_STYLE = { "qeLZfd" => "light", "lQAHbd" => "maroon", "tpmmCb" => "plain" }.freeze
HEADING_KIND  = { "duRjpb" => "heading", "JYVBee" => "heading", "OmQG5e" => "subheading" }.freeze

# Readable names for assets worth saying out loud. Everything else gets a
# positional name. Verified by eye against the images, not guessed.
ASSET_OVERRIDES = {
  "home-01" => "home-exterior",
  "home-02" => "home-icon-st-john",
  "home-03" => "home-iconostasis"
}.freeze

def slug_for(file) = File.basename(file, ".html").gsub("--", "/")

# Inline HTML we carry across: links and simple emphasis.
#
#   - Google injects an empty <a href="#h.xxxx"> copy-link anchor into every
#     heading. Chrome, not content; drop it.
#   - Whitespace collapses once, at the top. Collapsing inside the recursion
#     eats the spaces between adjacent <span>s ("Our Mission:To be a...").
def inline_fragment(node)
  node.children.map { |c|
    case c.name
    when "text" then CGI.escapeHTML(c.text)
    when "br"   then "<br>"
    when "a"
      href, inner = c["href"].to_s, inline_fragment(c)
      inner.strip.empty? || href.start_with?("#h.") ? inner
        : %(<a href="#{CGI.escapeHTML(href)}">#{inner}</a>)
    when "b", "strong" then "<strong>#{inline_fragment(c)}</strong>"
    when "i", "em"     then "<em>#{inline_fragment(c)}</em>"
    else                    inline_fragment(c)
    end
  }.join
end

def inline_html(node) = inline_fragment(node).gsub(/[[:space:]]+/, " ").strip
def plain(str) = Nokogiri::HTML.fragment(str.to_s).text.gsub(/[[:space:]]+/, " ").strip

def align_of(node)
  case node["style"].to_s
  when /text-align:\s*center/ then "center"
  when /text-align:\s*right/  then "right"
  else "left"
  end
end

def heading_kind(node)
  cls = node["class"].to_s.split
  HEADING_KIND.find { |k, _| cls.include?(k) }&.last || "heading"
end

# Everything the DOM says about one section, keyed so measured boxes can find it.
def dom_blocks(sec)
  out = []
  sec.css("img.CENy8b, div.w536ob[data-url], h1, h2, h3, h4, p").each do |n|
    next if n.css("h1,h2,h3,h4,p,img.CENy8b").any?   # container, not leaf

    case n.name
    when "img"
      out << { key: n["src"].to_s.gsub("&amp;", "&"),
               block: { "kind" => "image", "align" => "center",
                        "url" => n.ancestors("a").first&.[]("href") },
               alt: n["alt"].to_s }
    when "div"
      url = n["data-url"].to_s.gsub("&amp;", "&")
      out << { key: url, block: { "kind" => "embed", "url" => url, "align" => "center" } }
    else
      html = inline_html(n)
      next if html.empty?
      kind = %w[h1 h2 h3 h4].include?(n.name) ? heading_kind(n) : "text"
      out << { key: plain(html), block: { "kind" => kind, "content" => html, "align" => align_of(n) } }
    end
  end
  out
end

# Measured boxes -> columns. Items whose horizontal spans overlap by more than
# half belong to the same column; columns are then ordered left to right and
# each column's items top to bottom.
def columns_from(items)
  cols = []
  items.sort_by { |i| i["x"] }.each do |item|
    col = cols.find { |c|
      lo = [c[:x0], item["x"]].max
      hi = [c[:x1], item["x"] + item["w"]].min
      (hi - lo) > 0.5 * [item["w"], c[:x1] - c[:x0]].min
    }
    if col
      col[:items] << item
      col[:x0] = [col[:x0], item["x"]].min
      col[:x1] = [col[:x1], item["x"] + item["w"]].max
    else
      cols << { x0: item["x"], x1: item["x"] + item["w"], items: [item] }
    end
  end
  cols.sort_by { |c| c[:x0] }.each { |c| c[:items].sort_by! { |i| i["y"] } }
end

pages, assets = [], []

Dir[ROOT.join("dom/*.html")].sort.each do |file|
  slug = slug_for(file)
  doc  = Nokogiri::HTML(File.read(file))
  main = doc.at_css("div[jsname=ZBtY8b]") or next
  geo  = GEOMETRY[slug] || []

  page     = { "slug" => slug, "sections" => [] }
  img_seen = {}

  main.css("> section").each_with_index do |sec, si|
    cls = sec["class"].to_s.split

    if cls.include?("O13XJf")                                   # hero
      if (bg = sec.at_css(".IFuOkc[style*='background-image']")) &&
         (m = bg["style"].match(/url\(["']?(https:[^"')]+)["']?\)/))
        name = "#{slug.tr('/', '-')}-hero"
        assets << { "human_name" => name, "source_url" => m[1].gsub("&amp;", "&"),
                    "alt_text" => "", "page" => slug }
        page["hero_asset_name"] = name
      end
      heads = sec.css("h1,h2,h3").reject { |h| h.css("h1,h2,h3").any? }
      lines = heads.map { |h| [inline_html(h), h.at_css("[class*=FdCeP]") ? :big : :small] }
                   .reject { |t, _| t.empty? }
      big   = lines.select { |_, s| s == :big }.map(&:first)
      small = lines.select { |_, s| s == :small }.map(&:first)
      big, small = [lines.map(&:first), []] if big.empty?
      page["hero_heading"]    = big.join("<br>").presence
      page["hero_subheading"] = small.join("<br>").presence
      page["hero_size"]       = cls.include?("SBrW1") ? "tall" : "standard"
      next
    end

    lookup = dom_blocks(sec).index_by { |b| b[:key] }
    items  = geo[si]&.dig("items") || []
    cols   = columns_from(items)
    next if cols.empty?

    section = { "style"  => SECTION_STYLE[(cls & SECTION_STYLE.keys).first] || "plain",
                "column_widths" => cols.map { |c| (c[:x1] - c[:x0]).round }.join(","),
                "blocks" => [] }

    cols.each_with_index do |col, ci|
      col[:items].each_with_index do |item, pos|
        key   = (item["src"] || item["text"]).to_s
        found = lookup[key] || lookup[plain(key)] ||
                lookup.values.find { |b| b[:key].start_with?(key[0, 60]) && key.length > 20 }
        next unless found

        blk = found[:block].dup
        if blk["kind"] == "image"
          url  = found[:key]
          name = img_seen[url] ||= begin
            idx = img_seen.size + 1
            positional = format("%s-%02d", slug.tr("/", "-"), idx)
            ASSET_OVERRIDES.fetch(positional, positional)
          end
          assets << { "human_name" => name, "source_url" => url,
                      "alt_text" => found[:alt].to_s, "page" => slug }
          blk["asset_name"] = name
        end
        blk["width"] = item["w"] if item["w"].to_i.positive?
        section["blocks"] << blk.merge("row" => 0, "column" => ci, "position" => pos)
      end
    end

    page["sections"] << section unless section["blocks"].empty?
  end

  pages << page
end

OUT_DIR.mkpath
File.write(OUT_DIR.join("content.yml"), pages.to_yaml)
File.write(OUT_DIR.join("assets.yml"),  assets.uniq { |a| a["human_name"] }.to_yaml)

puts "pages:    #{pages.size}"
puts "sections: #{pages.sum { |p| p['sections'].size }}"
puts "blocks:   #{pages.sum { |p| p['sections'].sum { |s| s['blocks'].size } }}"
puts "assets:   #{assets.uniq { |a| a['human_name'] }.size}"
