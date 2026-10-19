require "rails_helper"

# Realising it has misunderstood you and having to watch it work anyway is the
# worst minute in this interface.
RSpec.describe Admin::Editor, "stopping" do
  let(:revision) { Revision.tap { build_page }.open_sandbox }
  let(:client) { instance_double(Anthropic::Client) }
  let(:editor) { described_class.new(revision, client: client) }

  def a_tool_call(name = "list_pages", input = {})
    { "content" => [{ "type" => "tool_use", "id" => "t1", "name" => name, "input" => input }],
      "usage" => {} }
  end

  # Stop is noticed between steps, so the model is asked for at least one.
  def stop_after_first_step
    calls = 0
    allow(client).to receive(:call) do
      calls += 1
      revision.messages.where(state: "working").update_all(state: "stopping") if calls == 1
      a_tool_call
    end
  end

  it "stops rather than running to the step limit" do
    stop_after_first_step

    expect(editor.call("do something long").reply).to start_with("Stopped")
  end

  it "says plainly when it had changed nothing" do
    stop_after_first_step

    expect(editor.call("just have a look around").reply).to include("Nothing was changed")
  end

  it "says what it had already done, and that those changes are still there" do
    calls = 0
    allow(client).to receive(:call) do
      calls += 1
      revision.messages.where(state: "working").update_all(state: "stopping") if calls == 2
      a_tool_call("add_styles", { "css" => ".x { color: red }" })
    end

    reply = editor.call("restyle everything").reply

    expect(reply).to include("I had already done")
    expect(reply).to include("CSS")
    expect(reply).to include("still there")
  end

  it "keeps the record of what it did, so the change log is not lost" do
    stop_after_first_step
    editor.call("do something long")

    expect(revision.messages.last.tool_calls).to be_present
  end

  it "records the cost of the part that ran" do
    stop_after_first_step
    editor.call("do something long")

    expect(revision.messages.last.usage).to be_present
  end

  # A stopped turn is finished, not interrupted: nothing should pick it up.
  it "does not ask to be continued" do
    stop_after_first_step

    expect(editor.call("do something long").unfinished).to be_falsey
  end

  it "stops between steps rather than mid-step, so nothing is left half-done" do
    seen = []
    calls = 0
    allow(client).to receive(:call) do
      calls += 1
      seen << calls
      revision.messages.where(state: "working").update_all(state: "stopping") if calls == 1
      a_tool_call
    end

    editor.call("do something long")

    # One call made, its tool run, then the stop noticed at the top of the next
    # turn of the loop -- not in the middle of the first.
    expect(seen).to eq([1])
  end
end
