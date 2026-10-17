# An outside source of data, named by whoever set it up, belonging to a revision.
#
# This is the one primitive that replaces per-feed Ruby. Before it, each source
# the parish wanted -- the ChurchTrac calendar, the class recordings, the daily
# readings -- meant a developer writing an importer, a model, a drop and a cron
# job. Now it is a row: a name and one or more URLs. The server fetches them
# (guarded -- see Site::OutboundFetch), caches the result, and hands it to the
# page as JSON. Everything after that is JavaScript the AI writes.
class DataSource < ApplicationRecord
  NAME = /\A[a-z0-9][a-z0-9-]{0,40}\z/

  belongs_to :revision

  validates :name, presence: true, format: {
    with: NAME,
    message: "must be lower case letters, numbers and hyphens — it becomes an id in the page"
  }, uniqueness: { scope: :revision_id, message: "is already set up in this revision" }
  validates :refresh_minutes, numericality: { greater_than_or_equal_to: 5,
                                              less_than_or_equal_to: 10_080 }
  validate :at_least_one_url
  validate :urls_are_fetchable

  def url_list = Array(urls).map(&:to_s).map(&:strip).reject(&:blank?)

  def domains = url_list.filter_map { |u| URI.parse(u).host rescue nil }.uniq

  # Every page, fetched or served from cache. One URL gives one payload; several
  # give an array, so a date range (the daily readings, say) is one source.
  def pages = url_list.map { |u| FetchedPage.for(u, max_age_minutes: refresh_minutes) }

  def payload
    rows = pages
    return rows.first.as_json_payload if rows.one?

    JSON.generate(rows.map { |r| { "url" => r.url, "body" => parse_or_string(r.body) } })
  end

  private

  def parse_or_string(body)
    JSON.parse(body.to_s)
  rescue JSON::ParserError
    body.to_s
  end

  def at_least_one_url
    errors.add(:urls, "must include at least one address") if url_list.empty?
    errors.add(:urls, "cannot list more than 60 addresses") if url_list.size > 60
  end

  # Refuse a bad address at the point it is SET, not when a visitor loads the
  # page. The check is the parse-and-resolve half of the fetch guard, so a
  # private address is rejected while the person who typed it is still here.
  def urls_are_fetchable
    url_list.each do |u|
      uri = URI.parse(u)
      next errors.add(:urls, "#{u} is not an https address") unless uri.is_a?(URI::HTTP) && uri.scheme == "https"
      next errors.add(:urls, "#{u} has no host") if uri.host.blank?
    rescue URI::InvalidURIError
      errors.add(:urls, "#{u} is not a valid address")
    end
  end
end
