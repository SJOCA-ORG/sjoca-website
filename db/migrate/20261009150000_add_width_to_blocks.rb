class AddWidthToBlocks < ActiveRecord::Migration[8.1]
  def change
    # Rendered width in pixels on the current site. Used as a max-width so an
    # image keeps its original size instead of stretching to fill its column —
    # the live-stream badge is 162px wide, not 660.
    add_column :blocks, :width, :integer
  end
end
