class AddColumnWidthsToSections < ActiveRecord::Migration[8.1]
  def change
    # Comma-separated relative column widths measured off the current site,
    # e.g. "464,661". Rendered as grid-template-columns fractions, so the
    # proportions survive at any viewport width.
    add_column :sections, :column_widths, :string
  end
end
