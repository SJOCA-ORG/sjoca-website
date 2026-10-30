# Taking a website out, and putting one back.
#
#   bin/rails "organization:export[sjoca,tmp/sjoca]"
#   bin/rails "organization:export[sjoca,tmp/sjoca,archive]"      -> also tmp/sjoca.tar.gz
#   bin/rails "organization:import[db/starters/trade,trade,Trade]"
#   bin/rails "organization:import[tmp/sjoca,sjoca,Saint John,starter]"
#
# A directory, because the sample sites live in git and a change to one should
# read as a change to a sentence. The archive form is for handing somebody a
# single file to keep. See app/services/website_archive.rb.
namespace :organization do
  desc "Write an organization's whole website to a folder (SLUG, DIR, [archive])"
  task :export, %i[slug dir archive] => :environment do |_t, args|
    slug = args[:slug] or abort "usage: organization:export[slug,dir]"
    dir  = args[:dir].presence || "tmp/#{slug}"

    organization = Organization.find_by(slug: slug) or abort "no organization with slug #{slug.inspect}"
    WebsiteArchive.export(organization, to: dir)

    photos = Dir.children(File.join(dir, "photos")).size
    puts "#{organization.name} -> #{dir}  (#{photos} photographs)"

    next unless args[:archive] == "archive"

    tarball = "#{dir}.tar.gz"
    system("tar", "-czf", tarball, "-C", File.dirname(dir), File.basename(dir), exception: true)
    puts "#{tarball}  (#{ActiveSupport::NumberHelper.number_to_human_size(File.size(tarball))})"
  end

  desc "Create an organization from a folder (DIR, SLUG, [NAME], [starter])"
  task :import, %i[dir slug name starter] => :environment do |_t, args|
    dir  = args[:dir]  or abort "usage: organization:import[dir,slug]"
    slug = args[:slug] or abort "usage: organization:import[dir,slug]"

    organization = WebsiteArchive.import(dir, slug: slug, name: args[:name].presence,
                                              starter: args[:starter] == "starter")
    pages, photos = Organization.acting_as(organization) do
      [Page.in_revision(Revision.live).count, Photo.count]
    end

    puts "#{organization.name} (#{organization.slug})#{' [starter]' if organization.starter?}"
    puts "  #{pages} pages, #{photos} photographs"
    puts "  It has no hostname yet: organization.add_host(\"...\")"
  end

  # The one thing a fresh deployment cannot do for itself.
  #
  # Seeds give an installation its sample sites and no people, which is right:
  # a password in a seed file is a password in a repository. So the first
  # person is made here, by somebody with a shell, and sets their own password
  # through a link -- the same invitation mechanism a customer's owner gets.
  desc "Create the first application administrator (EMAIL, [NAME])"
  task :bootstrap, %i[email name] => :environment do |_t, args|
    email = args[:email] or abort "usage: organization:bootstrap[you@example.com]"
    abort "#{email} already has an account" if User.exists?(email: email.downcase)

    user = User.create!(email: email, name: args[:name].presence,
                        application_admin: true, organization: nil,
                        role: "superadmin",
                        password: Operator::CreateOrganization.unguessable_password)

    base = Organization.current_url
    puts "#{user.email} can now act in every organization."
    puts
    puts "Set a password with this link. It lasts seven days and works once:"
    puts "  #{base}/admin/password/edit?token=#{user.generate_token_for(:invite)}"
    puts
    puts "Then sign in and create the organization whose website advertises this"
    puts "tool, from a starter, and mark it as the product:"
    puts "  Organization.find_by(slug: \"...\").update!(product: true)"
  end

  desc "List the organizations on this installation"
  task list: :environment do
    Organization.order(:starter, :name).each do |org|
      kind = org.starter? ? "look" : (org.product? ? "product" : "site")
      pages, photos = Organization.acting_as(org) do
        live = Revision.live
        [live ? Page.in_revision(live).count : 0, Photo.count]
      end
      puts format("%-10s %-28s %-22s %3d pages %4d photos  %s",
                  kind, org.slug, org.name.truncate(22), pages, photos, org.hosts.join(" "))
    end
  end
end
