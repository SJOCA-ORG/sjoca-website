require "rails_helper"

RSpec.describe EditingTurnJob do
  include ActiveJob::TestHelper

  let(:revision) { Revision.tap { build_page }.open_sandbox }

  # Typing a second request while the first was still running started a second
  # job on the same revision. Both rebuilt the conversation from the database
  # and both edited the same pages, while the page showed only one of them as
  # working -- so the second request looked swallowed. It was not; it was
  # racing the first.
  it "allows only one turn at a time per revision, keyed on the revision" do
    expect(described_class.concurrency_limit).to eq(1)
    expect(described_class.concurrency_key.call(revision.id))
      .to eq("editing-revision-#{revision.id}")
  end

  it "keys separate revisions separately, so two drafts do not block each other" do
    key = described_class.concurrency_key
    expect(key.call(1)).not_to eq(key.call(2))
  end

  # A restart or a deploy during a turn left the message marked done with EMPTY
  # content -- nothing to show for twenty-five calls of work.
  describe "when a turn is interrupted" do
    before { allow(Admin::Editor).to receive(:new).and_raise(Interrupt) }

    it "says what it had managed" do
      message = revision.messages.create!(
        role: "assistant", state: "working", content: "",
        progress: [{ "name" => "add_block", "summary" => "added a heading to the home page" },
                   { "name" => "get_page", "summary" => "looked at it", "read" => true }]
      )

      # Interrupt is not a StandardError -- which is the whole point: the job's
      # rescue does not catch a kill, only its ensure runs.
      begin
        described_class.perform_now(revision.id, "a change", message.id)
      rescue Exception # rubocop:disable Lint/RescueException
        nil
      end

      expect(message.reload.state).to eq("done")
      expect(message.content).to include("added a heading to the home page")
      expect(message.content).to include("carry on")
    end

    it "says so plainly when it had done nothing" do
      message = revision.messages.create!(role: "assistant", state: "working",
                                          content: "", progress: [])

      # Interrupt is not a StandardError -- which is the whole point: the job's
      # rescue does not catch a kill, only its ensure runs.
      begin
        described_class.perform_now(revision.id, "a change", message.id)
      rescue Exception # rubocop:disable Lint/RescueException
        nil
      end

      expect(message.reload.content).to include("Nothing was changed")
    end

    it "never leaves a message looking like it is still working" do
      message = revision.messages.create!(role: "assistant", state: "working",
                                          content: "", progress: [])

      # Interrupt is not a StandardError -- which is the whole point: the job's
      # rescue does not catch a kill, only its ensure runs.
      begin
        described_class.perform_now(revision.id, "a change", message.id)
      rescue Exception # rubocop:disable Lint/RescueException
        nil
      end

      expect(revision.messages.where(state: "working")).to be_empty
    end
  end

  # Queueing a second request while the first was running showed "I was
  # interrupted before I could do anything. Nothing was changed" -- and then
  # the queued turn ran and did the work perfectly. The cleanup was sweeping
  # EVERY working message on the revision, including the placeholder the
  # controller had just created for the request still waiting its turn.
  describe "a request waiting its turn" do
    it "is left alone when the running turn finishes" do
      editor = instance_double(Admin::Editor, call: Admin::Editor::Result.new(reply: "done"),
                                              working: nil)
      allow(Admin::Editor).to receive(:new).and_return(editor)
      queued = revision.messages.create!(role: "assistant", state: "working",
                                         content: "", progress: [])

      described_class.perform_now(revision.id, "the first request")

      expect(queued.reload.state).to eq("working")
      expect(queued.content).to be_blank
    end

    it "is left alone even when the running turn is killed" do
      mine = revision.messages.create!(role: "assistant", state: "working",
                                       content: "", progress: [])
      queued = revision.messages.create!(role: "assistant", state: "working",
                                         content: "", progress: [])
      allow(Admin::Editor).to receive(:new).and_raise(Interrupt)

      begin
        described_class.perform_now(revision.id, "the first request", mine.id)
      rescue Exception # rubocop:disable Lint/RescueException
        nil
      end

      expect(mine.reload.state).to eq("done")
      expect(queued.reload.state).to eq("working")
    end
  end

  describe "carrying on" do
    def result(unfinished:) = Admin::Editor::Result.new(reply: "x", unfinished: unfinished)

    def stub_editor(unfinished:)
      instance_double(Admin::Editor, call: result(unfinished: unfinished), working: nil)
        .tap { |e| allow(Admin::Editor).to receive(:new).and_return(e) }
    end

    it "queues another round when the work is unfinished" do
      stub_editor(unfinished: true)

      expect { described_class.perform_now(revision.id, "long job") }
        .to have_enqueued_job(described_class).with(revision.id, "long job", nil, 2)
    end

    it "stops at the last round rather than going round forever" do
      stub_editor(unfinished: true)

      expect { described_class.perform_now(revision.id, "long job", nil, described_class::MAX_ROUNDS) }
        .not_to have_enqueued_job(described_class)
    end

    it "does not queue anything when the work finished" do
      stub_editor(unfinished: false)

      expect { described_class.perform_now(revision.id, "short job") }
        .not_to have_enqueued_job(described_class)
    end
  end
end
