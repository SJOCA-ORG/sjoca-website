require "rails_helper"

# A tool nobody calls is not a safeguard. The three seeing tools existed for a
# day with nothing in the prompt mentioning them, so verification is part of the
# loop rather than something the model has to remember.
RSpec.describe "Automatic verification" do
  let(:live) do
    test_revision.tap do
      build_page(slug: "giving",  title: "Giving",  nav_title: "Giving",  position: 1)
      build_page(slug: "contact", title: "Contact", nav_title: "Contact", position: 2)
      build_page(slug: "about",   title: "About",   nav_title: "About",   position: 3)
    end
  end
  let(:draft) { live && Revision.open_sandbox }

  before do
    section = draft.pages.find_by(slug: "giving").sections.create!(revision: draft, style: "plain")
    section.blocks.create!(revision: draft, kind: "heading", content: "Financially Support")
  end

  # Nothing is re-rendered when nothing changed; a question costs no checking.
  it "does not run after a turn that only looked at things" do
    tools = Admin::Tools.new(draft)
    tools.call("get_page", { "slug" => "giving" })

    expect(tools.touched).to include("giving")
    expect(described_class_verify([{ "name" => "get_page", "read" => true }], tools)).to be_empty
  end

  it "catches a template the model broke, before the reply is shown" do
    tools = Admin::Tools.new(draft)
    tools.call("set_template", { "name" => "block/heading",
                                 "source" => "<h2>{{ block.does_not_exist }}</h2>" })

    problems = described_class_verify([{ "name" => "set_template", "summary" => "rewrote" }], tools)

    expect(problems.join).to match(/does_not_exist/)
  end

  it "knows which pages a change landed on, so it checks the right ones" do
    tools = Admin::Tools.new(draft)
    block = draft.blocks.first
    tools.call("update_block", { "id" => block.id, "content" => "Changed" })

    expect(tools.touched).to include("giving")
  end

  # A template or stylesheet change affects every page, so a sample is checked
  # rather than one page -- but checking all thirteen every turn is wasteful.
  it "widens the check when something site-wide changes" do
    tools = Admin::Tools.new(draft)
    tools.call("add_styles", { "css" => ".x { color: red }" })

    expect(tools.touched.size).to be > 1
  end

  def described_class_verify(performed, tools)
    editor = Admin::Editor.allocate
    editor.instance_variable_set(:@revision, draft)
    editor.instance_variable_set(:@tools, tools)
    editor.send(:verify, performed)
  end
end
