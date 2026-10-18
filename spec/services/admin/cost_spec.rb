require "rails_helper"

RSpec.describe Admin::Cost do
  def usage(**over)
    { "input" => 0, "output" => 0, "cache_read" => 0, "cache_write" => 0,
      "model" => "claude-opus-5" }.merge(over.stringify_keys)
  end

  it "prices fresh input and output at the published rates" do
    # 1M in at $15, 1M out at $75.
    expect(described_class.of(usage(input: 1_000_000))).to be_within(0.001).of(15.0)
    expect(described_class.of(usage(output: 1_000_000))).to be_within(0.001).of(75.0)
  end

  it "prices a cached read at a tenth of fresh input" do
    fresh = described_class.of(usage(input: 1_000_000))
    cached = described_class.of(usage(cache_read: 1_000_000))

    expect(cached).to be_within(0.001).of(fresh / 10)
  end

  it "prices a cache write above fresh input, since writing one costs more" do
    expect(described_class.of(usage(cache_write: 1_000_000)))
      .to be > described_class.of(usage(input: 1_000_000))
  end

  it "uses each model's own rates" do
    opus = described_class.of(usage(input: 1_000_000))
    sonnet = described_class.of(usage(input: 1_000_000, model: "claude-sonnet-5"))

    expect(opus).to be_within(0.001).of(sonnet * 5)
  end

  # Every message without a model recorded predates the move to Opus, so it ran
  # on Sonnet. Pricing them at Opus rates reported $101 for a session that cost
  # about $19.
  it "treats a missing model as Sonnet, which is what actually ran" do
    expect(described_class.of(usage(input: 1_000_000).except("model")))
      .to be_within(0.001).of(3.0)
  end

  it "says what the same turn would have cost with no cache" do
    u = usage(input: 1_000, cache_read: 100_000, output: 500)

    expect(described_class.uncached(u)).to be > described_class.of(u)
  end

  describe "formatting, where pennies matter" do
    it "does not round a real cost down to nothing" do
      expect(described_class.format(0.002)).to eq("<$0.01")
    end

    it "shows nothing as nothing" do
      expect(described_class.format(0)).to eq("$0.00")
    end

    it "shows ordinary amounts to the penny" do
      expect(described_class.format(1.2345)).to eq("$1.23")
    end
  end

  it "adds up a whole revision" do
    revision = Revision.tap { build_page }.open_sandbox
    revision.messages.create!(role: "assistant", content: "a", usage: usage(input: 1_000_000))
    revision.messages.create!(role: "assistant", content: "b", usage: usage(output: 1_000_000))

    expect(described_class.of_revision(revision)).to be_within(0.01).of(90.0)
  end

  it "ignores messages that carry no usage" do
    revision = Revision.tap { build_page }.open_sandbox
    revision.messages.create!(role: "user", content: "a change please")

    expect(described_class.of_revision(revision)).to eq(0.0)
  end
end
