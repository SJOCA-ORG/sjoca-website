# What an application administrator did, and to whose data.
#
# An application admin can act inside any organization. That is necessary -- the
# person running this for other people has to be able to fix a club's broken
# page on a Tuesday evening -- and it is the one power that cannot be made
# smaller. So it is made accountable instead: entering an organization writes a
# row here, and so does creating or suspending one.
#
# This table is NOT scoped to an organization, and that is the point. It is the
# operator's log, and an organization's own administrators must not be able to
# read it (whose data an operator looked at is other customers' business) or to
# edit it (a log an organization can rewrite is not a log).
class CreateOperatorActions < ActiveRecord::Migration[8.1]
  def change
    create_table :operator_actions do |t|
      # Who. Nullified rather than cascaded if the account goes: the fact that
      # somebody entered an organization does not stop being true.
      t.references :user, foreign_key: { on_delete: :nullify }
      # Whose data. Also nullable, so deleting an organization does not take the
      # record of what was done to it.
      t.references :organization, foreign_key: { on_delete: :nullify }
      t.string  :action, null: false
      t.string  :detail
      t.string  :ip
      t.datetime :created_at, null: false
    end

    add_index :operator_actions, :created_at
    add_index :operator_actions, %i[organization_id created_at]
  end
end
