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

    Say "a person", "someone", "a parishioner", "a server" — not "a man" or "a
    woman" — unless you are VERY sure, and say nothing about age either. These
    are real people in a small parish who will read their own description, and
    being called the wrong thing on your own church's website is a small, public
    unkindness. Clergy are the exception: a deacon, priest or bishop serving in
    vestments can be named by his office, because the office is what is visible
    and what the picture is about. When in doubt, describe what the person is
    DOING and leave out what you think they are.
  ASK

  # 300 was not enough and failed in the worst way. The model thinks before it
  # answers, and the whole budget went on thinking: the reply came back
  # stop_reason "max_tokens" with one `thinking` block and NO text. The job then
  # succeeded, wrote nothing, and the photograph sat saying "description being
  # written" for the rest of its life.
  MAX_TOKENS = 2_000

  retry_on Anthropic::Client::Error, wait: :polynomially_longer, attempts: 3

  def perform(photo_id)
    photo = Photo.find_by(id: photo_id)
    return if photo.nil? || photo.alt_text.present?
    return unless Anthropic::Client.configured?

    bytes = Admin::ImageTools.fit_bytes(photo.data, Admin::Tools::PHOTO_FIT)
    response = Anthropic::Client.new.call(
      system: "You write alt text for a parish website.",
      max_tokens: MAX_TOKENS,
      # Nothing here repeats between photographs, so caching would cost more
      # than it saves.
      cache: false,
      messages: [{ role: "user", content: [
        Anthropic::Client.image_block(bytes, "image/png"),
        { type: "text", text: PROMPT }
      ] }]
    )

    text = Array(response["content"]).filter_map { |c| c["text"] }.join.strip
    if text.present?
      photo.update_columns(alt_text: text, updated_at: Time.current)
      return
    end

    # No text came back. Say so rather than leaving the photograph looking like
    # it is still being worked on -- a job that silently does nothing is
    # indistinguishable from one that never ran.
    Rails.logger.warn(
      "no description for photo #{photo_id} (#{photo.human_name}): " \
      "stop_reason #{response['stop_reason'].inspect}, " \
      "blocks #{Array(response['content']).map { |c| c['type'] }.inspect}"
    )
    photo.update_columns(alt_text: UNDESCRIBED, updated_at: Time.current)
  rescue StandardError => e
    # A photograph without alt text is worse than one with, but losing the
    # upload over it would be worse still.
    Rails.logger.warn("could not describe photo #{photo_id}: #{e.class}: #{e.message}")
    photo&.update_columns(alt_text: UNDESCRIBED, updated_at: Time.current)
  end

  # Not blank, so nothing retries it forever, and recognisable, so the library
  # can offer to try again.
  UNDESCRIBED = "(not described — ask for a description, or write one)".freeze
end
