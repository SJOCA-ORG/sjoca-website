# A hook for styling ONE block without inventing a block kind for it.
#
# Without this the only ways to make a single heading look different are to
# create a new kind (which accumulates -- forty bespoke kinds in two years) or
# an :nth-child selector (which breaks the moment blocks are reordered).
#
# Block ids are NOT a usable hook: a revision copies every row, so ids change on
# every publish and a stylesheet written against one would silently stop working.
class AddCssClassToBlocks < ActiveRecord::Migration[8.1]
  def change
    add_column :blocks, :css_class, :string
  end
end
