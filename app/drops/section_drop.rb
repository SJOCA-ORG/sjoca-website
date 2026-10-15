class SectionDrop < BaseDrop
  def initialize(section) = @section = section

  def id            = @section.id
  def style         = @section.style
  def grid_template = @section.grid_template
  def columns       = @section.columns.map { |col| col.map { |b| BlockDrop.new(b) } }
end
