require "rails_helper"

# Asked to add a paragraph BETWEEN two photographs, it inserted at position 1 --
# where the second photograph already sat -- and did not move it. Two blocks on
# one number, the paragraph rendered after both, and the reply said it sat
# between them. Nothing failed.
RSpec.describe Admin::Tools, "placing blocks" do
  let(:revision) { Revision.tap { build_page(slug: "home", title: "Home") }.open_sandbox }
  let(:tools) { described_class.new(revision) }
  let(:section) { revision.pages.find_by(slug: "home").sections.create!(revision: revision, position: 0, style: "plain") }

  def add(kind, content, **extra)
    tools.call("add_block", { "section_id" => section.id, "kind" => kind,
                              "content" => content }.merge(extra))
  end

  def order = section.blocks.where(column: 0).order(:position, :id).pluck(:content)

  before do
    add("text", "first")
    add("text", "last")
  end

  it "puts a block between two others when told which to sit after" do
    first = section.blocks.find_by(content: "first")
    add("text", "middle", "after_block" => first.id)

    expect(order).to eq(%w[first middle last])
  end

  it "puts a block before another" do
    last = section.blocks.find_by(content: "last")
    add("text", "middle", "before_block" => last.id)

    expect(order).to eq(%w[first middle last])
  end

  it "leaves no two blocks sharing a position" do
    first = section.blocks.find_by(content: "first")
    add("text", "middle", "after_block" => first.id)

    ties = section.blocks.reorder(nil).group(:column, :position).having("count(*) > 1").count
    expect(ties).to be_empty
  end

  # The bug exactly: an explicit number landing on an occupied slot.
  it "makes room even when given a raw position number" do
    add("text", "middle", "position" => 1)

    expect(order).to eq(%w[first middle last])
  end

  it "says what it ended up between, so the answer is checkable" do
    first = section.blocks.find_by(content: "first")
    result = add("text", "middle", "after_block" => first.id)

    expect(result[:summary]).to include("after first")
    expect(result[:summary]).to include("before last")
  end

  it "moves an existing block between two others" do
    stray = section.blocks.find_by(content: "last")
    first = section.blocks.find_by(content: "first")
    add("text", "third")

    tools.call("move_block", { "id" => stray.id, "after_block" => first.id })

    expect(order).to eq(%w[first last third])
  end

  it "refuses an anchor that is not in the section" do
    expect { add("text", "middle", "after_block" => 999_999) }
      .to raise_error(described_class::ToolError, /not in section/)
  end

  # What the loop hands back to the model instead of only a picture.
  it "reports the real order as data" do
    first = section.blocks.find_by(content: "first")
    add("text", "middle", "after_block" => first.id)

    layout = tools.structure_of("home")
    expect(layout).to match(/col0\.0.*first/m)
    expect(layout).to match(/col0\.1.*middle/m)
    expect(layout).to match(/col0\.2.*last/m)
  end
end
