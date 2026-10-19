require "rails_helper"

# Three requests in a row -- each a photograph to rotate, crop and place --
# ended with "I ran out of steps before finishing", and every time the person
# read it and typed some version of "carry on". That is a question with one
# answer, so it should not be asked.
RSpec.describe Admin::Editor, "running out of steps" do
  let(:revision) { Revision.tap { build_page }.open_sandbox }
  let(:client) { instance_double(Anthropic::Client) }
  let(:editor) { described_class.new(revision, client: client) }

  # A model that never stops calling tools, which is what exhausts a round.
  def always_working
    { "content" => [{ "type" => "tool_use", "id" => "t1", "name" => "list_pages",
                      "input" => {} }], "usage" => {} }
  end

  before { allow(client).to receive(:call).and_return(always_working) }

  it "says it is carrying on, not that it has given up" do
    reply = editor.call("do something long").reply

    expect(reply).to include("Carrying on")
    expect(reply).not_to include("ran out of steps")
  end

  it "marks the result unfinished, so the job knows to pick it up" do
    expect(editor.call("do something long").unfinished).to be(true)
  end

  it "says what it managed so far" do
    allow(client).to receive(:call).and_return(
      { "content" => [{ "type" => "tool_use", "id" => "t1", "name" => "add_styles",
                        "input" => { "css" => ".x { color: red }" } }], "usage" => {} }
    )

    expect(editor.call("do something long").reply).to match(/So far:.*CSS/)
  end

  it "stops asking for more rounds at the bound, since forever is not a bound" do
    result = editor.call("do something long", round: EditingTurnJob::MAX_ROUNDS)

    expect(result.unfinished).to be_falsey
    expect(result.reply).to include("as far as I can take this")
  end

  it "tells the model it is continuing, not starting again" do
    sent = []
    allow(client).to receive(:call) { |args| sent.concat(args[:messages]); always_working }

    editor.call("do something long", round: 2)

    expect(sent.map { |m| m[:content].to_s }.join).to include("Carry on with the request above")
  end

  it "does not say that on the first round" do
    sent = []
    allow(client).to receive(:call) { |args| sent.concat(args[:messages]); always_working }

    editor.call("do something long")

    expect(sent.map { |m| m[:content].to_s }.join).not_to include("Carry on with the request above")
  end

  # The placeholder this turn is about to fill in is an empty assistant
  # message. Sending it caused "cache_control cannot be set for empty text
  # blocks" and lost the whole turn.
  it "does not send the empty placeholder it is about to fill in" do
    sent = []
    allow(client).to receive(:call) { |args| sent.concat(args[:messages]); always_working }
    revision.messages.create!(role: "user", content: "earlier")
    revision.messages.create!(role: "assistant", state: "working", content: "")

    editor.call("do something long")

    expect(sent.map { |m| (m[:content] || m["content"]).to_s }).to all(be_present)
  end

  it "records the cost of the round even when it did not finish" do
    expect(editor.call("do something long")).to be_present
    expect(revision.messages.last.usage).to be_present
  end
end
