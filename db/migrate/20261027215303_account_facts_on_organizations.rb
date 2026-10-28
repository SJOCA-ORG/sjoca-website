# The facts about an ACCOUNT, as opposed to the facts a website publishes.
#
# The website's own name, address and email are site_settings, scoped to a
# revision, so they version with content and revert with it. These must not do
# that: an organization can roll back its pages, but it cannot roll back out of
# who owns the account or which clock its dates are in.
#
# Every column here has a consumer from the day it lands. A column nobody reads
# is the Site::Seo.coordinates mistake -- a field documented in a TODO list,
# wired to nothing, which somebody fills in and reasonably believes is working.
#
#   contact_name/email  the reply-to on account mail, when the website offers
#                       no public address of its own
#   time_zone           Time.zone for the request. config.time_zone is
#                       "America/New_York" -- one organization's clock, applied
#                       to everybody's dates. A club in Berlin should not keep
#                       Rochester's hours.
#   locale              I18n.locale for the request
#   product             which organization is this tool's own site: where the
#                       operator console answers, and who owns the "not
#                       configured yet" page. Exactly one, enforced below.
class AccountFactsOnOrganizations < ActiveRecord::Migration[8.1]
  def up
    add_column :organizations, :contact_name,  :string
    add_column :organizations, :contact_email, :string
    add_column :organizations, :time_zone, :string, null: false, default: "UTC"
    add_column :organizations, :locale,    :string, null: false, default: "en"
    add_column :organizations, :product,   :boolean, null: false, default: false

    # Whatever this deployment is configured to use, so nothing changes for the
    # organization that already exists. Read from the running app rather than
    # written in, because the point of the column is that it is not a constant.
    execute "UPDATE organizations SET time_zone = #{quote(Time.zone.name)}"
    execute "UPDATE organizations SET locale    = #{quote(I18n.default_locale.to_s)}"

    # The account contact starts as whoever can already sign in. Better than
    # blank: a blank contact is a column somebody has to remember to fill.
    contact = select_one(<<~SQL)
      SELECT name, email FROM users WHERE organization_id IS NOT NULL
      ORDER BY id LIMIT 1
    SQL
    if contact
      execute(<<~SQL)
        UPDATE organizations
        SET contact_email = #{quote(contact['email'])},
            contact_name  = #{quote(contact['name'])}
        WHERE contact_email IS NULL
      SQL
      say "account contact set to #{contact['email']}"
    end

    # One product organization, in the database and not only in a validation.
    # "Exactly one" is the sort of invariant that survives a validation right up
    # until a seed, a console session or a migration sets a second.
    add_index :organizations, :product, unique: true, where: "product",
              name: "index_organizations_on_the_one_product"
  end

  def down
    remove_index  :organizations, name: "index_organizations_on_the_one_product"
    %i[product locale time_zone contact_email contact_name].each do |c|
      remove_column :organizations, c
    end
  end
end
