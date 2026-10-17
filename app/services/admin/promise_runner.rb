require "open3"
require "json"

module Admin
  # Runs a revision's standing promises against the rendered site.
  #
  # The scripts are JavaScript evaluated inside the real page, so the browser is
  # the sandbox -- they cannot reach the server, the database or the filesystem.
  # Every promise for a page is checked in one page load.
  class PromiseRunner
    def initialize(revision) = @revision = revision

    # @param only [Array<String>] page slugs to check; all pages if omitted
    def call(only: nil)
      promises = @revision.promises.to_a
      return [] if promises.empty?

      by_page = promises.group_by(&:page_slug)
      slugs   = by_page.keys.compact
      slugs  &= Array(only) if only

      results = []

      # A promise with no page applies everywhere, so it runs against each page
      # being checked rather than once.
      (slugs.presence || default_slugs(only)).each do |slug|
        applicable = by_page.fetch(slug, []) + by_page.fetch(nil, [])
        next if applicable.empty?

        results.concat(run_against(slug, applicable))
      end

      results
    end

    private

    def default_slugs(only)
      scope = @revision.pages.order(:position)
      only ? scope.where(slug: only).pluck(:slug) : scope.limit(3).pluck(:slug)
    end

    def run_against(slug, promises)
      payload = promises.map { |p| { id: p.id, summary: p.summary, script: p.script } }
      base    = ENV.fetch("SITE_URL", "http://localhost:3000")
      url     = "#{base}/#{slug == 'home' ? '' : slug}?preview=#{@revision.preview_token}"

      out, err, status = Open3.capture3(
        "node", Rails.root.join("script/visual_check.mjs").to_s, url,
        "--promises=#{payload.to_json}"
      )
      unless status.success?
        return promises.map { |p| failure(p, slug, "the page could not be opened: #{err.lines.first}") }
      end

      data = JSON.parse(out) rescue nil
      return promises.map { |p| failure(p, slug, "the browser returned nothing usable") } if data.nil?

      Array(data["promises"]).map do |r|
        { promise_id: r["id"], summary: r["summary"], page: slug,
          pass: r["pass"], message: r["message"], broken: r["broken"] }
      end
    end

    def failure(promise, slug, message)
      { promise_id: promise.id, summary: promise.summary, page: slug,
        pass: false, message: message, broken: true }
    end
  end
end
