# Things the admin AI has worked out and should not have to work out again.
#
# The curated rules live in code (Admin::DropReference::RULES) because they were
# reviewed. These are the ones it learns in use: a Liquid construct that did not
# behave as expected, a house convention, a trap in this particular site. Both
# sets are handed to it together.
#
# Visible and editable by a person, because an AI that records a wrong lesson
# would otherwise follow it forever.
class CreateLessons < ActiveRecord::Migration[8.1]
  def change
    create_table :lessons do |t|
      t.string  :subject,  null: false            # "liquid", "photos", "house style"
      t.text    :body,     null: false
      t.string  :learned_in                       # which revision it came from
      t.boolean :active,   null: false, default: true
      t.timestamps
    end
    add_index :lessons, %i[active subject]
  end
end
