require "rails_helper"

# One editing session ran 30 turns for 5,979,000 input tokens against 87,000
# output. It was paying, over and over, to re-read its own past: the
# instructions, fifty-odd tool definitions, and a conversation that only grows.
# A turn with ten tool calls re-sends all of it ten times.
RSpec.describe Anthropic::Client, "prompt caching" do
  let(:client) { described_class.new(api_key: "test") }

  def body_sent
    captured = nil
    allow(Net::HTTP).to receive(:start) do |*_args, &blk|
      http = instance_double(Net::HTTP)
      allow(http).to receive(:post) do |_path, body, _headers|
        captured = JSON.parse(body)
        response = instance_double(Net::HTTPOK, body: '{"content":[],"usage":{}}', code: "200")
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        response
      end
      blk.call(http)
    end
    yield
    captured
  end

  def tools
    [{ name: "a", description: "x", input_schema: {} },
     { name: "b", description: "y", input_schema: {} }]
  end

  it "marks the system prompt, which changes only when the stylesheet does" do
    sent = body_sent { client.call(system: "instructions", messages: [{ role: "user", content: "hi" }]) }

    expect(sent["system"]).to eq([{ "type" => "text", "text" => "instructions",
                                    "cache_control" => { "type" => "ephemeral" } }])
  end

  # The breakpoint covers everything before it, so one mark on the last tool
  # caches the whole list.
  it "marks the last tool, caching all of them" do
    sent = body_sent { client.call(system: "s", messages: [{ role: "user", content: "hi" }], tools: tools) }

    expect(sent["tools"].first).not_to have_key("cache_control")
    expect(sent["tools"].last["cache_control"]).to eq("type" => "ephemeral")
  end

  # The one that actually grows, and so the one that matters.
  it "caches the conversation up to the newest exchange" do
    history = [{ role: "user", content: "one" },
               { role: "assistant", content: "two" },
               { role: "user", content: "three" }]
    sent = body_sent { client.call(system: "s", messages: history) }

    expect(sent["messages"][1]["content"].last["cache_control"]).to eq("type" => "ephemeral")
    expect(sent["messages"].last["content"]).to eq("three")
  end

  it "turns a string into a block, since cache_control cannot sit on a string" do
    history = [{ role: "user", content: "one" }, { role: "assistant", content: "two" }]
    sent = body_sent { client.call(system: "s", messages: history) }

    expect(sent["messages"].first["content"]).to be_an(Array)
    expect(sent["messages"].first["content"].first["text"]).to eq("one")
  end

  it "leaves a single message alone, there being no prefix to cache" do
    sent = body_sent { client.call(system: "s", messages: [{ role: "user", content: "only" }]) }

    expect(sent["messages"].first["content"]).to eq("only")
  end

  it "can be turned off" do
    sent = body_sent { client.call(system: "s", messages: [{ role: "user", content: "hi" }], cache: false) }

    expect(sent["system"]).to eq("s")
  end
end
