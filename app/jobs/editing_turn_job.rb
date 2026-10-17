# One turn of the editing conversation, run outside the web request.
#
# A turn takes ten to sixty seconds -- the model thinks, calls tools, renders
# pages, sometimes opens a browser. Doing that inside a request means a frozen
# page with no sign of life. Here the page polls and watches the work happen.
class EditingTurnJob < ApplicationJob
  queue_as :default

  def perform(revision_id, text, placeholder_id = nil)
    revision = Revision.find(revision_id)
    Admin::Editor.new(revision).call(text, placeholder_id: placeholder_id)
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
    # Whatever happened, nothing should be left looking like it is still working.
    revision&.messages&.where(state: "working")&.update_all(state: "done")
  end
end
