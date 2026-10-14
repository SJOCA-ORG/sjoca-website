# "classes" was a poor name: it reads as CSS classes, and says nothing about what
# it shows. These are recordings of the adult education classes.
class RenameClassesBlockToRecordings < ActiveRecord::Migration[8.1]
  def up
    execute "UPDATE blocks SET kind = 'recordings' WHERE kind = 'classes'"
    execute "UPDATE templates SET name = 'block/recordings' WHERE name = 'block/classes'"
  end

  def down
    execute "UPDATE blocks SET kind = 'classes' WHERE kind = 'recordings'"
    execute "UPDATE templates SET name = 'block/classes' WHERE name = 'block/recordings'"
  end
end
