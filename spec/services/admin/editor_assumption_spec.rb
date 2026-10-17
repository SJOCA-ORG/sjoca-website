require "rails_helper"

# Asked to put a title across a hero, it answered "Done -- the hero now has
# that title written across it" after ONE API call, 46 output tokens, and no
# tool calls at all. The title had been set a turn earlier, so it believed the
# job was done and answered from memory. Something else on the page was
# overriding it, which it would have seen had it looked.
#
# Every other safeguard in the loop is gated on having done something, so the
# one turn that does nothing was the one turn nothing checked.
RSpec.describe Admin::Editor, "answering without looking" do
  let(:revision) { Revision.tap { build_page }.open_sandbox }
  let(:client) { instance_double(Anthropic::Client) }
  let(:editor) { described_class.new(revision, client: client) }

  def said(text) = { "content" => [{ "type" => "text", "text" => text }], "usage" => {} }

  it "challenges a claim made with no tool calls behind it" do
    sent = []
    allow(client).to receive(:call) { |args| sent << args[:messages].last; said("Done.") }

    editor.call("put the title across the hero")

    nudge = sent.compact.map { |m| m[:content].to_s }.join
    expect(nudge).to include("you have not looked at anything")
    expect(nudge).to include("CHECK IT FIRST")
  end

  it "tells it that earlier conversation is not evidence" do
    allow(client).to receive(:call).and_return(said("Done."))

    sent = []
    allow(client).to receive(:call) { |args| sent << args[:messages].last; said("Done.") }
    editor.call("put the title across the hero")

    expect(sent.compact.map { |m| m[:content].to_s }.join).to include("not evidence")
  end

  it "lets the second answer through, so a plain question still works" do
    allow(client).to receive(:call).and_return(said("Nothing to change."), said("As I said."))

    expect(editor.call("what is a block?").reply).to eq("As I said.")
  end

  it "challenges only once, never looping" do
    calls = 0
    allow(client).to receive(:call) { calls += 1; said("Done.") }

    editor.call("put the title across the hero")

    expect(calls).to eq(2)
  end

  it "does not challenge a turn that actually did something" do
    used = { "content" => [{ "type" => "tool_use", "id" => "t1", "name" => "add_styles",
                             "input" => { "css" => ".x { color: red }" } }], "usage" => {} }
    calls = 0
    allow(client).to receive(:call) { calls += 1; calls == 1 ? used : said("Changed it.") }
    allow(editor).to receive(:verify).and_return([])
    allow(editor).to receive(:look_at_it).and_return(nil)

    expect(editor.call("make the heading red").reply).to eq("Changed it.")
    expect(calls).to eq(2)   # the tool call, then the reply -- no challenge
  end

  # The same must hold for a turn that only LOOKED: reading counts as looking.
  it "does not challenge a turn that only read something" do
    looked = { "content" => [{ "type" => "tool_use", "id" => "t1", "name" => "list_pages",
                               "input" => {} }], "usage" => {} }
    calls = 0
    allow(client).to receive(:call) { calls += 1; calls == 1 ? looked : said("Here they are.") }

    expect(editor.call("what pages are there?").reply).to eq("Here they are.")
    expect(calls).to eq(2)
  end
end
