# Standing promises: things about the site that should remain true after the
# next change, and which nobody can be relied upon to re-check every time.
#
# Immutable. Changing one means creating a new one and swapping the id in the
# revision's manifest, so a diff of two revisions' lists IS the history of what
# the site promises.
#
# See docs/ai-admin.md.
class CreatePromises < ActiveRecord::Migration[8.1]
  def change
    create_table :promises do |t|
      t.string  :summary,    null: false            # shown at approval
      t.text    :intent,     null: false            # the full reasoning, for judging a failure
      t.text    :script,     null: false            # JavaScript, run in the rendered page
      t.string  :page_slug                          # nil means "every page"
      t.string  :created_by
      t.integer :introduced_in                      # the revision it first appeared in
      t.text    :proof                              # what makes it fail, if it could not be shown
      t.timestamps
    end

    # A revision carries a LIST of promise ids. A list rather than a query: a
    # query infers intent from ordering, and a branch from an old revision makes
    # that inference wrong. This is the lesson the photograph versions taught.
    create_table :revision_promises do |t|
      t.bigint :revision_id, null: false
      t.bigint :promise_id,  null: false
      t.timestamps
    end
    add_index :revision_promises, %i[revision_id promise_id], unique: true
    add_index :revision_promises, :promise_id
  end
end
