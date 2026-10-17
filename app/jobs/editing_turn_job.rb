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
    Rails.logger.error("editing turn failed: #{e.class}: #{e.message}")
    revision&.messages&.create!(
      role: "assistant", state: "done",
      content: "Something went wrong and the change was not completed: #{e.message}"
    )
  ensure
    # Whatever happened, nothing should be left looking like it is still working.
    revision&.messages&.where(state: "working")&.update_all(state: "done")
  end
end
