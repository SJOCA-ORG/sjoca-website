# An organization is whoever this website belongs to.
#
# Until now the app assumed there was exactly one, and said so everywhere by
# saying nothing: one live revision, one photo library, one set of settings. The
# assumption was invisible, which is the kind that costs the most to remove.
#
# Deliberately NOT called a parish. A parish is one thing an organization can
# be; a club, a school or a shop are others, and none of that belongs in Ruby.
# The word "church" appears nowhere in this table -- what an organization IS
# lives in its own settings, templates and lessons, as rows.
#
# One organization has one website, for now. If one ever needs two, a sites
# table slots in between and revisions move to it. That is a real migration, so
# it is recorded here as a choice rather than left as an oversight.
class CreateOrganizations < ActiveRecord::Migration[8.1]
  def up
    create_table :organizations do |t|
      # What to call it in the admin. Not what the website calls itself -- that
      # is a site setting, revision-scoped, and the organization must not
      # second-guess it.
      t.string  :name,    null: false
      # Short, stable, lower case. Used in logs, dump filenames and support
      # conversations, where "organization 7" helps nobody.
      t.string  :slug,    null: false
      # An organization that has stopped paying, or has not started, still owns
      # its data. Deleting rows is not how that gets handled.
      t.boolean :active,  null: false, default: true
      t.timestamps
    end
    add_index :organizations, :slug, unique: true

    # Which hostnames resolve to which organization. A separate table because
    # every organization has several from the start -- apex, www, and whatever
    # the host platform calls it -- and because a hostname must be claimable by
    # exactly one organization, which is a database constraint and not a
    # convention.
    create_table :organization_hosts do |t|
      t.references :organization, null: false, foreign_key: true
      t.string     :host, null: false
      t.timestamps
    end
    add_index :organization_hosts, :host, unique: true

    say "creating the first organization from the live revision's own settings"
    name = select_value(<<~SQL) || "This organization"
      SELECT value FROM site_settings
      WHERE key = 'name' AND value <> ''
      ORDER BY revision_id DESC LIMIT 1
    SQL

    now = Time.current
    execute(<<~SQL)
      INSERT INTO organizations (name, slug, active, created_at, updated_at)
      VALUES (#{quote(name)}, 'sjoca', true, #{quote(now)}, #{quote(now)})
    SQL
    id = select_value("SELECT id FROM organizations WHERE slug = 'sjoca'")

    # Every hostname this app answers on today. localhost included, or
    # development resolves to no organization at all and every page 404s.
    %w[
      sjoca.org
      www.sjoca.org
      sjoca.onrender.com
      localhost
      127.0.0.1
    ].each do |host|
      execute(<<~SQL)
        INSERT INTO organization_hosts (organization_id, host, created_at, updated_at)
        VALUES (#{id}, #{quote(host)}, #{quote(now)}, #{quote(now)})
      SQL
    end
    say "#{name.inspect} created, answering on 5 hostnames"
  end

  def down
    drop_table :organization_hosts
    drop_table :organizations
  end
end
