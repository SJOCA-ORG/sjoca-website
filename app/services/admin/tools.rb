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
    end

    attr_reader :revision

    # ---- schema handed to the model ---------------------------------------

    def self.definitions
      [
        tool("list_pages", "List every page, with its sections and how many blocks each holds.", {}),
        tool("get_page", "The full contents of one page: every section, column and block, with ids.",
             { slug: str("Page slug, e.g. \"giving\" or \"about-us/choir\"") }, %w[slug]),
        tool("update_block", "Change an existing block's text, alignment or width.",
             { id: int("Block id"), content: str("New text. Inline HTML links are allowed."),
               align: str("left, center or right"), width: int("Max width in px, images only") },
             %w[id]),
        tool("add_block", "Add a block to a section.",
             { section_id: int("Section id"),
               kind: str("heading, subheading, text, image, button, list, quote, embed, calendar, upcoming, classes or lectionary"),
               content: str("Text, or one item per line for a list"),
               asset_name: str("Photo human_name, for image blocks"),
               url: str("Link target, for button, image or embed blocks"),
               column: int("Column index, 0-based"), position: int("Order within the column"),
               align: str("left, center or right") },
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
               hero_asset_name: str("Photo human_name for the hero"),
               hero_size: str("standard or tall"), position: int("Order in the navigation"),
               show_in_nav: { type: "boolean", description: "Whether it appears in the menu" } },
             %w[slug]),
        tool("add_page", "Create a page. It renders immediately at /slug.",
             { slug: str("Path, e.g. \"about-us/our-icons\""), title: str("Browser title"),
               nav_title: str("Navigation label"), parent_slug: str("Parent page slug, for submenus"),
               position: int("Order in the navigation") },
             %w[slug title nav_title]),
        tool("list_photos", "Every photograph available, by name.", {}),
        tool("get_styles", "The site's current custom CSS overrides.", {}),
        tool("set_styles", "Replace the custom CSS. Appended after the main stylesheet, so it overrides.",
             { css: str("The complete CSS to use") }, %w[css]),

        # --- templates: how things look, as opposed to what they say ---------
        tool("list_templates", "Every Liquid template, by name.", {}),
        tool("get_template", "The source of one Liquid template.",
             { name: str("e.g. \"block/heading\", \"header\", \"page\"") }, %w[name]),
        tool("set_template", "Replace a Liquid template's source. This changes how that thing renders everywhere.",
             { name: str("Template name"), source: str("The complete Liquid source") },
             %w[name source]),

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

    def call(name, args)
      args = args.symbolize_keys
      raise ToolError, "unknown tool #{name}" unless respond_to?(name, true)

      send(name, **args)
    end

    private

    def pages    = revision.pages
    def sections = revision.sections
    def blocks   = revision.blocks

    def find_block(id)   = blocks.find_by(id: id)   || raise(ToolError, "no block #{id} in this revision")
    def find_section(id) = sections.find_by(id: id) || raise(ToolError, "no section #{id} in this revision")
    def find_page(slug)  = pages.find_by(slug: slug) || raise(ToolError, "no page #{slug.inspect}")

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
      b.update!(attrs.slice(:content, :align, :width, :url, :asset_name).compact)
      ok "updated #{b.kind} block #{b.id}", block: id
    end

    def add_block(section_id:, kind:, **attrs)
      s = find_section(section_id)
      position = attrs[:position] || (s.blocks.where(column: attrs[:column] || 0).maximum(:position).to_i + 1)
      b = s.blocks.create!(revision: revision, kind: kind, position: position,
                           column: attrs[:column] || 0,
                           **attrs.slice(:content, :asset_name, :url, :align, :width).compact)
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
      p.update!(attrs.slice(:title, :nav_title, :hero_heading, :hero_subheading,
                            :hero_asset_name, :hero_size, :position, :show_in_nav).compact)
      ok "updated the #{slug} page"
    end

    def add_page(slug:, title:, nav_title:, **attrs)
      p = pages.create!(slug: slug, title: title, nav_title: nav_title,
                        parent_slug: attrs[:parent_slug],
                        position: attrs[:position] || (pages.maximum(:position).to_i + 1))
      ok "created the page /#{p.slug}"
    end

    def list_photos(**)
      { photos: Photo.published.distinct.pluck(:human_name).sort }
    end

    def get_styles(**)
      { css: ThemeAsset.css_for(revision) }
    end

    def set_styles(css:, **)
      a = revision.theme_assets.find_or_initialize_by(name: "overrides.css")
      a.update!(content: css)
      ok "updated the custom stylesheet (#{css.to_s.lines.count} lines)"
    end

    # ---- templates ---------------------------------------------------------

    def list_templates(**)
      { templates: revision.templates.order(:name).pluck(:name) }
    end

    def get_template(name:, **)
      source = Template.source_for(revision, name) or
        raise ToolError, "there is no template called #{name.inspect}"
      { name: name, source: source }
    end

    def set_template(name:, source:, **)
      existing = revision.templates.find_by(name: name) or
        raise ToolError, "there is no template called #{name.inspect}. Use list_templates to see them."

      # Parse before saving: a template that does not compile would take every
      # page using it down, and the editor would find out by looking.
      Liquid::Template.parse(source)
      existing.update!(source: source)
      ok "rewrote the #{name} template"
    rescue Liquid::SyntaxError => e
      raise ToolError, "that Liquid does not compile: #{e.message}"
    end

    # ---- photographs ---------------------------------------------------------

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
