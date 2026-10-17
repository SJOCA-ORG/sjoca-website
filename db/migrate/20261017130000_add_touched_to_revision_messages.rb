# Which pages a turn changed, so the chat can offer a link straight to them
# rather than leaving someone to work out where to look.
class AddTouchedToRevisionMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :revision_messages, :touched, :json
  end
end
