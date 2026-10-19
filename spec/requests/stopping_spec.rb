require "rails_helper"

# 256 seconds of "Working..." with no steps and no feedback. The turn was not
# running at all: it was BLOCKED behind a concurrency semaphore at value 0,
# held by a job row that Stop had deleted outright. SolidQueue releases a
# semaphore when a job FINISHES, and a deleted row never finishes.
RSpec.describe "stopping a turn", type: :request do
  let(:revision) { Revision.tap { build_page }.open_sandbox }
  let(:lock_key) { "EditingTurnJob/editing-revision-#{revision.id}" }

  it "releases the concurrency lock, so the next request is not blocked behind nothing" do
    SolidQueue::Semaphore.create!(key: lock_key, value: 0, expires_at: 20.minutes.from_now)

    post "/admin/revisions/#{revision.id}/stop"

    expect(SolidQueue::Semaphore.where(key: lock_key)).to be_empty
  end

  it "asks a running turn to stop rather than killing it mid-step" do
    message = revision.messages.create!(role: "assistant", state: "working", content: "")

    post "/admin/revisions/#{revision.id}/stop"

    expect(message.reload.state).to eq("stopping")
  end

  it "says so when there was nothing to stop" do
    post "/admin/revisions/#{revision.id}/stop"

    expect(flash[:notice]).to match(/Nothing was running/)
  end

  it "leaves another revision's lock alone" do
    other = "EditingTurnJob/editing-revision-#{revision.id + 999}"
    SolidQueue::Semaphore.create!(key: other, value: 0, expires_at: 20.minutes.from_now)

    post "/admin/revisions/#{revision.id}/stop"

    expect(SolidQueue::Semaphore.where(key: other)).to be_present
  end

  # "Working..." with an animated ellipsis and no steps is the most misleading
  # thing this page can show.
  describe "a turn that has not started" do
    it "is reported as stalled once it has sat for a minute" do
      revision.messages.create!(role: "assistant", state: "working", content: "",
                                progress: [], created_at: 2.minutes.ago)

      get "/admin/revisions/#{revision.id}/status"

      expect(response.parsed_body["stalled"]).to be(true)
    end

    it "is not called stalled while it is merely new" do
      revision.messages.create!(role: "assistant", state: "working", content: "", progress: [])

      get "/admin/revisions/#{revision.id}/status"

      expect(response.parsed_body["stalled"]).to be(false)
    end

    it "is not called stalled when it is plainly working" do
      revision.messages.create!(role: "assistant", state: "working", content: "",
                                progress: [{ "name" => "get_page" }], created_at: 5.minutes.ago)

      get "/admin/revisions/#{revision.id}/status"

      expect(response.parsed_body["stalled"]).to be(false)
    end
  end
end
