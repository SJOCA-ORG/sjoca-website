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

  it "carries the rules that were learned the hard way" do
    rules = reference[:rules].join(" ")
    expect(rules).to match(/empty string is TRUE/i)
    expect(rules).to match(/does NOT inherit/i)
    expect(rules).to match(/quote attribute values/i)
  end

  it "is reachable as a tool, so the AI can ask rather than guess" do
    expect(Admin::Tools.definitions.map { |t| t[:name] }).to include("liquid_guide")
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
