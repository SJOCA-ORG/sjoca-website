require "rails_helper"

# A reply that hits the length limit stops mid-sentence. What comes back can
# contain no complete tool call and no text at all, and the loop fell straight
# through to "(no reply)" -- a turn that did nothing and explained nothing.
#
# This happened on a real request (rewriting the leadership page) and is the
# worst kind of failure here: silent, and indistinguishable from the system
# being broken.
RSpec.describe Admin::Editor, "when a reply is cut off" do
  let(:revision) { Revision.tap { build_page }.open_sandbox }
  let(:client) { instance_double(Anthropic::Client) }
  let(:editor) { described_class.new(revision, client: client) }

  def cut_off = { "content" => [], "stop_reason" => "max_tokens", "usage" => {} }
  def spoke(text) = { "content" => [{ "type" => "text", "text" => text }], "usage" => {} }

  it "tells the model it was cut off and lets it try again, smaller" do
    allow(client).to receive(:call).and_return(cut_off, spoke("Done, in smaller pieces."))

    expect(editor.call("rewrite the leadership page").reply).to include("smaller pieces")
  end

  it "passes the advice back as a message the model can act on" do
    sent = []
    allow(client).to receive(:call) { |args| sent << args[:messages].last; cut_off }

    editor.call("do something enormous")

    nudge = sent.compact.map { |m| m[:content].to_s }.join
    expect(nudge).to include("cut off")
    expect(nudge).to include("Do LESS in one go")
  end

  it "gives up after three, and says something a person can act on" do
    allow(client).to receive(:call).and_return(cut_off)

    reply = editor.call("do something enormous").reply

    expect(reply).to include("length limit")
    expect(reply).to include("splitting it")
    expect(reply).not_to include("no reply")
  end

  it "never answers with (no reply)" do
    allow(client).to receive(:call).and_return({ "content" => [], "usage" => {} })

    reply = editor.call("say nothing at all").reply

    expect(reply).not_to include("(no reply)")
    expect(reply).to be_present
  end

  it "says what it changed when it changed something but said nothing" do
    allow(client).to receive(:call).and_return({ "content" => [], "usage" => {} })
    editor.instance_variable_get(:@tools).call("add_styles", { "css" => ".x{color:red}" })

    # A turn that edits and then goes quiet should still report the edit.
    allow(editor).to receive(:verify).and_return([])
    expect(editor.call("make it red").reply).to be_present
  end
end
