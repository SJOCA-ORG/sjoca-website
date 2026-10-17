# What a turn cost. Shown while it runs, partly so the wait is legible and
# partly because the parish is paying for it and should be able to see.
class AddUsageToRevisionMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :revision_messages, :usage, :json
  end
end
