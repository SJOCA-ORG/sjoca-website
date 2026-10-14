require "rails_helper"

# The reference is generated from the Drop classes rather than written down,
# because a hand-maintained list drifts: someone adds a property and the AI
# never learns it, or removes one and the AI keeps trying to use it.
RSpec.describe Admin::DropReference do
  subject(:reference) { described_class.call }

  it "documents every drop a template can reach" do
    paths = reference[:objects].map { |o| o[:path] }
    expect(paths).to include("page", "site", "block", "photo", "nav", "section")
    expect(paths).to include("site.calendar", "site.lectionary", "site.lectionary.today")
  end

  it "stays in step with the code automatically" do
    page = reference[:objects].find { |o| o[:path] == "page" }
    expect(page[:properties]).to match_array(PageDrop.public_instance_methods(false).map(&:to_s) - ["initialize"])
  end

  it "omits predicate methods, which Liquid cannot call" do
    block = reference[:objects].find { |o| o[:path] == "block" }
    expect(block[:properties]).not_to include("map?")
    expect(block[:properties]).to include("is_map")
  end

  it "hands back lessons the AI recorded in earlier sessions" do
    Lesson.create!(subject: "liquid", body: "The weekly bulletin block must stay first in its band.")

    expect(described_class.call[:learned].map { |l| l[:lesson] })
      .to include(/weekly bulletin/)
  end

  it "omits lessons that a person has switched off" do
    Lesson.create!(subject: "liquid", body: "Something that turned out to be wrong.", active: false)

    expect(described_class.call[:learned]).to be_empty
  end

  it "carries the rules that were learned the hard way" do
    rules = reference[:rules].join(" ")
    expect(rules).to match(/empty string is TRUE/i)
    expect(rules).to match(/SHARES the surrounding scope/i)
    expect(rules).to match(/quote attribute values/i)
  end

  it "is reachable as a tool, so the AI can ask rather than guess" do
    expect(Admin::Tools.definitions.map { |t| t[:name] }).to include("liquid_guide")
  end

  # It referenced a drop class that had been renamed, so liquid_guide -- the tool
  # that teaches the AI the rules -- raised NameError every time it was called.
  # The AI worked around it by exploring, and nothing reported the breakage.
  it "actually builds, rather than naming a class that no longer exists" do
    expect { described_class.call }.not_to raise_error
  end

  it "names only drop classes that are defined" do
    (described_class::ROOTS.merge(described_class::NESTED)).each do |path, (klass, _)|
      expect(klass).to be_a(Class), "#{path} does not point at a real class"
    end
  end

  # Every tool the AI is offered must actually be callable.
  it "offers no tool without a method behind it" do
    build_page   # so there is live content to branch from
    tools = Admin::Tools.new(Revision.open_sandbox)
    Admin::Tools.definitions.each do |definition|
      expect(tools.respond_to?(definition[:name], true))
        .to be(true), "tool #{definition[:name]} is advertised but has no method"
    end
  end

  # Every property named must actually work when a template calls it.
  it "names only properties that really resolve" do
    page = build_page
    drop = PageDrop.new(page)
    reference[:objects].find { |o| o[:path] == "page" }[:properties].each do |prop|
      expect { drop.public_send(prop) }.not_to raise_error, "page.#{prop} is documented but fails"
    end
  end
end
