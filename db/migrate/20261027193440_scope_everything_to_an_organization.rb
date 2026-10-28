# Give every root table an owner.
#
# Seven tables need an organization_id. Everything else already hangs off a
# revision -- pages, sections, blocks, templates, site_settings, data_sources,
# theme_assets, revision_messages, revision_promises -- and inherits the scope
# from it, which is why this migration is seven columns and not thirty.
#
# The unique indexes are the half that would have bitten later. "the photo
# called home-hero" and "the tag called feast-days" were unique across the whole
# database, which was correct when there was one organization and is a collision
# waiting to happen when there are two. Each one grows an organization_id at the
# front.
#
# Email stays unique across the WHOLE system, not per organization -- one person,
# one login, whoever they work for. The existing index_users_on_lower_email is
# left exactly as it is. (It does not appear if you list unique indexes by
# joining pg_index.indkey to pg_attribute: an expression index has indkey 0 and
# vanishes from that join. Worth knowing before concluding a constraint is
# missing.)
class ScopeEverythingToAnOrganization < ActiveRecord::Migration[8.1]
  SCOPED = %w[revisions photos tags promises lessons fetched_pages].freeze

  def up
    org = select_value("SELECT id FROM organizations ORDER BY id LIMIT 1")
    raise "No organization exists; run the previous migration first." unless org

    SCOPED.each do |table|
      add_column table, :organization_id, :bigint
      execute "UPDATE #{table} SET organization_id = #{org}"
      change_column_null table, :organization_id, false
      add_index table, :organization_id
      add_foreign_key table, :organizations
    end

    # Users are the one table that cannot simply be scoped, because signing in
    # happens before there is an organization to scope to. The column says where
    # a user belongs; application_admin says they may act anywhere.
    add_column :users, :organization_id, :bigint
    add_column :users, :application_admin, :boolean, null: false, default: false
    execute "UPDATE users SET organization_id = #{org}, application_admin = true"
    add_index :users, :organization_id
    add_foreign_key :users, :organizations

    # Null is allowed, but only for somebody who may act anywhere -- a support
    # account belonging to no customer. Enforced here rather than trusted to a
    # validation, because a user row with neither is a user who can see nothing
    # and would be a puzzle to debug.
    add_check_constraint :users,
                         "organization_id IS NOT NULL OR application_admin",
                         name: "users_belong_somewhere_or_are_application_admins"

    say "re-pointing the unique indexes that were global"
    remove_index :fetched_pages, :key
    add_index    :fetched_pages, %i[organization_id key], unique: true

    remove_index :photos, %i[human_name sha256]
    add_index    :photos, %i[organization_id human_name sha256], unique: true
    remove_index :photos, %i[human_name version]
    add_index    :photos, %i[organization_id human_name version], unique: true

    remove_index :tags, :name
    add_index    :tags, %i[organization_id name], unique: true
  end

  def down
    remove_index :tags, %i[organization_id name]
    add_index    :tags, :name, unique: true
    remove_index :photos, %i[organization_id human_name version]
    add_index    :photos, %i[human_name version], unique: true
    remove_index :photos, %i[organization_id human_name sha256]
    add_index    :photos, %i[human_name sha256], unique: true
    remove_index :fetched_pages, %i[organization_id key]
    add_index    :fetched_pages, :key, unique: true

    remove_check_constraint :users, name: "users_belong_somewhere_or_are_application_admins"
    remove_column :users, :application_admin
    remove_column :users, :organization_id

    SCOPED.reverse_each { |t| remove_column t, :organization_id }
  end
end
