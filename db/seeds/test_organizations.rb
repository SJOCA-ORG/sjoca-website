# Two small organizations to try things on, and they never reach production.
#
# Smoke testing multi-organization behaviour needs more than one organization,
# and doing it against a real customer's site is how a real customer's site
# gets edited by accident. These two are obviously nobody: a choir and an
# allotment society, three pages each, made the way a customer's site is made
# -- by copying a starter.
#
# Guarded by the environment rather than by a flag somebody could pass. A
# production database should contain the organizations that pay for it and the
# looks they chose from, and nothing else.
module SeedTestOrganizations
  ROOT = Rails.root.join("db/seeds/test-organizations")

  def self.run!(quiet: false)
    return puts("  (not in #{Rails.env})") if Rails.env.production?
    return unless ROOT.directory?

    ROOT.children.select(&:directory?).sort.each do |dir|
      slug = dir.basename.to_s
      if Organization.exists?(slug: slug)
        puts "  #{slug}: already here" unless quiet
        next
      end

      facts = YAML.safe_load_file(dir + "organization.yml")
      organization = WebsiteArchive.import(dir, slug: slug, name: facts["name"])
      organization.add_host("#{slug}.localhost")
      organization.update!(canonical_url: "http://#{slug}.localhost:3000")

      pages = Organization.acting_as(organization) { Page.in_revision(Revision.live).count }
      puts "  #{slug}: #{pages} pages at http://#{slug}.localhost:3000" unless quiet
    end
  end
end

SeedTestOrganizations.run! if $PROGRAM_NAME.end_with?("rails") || defined?(Rails::Command)
