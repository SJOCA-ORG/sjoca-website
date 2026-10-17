require "digest"

# One cached response from the outside world, keyed by URL and shared across
# revisions. Not revision-scoped on purpose: a megabyte of fetched HTML copied
# into every sandbox anyone opens would be a lot of database for no benefit.
class FetchedPage < ApplicationRecord
  validates :key, :url, presence: true

  def self.key_for(url) = Digest::SHA256.hexdigest(url.to_s)

  # Serve what we have if it is young enough. Otherwise fetch -- and if the
  # fetch fails but we still hold something, SERVE THE STALE COPY. A parish site
  # showing last night's calendar is fine; one showing an error because
  # ChurchTrac is briefly down is not.
  def self.for(url, max_age_minutes: 60)
    row = find_or_initialize_by(key: key_for(url))
    row.url = url
    return row if row.fresh?(max_age_minutes)

    begin
      result = Site::OutboundFetch.call(url)
      row.update!(body: result.body, content_type: result.content_type,
                  status: result.status, error: nil, fetched_at: Time.current)
    rescue Site::OutboundFetch::Refused => e
      row.assign_attributes(error: e.message, status: nil)
      row.fetched_at ||= nil
      row.save!
      raise if row.body.blank?
    end

    row
  end

  def fresh?(max_age_minutes)
    fetched_at.present? && body.present? && fetched_at > max_age_minutes.to_i.minutes.ago
  end

  def stale? = error.present? && body.present?

  def age_text
    return "never fetched" if fetched_at.blank?

    "#{ActionController::Base.helpers.time_ago_in_words(fetched_at)} ago"
  end

  # Valid JSON, whatever came back, so a template can embed it and a script can
  # JSON.parse it exactly once. If the source sent JSON it is passed through; if
  # it sent HTML it becomes a JSON string. Either way one parse gets you
  # something usable, and nothing can break out of the script tag.
  def as_json_payload
    parsed = JSON.parse(body.to_s)
    JSON.generate(parsed)
  rescue JSON::ParserError
    JSON.generate(body.to_s)
  end
end
