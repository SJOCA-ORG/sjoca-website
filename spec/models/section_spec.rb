require "rails_helper"

RSpec.describe Section do
  # Google Sites places grid cells explicitly: the home page reads as two rows
  # of two in the DOM and renders as two columns of stacked items. Layout comes
  # from measured boxes, never from document order -- these specs guard that.
  describe "#columns" do
    it "groups blocks by column, left to right" do
      section = build_section(page: build_page)
      right = build_block(section: section, content: "right", column: 1)
      left  = build_block(section: section, content: "left",  column: 0)

      expect(section.reload.columns.map { |c| c.map(&:content) })
        .to eq([["left"], ["right"]])
    end

    it "orders within a column by position, not insertion" do
      section = build_section(page: build_page)
      build_block(section: section, content: "second", column: 0, position: 2)
      build_block(section: section, content: "first",  column: 0, position: 1)

      expect(section.reload.columns.first.map(&:content)).to eq(%w[first second])
    end
  end

  describe "#grid_template" do
    it "preserves the measured proportions" do
      section = build_section(page: build_page, column_widths: "2,1")
      build_block(section: section, column: 0)
      build_block(section: section, column: 1)

      expect(section.reload.grid_template).to eq("minmax(0, 2fr) minmax(0, 1fr)")
    end

    # If the measurement and the content ever disagree, equal columns is wrong
    # but legible; honouring a stale measurement would drop or squash content.
    it "falls back to equal columns when the widths do not match the columns" do
      section = build_section(page: build_page, column_widths: "2,1,1")
      build_block(section: section, column: 0)
      build_block(section: section, column: 1)

      expect(section.reload.grid_template).to eq("repeat(2, minmax(0, 1fr))")
    end

    it "falls back when nothing was measured at all" do
      section = build_section(page: build_page)
      build_block(section: section, column: 0)

      expect(section.reload.grid_template).to eq("repeat(1, minmax(0, 1fr))")
    end

    it "never emits repeat(0) for an empty section" do
      expect(build_section(page: build_page).grid_template)
        .to eq("repeat(1, minmax(0, 1fr))")
    end
  end

  it "rejects an unknown band style" do
    expect(described_class.new(page: build_page, style: "chartreuse")).not_to be_valid
  end

  it "destroys its blocks with it" do
    section = build_section(page: build_page)
    build_block(section: section)
    expect { section.destroy }.to change(Block, :count).by(-1)
  end
end
