# A full-width horizontal band on a page. The current site alternates white,
# light grey and maroon bands; `style` carries that choice.
#
# Within a band, content sits in columns — that is how Google Sites actually
# lays out, and reading its DOM in document order gets the arrangement wrong.
# `column_widths` holds the proportions measured off the live page.
class Section < ApplicationRecord
  # The bands the site ships with. NOT a closed list: `style` becomes the CSS
  # class band--<style>, so a new one is a stylesheet rule rather than a Ruby
  # change. Bounded to a safe class name so it cannot break the markup.
  STYLES = %w[plain light maroon].freeze
  STYLE_NAME = /\A[a-z][a-z0-9-]{0,30}\z/

  belongs_to :page
  belongs_to :revision
  has_many :blocks, -> { order(:column, :position) },
           dependent: :destroy, inverse_of: :section

  validates :style, format: { with: STYLE_NAME,
                              message: "must be a simple name like plain, light or maroon" }

  # [[blocks in column 0], [blocks in column 1], ...], left to right.
  def columns = blocks.group_by(&:column).sort.map(&:last)

  # CSS grid track sizes preserving the original proportions at any width.
  # Falls back to equal columns if nothing was measured.
  def grid_template
    count  = columns.size
    widths = column_widths.to_s.split(",").map(&:to_i).reject(&:zero?)
    # An empty section has no measurement *and* no columns, so the sizes match
    # and the fallback below would be skipped — emitting an empty property.
    return "repeat(#{[count, 1].max}, minmax(0, 1fr))" if count.zero? || widths.size != count

    widths.map { |w| "minmax(0, #{w}fr)" }.join(" ")
  end
end
