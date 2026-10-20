require "rails_helper"

# Demo mode exists so the admin can be shown to a room. Twice now the cost has
# leaked back onto the screen after being hidden -- first the per-turn readout,
# then the "what it did" summary on every reply, which nobody thought of as a
# cost display because it is mostly token counts.
#
# So this does not check the places money is written. It checks the page for
# money, and only then checks that the same page shows it when demo mode is
# off -- because a test that passes against a blank page proves nothing.
RSpec.describe "demo mode", type: :request do
  MONEY = /\$\d/

  let(:revision) { Revision.tap { build_page }.open_sandbox }

  before do
    revision.messages.create!(role: "user", content: "make the heading bigger")
    revision.messages.create!(
      role: "assistant", content: "Done.",
      tool_calls: [{ "name" => "set_block", "summary" => "changed the heading" }],
      usage: { "calls" => 7, "input" => 11_300, "output" => 900, "cache_read" => 240_000 }
    )
  end

  after { Demo.off! }

  it "shows no money anywhere on the editing page" do
    Demo.on!
    get "/admin/revisions/#{revision.id}"
    expect(response.body).not_to match(MONEY)
  end

  it "shows money on that same page when demo mode is off" do
    Demo.off!
    get "/admin/revisions/#{revision.id}"
    expect(response.body).to match(MONEY)
  end

  it "shows no money on the revisions list" do
    Demo.on!
    get "/admin"
    expect(response.body).not_to match(MONEY)
  end

  it "lists standing promises but does not run them" do
    promise = Promise.create!(summary: "the heading is there", intent: "it matters",
                              script: "return {pass: true};", created_by: "spec",
                              introduced_in: revision.id)
    revision.revision_promises.create!(promise: promise)

    Demo.on!
    # No browser is started: that is the whole point of pausing them.
    expect(Open3).not_to receive(:capture3)

    results = Admin::PromiseRunner.new(revision).call

    expect(results.size).to eq(1)
    expect(results.first[:summary]).to eq("the heading is there")
    expect(results.first[:paused]).to be(true)
    expect(results.first[:message]).to include("paused")
  end
end
