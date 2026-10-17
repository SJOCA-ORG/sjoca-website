# An editing turn takes ten to sixty seconds. Running it inside the web request
# means a frozen page with no sign of progress -- unpleasant in testing, and
# unusable across a long session. The turn becomes a job, and the message row
# carries its state so the page can poll.
class AddStateToRevisionMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :revision_messages, :state, :string, null: false, default: "done"
    add_column :revision_messages, :progress, :json
    add_index  :revision_messages, %i[revision_id state]
  end
end
