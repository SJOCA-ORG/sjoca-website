require "open3"
module Admin
  # The AI's entire reach into the site.
  #
  # Every tool writes rows in ONE revision and nothing else. There is no shell,
  # no filesystem, no eval, and no way to add a *type* -- only new records of
  # types that already exist. The AI cannot write code because nothing here
  # does. This file is the security boundary; widening it is a code review.
  class Tools
    class ToolError < StandardError; end

    def initialize(revision)
      raise ToolError, "revision #{revision.id} is not a draft" unless revision.editable?

      @revision = revision
      @touched  = Set.new
    end

    attr_reader :revision, :touched

    # ---- schema handed to the model ---------------------------------------

    def self.definitions
      [
        tool("list_pages", "List every page, with its sections and how many blocks each holds.", {}),
        tool("get_page", "The full contents of one page: every section, column and block, with ids.",
             { slug: str("Page slug, e.g. \"giving\" or \"about-us/choir\"") }, %w[slug]),
        tool("update_block", "Change an existing block's text, alignment or width.",
             { id: int("Block id"), content: str("New text. Inline HTML links are allowed."),
               align: str("left, center or right"), width: int("Max width in px, images only"),
               css_class: str("A style name for THIS block alone, e.g. \"lead\" — then write a " \
                              "CSS rule for it. Use this rather than inventing a block kind for a one-off.") },
             %w[id]),
        tool("add_block", "Add a block to a section.",
             { section_id: int("Section id"),
               kind: str("heading, subheading, text, image, button, list, quote, embed, calendar, upcoming, classes or lectionary"),
               content: str("Text, or one item per line for a list"),
               asset_name: str("Photo name, for image blocks"),
               asset_version: int("Which version of that photo. Required with asset_name — " \
                                  "a name alone resolves to nothing. list_photos shows them."),
               url: str("Link target, for button, image or embed blocks"),
               column: int("Column index, 0-based"), position: int("Order within the column"),
               align: str("left, center or right"),
               css_class: str("A style name for this block alone") },
             %w[section_id kind]),
        tool("move_block", "Move a block to a different column or position, or to another section.",
             { id: int("Block id"), section_id: int("Target section, if moving between sections"),
               column: int("Column index"), position: int("Order within the column") }, %w[id]),
        tool("delete_block", "Remove a block.", { id: int("Block id") }, %w[id]),
        tool("add_section", "Add a horizontal band to a page.",
             { page_slug: str("Page slug"), style: str("plain, light or maroon"),
               position: int("Order on the page"), column_widths: str("e.g. \"2,1\"") },
             %w[page_slug]),
        tool("update_section", "Change a band's style or column proportions.",
             { id: int("Section id"), style: str("plain, light or maroon"),
               column_widths: str("e.g. \"2,1\"") }, %w[id]),
        tool("delete_section", "Remove a band and everything in it.", { id: int("Section id") }, %w[id]),
        tool("update_page", "Change a page's titles or hero.",
             { slug: str("Page slug"), title: str("Browser title"), nav_title: str("Navigation label"),
               hero_heading: str("Large heading over the hero image"),
               hero_subheading: str("Smaller line under it"),
               hero_asset_name: str("Photo name for the hero"),
               hero_asset_version: int("Which version of it"),
               hero_size: str("standard or tall"), position: int("Order in the navigation"),
               show_in_nav: { type: "boolean", description: "Whether it appears in the menu" },
               parent_slug: str("Slug of the page this sits under in the menu, or empty for top level"),
               self_nav_title: str("Label this page takes as the FIRST item in its own submenu, " \
                                   "so a visitor can tell the parent has a page of its own") },
             %w[slug]),
        tool("delete_page", "Remove a page and everything on it. Existing links to it will 404.",
             { slug: str("Page slug") }, %w[slug]),
        tool("move_section", "Move a band to a different page, or to a different position.",
             { id: int("Section id"), page_slug: str("Target page, if moving between pages"),
               position: int("Order on the page") }, %w[id]),
        tool("add_page", "Create a page. It renders immediately at /slug.",
             { slug: str("Path, e.g. \"about-us/our-icons\""), title: str("Browser title"),
               nav_title: str("Navigation label"), parent_slug: str("Parent page slug, for submenus"),
               position: int("Order in the navigation") },
             %w[slug title nav_title]),
        tool("view_page",
             "The rendered HTML of a page as it will actually appear. USE THIS after " \
             "changing a template or adding blocks — it is the only way to see whether " \
             "what you wrote produced anything.",
             { slug: str("Page slug"),
               find: str("Optional: only return the parts matching this, e.g. \"calendar\"") },
             %w[slug]),
        tool("check_appearance",
             "Open the page in a real browser at phone width AND desktop width, and report " \
             "what is visibly wrong — content running off the side, a menu taller than the " \
             "screen, things overlapping. This is the only check that sees LAYOUT; check_page " \
             "only reads the markup. On a phone the menu is opened before looking, because " \
             "a closed menu hides its own faults.",
             { slug: str("Page slug"),
               click: str("Optional CSS selector to click before looking — an accordion, a " \
                          "\"read more\", anything that only misbehaves once opened") },
             %w[slug]),
        tool("check_page",
             "Look for problems on a page: template errors, elements that rendered empty, " \
             "images that point at nothing, links going nowhere.",
             { slug: str("Page slug") }, %w[slug]),
        tool("list_photos",
             "Every photograph, with its versions. A reference is a PAIR — name and " \
             "version — so a page says exactly which picture it shows and a rollback " \
             "restores it. A name on its own renders nothing.", {}),
        tool("find_photos",
             "Search the photographs by what is IN them, not by filename. The library is " \
             "named positionally (about-us-leadership-01), so a filename tells you nothing " \
             "about the subject. Ask for what you want a picture of in plain words.",
             { looking_for: str("What you want a picture of, e.g. the choir singing, " \
                                "a priest vested in purple, the church exterior") },
             %w[looking_for]),
        tool("repoint_photo",
             "Point every reference to a photograph at a particular version — how a " \
             "picture is replaced across the site, or an old one brought back.",
             { name: str("Photo name"), version: int("Which version to use") },
             %w[name version]),
        tool("get_styles",
             "The site's complete stylesheet — about 26KB. Usually too large to work with; " \
             "prefer find_styles.", {}),
        tool("add_styles",
             "Add CSS rules to the end of the stylesheet. This is how to style something: " \
             "it sends only what you are adding. PREFER THIS over set_styles.",
             { css: str("The rules to add"),
               note: str("A short comment saying what these are for, e.g. \"Giving page heading\"") },
             %w[css]),
        tool("edit_styles",
             "Change one part of the stylesheet by replacing an exact snippet. Read the " \
             "relevant part with find_styles first. Sends only the part that changes.",
             { find: str("The exact existing text to replace"),
               replace: str("What to put in its place") }, %w[find replace]),
        tool("find_styles",
             "Search the stylesheet and return the matching rules with their line numbers. " \
             "Use this instead of get_styles, which returns 26KB.",
             { pattern: str("A selector or word to look for, e.g. \"site-nav\" or \"--maroon\"") },
             %w[pattern]),
        tool("set_styles",
             "Replace the ENTIRE stylesheet. Rarely the right tool — it is about 26KB, which " \
             "will not fit in one reply. Use add_styles or edit_styles instead.",
             { css: str("The complete stylesheet") }, %w[css]),
        tool("add_script",
             "Add JavaScript to the site. Runs on every page, after the document is parsed " \
             "(the tag is deferred), so no DOMContentLoaded wrapper is needed. This is how to " \
             "do anything the templates and stylesheet cannot: read data out of the page, " \
             "reformat it, sort it, filter it, respond to a click.",
             { js: str("The JavaScript to add"),
               note: str("A short comment saying what it is for, e.g. \"format the calendar\"") },
             %w[js]),
        tool("edit_script",
             "Change one part of the JavaScript by replacing an exact snippet. Read it with " \
             "find_script first.",
             { find: str("The exact existing text to replace"),
               replace: str("What to put in its place") }, %w[find replace]),
        tool("find_script",
             "Read the site's JavaScript. With no pattern it returns the whole thing when it " \
             "is small; with one it returns the matching lines and their surroundings.",
             { pattern: str("Optional: a word or function name to look for") }, []),

        # --- data from outside this site --------------------------------------
        tool("list_data_sources",
             "The outside data this site pulls in — a calendar feed, a playlist, a readings " \
             "page — with the exact Liquid and JavaScript needed to use each one.", {}),
        tool("add_data_source",
             "Set up an address for the server to fetch, cache, and hand to the page as JSON. " \
             "This is how the site shows anything that lives somewhere else. The server does " \
             "the fetching because a browser cannot: most sites refuse a request from another " \
             "site. Give several addresses to treat them as one source (a date range, say). " \
             "Then put {{ site.data.<name>.json_tag }} in a template and read it in your " \
             "script with JSON.parse(document.getElementById(\"data-<name>\").textContent). " \
             "Only https, and the address must be a public one.",
             { name: str("A short name, lower case with hyphens, e.g. \"calendar\". It becomes " \
                         "the id of the element in the page."),
               urls: { type: "array", items: { type: "string" },
                       description: "One or more https addresses to fetch" },
               refresh_minutes: { type: "integer",
                                  description: "How old the cached copy may get before it is " \
                                               "fetched again. 5 at the least; 60 is sensible " \
                                               "for a calendar." },
               note: str("What this is, in a few words") },
             %w[name urls]),
        tool("peek_data",
             "Look at what a data source actually returned: its type, its size, the names of " \
             "its fields and a short sample. Call this BEFORE writing JavaScript to read it — " \
             "guessing the shape of someone else's feed wastes a turn. For anything that is " \
             "not JSON you only get the first part, so use `find` to search the whole thing. " \
             "That is also how to work out where a page gets ITS data: fetch the page and " \
             "search it for the address it calls.",
             { name: str("The data source name"),
               path: str("Optional: dig into the structure of JSON, e.g. \"items.0.title\""),
               find: str("Optional: search the whole body for this text and show what " \
                         "surrounds each match — e.g. \"eventSources\", \".json\", \"api\"") },
             %w[name]),
        tool("remove_data_source",
             "Stop pulling in an outside data source. Anything in a template or script that " \
             "used it will stop working, so check first.",
             { name: str("The data source name") }, %w[name]),

        # --- templates: how things look, as opposed to what they say ---------
        tool("liquid_guide",
             "READ THIS BEFORE WRITING ANY LIQUID. Everything a template can see — every " \
             "object and property available — plus the rules of this Liquid dialect. " \
             "Generated from the code, so it is never out of date.", {}),
        tool("list_templates", "Every Liquid template, by name.", {}),
        tool("get_template", "The source of one Liquid template.",
             { name: str("e.g. \"block/heading\", \"header\", \"page\"") }, %w[name]),
        tool("set_template", "Replace a Liquid template's source. This changes how that thing renders everywhere.",
             { name: str("Template name"), source: str("The complete Liquid source") },
             %w[name source]),
        tool("add_template",
             "Create a new Liquid template. Naming it block/<something> creates a new " \
             "kind of block, usable immediately with add_block — no developer needed.",
             { name: str("New template name, e.g. \"block/scripture\" or \"partial/card\""),
               source: str("The complete Liquid source") }, %w[name source]),

        # --- scripts ----------------------------------------------------------
        tool("get_scripts", "The site's current custom JavaScript.", {}),
        tool("set_scripts",
             "Replace the ENTIRE JavaScript file. Rarely the right tool: once the file is a " \
             "few hundred lines it will not fit in one reply, and the attempt fails silently " \
             "by being cut short. Use add_script or edit_script instead.",
             { js: str("The complete JavaScript to use") }, %w[js]),

        # --- what you have worked out -----------------------------------------
        tool("list_promises",
             "The site's standing promises — things that should stay true after any change, " \
             "with what each one is for.", {}),
        tool("add_promise",
             "Record something that should stay true from now on. Use this when a change " \
             "establishes a REQUIREMENT, not a preference: 'the home page shows the service " \
             "times' is a promise; 'the heading reads Financially Support' is not, because " \
             "rewording it is legitimate. The script is JavaScript run in the rendered page, " \
             "returning { pass, message }. It is checked before being saved.",
             { summary: str("One short line, shown to whoever approves"),
               intent: str("The full reasoning: what this is for and why it matters. You will " \
                           "read this later when judging whether a failure means the site is " \
                           "wrong or the promise is."),
               script: str("JavaScript returning { pass: boolean, message: string }"),
               page_slug: str("Which page, or leave empty for every page"),
               proof: str("What would make this fail. If you cannot show it failing, say here " \
                          "what would — a promise that cannot fail is worse than none.") },
             %w[summary intent script]),
        tool("remove_promise",
             "Stop checking a promise. Only after agreeing it with the person you are talking " \
             "to — never on your own judgement.",
             { id: int("Promise id"), because: str("Why it no longer applies, in their words") },
             %w[id because]),
        tool("check_promises",
             "Run the standing promises and report which are kept and which are broken.",
             { slug: str("Optional: just this page") }),
        tool("record_lesson",
             "Write down something you worked out that would otherwise have to be worked " \
             "out again — a Liquid construct that behaved unexpectedly, a convention of " \
             "this site, a trap. It is handed back to you by liquid_guide in every future " \
             "session. Record facts you verified, not guesses.",
             { subject: str("liquid, styles, photos, content or house-style"),
               lesson: str("One or two sentences, specific enough to act on") },
             %w[subject lesson]),

        # --- photographs ------------------------------------------------------
        tool("describe_photo", "A photograph's dimensions, format and size.",
             { name: str("Photo name") }, %w[name]),
        tool("crop_photo", "Crop a photograph. Saves the result as a NEW photograph; the original is untouched.",
             { name: str("Photo to crop"), x: int("Left edge"), y: int("Top edge"),
               width: int("Width in px"), height: int("Height in px"),
               as: str("Name for the result") },
             %w[name x y width height as]),
        tool("resize_photo", "Resize a photograph, keeping its proportions. Saves a NEW photograph.",
             { name: str("Photo to resize"), width: int("Target width in px"),
               height: int("Target height in px"), as: str("Name for the result") },
             %w[name as]),
        tool("rotate_photo", "Rotate a photograph. Saves a NEW photograph.",
             { name: str("Photo"), degrees: int("Degrees clockwise"), as: str("Name for the result") },
             %w[name degrees as]),
        tool("trim_photo", "Trim blank or uniform edges off a photograph. Saves a NEW photograph.",
             { name: str("Photo"), as: str("Name for the result") }, %w[name as]),
        tool("adjust_photo", "Adjust brightness, saturation or hue. 100 means unchanged. Saves a NEW photograph.",
             { name: str("Photo"), brightness: int("Percent, 100 = unchanged"),
               saturation: int("Percent, 100 = unchanged"), hue: int("Percent, 100 = unchanged"),
               as: str("Name for the result") }, %w[name as]),
        tool("grayscale_photo", "Convert a photograph to black and white. Saves a NEW photograph.",
             { name: str("Photo"), as: str("Name for the result") }, %w[name as]),
        tool("feather_photo", "Soften a photograph's edges into a vignette, so it sits on the page without a hard border. Saves a NEW photograph.",
             { name: str("Photo"), radius: int("Softness in px, 1-200"), as: str("Name for the result") },
             %w[name as]),
        tool("round_photo_corners", "Round a photograph's corners. Saves a NEW photograph.",
             { name: str("Photo"), radius: int("Corner radius in px"), as: str("Name for the result") },
             %w[name as]),
        tool("convert_photo", "Convert a photograph to another format (png, jpg, webp, gif). Saves a NEW photograph.",
             { name: str("Photo"), format: str("png, jpg, webp or gif"), as: str("Name for the result") },
             %w[name format as]),
        tool("combine_photos", "Place one photograph over another. Saves a NEW photograph.",
             { base: str("Photo underneath"), overlay: str("Photo on top"),
               gravity: str("center, north, south, east, west, or a corner"),
               as: str("Name for the result") }, %w[base overlay as])
      ]
    end

    def self.tool(name, description, props, required = [])
      { name: name, description: description,
        input_schema: { type: "object", properties: props, required: required } }
    end
    def self.str(d) = { type: "string",  description: d }
    def self.int(d) = { type: "integer", description: d }
    private_class_method :tool, :str, :int

    # ---- dispatch ----------------------------------------------------------

    # Only a DECLARED tool may be called. respond_to?(name, true) was enough to
    # reach any private method on this class -- write_css, touched_everything!,
    # the lot -- which made the tool list a suggestion rather than the boundary
    # it is supposed to be.
    def self.names = @names ||= definitions.map { |d| d[:name] }.to_set

    def call(name, args)
      args = (args || {}).symbolize_keys
      raise ToolError, "unknown tool #{name}" unless self.class.names.include?(name.to_s)

      send(name, **args)
    rescue ArgumentError => e
      # A missing or mistyped argument must come back as something the model can
      # read and retry, not an exception that ends the turn. It called set_styles
      # with no css and the whole conversation died.
      raise ToolError, "#{name}: #{e.message}. Check the tool's required arguments."
    end

    private

    def pages    = revision.pages
    def sections = revision.sections
    def blocks   = revision.blocks

    # Note the page every change lands on, so the loop knows what to re-check.
    def find_block(id)
      b = blocks.find_by(id: id) || raise(ToolError, "no block #{id} in this revision")
      @touched << b.section.page.slug
      b
    end

    def find_section(id)
      s = sections.find_by(id: id) || raise(ToolError, "no section #{id} in this revision")
      @touched << s.page.slug
      s
    end

    def find_page(slug)
      p = pages.find_by(slug: slug) || raise(ToolError, "no page #{slug.inspect}")
      @touched << p.slug
      p
    end

    # A template or stylesheet change affects everything, so everything is
    # suspect -- but checking 13 pages every turn is wasteful. Check a sample.
    def touched_everything! = @touched.merge(pages.order(:position).limit(3).pluck(:slug))

    def list_pages(**)
      { pages: pages.order(:position).map { |p|
          { slug: p.slug, nav_title: p.nav_title, in_nav: p.show_in_nav,
            parent: p.parent_slug, sections: p.sections.count, blocks: p.sections.sum { |s| s.blocks.count } } } }
    end

    def get_page(slug:, **)
      page = find_page(slug)
      { slug: page.slug, title: page.title, nav_title: page.nav_title,
        hero: { heading: page.hero_heading, subheading: page.hero_subheading,
                photo: page.hero_asset_name, size: page.hero_size },
        sections: page.sections.order(:position).map { |s|
          { id: s.id, style: s.style, column_widths: s.column_widths,
            blocks: s.blocks.order(:column, :position).map { |b|
              { id: b.id, kind: b.kind, column: b.column, position: b.position,
                align: b.align, width: b.width, photo: b.asset_name, url: b.url,
                content: b.content&.truncate(400) } } } } }
    end

    def update_block(id:, **attrs)
      b = find_block(id)
      b.update!(attrs.slice(:content, :align, :width, :url, :asset_name,
                            :asset_version, :css_class).compact)
      ok "updated #{b.kind} block #{b.id}", block: id
    end

    def add_block(section_id:, kind:, **attrs)
      s = find_section(section_id)
      position = attrs[:position] || (s.blocks.where(column: attrs[:column] || 0).maximum(:position).to_i + 1)
      b = s.blocks.create!(revision: revision, kind: kind, position: position,
                           column: attrs[:column] || 0,
                           **attrs.slice(:content, :asset_name, :asset_version, :url,
                                         :align, :width, :css_class).compact)
      ok "added a #{kind} block to section #{s.id}", block: b.id
    end

    def move_block(id:, **attrs)
      b = find_block(id)
      b.section = find_section(attrs[:section_id]) if attrs[:section_id]
      b.update!(attrs.slice(:column, :position).compact)
      ok "moved block #{b.id}", block: b.id
    end

    def delete_block(id:, **)
      b = find_block(id)
      kind = b.kind
      b.destroy!
      ok "deleted the #{kind} block #{id}"
    end

    def add_section(page_slug:, **attrs)
      page = find_page(page_slug)
      position = attrs[:position] || (page.sections.maximum(:position).to_i + 1)
      s = page.sections.create!(revision: revision, position: position,
                                style: attrs[:style] || "plain",
                                column_widths: attrs[:column_widths])
      ok "added a #{s.style} band to #{page_slug}", section: s.id
    end

    def update_section(id:, **attrs)
      s = find_section(id)
      s.update!(attrs.slice(:style, :column_widths, :position).compact)
      ok "updated section #{s.id}"
    end

    def delete_section(id:, **)
      s = find_section(id)
      n = s.blocks.count
      s.destroy!
      ok "deleted section #{id} and its #{n} blocks"
    end

    def update_page(slug:, **attrs)
      p = find_page(slug)
      # parent_slug and self_nav_title are deliberately not .compact-ed: setting
      # either to empty is how a page is moved back to the top level.
      permitted = attrs.slice(:title, :nav_title, :hero_heading, :hero_subheading,
                              :hero_asset_name, :hero_asset_version, :hero_size,
                              :position, :show_in_nav).compact
      permitted[:parent_slug]    = attrs[:parent_slug].presence    if attrs.key?(:parent_slug)
      permitted[:self_nav_title] = attrs[:self_nav_title].presence if attrs.key?(:self_nav_title)

      if permitted[:parent_slug].present? && !pages.exists?(slug: permitted[:parent_slug])
        raise ToolError, "there is no page #{permitted[:parent_slug].inspect} to sit under"
      end

      p.update!(permitted)
      ok "updated the #{slug} page"
    end

    def delete_page(slug:, **)
      page = find_page(slug)
      children = pages.where(parent_slug: slug).pluck(:slug)
      raise ToolError, "#{slug} has pages under it (#{children.join(', ')}). Move or remove those first." if children.any?

      n = page.sections.sum { |s| s.blocks.count }
      page.destroy!
      ok "deleted the page /#{slug} and the #{n} blocks on it"
    end

    def move_section(id:, **attrs)
      s = find_section(id)
      s.page = find_page(attrs[:page_slug]) if attrs[:page_slug].present?
      s.position = attrs[:position] if attrs[:position]
      s.save!
      ok "moved section #{s.id}#{attrs[:page_slug].present? ? " to /#{attrs[:page_slug]}" : ""}"
    end

    def add_page(slug:, title:, nav_title:, **attrs)
      p = pages.create!(slug: slug, title: title, nav_title: nav_title,
                        parent_slug: attrs[:parent_slug],
                        position: attrs[:position] || (pages.maximum(:position).to_i + 1))
      ok "created the page /#{p.slug}"
    end

    def view_page(slug:, find: nil, **)
      page = find_page(slug)
      html = render_page(page)

      if find.present?
        lines = html.lines.each_with_index
                    .select { |l, _| l.downcase.include?(find.to_s.downcase) }
        return { slug: slug, matching: find,
                 html: lines.first(40).map { |l, i| "#{i + 1}: #{l.rstrip}" }.join("\n") }
      end

      { slug: slug, html: html.truncate(12_000),
        truncated: html.length > 12_000, length: html.length }
    end

    # The checks a person would do by looking, done by reading the markup. Not a
    # substitute for seeing it at phone width -- that needs a browser -- but it
    # catches the whole class of "it rendered nothing and said nothing".
    def check_page(slug:, **)
      page = find_page(slug)
      problems = []

      begin
        html = render_page(page)
      rescue Site::Renderer::Error => e
        return { slug: slug, ok: false, suggestions: [],
                 problems: ["the page does not render: #{e.message}"] }
      end

      doc = Nokogiri::HTML5.fragment(html)
      suggestions = []

      doc.css("[class*=__]").each do |node|
        next unless node.children.empty? && node.text.strip.empty?
        next if %w[img br hr input iframe].include?(node.name)

        problems << "<#{node.name} class=\"#{node['class']}\"> rendered empty — " \
                    "usually a property that does not exist on the drop"
      end

      doc.css("img").each do |img|
        problems << "an image has no src" if img["src"].blank?
        # Accessibility, not breakage. Kept separate or it drowns out the things
        # that are actually wrong -- which is how a checker gets ignored.
        suggestions << "#{img['src']} has no alt text for screen readers" if img["alt"].blank?
      end

      doc.css("a").each do |a|
        problems << "a link has no href" if a["href"].blank?
      end

      # A reference is a pair. Half a reference resolves to nothing and renders
      # nothing, with no error anywhere -- the photograph simply is not there.
      page.sections.flat_map(&:blocks).select { |b| b.asset_name.present? }.each do |b|
        next if b.asset
        problems << if b.asset_version.blank?
                      "block #{b.id} names the photograph #{b.asset_name.inspect} but no version, " \
                      "so nothing renders. Pin it with update_block asset_version:"
                    else
                      "block #{b.id} points at #{b.asset_name}@#{b.asset_version}, which does not exist"
                    end
      end
      if page.hero_asset_name.present? && page.hero_asset.nil?
        problems << "the hero names #{page.hero_asset_name.inspect} but it does not resolve"
      end

      blocks = page.sections.sum { |s| s.blocks.count }
      problems << "the page has #{blocks} blocks but rendered almost nothing" if blocks.positive? && html.length < 200

      { slug: slug, blocks: blocks, rendered_bytes: html.length,
        problems: problems.uniq.first(25),
        suggestions: suggestions.uniq.first(10),
        ok: problems.empty? }
    end

    # The markup checks cannot see layout. This opens the draft in a real
    # browser -- the same code, and the same CDP protocol, that runs in a
    # container; only the path to the binary differs.
    # The findings below are measurements -- sideways scroll, unreachable menu
    # items, overlap. They cannot say "that box belongs in the right-hand column
    # rather than at the bottom of the page", because nothing is broken by any
    # measure; it simply looks wrong. So this also returns the screenshots, and
    # the editor attaches them to the reply as images. Judging a layout from a
    # list of findings is what put the upcoming-events box in the footer.
    def check_appearance(slug:, click: nil, **)
      page = find_page(slug)
      base = ENV.fetch("SITE_URL", "http://localhost:3000")
      token = revision.preview_token
      url = "#{base}/#{page.slug == 'home' ? '' : page.slug}?preview=#{token}"

      # A directory of its own per call: the script names shots by width, so two
      # checks sharing a directory would overwrite each other's pictures.
      shot_dir = Rails.root.join("tmp/shots", SecureRandom.hex(4)).to_s
      args = ["node", Rails.root.join("script/visual_check.mjs").to_s, url, "--shots"]
      args << "--click=#{click}" if click.present?
      out, err, status = Open3.capture3({ "SHOT_DIR" => shot_dir }, *args)
      return { slug: slug, error: "could not run the browser check: #{err.lines.first}" } unless status.success?

      data = JSON.parse(out) rescue nil
      return { slug: slug, error: "the browser check returned nothing usable" } if data.nil?
      return { slug: slug, error: data["error"] } if data["error"]

      findings = data["widths"].flat_map { |w, v|
        (v["findings"] || []).map { |f| f.merge("width" => w) }
      }
      { slug: slug,
        ok: findings.none? { |f| f["severity"] == "broken" },
        findings: findings,
        checked: data["widths"].keys,
        # Paths, not bytes. The editor reads them and builds the image blocks, so
        # nothing here is large enough to bloat the message log it is recorded in.
        screenshots: data["widths"].filter_map { |w, v| { "width" => w, "path" => v["screenshot"] } if v["screenshot"] } }
    end

    # Screenshots are tall -- a whole page, not a viewport -- and the API
    # downscales anything over 1568px on its long edge anyway. So fit them to
    # exactly that box: one predictable resize instead of ours followed by
    # theirs, and no wasted tokens on detail that gets thrown away.
    #
    # The first attempt here used a 900x2400 box, which was wrong in a way worth
    # recording: for a tall page the HEIGHT binds, so the phone shot came out
    # NARROWER than the 390px it was taken at. Constrain the square, not a
    # shape, or a long page collapses into an unreadable sliver.
    #
    # Text is not legible at this size and does not need to be. The question put
    # to these pictures is where things sit on the page.
    SHOT_FIT = "1568x1568>"

    def self.screenshot_blocks(screenshots)
      Array(screenshots).filter_map do |shot|
        path = shot["path"] || shot[:path]
        next unless path && File.exist?(path)

        bytes = ImageTools.fit(path, SHOT_FIT)
        next if bytes.blank?

        [{ type: "text", text: "Screenshot of the page at #{shot['width'] || shot[:width]} width:" },
         Anthropic::Client.image_block(bytes, "image/png")]
      rescue StandardError => e
        Rails.logger.warn("could not prepare screenshot #{path}: #{e.message}")
        nil
      end.flatten
    end

    def render_page(page)
      Current.revision = revision
      Site::PageRenderer.new(revision).body(page).to_s
    end

    # The library is named positionally, so a filename says nothing about what is
    # in the picture. Descriptions are what make it findable -- see
    # lib/tasks/photos.rake, which writes them by looking at each photograph.
    def find_photos(looking_for:, **)
      words = looking_for.to_s.downcase.scan(/[a-z]{3,}/) -
              %w[the and for with photo picture image shows showing some any]
      return { matches: [], note: "say what you are looking for in a few words" } if words.empty?

      described = Photo.published.where.not(alt_text: [nil, ""])
                       .select(:human_name, :version, :alt_text).to_a
      haystacks = described.to_h { |p| [p, "#{p.human_name.tr('-', ' ')} #{p.alt_text}".downcase] }

      # Weight by rarity. Counting plain matches rewards the common words:
      # "a priest in purple vestments" scored every priest photograph equally and
      # ignored "purple", which was the only word that mattered.
      rarity = words.to_h do |w|
        seen = haystacks.count { |_, text| text.include?(w) }
        [w, seen.zero? ? 0.0 : Math.log((haystacks.size + 1).to_f / seen)]
      end

      scored = haystacks.filter_map do |photo, text|
        hit = words.select { |w| text.include?(w) }
        next if hit.empty?

        [hit.sum { |w| rarity[w] }, hit, photo]
      end

      best = scored.sort_by { |score, _, p| [-score, p.human_name] }
                   .uniq { |_, _, p| p.human_name }
                   .first(8)

      { matches: best.map { |score, hit, p|
          { name: p.human_name, version: p.version,
            matched: hit.join(", "), score: score.round(2),
            shows: p.alt_text.to_s.truncate(170) } },
        searched: described.map(&:human_name).uniq.size }
    end

    def list_photos(**)
      { photos: Photo.published.order(:human_name, version: :desc)
                     .group_by(&:human_name)
                     .map { |name, rows|
                       { name: name,
                         versions: rows.map(&:version),
                         newest: rows.first.version,
                         shows: rows.first.alt_text.presence&.truncate(120),
                         note: rows.size > 1 ? "#{rows.size} versions — point at whichever you want" : nil
                       }.compact },
        reminder: "A reference is a PAIR: asset_name AND asset_version. A name alone renders nothing." }
    end

    # Replacing a photograph everywhere is a real operation now, not invisible
    # magic. It appears in the change log as the edits it actually is.
    def repoint_photo(name:, version:, **)
      photo = Photo.find_version(name, version) or
        raise ToolError, "there is no #{name} at version #{version}. " \
                         "Versions: #{Photo.versions_of(name).pluck(:version).join(', ')}"

      changed = blocks.where(asset_name: name).where.not(asset_version: version)
      heroes  = pages.where(hero_asset_name: name).where.not(hero_asset_version: version)
      n = changed.count + heroes.count
      changed.update_all(asset_version: version)
      heroes.update_all(hero_asset_version: version)
      touched_everything!

      ok "pointed #{n} #{'reference'.pluralize(n)} to #{name} at version #{version}"
    end

    def get_styles(**)
      { css: ThemeAsset.css_for(revision) }
    end

    def add_styles(css:, note: nil, **)
      current = ThemeAsset.css_for(revision)
      heading = note.present? ? "\n\n/* #{note.to_s.gsub(%r{[*/]}, '')} */\n" : "\n\n"
      write_css(current + heading + css.to_s.strip + "\n")
      touched_everything!
      ok "added #{css.to_s.lines.count} lines of CSS#{note.present? ? " for #{note}" : ''}"
    end

    def edit_styles(find:, replace:, **)
      current = ThemeAsset.css_for(revision)
      count = current.scan(find.to_s).size
      raise ToolError, "that text is not in the stylesheet. Use find_styles to see what is there." if count.zero?
      raise ToolError, "that text appears #{count} times; include enough surrounding text to be unique." if count > 1

      write_css(current.sub(find.to_s, replace.to_s))
      touched_everything!
      ok "changed #{find.to_s.truncate(50).inspect} in the stylesheet"
    end

    def find_styles(pattern:, **)
      lines = ThemeAsset.css_for(revision).lines
      hits = lines.each_with_index.select { |l, _| l.downcase.include?(pattern.to_s.downcase) }
      return { matches: [], note: "nothing matching #{pattern.inspect}" } if hits.empty?

      { matches: hits.first(40).map { |line, i|
          { line: i + 1, text: line.rstrip,
            context: lines[[i - 1, 0].max..(i + 3)].join.rstrip } } }
    end

    def write_css(css)
      a = revision.theme_assets.find_or_initialize_by(name: ThemeAsset::KINDS.fetch("css"))
      a.update!(content: css)
    end

    # ---- JavaScript --------------------------------------------------------
    #
    # Same three-tool shape as the stylesheet, and for the same reason: sending
    # the whole file back on every change does not fit in one reply.
    #
    # site.js is served by ThemeController and linked from the layout with
    # `defer`, so it runs after the document is parsed and does not need a
    # DOMContentLoaded wrapper.

    def add_script(js:, note: nil, **)
      current = ThemeAsset.js_for(revision)
      heading = note.present? ? "\n\n// #{note.to_s.delete("\n")}\n" : "\n\n"
      write_js((current.presence || SCRIPT_HEADER) + heading + js.to_s.strip + "\n")
      touched_everything!
      ok "added #{js.to_s.lines.count} lines of JavaScript#{note.present? ? " for #{note}" : ''}"
    end

    def edit_script(find:, replace:, **)
      current = ThemeAsset.js_for(revision)
      raise ToolError, "there is no JavaScript yet. Use add_script." if current.blank?

      count = current.scan(find.to_s).size
      raise ToolError, "that text is not in the script. Use find_script to see what is there." if count.zero?
      raise ToolError, "that text appears #{count} times; include enough surrounding text to be unique." if count > 1

      write_js(current.sub(find.to_s, replace.to_s))
      touched_everything!
      ok "changed #{find.to_s.truncate(50).inspect} in the script"
    end

    def find_script(pattern: nil, **)
      js = ThemeAsset.js_for(revision)
      return { matches: [], note: "there is no JavaScript on this site yet" } if js.blank?

      lines = js.lines
      return { lines: lines.size, script: js } if pattern.blank? && js.bytesize < 4000

      hits = lines.each_with_index.select { |l, _| l.downcase.include?(pattern.to_s.downcase) }
      return { matches: [], note: "nothing matching #{pattern.inspect}", lines: lines.size } if hits.empty?

      { matches: hits.first(40).map { |line, i|
          { line: i + 1, text: line.rstrip,
            context: lines[[i - 1, 0].max..(i + 3)].join.rstrip } } }
    end

    SCRIPT_HEADER = <<~JS.freeze
      // The site's JavaScript. A database row, not a file, so it is part of a
      // revision: previewed before publishing and undone by republishing.
      JS

    def write_js(js)
      a = revision.theme_assets.find_or_initialize_by(name: ThemeAsset::KINDS.fetch("js"))
      a.update!(content: js)
    end

    # ---- outside data ------------------------------------------------------

    def list_data_sources(**)
      rows = revision.data_sources.order(:name)
      return { sources: [], note: "no outside data is set up yet. add_data_source adds one." } if rows.empty?

      { sources: rows.map { |d|
          state = begin
                    d.pages.map { |r| r.error.presence || (r.stale? ? "stale" : "ok") }.uniq.join(", ")
                  rescue Site::OutboundFetch::Refused => e
                    e.message
                  end
          { name: d.name, urls: d.url_list, refresh_minutes: d.refresh_minutes,
            note: d.note.presence, state: state,
            use: "{{ site.data.#{d.name.tr('-', '_')}.json_tag }} in a template, " \
                 "then JSON.parse(document.getElementById(\"data-#{d.name}\").textContent) in the script" } } }
    end

    def add_data_source(name:, urls:, refresh_minutes: 60, note: nil, **)
      list = urls.is_a?(Array) ? urls : [urls.to_s]
      source = revision.data_sources.find_or_initialize_by(name: name.to_s.strip.downcase)
      source.assign_attributes(urls: list, refresh_minutes: refresh_minutes.to_i, note: note)
      raise ToolError, source.errors.full_messages.to_sentence unless source.save

      # Fetch once now, so a bad address is reported to the person who just
      # typed it rather than to a visitor reading the page next week.
      begin
        source.pages
      rescue Site::OutboundFetch::Refused => e
        source.destroy
        raise ToolError, "that address could not be fetched, so the source was not added: #{e.message}"
      end

      touched_everything!
      ok "set up #{source.name} from #{source.domains.join(', ')} " \
         "(#{source.url_list.size} #{'address'.pluralize(source.url_list.size)})"
    end

    def remove_data_source(name:, **)
      source = revision.data_sources.find_by(name: name.to_s) or
        raise ToolError, "there is no data source called #{name.inspect}. " \
                         "There is: #{revision.data_sources.pluck(:name).join(', ').presence || 'nothing'}"

      source.destroy
      touched_everything!
      ok "removed the #{name} data source"
    end

    # The AI has to write JavaScript that picks this data apart, and it cannot do
    # that without knowing its shape. It also cannot be handed a megabyte of
    # fetched HTML. So: describe the structure, and show a small sample.
    PEEK_CHARS = 1200

    def peek_data(name:, path: nil, find: nil, **)
      source = revision.data_sources.find_by(name: name.to_s) or
        raise ToolError, "there is no data source called #{name.inspect}"

      row = source.pages.first
      raise ToolError, "#{name} has not been fetched: #{row.error}" if row.body.blank?

      body = row.body.to_s
      parsed = begin
                 JSON.parse(body)
               rescue JSON::ParserError
                 nil
               end

      base = { name: source.name, url: row.url, content_type: row.content_type,
               bytes: body.bytesize, fetched: row.age_text,
               addresses: source.url_list.size }

      return base.merge(found: find_in(body, find), looked_for: find) if find.present?

      if parsed.nil?
        return base.merge(
          json: false, sample: body[0, PEEK_CHARS],
          note: "Not JSON, and this is only the FIRST #{PEEK_CHARS} of #{body.bytesize} " \
                "characters. If what you need is not here, search the whole thing: " \
                "peek_data with find: \"...\". A page that embeds a feed usually names " \
                "the address and its parameters somewhere in its script."
        )
      end

      base.merge(json: true, shape: shape_of(parsed), sample: sample_of(parsed, path))
    end

    # Search the whole fetched body rather than its first page. Without this the
    # AI was shown the first 1200 characters of a 6278-character page and had to
    # GUESS the rest: asked to replace the ChurchTrac iframe, the address and
    # parameters it needed sat at character 4123, it never saw them, and it spent
    # its turn being refused by a server it was asking the wrong way.
    FIND_CONTEXT = 400
    FIND_HITS = 6

    def find_in(body, needle)
      offsets = []
      at = 0
      while (i = body.index(needle.to_s, at)) && offsets.size < FIND_HITS
        offsets << i
        at = i + 1
      end
      return { hits: 0, note: "#{needle.inspect} does not appear in this. It is #{body.bytesize} characters." } if offsets.empty?

      { hits: offsets.size,
        extracts: offsets.map { |i|
          { at: i, text: body[[i - FIND_CONTEXT / 2, 0].max, FIND_CONTEXT] } } }
    end

    def shape_of(value, depth = 0)
      case value
      when Array then "array of #{value.size}#{value.first ? " × #{shape_of(value.first, depth + 1)}" : ''}"
      when Hash  then depth > 1 ? "object" : "{ #{value.keys.first(25).join(', ')} }"
      else value.class.name.downcase
      end
    end

    def sample_of(parsed, path)
      subject = path.present? ? parsed.dig(*path.to_s.split(".")) : parsed
      first = subject.is_a?(Array) ? subject.first(2) : subject
      JSON.pretty_generate(first)[0, PEEK_CHARS]
    rescue StandardError
      JSON.generate(parsed)[0, PEEK_CHARS]
    end

    def set_styles(css:, **)
      a = revision.theme_assets.find_or_initialize_by(name: ThemeAsset::KINDS.fetch("css"))
      a.update!(content: css)
      ok "rewrote the stylesheet (#{css.to_s.lines.count} lines)"
    end

    # ---- templates ---------------------------------------------------------

    def liquid_guide(**) = DropReference.call

    def list_templates(**)
      { templates: revision.templates.order(:name).pluck(:name) }
    end

    def get_template(name:, **)
      source = Template.source_for(revision, name) or
        raise ToolError, "there is no template called #{name.inspect}"
      { name: name, source: source }
    end

    def add_template(name:, source:, **)
      raise ToolError, "#{name.inspect} already exists; use set_template" if revision.templates.exists?(name: name)
      raise ToolError, "a template name looks like block/heading or partial/card" unless
        name.to_s.match?(%r{\A[a-z][a-z0-9_-]*(/[a-z][a-z0-9_-]*)?\z})

      Liquid::Template.parse(source)
      revision.templates.create!(name: name, source: source)
      note = name.to_s.start_with?("block/") ? " — blocks of kind #{name.to_s.delete_prefix('block/')} can now be added" : ""
      ok "created the #{name} template#{note}"
    rescue Liquid::SyntaxError => e
      raise ToolError, "that Liquid does not compile: #{e.message}"
    end

    def get_scripts(**) = { js: ThemeAsset.js_for(revision) }

    def set_scripts(js:, **)
      write_js(js)
      # Was missing, so a JavaScript change marked nothing as touched and the
      # automatic verify and promise checks skipped the page entirely.
      touched_everything!
      ok "replaced the custom JavaScript (#{js.to_s.lines.count} lines)"
    end

    def record_lesson(subject:, lesson:, **)
      record = Lesson.new(subject: subject, body: lesson, learned_in: revision.id.to_s)
      return ok("already noted: #{lesson.to_s.truncate(60)}") unless record.valid? || record.errors[:body].none?
      raise ToolError, record.errors.full_messages.to_sentence unless record.save

      ok "noted for next time: #{lesson.to_s.truncate(70)}"
    end

    def set_template(name:, source:, **)
      existing = revision.templates.find_by(name: name) or
        raise ToolError, "there is no template called #{name.inspect}. Use list_templates to see them."

      # Parse before saving: a template that does not compile would take every
      # page using it down, and the editor would find out by looking.
      Liquid::Template.parse(source)
      existing.update!(source: source)
      touched_everything!
      ok "rewrote the #{name} template"
    rescue Liquid::SyntaxError => e
      raise ToolError, "that Liquid does not compile: #{e.message}"
    end

    # ---- photographs ---------------------------------------------------------

    # ---- standing promises ---------------------------------------------------

    def list_promises(**)
      { promises: revision.promises.map { |p|
          { id: p.id, summary: p.summary, applies_to: p.scope_text,
            intent: p.intent, since: p.age_text } },
        note: "A promise is only removed after agreeing it with the person you are talking to." }
    end

    def add_promise(summary:, intent:, script:, page_slug: nil, proof: nil, **)
      promise = Promise.new(summary: summary, intent: intent, script: script,
                            page_slug: page_slug.presence, proof: proof,
                            created_by: revision.created_by, introduced_in: revision.id)
      raise ToolError, promise.errors.full_messages.to_sentence unless promise.valid?

      # It must pass NOW, or it is asserting something that is not true.
      promise.save!
      revision.revision_promises.create!(promise: promise)
      results = PromiseRunner.new(revision).call(only: [page_slug.presence || revision.pages.first&.slug].compact)
      mine = results.find { |r| r[:promise_id] == promise.id }

      if mine && !mine[:pass]
        revision.revision_promises.where(promise: promise).destroy_all
        promise.destroy
        raise ToolError, "that promise does not hold on the site as it is now: #{mine[:message]}. " \
                         "Either the script is wrong, or the thing it promises is not there yet."
      end

      touched_everything!
      ok "promised: #{summary}", promise: promise.id
    end

    def remove_promise(id:, because:, **)
      link = revision.revision_promises.find_by(promise_id: id) or
        raise ToolError, "promise #{id} is not on this revision"
      promise = link.promise
      link.destroy!
      touched_everything!
      ok "stopped checking \"#{promise.summary}\" (#{promise.age_text}) — #{because}"
    end

    def check_promises(slug: nil, **)
      results = PromiseRunner.new(revision).call(only: slug.present? ? [slug] : nil)
      broken = results.reject { |r| r[:pass] }
      { kept: results.count { |r| r[:pass] },
        broken: broken.map { |r| { id: r[:promise_id], summary: r[:summary],
                                   page: r[:page], why: r[:message] } },
        ok: broken.empty? }
    end

    def images = @images ||= ImageTools.new(revision)

    def describe_photo(name:, **)      = images.describe(name: name)
    def crop_photo(**a)                = images.crop(**a.slice(:name, :x, :y, :width, :height, :as))
    def resize_photo(**a)              = images.resize(**a.slice(:name, :width, :height, :as).compact)
    def rotate_photo(**a)              = images.rotate(**a.slice(:name, :degrees, :as))
    def trim_photo(**a)                = images.trim(**a.slice(:name, :as))
    def adjust_photo(**a)              = images.adjust(**a.slice(:name, :brightness, :saturation, :hue, :as).compact)
    def grayscale_photo(**a)           = images.grayscale(**a.slice(:name, :as))
    def feather_photo(**a)             = images.feather_edges(**a.slice(:name, :radius, :as).compact)
    def round_photo_corners(**a)       = images.round_corners(**a.slice(:name, :radius, :as).compact)
    def convert_photo(**a)             = images.convert(**a.slice(:name, :format, :as))
    def combine_photos(**a)            = images.composite(**a.slice(:base, :overlay, :gravity, :as).compact)

    def ok(summary, **extra) = { ok: true, summary: summary, **extra }
  end
end
