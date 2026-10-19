# Tags, as a table rather than a column on photos.
#
# The parish wants to pick from a menu and add new ones easily, and that needs a
# canonical list. A free-text column gives you "clergy", "Clergy" and "clerrgy"
# within a month, no way to rename one everywhere, and a menu that grows a new
# entry every time somebody mistypes.
class AddTagsToPhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false          # canonical: lower case, hyphenated
      t.string :label, null: false         # as a person typed it, for the menu
      t.text :note
      t.timestamps
      t.index :name, unique: true
    end

    create_table :photo_tags do |t|
      t.references :photo, null: false, foreign_key: true
      t.references :tag,   null: false, foreign_key: true
      t.timestamps
      t.index %i[photo_id tag_id], unique: true
    end

    # Where an upload came from, and when it arrived. "The photo I am about to
    # upload" and "anything you would like done with those?" both need the
    # conversation to know which photographs are NEW, which means knowing more
    # than created_at: a photo can be created by a crop, an import or a seed.
    add_column :photos, :uploaded_at, :datetime
    add_column :photos, :original_filename, :string
    add_index :photos, :uploaded_at
  end
end
