require "rails_helper"

# A turn whose process is killed never marks itself done.
#
# On 9 November 2026 two were left behind -- one by an out-of-memory restart,
# one by a deploy -- and the chat page reported the OLDER of them on every poll
# for the next fourteen hours. The banner read "Stopping..." over turns that
# were running perfectly well, repainted two or three times a second, and the
# only way through was to press Stop before every single request.
#
# The cause was `.first` on an unordered relation: the oldest unfinished row won
# forever. Three things fix it and each is checked below -- report the newest,
# never report a stranded one, and clear them when the page is opened.
RSpec.describe "Turns stranded by a restart", type: :request do
  let(:revision) { Revision.tap { build_page(slug: "home", title: "Home") }.open_sandbox }

  def message(state:, age:)
    revision.messages.create!(role: "assistant", state: state,
                              created_at: age.ago, updated_at: age.ago)
  end

  it "reports the current turn, not one stranded before it" do
    stranded = message(state: "stopping", age: 14.hours)
    current  = message(state: "working",  age: 10.seconds)

    get status_admin_revision_path(revision)
    body = JSON.parse(response.body)

    expect(body["working"]).to be(true)
    expect(body["stopping"]).to be(false),
      "the page reported stranded message ##{stranded.id} instead of ##{current.id}"
  end

  # Past the lock duration nothing can still be running: EditingTurnJob holds
  # its semaphore for exactly as long as a turn can take.
  it "does not report a stranded turn as working at all" do
    message(state: "working", age: EditingTurnJob::LOCK_DURATION + 1.minute)

    get status_admin_revision_path(revision)

    expect(JSON.parse(response.body)["working"]).to be(false)
  end

  it "still reports a turn that is merely slow" do
    message(state: "working", age: EditingTurnJob::LOCK_DURATION - 1.minute)

    get status_admin_revision_path(revision)

    expect(JSON.parse(response.body)["working"]).to be(true)
  end

  it "clears stranded turns when the page is opened" do
    stranded = message(state: "stopping", age: 14.hours)
    running  = message(state: "working",  age: 5.seconds)

    get admin_revision_path(revision)

    expect(stranded.reload.state).to eq("done")
    expect(running.reload.state).to eq("working"), "the live turn must be left alone"
  end
end
