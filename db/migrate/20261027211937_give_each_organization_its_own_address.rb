# Where an organization's website lives, as a row rather than an env var.
#
# SITE_URL was read in five places to build an absolute link -- the sitemap,
# robots.txt, the bulletin email, the promise runner, one admin tool. One
# environment variable can only be right for one organization, so with two
# installed, the second one's emails and sitemap would advertise the first one's
# domain. Mail with a broken picture in it is the visible half; a sitemap
# handing Google the wrong hostname is the half that is hard to undo.
#
# It is also exactly the kind of fact this project keeps out of Ruby: what a
# website is called and where it lives belongs to the organization, not the
# deployment.
class GiveEachOrganizationItsOwnAddress < ActiveRecord::Migration[8.1]
  def up
    add_column :organizations, :canonical_url, :string

    # Seeded from the deployment's own setting, which is correct for the one
    # organization that exists today.
    from_env = ENV.fetch("SITE_URL", "http://localhost:3000").sub(%r{/+\z}, "")
    execute "UPDATE organizations SET canonical_url = #{quote(from_env)} WHERE canonical_url IS NULL"
    say "canonical_url set to #{from_env} for #{select_value('SELECT count(*) FROM organizations')} organization(s)"
  end

  def down
    remove_column :organizations, :canonical_url
  end
end
