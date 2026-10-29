# What a new organization is built from.
#
# Every organization used to come out identical: the default templates and one
# empty home page. A starter is that step made plural and made DATA -- a folder
# under db/starters with a manifest, optional template overrides, optional CSS,
# and a few pages so a new site has shape before anybody writes a word.
#
# Files rather than Ruby, for the same reason db/seeds/content.yml is files:
# a look is reviewable in a pull request, and the no-parish scan already reads
# db/starters/**, so a starter carrying somebody's monogram fails the build.
# That is how SJTB got into the default header and stayed there a fortnight.
#
# Every starter begins from DefaultTemplates and overlays its own, so a starter
# cannot forget to provide a template for a block kind and render nothing.
class Starter
  ROOT = Rails.root.join("db/starters")
  DEFAULT = "plain".freeze

  # A starter name arrives from a form. It is used to build a path, so it is
  # checked as a name and not merely interpolated -- "../../etc" is a starter
  # name too, as far as a string is concerned.
  NAME = /\A[a-z0-9][a-z0-9-]{0,40}\z/

  attr_reader :name

  def initialize(name)
    @name = name.to_s
  end

  def self.all
    Dir.children(ROOT).select { |d| (ROOT + d).directory? }.sort.map { |d| new(d) }.select(&:exists?)
  end

  def self.find(name)
    return nil unless name.to_s.match?(NAME)

    starter = new(name)
    starter.exists? ? starter : nil
  end

  def self.find_or_default(name) = find(name) || find(DEFAULT)

  def dir = ROOT + name
  def exists? = name.match?(NAME) && (dir + "starter.yml").file?

  def manifest
    @manifest ||= YAML.safe_load_file(dir + "starter.yml", permitted_classes: [], aliases: false) || {}
  end

  def title   = manifest["title"].presence || name.titleize
  def summary = manifest["summary"].to_s

  # Everything in one go, into a revision that is assumed to be empty.
  def install!(revision)
    # db/seeds/templates.rb is not on the autoload path, so this class worked in
    # the specs only because rails_helper had loaded it for its own reasons. The
    # first thing to call Starter from a runner script got an uninitialized
    # constant. A dependency that is satisfied by accident is not satisfied.
    require Rails.root.join("db/seeds/templates") unless defined?(DefaultTemplates)

    DefaultTemplates.install!(revision)
    install_templates(revision)
    install_theme(revision)
    install_settings(revision)
    install_pages(revision)
    self
  end

  private

  def install_templates(revision)
    Dir.glob(dir + "templates" + "*.liquid").sort.each do |path|
      template = revision.templates.find_or_initialize_by(name: File.basename(path, ".liquid"))
      template.update!(source: File.read(path))
    end
  end

  # A starter's theme.css is an ADDITION to the house style, not a replacement
  # -- half a dozen rules changing colours and spacing cannot stand in for
  # thirty kilobytes of layout.
  #
  # Two things were wrong here until 29 October and the second hid the first.
  # The row was written under the name "css", and the app looks for "site.css"
  # (ThemeAsset::KINDS), so no starter's CSS was ever served. And it REPLACED
  # rather than appended, so even under the right name it would have thrown the
  # house style away and left the site nearly as bare.
  def install_theme(revision)
    css = [DefaultTemplates::BASE_CSS.read, read_optional("theme.css")].compact
    revision.theme_assets
            .find_or_initialize_by(name: ThemeAsset::KINDS.fetch("css"))
            .update!(content: css.join("\n\n/* ---- #{name} ---- */\n\n"))

    js = read_optional("theme.js")
    return if js.blank?

    revision.theme_assets
            .find_or_initialize_by(name: ThemeAsset::KINDS.fetch("js"))
            .update!(content: js)
  end

  def read_optional(file)
    path = dir + file
    path.file? ? path.read : nil
  end

  def install_settings(revision)
    manifest.fetch("settings", {}).each do |key, value|
      revision.site_settings.find_or_initialize_by(key: key.to_s).update!(value: value.to_s)
    end
  end

  def install_pages(revision)
    manifest.fetch("pages", []).each_with_index do |page_attrs, page_index|
      sections = page_attrs["sections"] || []
      page = revision.pages.create!(
        page_attrs.except("sections").symbolize_keys.merge(position: page_index)
      )

      sections.each_with_index do |section_attrs, section_index|
        blocks = section_attrs["blocks"] || []
        section = page.sections.create!(
          revision: revision, position: section_index,
          **section_attrs.except("blocks").symbolize_keys
        )

        blocks.each_with_index do |block_attrs, block_index|
          section.blocks.create!(revision: revision, position: block_index,
                                 **block_attrs.symbolize_keys)
        end
      end
    end
  end
end
