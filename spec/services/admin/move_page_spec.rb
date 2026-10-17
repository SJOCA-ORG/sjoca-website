require "rails_helper"

# "Move Donate after Education & Resources" has no honest expression as an
# integer. Asked for one, the AI set Donate's position to 5 -- which Community
# Outreach already held -- and the order between them became whatever Postgres
# returned. The menu was wrong and nothing had failed.
RSpec.describe Admin::Tools, "move_page" do
  let(:revision) { Revision.tap { build_page(slug: "home", title: "Home") }.open_sandbox }
  let(:tools) { described_class.new(revision) }

  before do
    %w[about events education donate outreach contact].each_with_index do |slug, i|
      revision.pages.create!(slug: slug, title: slug.titleize, nav_title: slug.titleize,
                             position: i + 2)
    end
  end

  def order = revision.pages.where(parent_slug: nil).order(:position, :id).pluck(:slug)

  it "moves a page after another and renumbers the rest" do
    tools.call("move_page", { "slug" => "donate", "after" => "education" })

    expect(order).to eq(%w[home about events education donate outreach contact])
    expect(revision.pages.where(parent_slug: nil).pluck(:position).sort).to eq((1..7).to_a)
  end

  it "moves a page before another" do
    tools.call("move_page", { "slug" => "contact", "before" => "about" })

    expect(order).to eq(%w[home contact about events education donate outreach])
  end

  it "leaves no two pages sharing a position" do
    tools.call("move_page", { "slug" => "donate", "after" => "education" })

    ties = revision.pages.group(:parent_slug, :position).having("count(*) > 1").count
    expect(ties).to be_empty
  end

  it "says what the menu now reads, so the result is checkable" do
    result = tools.call("move_page", { "slug" => "donate", "after" => "education" })

    expect(result[:summary]).to include("Education, Donate, Outreach")
  end

  it "refuses to move a page next to one at another level" do
    revision.pages.create!(slug: "about/story", title: "Story", nav_title: "Story",
                           parent_slug: "about", position: 1)

    expect { tools.call("move_page", { "slug" => "donate", "after" => "about/story" }) }
      .to raise_error(described_class::ToolError, /top level/)
  end

  it "refuses an anchor that does not exist" do
    expect { tools.call("move_page", { "slug" => "donate", "after" => "nowhere" }) }
      .to raise_error(described_class::ToolError, /no page "nowhere"/)
  end

  it "insists on being told where" do
    expect { tools.call("move_page", { "slug" => "donate" }) }
      .to raise_error(described_class::ToolError, /after.*before/)
  end
end
