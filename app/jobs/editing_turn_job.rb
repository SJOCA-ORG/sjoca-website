# One turn of the editing conversation, run outside the web request.
#
# A turn takes ten to sixty seconds -- the model thinks, calls tools, renders
# pages, sometimes opens a browser. Doing that inside a request means a frozen
# page with no sign of life. Here the page polls and watches the work happen.
class EditingTurnJob < ApplicationJob
  queue_as :default

  # One turn at a time per revision, and the others WAIT rather than being
  # dropped.
  #
  # Typing a second request while the first is still running started a second
  # job on the same revision. Both rebuilt the conversation from the database,
  # both edited the same pages, and the page only ever showed the first one as
  # working -- so the second request looked like it had been swallowed. It had
  # not; it was running underneath, racing the first.
  limits_concurrency to: 1, key: ->(revision_id, *) { "editing-revision-#{revision_id}" },
                     duration: 20.minutes

  # A long request does not fit in one turn, and stopping to say so wastes the
  # person's time: they only ever answer "yes, carry on". So it carries on by
  # itself, up to a bound, because "keep going" without one is how a loop runs
  # all night.
  MAX_ROUNDS = 4

  def perform(revision_id, text, placeholder_id = nil, round = 1)
    revision = Revision.find(revision_id)
    result = Admin::Editor.new(revision).call(text, placeholder_id: placeholder_id, round: round)

    continue(revision, text, round, result) if result&.unfinished && round < MAX_ROUNDS
    result
  rescue StandardError => e
    # WITH the backtrace. Logging only the class and the message turned
    # "no implicit conversion of Symbol into Integer" into a half-hour of
    # reading code, when one line would have named the file.
    Rails.logger.error("editing turn failed: #{e.class}: #{e.message}\n" +
                       e.backtrace.to_a.grep(/#{Regexp.escape(Rails.root.to_s)}/).first(8).join("\n"))

    # The person reading this is a parish volunteer. A Ruby exception message
    # tells them nothing they can act on, so say what it means for them and
    # keep the detail for whoever can use it.
    where = e.backtrace.to_a.grep(/#{Regexp.escape(Rails.root.to_s)}/).first.to_s
                      .sub("#{Rails.root}/", "").split(":in ").first
    revision&.messages&.create!(
      role: "assistant", state: "done",
      content: "Something went wrong at my end and the change was not finished. " \
               "Nothing was published, and the draft is as it was before this request. " \
               "Worth telling whoever looks after the site: #{e.class} in #{where} — #{e.message}"
    )
  ensure
    # Whatever happened, nothing should be left looking like it is still
    # working. A turn killed mid-flight -- a restart, a deploy -- used to be
    # marked done with EMPTY content, which reads as the system having nothing
    # to say about twenty-five calls' worth of work. Say what it managed.
    revision&.messages&.where(state: "working")&.find_each do |message|
      done = Array(message.progress).reject { |t| t["failed"] || t["read"] || t["say"] }
                                    .filter_map { |t| t["summary"] }
      message.update!(
        state: "done",
        content: message.content.presence ||
                 if done.any?
                   "I was interrupted part way through. I had done: #{done.join('; ')}. " \
                   "Ask me to carry on and I will pick it up from there."
                 else
                   "I was interrupted before I could do anything. Nothing was changed."
                 end
      )
    end
  end

  private

  # Pick it up in a new turn rather than a longer one: a fresh turn re-reads the
  # conversation, so what the last round did is already written down, and the
  # cached prompt makes the continuation cheap.
  #
  # The next round makes its OWN placeholder. Creating it here put a message in
  # "working" that this job's ensure block then swept to "done" on its way out
  # -- the continuation was marked finished before it had begun.
  def continue(revision, text, round, _result)
    self.class.perform_later(revision.id, text, nil, round + 1)
  end
end
