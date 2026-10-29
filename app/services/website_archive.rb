# A whole website, as files you can read.
#
# One primitive, two jobs. The sample sites live in git as archives -- that is
# how a fresh deployment gets its starters, with photographs and all, from the
# repository and nothing else. And an organization can take an archive of
# itself and keep it wherever it keeps things, which is the only copy of a
# website that is not a database backup.
#
# A DIRECTORY, not a tarball, because the sample sites are reviewed in pull
# requests: a change to a starter should read as a change to a sentence or a
# stylesheet, not as a new opaque blob. `--archive` on the rake task tars the
# directory for anybody who wants one file to keep.
#
#   db/seeds/starters/trade/
#     organization.yml     what to call it, and which clock it keeps
#     site.yml             settings, templates, theme, pages, blocks, lessons
#     photos.yml           every photograph, by name, with its digest
#     photos/hero-v1.png   the bytes, under a name a person can read
#
# What travels is a WEBSITE. No users, no hostnames, no contact details, no
# canonical address -- those belong to an account, and an account belongs to
# wherever it is installed. See Revision#copy_into, which makes the same
# distinction for the same reason.
#
# The live revision only. Ten revisions of history is a different feature, and
# an archive is for moving a website rather than for undoing an accident --
# that is what a database dump is for.
class WebsiteArchive
  FORMAT = 1

  class Missing < StandardError; end

  EXTENSIONS = {
    "image/png" => "png", "image/jpeg" => "jpg", "image/jpg" => "jpg",
    "image/webp" => "webp", "image/gif" => "gif", "image/svg+xml" => "svg",
    "image/avif" => "avif", "application/pdf" => "pdf"
  }.freeze

  def self.export(organization, to:) = new(organization).export(Pathname(to))

  def self.import(from, slug:, name: nil, starter: false)
    new(nil).import(Pathname(from), slug: slug, name: name, starter: starter)
  end

  def initialize(organization) = @organization = organization

  # ---------------------------------------------------------------- export

  def export(dir)
    revision = Organization.acting_as(@organization) { Revision.live }
    raise Missing, "#{@organization.slug} has nothing published to archive" if revision.nil?

    dir.mkpath
    (dir + "photos").mkpath

    Organization.acting_as(@organization) do
      write(dir + "organization.yml", organization_facts)
      write(dir + "site.yml", site(revision))
      write(dir + "photos.yml", photographs(dir))
    end
    dir
  end

  # ---------------------------------------------------------------- import

  def import(dir, slug:, name: nil, starter: false)
    facts  = read(dir + "organization.yml")
    site   = read(dir + "site.yml")
    photos = read(dir + "photos.yml")

    organization = Organization.create!(
      slug: slug,
      name: name.presence || facts["name"],
      time_zone: facts["time_zone"].presence || "UTC",
      locale: facts["locale"].presence || "en",
      starter: starter
    )

    Organization.acting_as(organization) do
      ActiveRecord::Base.transaction do
        revision = Revision.create!(state: "published", title: site["title"].presence || "First")
        restore_photographs(dir, photos)
        restore_site(revision, site)
      end
    end

    organization
  end

  private

  def write(path, data) = path.write(data.to_yaml.sub(/\A---\n/, ""))

  # A PLAIN hash, deliberately.
  #
  # ActiveRecord#slice returns a HashWithIndifferentAccess, and YAML writes one
  # of those as "!ruby/hash:ActiveSupport::HashWithIndifferentAccess" with every
  # key tagged -- which makes the file unreadable in a pull request, which is
  # the entire reason these are directories rather than tarballs, and makes it
  # unloadable without permitting arbitrary Ruby classes, which is the entire
  # reason safe_load exists.
  def plain(record, *names) = record.slice(*names).to_h

  def read(path)
    raise Missing, "#{path} is not there" unless path.file?

    YAML.safe_load_file(path, permitted_classes: [Date, Time], aliases: false) || {}
  end

  def organization_facts
    {
      "format" => FORMAT,
      "name" => @organization.name,
      "time_zone" => @organization.time_zone,
      "locale" => @organization.locale,
      "exported_on" => Date.current.iso8601
    }
  end

  # Ordered so a diff reads: the facts, then the look, then the words.
  def site(revision)
    {
      "title" => revision.title,
      "settings" => revision.site_settings.order(:key).map { |s| plain(s, "key", "value") },
      "templates" => revision.templates.order(:name).map { |t| plain(t, "name", "source") },
      "theme" => revision.theme_assets.order(:name).map { |a| plain(a, "name", "content") },
      "data_sources" => revision.data_sources.order(:name).map { |d|
        plain(d, "name", "urls", "refresh_minutes", "note") },
      "pages" => revision.pages.order(:position, :id).map { |page| page_with_contents(page) },
      "lessons" => Lesson.order(:subject).map { |l| plain(l, "subject", "body", "learned_in", "active") },
      "promises" => revision.promises.order(:summary).map { |p|
        plain(p, "summary", "intent", "script", "page_slug", "introduced_in") }
    }
  end

  PAGE_FIELDS = %w[slug title nav_title self_nav_title parent_slug position show_in_nav
                   on_website layout dated_on description
                   hero_asset_name hero_asset_version hero_heading hero_subheading
                   hero_detail hero_size].freeze
  BLOCK_FIELDS = %w[kind content url align width css_class row column position
                    asset_name asset_version].freeze

  def page_with_contents(page)
    plain(page, *PAGE_FIELDS).compact.merge(
      "sections" => page.sections.order(:position, :id).map { |section|
        plain(section, "position", "style", "column_widths").compact.merge(
          "blocks" => section.blocks.order(:position, :id).map { |b| plain(b, *BLOCK_FIELDS).compact }
        )
      }
    )
  end

  # Readable filenames, decided with Mitch: hero-v1.png rather than a digest.
  # The digest is in the manifest, where it is checked; a filename is for a
  # person opening the folder to see what a starter looks like.
  def photographs(dir)
    Photo.order(:human_name, :version).map do |photo|
      file = "#{photo.human_name}-v#{photo.version}.#{EXTENSIONS.fetch(photo.content_type, 'bin')}"
      (dir + "photos" + file).binwrite(photo.data)

      {
        "file" => file,
        "human_name" => photo.human_name,
        "version" => photo.version,
        "status" => photo.status,
        "content_type" => photo.content_type,
        "sha256" => photo.sha256,
        "alt_text" => photo.alt_text,
        "original_filename" => photo.original_filename,
        "tags" => photo.tags.order(:name).map { |t| plain(t, "name", "label") }
      }.compact
    end
  end

  # ---------------------------------------------------------------- restore

  def restore_photographs(dir, photos)
    photos.each do |row|
      path = dir + "photos" + row.fetch("file")
      raise Missing, "#{path} is listed in photos.yml and is not there" unless path.file?

      bytes = path.binread
      # The digest is the point of recording it: a photograph that changed on
      # the way through is a photograph somebody edited by hand, and silently
      # importing it would hide that.
      if row["sha256"].present? && Photo.digest(bytes) != row["sha256"]
        raise Missing, "#{row['file']} does not match the digest in photos.yml"
      end

      photo = Photo.create!(
        human_name: row["human_name"], version: row["version"],
        status: row.fetch("status", "published"),
        content_type: row["content_type"], data: bytes, byte_size: bytes.bytesize,
        sha256: Photo.digest(bytes), alt_text: row["alt_text"],
        original_filename: row["original_filename"]
      )

      Array(row["tags"]).each do |tag|
        found = Tag.find_or_create_by!(name: tag.fetch("name")) { |t| t.label = tag["label"].presence || tag["name"] }
        photo.tags << found unless photo.tags.include?(found)
      end
    end
  end

  def restore_site(revision, site)
    Array(site["settings"]).each { |s| revision.site_settings.create!(s) }
    Array(site["templates"]).each { |t| revision.templates.create!(t) }
    Array(site["theme"]).each     { |a| revision.theme_assets.create!(a) }
    Array(site["data_sources"]).each { |d| revision.data_sources.create!(d) }

    Array(site["pages"]).each do |attrs|
      sections = attrs["sections"] || []
      page = revision.pages.create!(attrs.except("sections"))

      sections.each do |section_attrs|
        blocks = section_attrs["blocks"] || []
        section = page.sections.create!(section_attrs.except("blocks").merge(revision: revision))
        blocks.each { |b| section.blocks.create!(b.merge(revision: revision)) }
      end
    end

    Array(site["lessons"]).each { |l| Lesson.create!(l) }
    Array(site["promises"]).each do |p|
      promise = Promise.create!(p)
      revision.revision_promises.create!(promise: promise)
    end
  end
end
