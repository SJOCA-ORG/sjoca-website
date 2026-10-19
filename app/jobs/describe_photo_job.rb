# Writes the alt text for an uploaded photograph, by looking at it.
#
# Not a nicety. alt_text is what a screen reader announces, and it is also what
# find_photos searches -- so a photograph with none is invisible to the editor
# who later asks for "the one of the children at the picnic". Asking the person
# uploading twenty pictures to describe each one is how that stops happening.
#
# Out of the request because it is an API call per photograph; the upload must
# not wait on it.
class DescribePhotoJob < ApplicationJob
  queue_as :default

  PROMPT = <<~ASK.freeze
    Describe this photograph for the website of an Orthodox parish, in one or two
    sentences, as alt text for someone who cannot see it.

    Say what is actually there: who, doing what, where. Name vestment colours and
    liturgical objects where you can see them clearly — they are often how someone
    later finds the picture again. If it is an icon, say which saint if the
    inscription makes it plain.

    Do not begin with "a photograph of" or "an image of". Do not guess at names of
    people. Do not invent detail you cannot see. If it does not depict parish life
    at all, say so plainly and briefly.
  ASK

  def perform(photo_id)
    photo = Photo.find_by(id: photo_id)
    return if photo.nil? || photo.alt_text.present?
    return unless Anthropic::Client.configured?

    bytes = Admin::ImageTools.fit_bytes(photo.data, Admin::Tools::PHOTO_FIT)
    response = Anthropic::Client.new.call(
      system: "You write alt text for a parish website.",
      max_tokens: 300,
      # Nothing here repeats between photographs, so caching would cost more
      # than it saves.
      cache: false,
      messages: [{ role: "user", content: [
        Anthropic::Client.image_block(bytes, "image/png"),
        { type: "text", text: PROMPT }
      ] }]
    )

    text = Array(response["content"]).filter_map { |c| c["text"] }.join.strip
    photo.update_columns(alt_text: text, updated_at: Time.current) if text.present?
  rescue StandardError => e
    # A photograph without alt text is worse than one with, but losing the
    # upload over it would be worse still. It can be described later.
    Rails.logger.warn("could not describe photo #{photo_id}: #{e.class}: #{e.message}")
  end
end
