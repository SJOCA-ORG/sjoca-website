# The sample sites, from the repository.
#
# Each folder under db/seeds/starters is a complete website -- settings,
# templates, stylesheet, pages, photographs -- written by WebsiteArchive. This
# reads them back, so a fresh deployment arrives with its looks and nothing
# else: no customer, no parish, no data anybody has to be trusted with.
#
# Idempotent. A starter already on this installation is left exactly as it is,
# because by then somebody may have improved it through the admin, and the copy
# in git is a starting point rather than an authority. To take a change FROM
# git, delete the organization first; to put one IN, export it.
module SeedStarters
  ROOT = Rails.root.join("db/seeds/starters")

  def self.run!(quiet: false)
    return unless ROOT.directory?

    ROOT.children.select(&:directory?).sort.each do |dir|
      slug = "starter-#{dir.basename}"
      if Organization.exists?(slug: slug)
        puts "  #{dir.basename}: already here" unless quiet
        next
      end

      facts = YAML.safe_load_file(dir + "organization.yml")
      organization = WebsiteArchive.import(dir, slug: slug, name: facts["name"], starter: true)
      # Its own address, so it can be looked at. In development that resolves
      # without touching /etc/hosts; in production the wildcard covers it.
      organization.add_host("#{dir.basename}-starter.localhost")
      organization.update!(canonical_url: "http://#{dir.basename}-starter.localhost:3000")

      pages, photos = Organization.acting_as(organization) do
        [Page.in_revision(Revision.live).count, Photo.count]
      end
      puts "  #{dir.basename}: #{pages} pages, #{photos} photographs" unless quiet
    end
  end
end

SeedStarters.run! if $PROGRAM_NAME.end_with?("rails") || defined?(Rails::Command)
